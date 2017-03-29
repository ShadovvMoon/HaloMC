//
//  ZZCELobby.m
//  CustomEditionLobby
//
//  Created by Paul Whitcomb on 7/30/16.
//  Copyright © 2016 Zero2. All rights reserved.
//

#import "ZZCELobby.h"
#import "mach_override.h"

static const char *lobby_ce = "halom";
static const char *version = "01.00.10.0621";
static const char *natneg1 = "natneg1.hosthpc.com";
static const char *natneg2 = "natneg2.hosthpc.com";
static const char *ms = "s1.ms01.hosthpc.com";
static const char *ui = "levels\\ce\\ce";

@implementation ZZCELobby

- (id)initWithMode:(MDPluginMode)mode {
    self = [super init];
    if(self) {
        NSURL *ce = [[NSBundle bundleWithIdentifier:@"com.protonnebula.CustomEditionLobby"] URLForResource:@"ce" withExtension:@"map"];
        NSURL *ce_dest = [NSURL fileURLWithPath:[[[[[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"HaloMD"] stringByAppendingPathComponent:@"GameData"] stringByAppendingPathComponent:@"Maps"] stringByAppendingPathComponent:@"ce.map"]];
        
        if ([[NSFileManager defaultManager] isReadableFileAtPath:[ce path]] && [[NSFileManager defaultManager] isReadableFileAtPath:[ce_dest path]] == NO) {
            [[NSFileManager defaultManager] copyItemAtURL:ce toURL:ce_dest error:nil];
            NSLog(@"Copied ce.map");
        }
        
        void *a = (void *)0x2E5000;
        mprotect(a,0x79000,PROT_READ | PROT_WRITE);
        
        char *ui_old = (char *)0x32D598; //levels\ui\ui
        strcpy(ui_old, ui);
        
        char *v_old_1 = (char *)0x32D37C; //01.00.09.0620
        strcpy(v_old_1, version);
        
        char *v_old_2 = (char *)0x323B14; //01.00.09.0620
        strcpy(v_old_2, version);
        
        char *v_old_3 = (char *)0x332BF8; //01.00.09.0620
        strcpy(v_old_3, version);
        
        char *l_old = (char *)0x332FC0; //halor
        strcpy(l_old, lobby_ce);
        
        char *ms_old = (char *)0x38BF5B; //s1<0>ms%d.gamespy.com
        strcpy(ms_old, ms);
        
        char *nn1_old = (char *)0x3867A6; //natneg1.gamespy.com
        strcpy(nn1_old, natneg1);
        
        char *nn2_old = (char *)0x3867C0; //natneg2.gamespy.com
        strcpy(nn2_old, natneg2);
        
        mprotect(a, 0x79000,PROT_READ | PROT_EXEC);
        
        void *b = (void *)0x155000;
        mprotect(b, 0x1000, PROT_READ | PROT_WRITE);
        
        void *check_if_map_is_present = (void *)(0x1557B2);
        memset(check_if_map_is_present,0x90,4);
        
        mprotect(b, 0x1000, PROT_READ | PROT_EXEC);
        
        void *c = (void *)0x231000;
        mprotect(c,0x12000,PROT_READ | PROT_WRITE);
        
        *(uint32_t *)(0x237E24) = 808529456;
        *(uint8_t *)(0x237E33) = 0x31;
        
        mprotect(c,0x12000,PROT_READ | PROT_EXEC);
        
        mach_override_ptr((void *)0xe62d4, (const void *)interceptTick, (void **)&onTick);
    }
    return self;
}

static void *(*onTick)(uint32_t q) = NULL;
static void *interceptTick(uint32_t q) {
    void *a = *(void **)0x3d50f4;
    if(a != NULL) {
        *(uint32_t *)(a+4) = 100;
    }
    return onTick(q);
}

- (void)mapDidBegin:(NSString *)mapName {}
- (void)mapDidEnd:(NSString *)mapName {}

@end
