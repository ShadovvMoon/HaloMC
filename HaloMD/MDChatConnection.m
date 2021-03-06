/*
 * Copyright (c) 2014, Null <foo.null@yahoo.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this
 * list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright notice, this
 * list of conditions and the following disclaimer in the documentation and/or
 * other materials provided with the distribution.
 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "MDChatConnection.h"

#import "XMPPJID.h"
#import "XMPPAnonymousAuthentication.h"
#import "XMPPStream.h"
#import "XMPPRoomMemoryStorage.h"
#import "XMPPRoom.h"
#import "XMPPMessage+XEP0045.h"
#import "XMPPReconnect.h"

#define XMPP_HOST_NAME @"gekko.macgamingmods.com"
#define XMPP_ROOM_HOST @"conference.gekko.macgamingmods.com"
#define XMPP_ROOM_NAME @"halomd"
#define XMPP_RESOURCE @"md"

@interface MDChatConnection ()

@property (nonatomic) XMPPStream *stream;
@property (nonatomic) XMPPReconnect *reconnect;
@property (nonatomic) XMPPRoom *room;
@property (nonatomic) NSUInteger chancesLeftToJoin;
@property (nonatomic) NSString *desiredNickname;
@property (nonatomic) NSUInteger nicknameTag;

@end

@implementation MDChatConnection

- (id)initWithNickname:(NSString *)nickname userIdentifier:(NSString *)userIdentifier delegate:(id <MDChatConnectionDelegate>)delegate;
{
	self = [super init];
	if (self != nil)
	{
		_desiredNickname = [nickname copy];
		_nickname = _desiredNickname;
		_userIdentifier = [userIdentifier copy];
		_delegate = delegate;
		_chancesLeftToJoin = 5;
		_nicknameTag = 1;
	}
	return self;
}

- (void)dealloc
{
	[self disconnect];
}

- (NSString *)dateFormat
{
	NSDateFormatter *formatter = [[NSDateFormatter alloc] initWithDateFormat:@"%I:%M:%S" allowNaturalLanguage:NO];
	//NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	//[formatter setDateFormat:@"%I:%M:%S"];
	return [formatter stringFromDate:[NSDate date]];
}

- (NSString *)prependCurrentDateToMessage:(NSString *)message
{
	return [NSString stringWithFormat:@"%@ %@", [self dateFormat], message];
}

- (BOOL)joinRoom
{
	if (!_stream.isConnected)
	{
		[_delegate processMessage:[self prependCurrentDateToMessage:@"Connecting to server..."] type:@"connection_initiating" nickname:nil text:nil];
		
		_stream = [[XMPPStream alloc] init];
		[_stream addDelegate:self delegateQueue:dispatch_get_main_queue()];
		_stream.hostName = XMPP_HOST_NAME;
		_stream.myJID = [XMPPJID jidWithUser:_userIdentifier domain:XMPP_HOST_NAME resource:XMPP_RESOURCE];
		
		_reconnect = [[XMPPReconnect alloc] init];
		if (![_reconnect activate:_stream])
		{
			return NO;
		}
		
		[_reconnect manualStart];
	}
	
	[_room joinRoomUsingNickname:_nickname history:nil];
	
	return YES;
}

- (void)xmppStreamConnectDidTimeout:(XMPPStream *)sender
{
	NSLog(@"Error: Timed out connecting to server..");
}

- (BOOL)xmppReconnect:(XMPPReconnect *)sender shouldAttemptAutoReconnect:(SCNetworkReachabilityFlags)reachabilityFlags
{
	[_delegate processMessage:[self prependCurrentDateToMessage:@"Reconnecting to server..."] type:@"connection_reconnect" nickname:nil text:nil];
	return YES;
}

- (void)leaveRoom
{
	[_room deactivate]; // this will leave the room
	[_room removeDelegate:self];
}

- (void)disconnect
{
	[_stream disconnect];
	[_stream removeDelegate:self];
}

- (BOOL)isInRoom
{
	return _room.isJoined;
}

- (void)reauthenticateWithUserID:(NSString *)newUserID
{
	_stream.myJID = [XMPPJID jidWithUser:newUserID domain:XMPP_HOST_NAME resource:XMPP_RESOURCE];
	[self authenticate];
}

- (void)authenticate
{
	NSError *error = nil;
	// -[XMPPStream authenticateAnonymously:] which uses SASL ANONYMOUS authentication may use a randomized JID from the server, which is not desirable
	
	BOOL operationInProgress = [_stream authenticate:[[XMPPDigestMD5Authentication alloc] initWithStream:_stream password:[@"password" stringByAppendingFormat:@"%u", arc4random()]] error:&error];
	if (!operationInProgress)
	{
		//NSLog(@"We failed to authenticate..: %@", error);
	}
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
	[self authenticate];
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
	//NSLog(@"Error: Disconnected: %@", error);
	[_delegate processMessage:[self prependCurrentDateToMessage:@"Disconnected from server..."] type:@"connection_disconnected" nickname:nil text:nil];
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	_room = [[XMPPRoom alloc] initWithRoomStorage:[[XMPPRoomMemoryStorage alloc] init] jid:[XMPPJID jidWithUser:XMPP_ROOM_NAME domain:XMPP_ROOM_HOST resource:XMPP_RESOURCE]];
	
	[_room addDelegate:self delegateQueue:dispatch_get_main_queue()];
	[_room activate:_stream];
	
	[self joinRoom];
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
	[_delegate processMessage:[self prependCurrentDateToMessage:@"Failed to authenticate to the server. Trying again..."] type:@"auth_failed" nickname:nil text:nil];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveError:(id)error
{
	NSLog(@"Received xmpp stream error: %@", error);
}

- (void)xmppRoom:(XMPPStream *)sender didReceiveError:(NSXMLElement *)error
{
	NSString *errorType = [error attributeForName:@"type"].objectValue;
	if ([errorType isKindOfClass:[NSString class]])
	{
		if ([errorType isEqualToString:@"cancel"])
		{
			_nickname = [_desiredNickname stringByAppendingFormat:@"%lu", ++_nicknameTag];
			[self joinRoom];
		}
		else if ([errorType isEqualToString:@"auth"])
		{
			NSString *messageToUser = nil;
			if ([error elementForName:@"forbidden"] != nil)
			{
				NSString *text = [error elementForName:@"text"].objectValue;
				if (text != nil)
				{
					messageToUser = text;
				}
				else
				{
					messageToUser = @"You are not authorized to join this room.";
				}
			}
			else
			{
				messageToUser = @"You are unable to join this room for an unknown reason.";
			}
			
			if (_showJIDOnBan)
			{
				messageToUser = [messageToUser stringByAppendingFormat:@" (IDENT = %@)", _userIdentifier];
			}
			
			[_delegate processMessage:[self prependCurrentDateToMessage:messageToUser] type:@"failed_room_auth" nickname:nil text:nil];
		}
		else
		{
			NSLog(@"Encountered unhandled room error: %@", error);
		}
	}
	else
	{
		NSLog(@"Error: Encountered unknown type of room error: %@", error);
	}
}

- (void)xmppRoom:(XMPPRoom *)sender occupantChangedNickname:(XMPPJID *)occupant withPresence:(XMPPPresence *)presence
{
	if ([presence.type isEqualToString:@"unavailable"])
	{
		NSXMLElement *x = [presence elementForName:@"x" xmlns:XMPPMUCUserNamespace];
		NSXMLElement *item = [x elementForName:@"item"];
		id nickname = [item attributeForName:@"nick"].objectValue;
		if ([nickname isKindOfClass:[NSString class]])
		{
			NSString *message = nil;
			if ([occupant.resource isEqualToString:_nickname])
			{
				message = [NSString stringWithFormat:@"You changed your nickname to %@", nickname];
				_nickname = [nickname copy];
			}
			else
			{
				message = [NSString stringWithFormat:@"%@ changed their nickname to %@", occupant.resource, nickname];
			}
			
			[_delegate processMessage:[self prependCurrentDateToMessage:message] type:@"muc_nick_change" nickname:occupant.resource text:nickname];
		}
	}
}

- (void)xmppRoomDidJoin:(XMPPRoom *)sender
{
	_nickname = [_room.myNickname copy];
	[_delegate processMessage:[self prependCurrentDateToMessage:@"You joined the chat..."] type:@"muc_joined" nickname:_nickname text:nil];
}

- (void)xmppRoom:(XMPPRoom *)sender occupantDidJoin:(XMPPJID *)occupantJID withPresence:(XMPPPresence *)presence
{
	NSString *senderName = occupantJID.resource;
	
	[_delegate processMessage:[self prependCurrentDateToMessage:[NSString stringWithFormat:@"<%@> joined", senderName]] type:@"on_join" nickname:senderName text:presence.status];
}

- (void)xmppRoom:(XMPPRoom *)sender occupantDidLeave:(XMPPJID *)occupantJID withPresence:(XMPPPresence *)presence
{
	NSString *senderName = occupantJID.resource;
	
	[_delegate processMessage:[self prependCurrentDateToMessage:[NSString stringWithFormat:@"<%@> left", senderName]] type:@"on_leave" nickname:senderName text:presence.status];
}

- (void)xmppRoom:(XMPPRoom *)sender occupantDidUpdate:(XMPPJID *)occupantJID withPresence:(XMPPPresence *)presence
{
	NSString *senderName = occupantJID.resource;
	[_delegate processMessage:[self prependCurrentDateToMessage:@""] type:@"on_join" nickname:senderName text:presence.status];
}

- (void)xmppStream:(XMPPStream *)stream didReceivePresence:(XMPPPresence *)presence
{
	NSString *type = presence.type;
	
	if ([type isEqualToString:@"unavailable"])
	{
		NSXMLElement *x = [presence elementForName:@"x" xmlns:XMPPMUCUserNamespace];
		NSXMLElement *item = [x elementForName:@"item"];
		NSString *affiliation = [item attributeForName:@"affiliation"].objectValue;
		NSString *status = [[x elementForName:@"status"] attributeForName:@"code"].objectValue;
		if ([affiliation isKindOfClass:[NSString class]] && [status isKindOfClass:[NSString class]])
		{
			static const int banID = 301;
			static const int kickID = 307;
			
			int statusValue = [status intValue];
			if (statusValue == banID || statusValue == kickID)
			{
				NSString *leaveAction = nil;
				if ([affiliation isEqualToString:@"none"])
				{
					leaveAction = @"kicked";
				}
				else if ([affiliation isEqualToString:@"outcast"])
				{
					leaveAction = @"banned";
				}
				
				if (leaveAction != nil)
				{
					XMPPJID *from = presence.from;
					BOOL isItMe = [from isEqualToJID:[XMPPJID jidWithUser:XMPP_ROOM_NAME domain:XMPP_ROOM_HOST resource:_nickname]];
					
					NSString *reason = [item elementForName:@"reason"].objectValue;
					NSString *messageToUser = [NSString stringWithFormat:@"%@ %@ been %@ from this room.", (isItMe ? @"You" : from.resource), (isItMe ? @"have" : @"has"), leaveAction];
					
					if ([reason isKindOfClass:[NSString class]] && reason.length > 0)
					{
						messageToUser = [messageToUser stringByAppendingFormat:@" Reason: %@", reason];
					}
					
					[_delegate processMessage:[self prependCurrentDateToMessage:messageToUser] type:@"removed" nickname:nil text:nil];
				}
			}
		}
	}
	else
	{
		NSXMLElement *x = [presence elementForName:@"x" xmlns:XMPPMUCUserNamespace];
		NSXMLElement *item = [x elementForName:@"item"];
		
		NSString *roleValue = [item attributeForName:@"role"].objectValue;
		if ([roleValue isKindOfClass:[NSString class]] && [@[@"visitor", @"participant"] containsObject:roleValue])
		{
			XMPPJID *from = presence.from;
			BOOL isItMe = [from isEqualToJID:[XMPPJID jidWithUser:XMPP_ROOM_NAME domain:XMPP_ROOM_HOST resource:_nickname]];
			
			NSString *action = [roleValue isEqualToString:@"visitor"] ? @"muted" : @"unmuted";
			NSString *reason = [item elementForName:@"reason"].objectValue;
			NSString *messageToUser = [NSString stringWithFormat:@"%@ %@ been %@ from this room.", (isItMe ? @"You" : from.resource), (isItMe ? @"have" : @"has"), action];
			
			if ([reason isKindOfClass:[NSString class]] && reason.length > 0)
			{
				messageToUser = [messageToUser stringByAppendingFormat:@" Reason: %@", reason];
			}
			
			[_delegate processMessage:[self prependCurrentDateToMessage:messageToUser] type:@"voice" nickname:from.resource text:roleValue];
		}
	}
}

- (void)xmppRoomDidLeave:(XMPPRoom *)room
{
	if (_stream.isConnected)
	{
		[_delegate processMessage:[self prependCurrentDateToMessage:@"You left the room."] type:@"on_self_leave" nickname:nil text:nil];
	}
}

- (void)xmppRoom:(XMPPRoom *)sender didReceiveMessage:(XMPPMessage *)message fromOccupant:(XMPPJID *)occupantJID
{
	NSString *senderName = occupantJID.resource;
	
	NSString *messageType = ([senderName isEqualToString:_nickname]) ? @"my_message" : @"on_message";
	
	NSString *body = message.body;
	if ([body rangeOfString:@"\n" options:NSLiteralSearch | NSCaseInsensitiveSearch].location != NSNotFound)
	{
		body = [@"\n" stringByAppendingString:body];
	}
	
	[_delegate processMessage:[self prependCurrentDateToMessage:[NSString stringWithFormat:@"<%@> %@", senderName, body]] type:messageType nickname:senderName text:body];
}

- (void)xmppRoom:(XMPPRoom *)sender didReceiveSubject:(NSString *)subject
{
	_subject = [subject copy];
	[_delegate processMessage:[self prependCurrentDateToMessage:[NSString stringWithFormat:@"Topic is: %@", _subject]] type:@"on_subject" nickname:nil text:_subject];
}

- (BOOL)sendMessage:(NSString *)message
{
	if (self.isInRoom)
	{
		[_room sendMessageWithBody:message];
		return YES;
	}
	
	return NO;
}

- (void)sendPrivateMessage:(NSString *)message toUser:(NSString *)nickname
{
	XMPPMessage *xmppMessage = [XMPPMessage message];
	
	[xmppMessage addBody:message];
	[xmppMessage addAttributeWithName:@"type" stringValue:@"chat"];
	[xmppMessage addAttributeWithName:@"to" stringValue:[[XMPPJID jidWithUser:XMPP_ROOM_NAME domain:XMPP_ROOM_HOST resource:nickname] full]];
	
	[_stream sendElement:xmppMessage];
	
	[_delegate processMessage:[self prependCurrentDateToMessage:[NSString stringWithFormat:@"Private: <to %@>: %@", nickname, message]] type:@"my_private_message" nickname:_nickname text:message];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	if ([message isChatMessageWithBody])
	{
		NSString *sender = message.from.resource;
		[_delegate processMessage:[self prependCurrentDateToMessage:[NSString stringWithFormat:@"Private: <%@> %@", sender, message.body]] type:@"on_private_message" nickname:sender text:message.body];
	}
}

- (void)setStatus:(NSString *)status
{
	XMPPPresence *presence = [XMPPPresence presence];
	
	[presence addAttributeWithName:@"from" stringValue:_stream.myJID.full];
	[presence addAttributeWithName:@"to" stringValue:[[XMPPJID jidWithUser:XMPP_ROOM_NAME domain:XMPP_ROOM_HOST resource:_nickname] full]];
	[presence addAttributeWithName:@"id" stringValue:[_stream generateUUID]];
	
	[presence addChild:[NSXMLElement elementWithName:@"status" stringValue:status]];
	
	// have to notify ourselves of our own status update
	[_delegate processMessage:[self prependCurrentDateToMessage:@""] type:@"on_join" nickname:_nickname text:status];
	
	[_stream sendElement:presence];
}

@end
