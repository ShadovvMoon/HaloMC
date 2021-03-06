// Syntax: master_server [ip address (0.0.0.0 by default)]
// This was created for HaloMD.

// If the server does not respond in at least this many seconds, it will be dropped from the list.
const DROP_TIME : i64 = 60;

// Blacklist for blocking IPs. Separate with newlines. Any line that starts with a # is ignored.
// Blacklisting IPs ignores heartbeat and keepalive packets from an IP address.
// That means that servers that are banned will not be immediately removed, but will time out, instead.
const BLACKLIST_FILE : &'static str = "blacklist.txt";

// Read the blacklist every x amount of seconds.
const BLACKLIST_UPDATE_TIME : u64 = 60;

// Note: The master server must have TCP 29920 open and UDP 27900 open.
const BROADCAST_PORT_UDP : u16 = 27900;
const SERVER_LIST_PORT_TCP : u16 = 29920;

// Opcode info from game packets
const OPCODE_INDEX : usize = 0;
const OPCODE_AND_HANDSHAKE_LENGTH : usize = 5;

// Broadcast packet type opcodes.
const KEEPALIVE : u8 = 8;
const HEARTBEAT : u8 = 3;

const TCP_SERVER_THREAD_NAME : &'static str = "halomd_thread";
const DESTRUCTION_THREAD_NAME : &'static str = "destruction_thread";
const BLACKLIST_THREAD_NAME : &'static str = "blacklist_thread";

use std::net::{UdpSocket,TcpListener,SocketAddr};
use std::net::SocketAddr::{V4,V6};
use std::io::{Write,BufReader,BufRead};
use std::env;
use std::fs::File;
use std::thread;
use std::thread::Builder;
use std::sync::{Arc, Mutex};
use std::collections::HashMap;
use std::time::Duration;

extern crate time;
use time::{SteadyTime,Duration as TimeDuration};

mod error_macros;

mod halo_server;
use halo_server::HaloServer;

mod heartbeat_packet;
use heartbeat_packet::{HeartbeatPacket,GAMEEXITED,VALID_GAME_VERSIONS,HALO_RETAIL};

trait IPString {
    fn ip_string(&self) -> String;
}

impl IPString for SocketAddr {
    fn ip_string(&self) -> String {
        match *self {
            V4(ipv4) => ipv4.ip().to_string(),
            V6(ipv6) => "[".to_owned() + &ipv6.ip().to_string() + "]"
        }
    }
}

