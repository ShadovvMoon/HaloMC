//
//  AspectRatioFixer.m
//  Aspect Ratio FOV Fixer
//
//  Created by Paul Whitcomb on 12/27/14.
//  Copyright (c) 2014 Zero2. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AspectRatioFixer.h"
#import "mach_override.h"
#import "HaloMemoryStructs.h"

#define FIELD_OF_VIEW_CONSTANT (70.0 * M_PI / 180.0);

@implementation AspectRatioFixer

MDPluginMode currentMode;
bool active = false;

-(id)initWithMode:(MDPluginMode)mode {
    self = [super init];
    if(self) {
        currentMode = mode;
        mach_override_ptr((void *)0xc8f94, haloTickBefore, (void **)&haloTick);
        mach_override_ptr((void *)0x11e3de, interceptCommand, (void **)&runCommand);
    }
    return self;
}

static uint32_t *width = (uint32_t *)(0x37C400);
static uint32_t *height = (uint32_t *)(0x37C404);

static float forceFOV = 0.0;
bool autoFOV = true;


static void *(*haloprintf)(ColorARGB *color, const char *message, ...) = (void *)0x1588a8;
static void (*runCommand)(const char *command,const char *error_result,const char *command_name) = NULL;
static void interceptCommand(const char *command,const char *error_result, const char *command_name)
{
    static ColorARGB yellow = { 1, 1, 1, 0 };
    static ColorARGB red = { 1, 1, 0, 0 };
    NSArray *array_command = [[NSString stringWithUTF8String:command] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if([array_command count] >= 1) {
        NSString *command = [[array_command objectAtIndex:0] lowercaseString];
        if([command isEqualToString:@"fov"]) {
            if([array_command count] == 1) {
                if(autoFOV) {
                    NSString *fov = [NSString stringWithFormat:@"FOV: auto (%.1f degrees)",calculateFOV() / M_PI * 180.0];
                    haloprintf(&yellow,"%s",[fov UTF8String]);
                }
                else {
                    haloprintf(&yellow,[[NSString stringWithFormat:@"Current FOV: %.1f degrees",forceFOV]UTF8String]);
                }
                haloprintf(&yellow,"Valid FOVs: <degrees>, auto");
            }
            else if([array_command count] == 2) {
                NSString *sec = [[array_command objectAtIndex:1]lowercaseString];
                autoFOV = false;
                if([sec isEqualToString:@"auto"] ) {
                    autoFOV = true;
                    haloprintf(&yellow,[[NSString stringWithFormat:@"Changed FOV to auto"] UTF8String]);
                }
                else {
                    forceFOV = [sec floatValue];
                    haloprintf(&yellow,"%s",[[NSString stringWithFormat:@"Changed FOV to %.1f",forceFOV] UTF8String]);
                    if(forceFOV >= 180 || forceFOV <= 0) {
                        haloprintf(&red,"Warning: You may experience issues with this FOV.");
                    }
                }
            }
        }
    }
    return runCommand(command,error_result,command_name);
}
static float verticalFieldOfView = 0;

static float calculateFOV() {
    if(verticalFieldOfView == 0.0) {
        verticalFieldOfView = 2.0 * atan(tan(70.0 * M_PI / 180.0 / 2.0) * (3.0/4.0));
    }
    return 2.0 * atan(tan(verticalFieldOfView / 2.0) * *width / *height);
}

static void (*haloTick)(void *a, void *b) = NULL;
static void haloTickBefore(void *a, void *b) {
    haloTick(a,b);
    if(active) {
        float wantedFov = *(float *)(0x3B18B0);
        float baseFOV = FIELD_OF_VIEW_CONSTANT;
        
        uint16_t playerid = *(uint16_t *)0x402AD404;
        if(playerid < 0x10) {
            struct Player *player = GetPlayer(playerid);
            if(player->objectId.objectTableIndex != 0xFFFF) {
                struct BaseObject *baseobject = ObjectFromObjectId(player->objectId);
                void *object_data = *(void **)(*(void **)(0x40440000) + 0x20 * baseobject->tagId.tagTableIndex + 0x14);
                if(*(uint16_t *)(object_data) < 2) {
                    float *fov = (float *)(object_data + 0x1A0);
                    if(*fov != baseFOV) {
                        *fov = baseFOV;
                    }
                }
            }
        }
        
        float divisor = baseFOV / wantedFov;
        
        if(*(uint8_t *)(0x3B16BE) ==3 ) {
            divisor = 1.0;
        }
        
        float fieldOfViewCustom;
        if(autoFOV) {
            fieldOfViewCustom = calculateFOV();
        }
        else {
            fieldOfViewCustom = forceFOV * M_PI / 180.0;
        }
        
        float fieldOfView = fieldOfViewCustom / divisor;
        *(float *)(0x3B1890) = fieldOfView;
    }
}

-(void)mapDidBegin:(NSString *)mapName {
    active=true;
}
-(void)mapDidEnd:(NSString *)mapName {
    active = false;
}

@end