fn main() {
    let count = env::args().count();
    let ip = if count == 2 {
        let args : Vec<_> = env::args().collect();
        args[1].to_owned()
    }
    else if count == 1 {
        "0.0.0.0".to_owned()
    }
    else {
        println!("Only one argument is allowed: the IP to bind to.");
        return;
    };

    // We need to bind on two different ports. If it failed to bind (invalid IP, port is taken), then we must make sure this is known.
    let halo_socket = unwrap_result_or_bail!(UdpSocket::bind((&ip as &str,BROADCAST_PORT_UDP)), {
        println!("Failed creating a UDP socket at {}:{}.",ip,BROADCAST_PORT_UDP);
        return;
    });

    let client_socket = unwrap_result_or_bail!(TcpListener::bind((&ip as &str,SERVER_LIST_PORT_TCP)), {
        println!("Failed listening to TCP at {}:{}.",ip,SERVER_LIST_PORT_TCP);
        return;
    });

    // Mutex for thread safety.
    let servers_halo: Vec<HaloServer> = Vec::new();
    let servers_mut_udp = Arc::new(Mutex::new(servers_halo));
    let servers_mut_tcp = servers_mut_udp.clone();
    let servers_mut_destruction = servers_mut_udp.clone();

    // Destruction thread. This will remove servers that have not broadcasted their presence in a while.
    let _ = Builder::new().name(DESTRUCTION_THREAD_NAME.to_owned()).spawn(move || {
        loop {
            thread::sleep(Duration::from_secs(10));
            let mut servers = servers_mut_destruction.lock().unwrap();
            let timenow = SteadyTime::now();
            servers.retain(|x| x.last_alive + TimeDuration::seconds(DROP_TIME) > timenow);
        }
    });

    // Blacklist mutex. Concurrency needs to be safe, my friend.
    let blacklist_update = Arc::new(Mutex::new(None as Option<HashMap<String, Option<Vec<u16>>>>));
    let blacklist_udp = blacklist_update.clone();

    // Takes a line fed from the blacklist file which is in the format:
    // ip_address \t port1, port2, port3,...
    // and returns a tuple of the IP and ports
    // If no ports are specified, then all ports are considered (should act like a wildcard)
    fn blacklist_info(line: &str) -> (String, Option<Vec<u16>>) {
        let components: Vec<&str> = line.split("\t").map(|x| x.trim()).collect();

        if components.len() <= 1 {
            (line.to_owned(), None)
        }
        else {
            let ports: Vec<u16> = components[1].split(",").flat_map(|x| x.trim().parse::<u16>().ok()).collect();
            (components[0].to_owned(), Some(ports))
        }
    }

    // Blacklist read thread.
    let _ = Builder::new().name(BLACKLIST_THREAD_NAME.to_owned()).spawn(move || {
        let valid_line = |x: &str| -> bool { x.trim().len() > 0 && !x.starts_with("#") };
        loop {
            // Placed in a block so blacklist is unlocked before sleeping to prevent threads from being locked for too long.
            {
                let mut blacklist_ref = blacklist_update.lock().unwrap();
                *blacklist_ref =
                    File::open(BLACKLIST_FILE).
                    map(|file|
                        BufReader::new(&file).lines().
                        filter_map(|line| line.ok().and_then(|x| if valid_line(&x) { Some(blacklist_info(&x)) } else { None })).
                        collect()
                    ).ok();
            }
            thread::sleep(Duration::from_secs(BLACKLIST_UPDATE_TIME));
        }
    });

    // TCP server thread. This is for the HaloMD application.
    let _ = Builder::new().name(TCP_SERVER_THREAD_NAME.to_owned()).spawn(move || {
        loop {
            for stream in client_socket.incoming() {
                let mut client = unwrap_option_or_bail!(stream.ok(), { continue });
                let ip = unwrap_option_or_bail!(client.peer_addr().ok(), { continue }).ip_string();
                let mut ips = String::new();

                // Make servers_ref go out of scope to unlock it for other threads, since we don't need it.
                {
                    let servers_ref = servers_mut_tcp.lock().unwrap();
                    let servers = (*servers_ref).iter();

                    for j in servers {
                        ips.push_str(&(j.to_string()));
                        ips.push('\n');
                    }
                }

                // Some number placed after the requester's IP. If you ask me, the source code was abducted by aliens, and this is a tracking number. Regardless, it's needed.
                ips.push_str(&ip);
                ips.push_str(":49149:3425");

                // We may be here a while. Just in case...
                // May want to consider some lightweight thread library in the future, or some non-blocking polling mechanism
                thread::spawn( move || {
                    let _ = client.write_all(ips.as_bytes());
                });
            }
        }
    });

    // UDP server is run on the main thread. Servers broadcast their presence here.

    let mut buffer = [0; 2048];
    loop {
        let (length, source) = unwrap_option_or_bail!(halo_socket.recv_from(&mut buffer).ok(), { continue });

        if length <= OPCODE_INDEX {
            continue;
        }

        if buffer[OPCODE_INDEX] != KEEPALIVE && buffer[OPCODE_INDEX] != HEARTBEAT {
            continue;
        }

        let client_ip = source.ip_string();

        let blacklist_ref = blacklist_udp.lock().unwrap();
        let ignore_host = match *blacklist_ref {
            Some(ref blacklist) => {
                match (*blacklist).get(&client_ip) {
                    Some(ports_opt) => {
                        match *ports_opt {
                            Some(ref ports) => ports.contains(&source.port()), // ignore if port is blacklisted
                            None => true // wildcard for all ports
                        }
                    },
                    None => false // no IP was found
                }
            },
            None => false // no blacklist available
        };

        if ignore_host {
            continue;
        }

        // Heartbeat packet. These contain null-terminated C strings and are ordered in key1[0]value1[0]key2[0]value2[0]key3[0]value3[0] where [0] is a byte equal to 0x00.
        if buffer[OPCODE_INDEX] == HEARTBEAT && length > OPCODE_AND_HANDSHAKE_LENGTH {
            let mut servers = servers_mut_udp.lock().unwrap();

            match HeartbeatPacket::from_buffer(&buffer[OPCODE_AND_HANDSHAKE_LENGTH..length]) {
                None => {},
                Some(packet) => {
                    let updatetime = SteadyTime::now();
                    match servers.iter_mut().position(|x| *x == (&client_ip, packet.localport)) {
                        None => {
                            if packet.gamename == HALO_RETAIL && VALID_GAME_VERSIONS.contains(&&*packet.gamever) {
                                (*servers).push(HaloServer { ip:client_ip, port: packet.localport, last_alive: updatetime });
                            }
                        }
                        Some(k) => {
                            servers[k].last_alive = updatetime;
                            if packet.statechanged == GAMEEXITED {
                                servers.remove(k);
                            }
                        }
                    };
                }
            };
        }

        // Keepalive packet. We need to rely on the origin's port for this, unfortunately. This may mean that the source port is incorrect if the port was changed with NAT.
        else if buffer[OPCODE_INDEX] == KEEPALIVE {
            let mut servers_ref = servers_mut_udp.lock().unwrap();
            let servers = (*servers_ref).iter_mut();

            for i in servers {
                if *i == (&client_ip, source.port()) {
                    i.last_alive = SteadyTime::now();
                    break;
                }
            }
        }
    }
}
