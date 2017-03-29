//
//  SMHaloHUD.m
//  HaloHUD
//
//  Created by Samuco on 11/23/13.
//  Copyright (c) 2013. All rights reserved.
//

#import "SMHaloUP.h"
#import "mach_override.h"
#include <wchar.h>

#import <OpenGL/glext.h>
#import <OpenGL/glu.h>
#import <Carbon/Carbon.h>
#import <AGL/AGL.h>

@implementation SMHaloUP

void nop(uint32_t offset, size_t size) {
    int i;
    for (i=0; i < size; i++) {
        *(int8_t  *)(offset + i) = 0x90;
    }
}

#pragma mark TABLE SIZE
void* (*oldcreateTable)(char*name, int count, int size) = NULL;
void* createTable(char*name, int count, int size) {
    void *eax = oldcreateTable(name, count, size);
    NSLog(@"Creating table %s of size %d with count %d at 0x%0x", name, size, count, eax);
    if (count < 2048) {
        //Reallocate this array (2x size!)
        int old_array_length = count*size;
        
        short new_count = count*2;
        short new_size  = size;
        
        int new_array_length = (new_count+1)*new_size;
        void *new_array = malloc(new_array_length);
        memcpy(new_array, eax, old_array_length);
        
        *(int16_t *)(new_array + 0x20) = new_count;
        *(int16_t *)(new_array + 0x22) = new_size;
        *(int8_t  *)(new_array + 0x24) = 0x0;
        *(int32_t *)(new_array + 0x34) = (int32_t)(new_array+0x38);
        
        NSLog(@"Moving 0x%x to 0x%x", (int)eax, (int)new_array);
        return new_array;
    }
    return eax;
}
                         
-(void)increaseTables {
    mach_override_ptr((void *)0x2383a2, createTable, (void **)&oldcreateTable);
}

#pragma mark INTEGRATED GRAPHICS FIX
-(void)integratedGraphics {
    // changes
    // jz short 0x2b3ecd	74 2B
    // to
    // jmp short 0x2b3ecd	EB 2B
    *(uint8_t*)0x2B3EA0 = 0xEB;
}

#pragma mark PIXEL ATTRIBUTES
// This is broken.
-(void)pixelAttributes {
    nop(0x2B39E6, 45);
    uint32_t attrib[] = {
        AGL_RGBA,
        AGL_DEPTH_SIZE, 0x10,
        //0x48, 0x49,
        AGL_DOUBLEBUFFER,
        AGL_MAXIMUM_POLICY,
        AGL_OFFSCREEN,
        AGL_SAMPLE_BUFFERS_ARB, 10,
        AGL_SAMPLES_ARB, 4,
        AGL_SUPERSAMPLE,
        AGL_SAMPLE_ALPHA,
        0
    };
    int size = sizeof(uint32_t) * 20;
    void *attribs = malloc(size);
    memcpy(attribs, attrib, 15);
    *(uint8_t *)0x2B39E6  = 0xb8;
    *(uint8_t**)0x2B39E7 = (uint8_t*)attribs;
}

#pragma mark CPU USAGE
uint32_t (*old_sub_243f48)() = NULL;
uint32_t sub_243f48() {
    ProcessSerialNumber serial; GetFrontProcess(&serial);
    ProcessSerialNumber psn; GetCurrentProcess(&psn);
    if (psn.lowLongOfPSN != serial.lowLongOfPSN) {
        usleep(10000);
    }
    
    return old_sub_243f48();
}
-(void)cpufix {
    mach_override_ptr((void *)0x243f48, sub_243f48, (void **)&old_sub_243f48);
}

#pragma mark EXTRA RESOLUTION
void writeUTF16String(mach_vm_address_t pointerToObject, NSString *message)
{
    NSUInteger numberOfBytes = [message lengthOfBytesUsingEncoding:NSUnicodeStringEncoding];
    void *buffer = malloc(numberOfBytes);
    NSUInteger usedLength = 0;
    NSRange range = NSMakeRange(0, [message length]);
    BOOL result = [message getBytes:buffer maxLength:numberOfBytes usedLength:&usedLength encoding:NSUnicodeStringEncoding options:0 range:range remainingRange:NULL];
    
    if (result) {
        memcpy((void*)pointerToObject, buffer, numberOfBytes);
    }
    
    free(buffer);
}

uint32_t (*old_sub_1eea70)() = NULL;
uint32_t sub_1eea70() {
    
    // Add resolutions above 21
    uint8_t number = *((uint8_t*)0x3D65E0);
    NSScreen *main = [NSScreen mainScreen];
    NSSize max = [[[main deviceDescription] valueForKey:NSDeviceSize] sizeValue];
    
    // Does this resolution exist in the table?
    int i;
    for (i=0; i < number; i++) {
        uint8_t *resolution_pointer = (uint8_t *)(0x3D5C60 + 0x4C * i);
        uint32_t width  = *(uint32_t*)resolution_pointer;
        uint32_t height = *(uint32_t*)(resolution_pointer + 4);
        
        if (width == max.width && height == max.height) {
            // The resolution exists.
            return old_sub_1eea70();
        }
    }
    
    // Add the new resolution
    uint8_t *resolution_pointer = (uint8_t *)(0x3D5C60 + 0x4C * number);
    
    // Reallocate the resolution table
    *(uint32_t*)(resolution_pointer)     = (uint32_t)max.width;
    *(uint32_t*)(resolution_pointer + 4) = (uint32_t)max.height;
    mach_vm_address_t display_text = (mach_vm_address_t)(resolution_pointer + 8);
    memset((void*)display_text, 0, 0x20);
    @autoreleasepool {
        writeUTF16String(display_text, [NSString stringWithFormat:@"%d x %d", (uint32_t)max.width, (uint32_t)max.height]);
    }

    // Random table entries - maybe Hz?
    *(uint32_t*)(resolution_pointer + 0x28) = 1;
    *(uint32_t*)(resolution_pointer + 0x2C) = 0x3C;
    
    // Override the code to compare
    mprotect((void *)0xE0000,0x1FFFFE, PROT_READ|PROT_WRITE);
    
    // Add
    nop(0x175120, 6);
    *(uint8_t*)0x175120 = 0x83;
    *(uint8_t*)0x175121 = 0xFA;
    *(uint8_t*)0x175122 = number+1;
    
    // Sub
    nop(0x1750C2, 7);
    *(uint8_t *)0x1750C2 = 0xB8;
    *(uint32_t*)0x1750C3 = number;
    
    mprotect((void *)0xE0000,0x1FFFFE, PROT_READ|PROT_EXEC);
    
    // Write the new counts
    *((uint8_t*)0x3D65E0) = number + 1;
    return old_sub_1eea70();
}

-(void)extra_resolutions {
    mach_override_ptr((void *)0x1eea70, sub_1eea70, (void **)&old_sub_1eea70);
}

#pragma mark ELCAP WINDOW FIX
-(void)elcap_fix {
    CGDirectDisplayID mainID = CGMainDisplayID(); GDHandle mainDevice;
    DMGetGDeviceByDisplayID(mainID, &mainDevice, true);
    (*(uint32_t*)(*(uint32_t*)*(uint32_t*)((*(uint32_t*)mainDevice) + 0x16) + 0x20)) = 0x20;
}

#pragma mark ANSIOTROPICAL FILTERING
bool aa_enabled;
float fLargest;

void aa_toggle() {
    aa_enabled ? aa_disable() : aa_enable();
}

void aa_enable() {
    glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &fLargest);
    aa_enabled = true;
}

void aa_disable() {
    aa_enabled = false;
}

uint32_t (*old_sub_2e4554)() = NULL;
uint32_t sub_2e4554(uint32_t arg_x0) {
    if (aa_enabled) {
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, fLargest);
    } else {
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, 1.0);
    }
    
    uint32_t val = old_sub_2e4554();
    return val;
}

-(void)ansi {
    mach_override_ptr((void *)0x2e4554, sub_2e4554, (void **)&old_sub_2e4554);
}

#pragma mark BSP BOOST

// Reallocate the BSP table to enable bigger BSPs
-(void)bsp {
    
    uint32_t *objectCacheArrayPointer = (uint32_t*)0x5B5100;
    void* buffer_location = (void*)(*objectCacheArrayPointer);
    int old_array_length = pow(2,16);
    int new_array_length = pow(2,20);
    void *new_array = malloc(new_array_length);
    int array_position = (int)new_array;
    memcpy(new_array, buffer_location, old_array_length);
    memcpy(objectCacheArrayPointer, &array_position, 4);
    
    uint16_t bspLimit = 0xFFF0;
    
    //0x5018b0
    
    
    
    
    *(int32_t *)(0x2305FE + 0) = (int32_t)new_array;
    *(int32_t *)(0x230607 + 0) = (int32_t)new_array+0xC;
    *(int32_t *)(0x23060F + 0) = (int32_t)new_array+0x10;
    *(int32_t *)(0x22FAB5 + 3) = (int32_t)new_array+0x14;
    *(int32_t *)(0x23068A + 0) = (int32_t)new_array+0xA;
    *(int32_t *)(0x2306BF + 3) = (int32_t)new_array+0x14;
    *(int32_t *)(0x2306D3 + 4) = (int32_t)new_array+0x68;
    *(int32_t *)(0x2306E3 + 3) = (int32_t)new_array+0x14;
    *(int32_t *)(0x22FA7A + 2) = (int32_t)new_array+0x4;
    *(int32_t *)(0x2307FB + 4) = (int32_t)new_array+0x68;
    *(int32_t *)(0x23080B + 3) = (int32_t)new_array+0x14;
    *(int32_t *)(0x2305FC + 2) = (int32_t)new_array;
    *(int32_t *)(0x22FA9F + 3) = (int32_t)new_array+0x8;
    *(int32_t *)(0x22FAD0 + 3) = (int32_t)new_array+0x68;
    *(int32_t *)(0x22FB46 + 4) = (int32_t)new_array+0x1F4;
    *(int32_t *)(0x22FC0F + 3) = (int32_t)new_array+0x290;
    *(int32_t *)(0x22FB2A + 3) = (int32_t)new_array+0xA;
    *(int32_t *)(0x22FC9E + 3) = (int32_t)new_array+0x290;
    *(int32_t *)(0x22FCDA + 3) = (int32_t)new_array+0x290;
    *(int32_t *)(0x22FDDE + 4) = (int32_t)new_array+(0x4f4688 - 0x4f4620);
    *(int32_t *)(0x22FDE6 + 3) = (int32_t)new_array+(0x4f4634 - 0x4f4620);
    *(int32_t *)(0x22FE32 + 4) = (int32_t)new_array+(0x4f4814 - 0x4f4620);
    *(int32_t *)(0x22FE54 + 4) = (int32_t)new_array+(0x4f4814 - 0x4f4620);
    *(int32_t *)(0x22FE5C + 3) = (int32_t)new_array+(0x4f4868 - 0x4f4620);
    *(int32_t *)(0x22FE6B + 4) = (int32_t)new_array+(0x4f482c - 0x4f4620);
    *(int32_t *)(0x22FE88 + 4) = (int32_t)new_array+(0x4f4854 - 0x4f4620);
    *(int32_t *)(0x22FD6D + 3) = (int32_t)new_array+(0x4f48b0 - 0x4f4620);
    *(int32_t *)(0x22FDE6 + 3) = (int32_t)new_array+(0x4f4634 - 0x4f4620);
    *(int32_t *)(0x22FE3E + 3) = (int32_t)new_array+(0x4f486e - 0x4f4620);
    *(int32_t *)(0x22FEB4 + 3) = (int32_t)new_array+(0x4f4824 - 0x4f4620);
    *(int16_t *)(0x25FA04) = bspLimit;
    *(int16_t *)(0x25FA45) = bspLimit;
    *(int16_t *)(0x25FA75) = bspLimit;
    *(int8_t  *)(0x25FA06) = 0x7C;
    *(int16_t *)(0x25FA47) = 0x8D0F;
    *(int16_t *)(0x25FA77) = 0x8D0F;
    *(int32_t *)(0x25FA1F) = 0xDB748583;
    *(int8_t  *)(0x25FA06) = 0x77;
    *(int16_t *)(0x25FA47) = 0x820F;
    
    // decal fix
    *(int32_t *)(0x22FD81 + 3) = (int32_t)new_array + 0xd290;
    *(int32_t *)(0x22FC23 + 3) = (int32_t)new_array + 0xd290;
    *(int32_t *)(0x22FCB2 + 3) = (int32_t)new_array + 0xd290;


    
    // CRASH
    /*
     Thread 0 Crashed:: Dispatch queue: com.apple.main-thread
     0   com.null.halominidemo         	0x0019df72 0x1000 + 1691506
     1   com.null.halominidemo         	0x000dae9c 0x1000 + 892572
     2   com.null.halominidemo         	0x002361b1 0x1000 + 2314673
     3   com.null.halominidemo         	0x0022fd3d 0x1000 + 2288957
     4   com.null.halominidemo         	0x00230202 0x1000 + 2290178
     5   com.null.halominidemo         	0x002307bb 0x1000 + 2291643
     6   com.null.halominidemo         	0x001919e6 0x1000 + 1640934
     7   com.null.halominidemo         	0x00192ff2 0x1000 + 1646578 <--
     8   com.null.halominidemo         	0x00244eb2 0x1000 + 2375346
     9   com.null.halominidemo         	0x0000334f 0x1000 + 9039
     10  com.null.halominidemo         	0x000027c6 0x1000 + 6086
     11  com.null.halominidemo         	0x000026ed 0x1000 + 5869
     */
    
    
    /*
     Thread 0 Crashed:: Dispatch queue: com.apple.main-thread
     0   com.null.halominidemo         	0x00236c20 0x1000 + 2317344
     1   com.null.halominidemo         	0x0023632a 0x1000 + 2315050
     2   com.null.halominidemo         	0x0022fd3d 0x1000 + 2288957
     3   com.null.halominidemo         	0x00230202 0x1000 + 2290178
     4   com.null.halominidemo         	0x002307bb 0x1000 + 2291643
     5   com.null.halominidemo         	0x001919e6 0x1000 + 1640934
     6   com.null.halominidemo         	0x00192ff2 0x1000 + 1646578
     7   com.null.halominidemo         	0x00244eb2 0x1000 + 2375346
     8   com.null.halominidemo         	0x0000334f 0x1000 + 9039
     9   com.null.halominidemo         	0x000027c6 0x1000 + 6086
     10  com.null.halominidemo         	0x000026ed 0x1000 + 5869
     
     
     Thread 0 Crashed:: Dispatch queue: com.apple.main-thread
     0   com.null.halominidemo         	0x0019df72 0x1000 + 1691506
     1   com.null.halominidemo         	0x000dae9c 0x1000 + 892572
     2   com.null.halominidemo         	0x002361b1 0x1000 + 2314673
     3   com.null.halominidemo         	0x0022fd3d 0x1000 + 2288957
     4   com.null.halominidemo         	0x00230202 0x1000 + 2290178
     5   com.null.halominidemo         	0x002307bb 0x1000 + 2291643
     6   com.null.halominidemo         	0x001919e6 0x1000 + 1640934
     7   com.null.halominidemo         	0x00192ff2 0x1000 + 1646578
     8   com.null.halominidemo         	0x00244eb2 0x1000 + 2375346
     9   com.null.halominidemo         	0x0000334f 0x1000 + 9039
     10  com.null.halominidemo         	0x000027c6 0x1000 + 6086
     11  com.null.halominidemo         	0x000026ed 0x1000 + 5869
     */
    
    
    
    // EXTEND BSP TO 65535
    /*
    *(int8_t  *)(0x25B066 + 0) = 0x8B;
    *(int32_t *)(0x25B066 + 1) = *(int32_t *)(0x25B066 + 2);
    *(int16_t *)(0x25B066 + 5) = 0x9000;
    *(int8_t  *)(0x25B5B8 + 0) = 0x8B;
    *(int32_t *)(0x25B5B8 + 1) = *(int32_t *)(0x25B5B8 + 2);
    *(int16_t *)(0x25B5B8 + 5) = 0x9000;
    *(int8_t  *)(0x25B772 + 0) = 0x8B;
    *(int32_t *)(0x25B772 + 1) = *(int32_t *)(0x25B772 + 2);
    *(int16_t *)(0x25B772 + 5) = 0x9000;
    *(int8_t  *)(0x25B948 + 0) = 0x8B;
    *(int32_t *)(0x25B948 + 1) = *(int32_t *)(0x25B948 + 2);
    *(int16_t *)(0x25B948 + 5) = 0x9000;
    *(int8_t  *)(0x25BB0B + 0) = 0x8B;
    *(int32_t *)(0x25BB0B + 1) = *(int32_t *)(0x25BB0B + 2);
    *(int16_t *)(0x25BB0B + 5) = 0x9000;
    *(int8_t  *)(0x25BCBE + 0) = 0x8B;
    *(int32_t *)(0x25BCBE + 1) = *(int32_t *)(0x25BCBE + 2);
    *(int16_t *)(0x25BCBE + 5) = 0x9000;
    *(int8_t  *)(0x25BE62 + 0) = 0x8B;
    *(int32_t *)(0x25BE62 + 1) = *(int32_t *)(0x25BE62 + 2);
    *(int16_t *)(0x25BE62 + 5) = 0x9000;
    *(int8_t  *)(0x25C006 + 0) = 0x8B;
    *(int32_t *)(0x25C006 + 1) = *(int32_t *)(0x25C006 + 2);
    *(int16_t *)(0x25C006 + 5) = 0x9000;
    *(int8_t  *)(0x25C202 + 0) = 0x8B;
    *(int32_t *)(0x25C202 + 1) = *(int32_t *)(0x25C202 + 2);
    *(int16_t *)(0x25C202 + 5) = 0x9000;
    *(int8_t  *)(0x25C3AD + 0) = 0x8B;
    *(int32_t *)(0x25C3AD + 1) = *(int32_t *)(0x25C3AD + 2);
    *(int16_t *)(0x25C3AD + 5) = 0x9000;
    *(int8_t  *)(0x25C534 + 0) = 0x8B;
    *(int32_t *)(0x25C534 + 1) = *(int32_t *)(0x25C534 + 2);
    *(int16_t *)(0x25C534 + 5) = 0x9000;
     
     
     //MOVSX -> MOVZX
    
    *(int8_t *)(0x25B06D + 0) = 0x85;
    *(int8_t *)(0x25B06D + 1) = 0xC0;
    *(int8_t *)(0x25B06D + 2) = 0x90;
    *(int8_t *)(0x25B076 + 0) = 0x90;
    *(int8_t *)(0x25B076 + 0) = 0x90;
    *(int16_t*)(0x1F76DF + 1) = 0xFFFF;
    *(int32_t *)(0x25B122 + 0) = *(int32_t *)(0x25B122 + 1);
    *(int8_t  *)(0x25B122 + 4) = 0x90;
    *(int8_t  *)(0x25B0FF + 1) = 0xB7;
    */

    
    
    
    
    
    // DECALS
    //0x2301FD	call 0x22fa58	E8 56 F8 FF FF
    //0x22FC6D	call 0x25b740	E8 CE BA 02 00 <-- bsp textures
    //0x22FC8B	call 0x22ab7e	E8 EE AE FF FF <-- kills decals
    //0x22FCA8	call 0x22ab8e	E8 E1 AE FF FF <-- draws
    //0x1F6899	call dword [edx+0x144]	FF 92 44 01 00 00 <-- decals
    //0x2BE786	call dword [edx+0x108]	FF 92 08 01 00 00 <-- render decals
    
    //0x1B698A	call 0x19dcee	E8 5F 73 FE FF
}

#pragma mark VISIBLE OBJECT LIMIT

// Increase the visible object limit
typedef struct
{
    uint16_t objectTableIndex;
    uint16_t objectTableIndexPlusSomething;
} ObjectID;

-(void)object_limit {
    struct ObjectId *objects = (void *)0x405d64; //old objects array location - will change after calloc
    int16_t newLimit = 0x2000;
    objects = calloc(sizeof(ObjectID),newLimit);
    *(struct ObjectId **)(0x235CAE + 3) = objects;
    *(struct ObjectId **)(0x235B82 + 3) = objects;
    *(struct ObjectId **)(0x235C47 + 3) = objects;
    *(struct ObjectId **)(0x235BFF + 3) = objects;
    *(int32_t *)(0x235BF7 + 4) = newLimit;
    *(int32_t *)(0x235C37 + 1) = newLimit;
}

#pragma mark CE NETCODE
#define ServerCE 0
#define ServerMD 1
int serverType = ServerMD;

uint32_t halo_crc32(uint8_t *data, int size) {
    const static uint32_t   crctable[] = {
        0x00000000, 0x77073096, 0xee0e612c, 0x990951ba,
        0x076dc419, 0x706af48f, 0xe963a535, 0x9e6495a3,
        0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988,
        0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91,
        0x1db71064, 0x6ab020f2, 0xf3b97148, 0x84be41de,
        0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7,
        0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec,
        0x14015c4f, 0x63066cd9, 0xfa0f3d63, 0x8d080df5,
        0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172,
        0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b,
        0x35b5a8fa, 0x42b2986c, 0xdbbbc9d6, 0xacbcf940,
        0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59,
        0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116,
        0x21b4f4b5, 0x56b3c423, 0xcfba9599, 0xb8bda50f,
        0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924,
        0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d,
        0x76dc4190, 0x01db7106, 0x98d220bc, 0xefd5102a,
        0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433,
        0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818,
        0x7f6a0dbb, 0x086d3d2d, 0x91646c97, 0xe6635c01,
        0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e,
        0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457,
        0x65b0d9c6, 0x12b7e950, 0x8bbeb8ea, 0xfcb9887c,
        0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65,
        0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2,
        0x4adfa541, 0x3dd895d7, 0xa4d1c46d, 0xd3d6f4fb,
        0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0,
        0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9,
        0x5005713c, 0x270241aa, 0xbe0b1010, 0xc90c2086,
        0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
        0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4,
        0x59b33d17, 0x2eb40d81, 0xb7bd5c3b, 0xc0ba6cad,
        0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a,
        0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683,
        0xe3630b12, 0x94643b84, 0x0d6d6a3e, 0x7a6a5aa8,
        0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1,
        0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe,
        0xf762575d, 0x806567cb, 0x196c3671, 0x6e6b06e7,
        0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc,
        0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5,
        0xd6d6a3e8, 0xa1d1937e, 0x38d8c2c4, 0x4fdff252,
        0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b,
        0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60,
        0xdf60efc3, 0xa867df55, 0x316e8eef, 0x4669be79,
        0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236,
        0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f,
        0xc5ba3bbe, 0xb2bd0b28, 0x2bb45a92, 0x5cb36a04,
        0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d,
        0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a,
        0x9c0906a9, 0xeb0e363f, 0x72076785, 0x05005713,
        0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38,
        0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21,
        0x86d3d2d4, 0xf1d4e242, 0x68ddb3f8, 0x1fda836e,
        0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777,
        0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c,
        0x8f659eff, 0xf862ae69, 0x616bffd3, 0x166ccf45,
        0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2,
        0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db,
        0xaed16a4a, 0xd9d65adc, 0x40df0b66, 0x37d83bf0,
        0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
        0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6,
        0xbad03605, 0xcdd70693, 0x54de5729, 0x23d967bf,
        0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94,
        0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d
    };
    uint32_t    crc = 0xffffffff;
    
    while(size--) {
        crc = crctable[(*data ^ crc) & 0xff] ^ (crc >> 8);
        data++;
    }
    return(crc);
}

int putxx(uint8_t *data, uint32_t num, int bits) {
    int     i,
    bytes;
    
    bytes = bits >> 3;
    for(i = 0; i < bytes; i++) {
        data[i] = (num >> (i << 3)) & 0xff;
    }
    return(bytes);
}

int sread_bit(uint8_t *p, int *o) {
    int result = (p[(*o)/8] & (1 << (7-((*o)%8)))) >> (7-((*o)%8));
    (*o)++;
    return result;
}
int sread_bits(uint8_t *p, int *o, int n) {
    int num = 0;
    for (int i=n-1; i >= 0; i--) {
        int bit = read_bits(1, p, *o);
        (*o)++;
        num |= bit << ((n-1)-i); //pow(2,(n-1)-i) * bit;
    }
    return num;
}
float sread_float(uint8_t *p, int *o, int n) {
    int x = sread_bits(p, o, n); //143
    float xf = 0.0;
    memcpy(&xf, &x, sizeof(float));
    return xf;
}
void swrite_bit(uint8_t *p, int *b, int d) {
    //printf("write bit: %d at offset %d (%d) 1=%d 0=%d\n", d, *b, (*b / 8), (1 << (7 - (*b % 8))), ~(1 << (7 - (*b % 8))));
    if (d == 1) {
        p[(*b / 8)] |= (1 << (7 - (*b % 8)));
    } else {
        p[(*b / 8)] &= ~(1 << (7 - (*b % 8)));
    }
    (*b)++;
}
void swrite_bits(uint8_t *p, int *b, uint8_t *in, int n) {
    //printf("write bits: %d at offset %d\n", n, *b);
    
    int o = 0;
    for (int i=0; i < n; i++) {
        int bit = read_bits(1, in, o);
        o++;
        write_bits(bit, 1, p, *b + i);
    }
}
unsigned int write_bits(   // position where the stored number finishs
                        unsigned int data,       // number to store
                        unsigned int bits,       // how much bits to occupy
                        unsigned char *out,      // buffer on which to store the number
                        unsigned int out_bits    // position of the buffer in bits
) {
    unsigned int    seek_bits,
    rem,
    mask;
    
    if(bits > 32) return(out_bits);
    if(bits < 32) data &= (1 << bits) - 1;
    for(;;) {
        seek_bits = out_bits & 7;
        mask = (1 << seek_bits) - 1;
        if((bits + seek_bits) < 8) mask |= ~(((1 << bits) << seek_bits) - 1);
        out[out_bits >> 3] &= mask; // zero
        out[out_bits >> 3] |= (data << seek_bits);
        rem = 8 - seek_bits;
        if(rem >= bits) break;
        out_bits += rem;
        bits     -= rem;
        data    >>= rem;
    }
    return(out_bits + bits);
}


unsigned int read_bits(    // number read
                       unsigned int bits,       // how much bits to read
                       unsigned char *in,       // buffer from which to read the number
                       unsigned int in_bits     // position of the buffer in bits
) {
    unsigned int    seek_bits,
    rem,
    seek = 0,
    ret  = 0,
    mask = 0xffffffff;
    
    if(bits > 32) return(0);
    if(bits < 32) mask = (1 << bits) - 1;
    for(;;) {
        seek_bits = in_bits & 7;
        ret |= ((in[in_bits >> 3] >> seek_bits) & mask) << seek;
        rem = 8 - seek_bits;
        if(rem >= bits) break;
        bits    -= rem;
        in_bits += rem;
        seek    += rem;
        mask     = (1 << bits) - 1;
    }
    return(ret);
}

int read_bstr(uint8_t *data, uint32_t len, uint8_t *buff, uint32_t bitslen) {
    int     i;
    
    for(i = 0; i < len; i++) {
        data[i] = read_bits(8, buff, bitslen);
        bitslen += 8;
    }
    return(bitslen);
}


void halobits(uint8_t *buff, int buffsz, bool output) {
    int     b,
    n,
    o;
    uint8_t      str[1 << 11];
    
    buffsz -= 4;    // crc;
    if(buffsz <= 0) return;
    buffsz <<= 3;
    
    for(b = 0;;) {
        if((b + 11) > buffsz) break;
        n = read_bits(11, buff, b);     b += 11;
        
        if((b + 1) > buffsz) break;
        o = read_bits(1,  buff, b);     b += 1;
        
        if((b + n) > buffsz) break;
        b = read_bstr(str, n, buff, b);
        show_dump(str, n, stderr);
    }
}

int haloreturnbits(uint8_t *buff,uint8_t *retbuff, int buffsz) {
    int     b,
    n,
    o;
    uint8_t      str[1 << 11];
    
    int offset = 0;
    
    buffsz -= 4;    // crc;
    if(buffsz <= 0) return -1;
    buffsz <<= 3;
    
    for(b = 0;;) {
        if((b + 11) > buffsz) break;
        n = read_bits(11, buff, b);     b += 11;
        
        if((b + 1) > buffsz) break;
        o = read_bits(1,  buff, b);     b += 1;
        
        if((b + n) > buffsz) break;
        b = read_bstr(str, n, buff, b);
        
        memcpy(retbuff+offset, str, n);
        offset+=n;
    }
    return offset;
}

#include <string.h>
const char *byte_to_binary(int x)
{
    static char b[9];
    b[0] = '\0';
    
    int z;
    for (z = 128; z > 0; z >>= 1)
    {
        strcat(b, ((x & z) == z) ? "1" : "0");
    }
    
    return b;
}

void show_dump(unsigned char *data, unsigned int len, FILE *stream) {
    const static char       hex[] = "0123456789abcdef";
    static unsigned char    buff[67];   /* HEX  CHAR\n */
    unsigned char           chr,
    *bytes,
    *p,
    *limit,
    *glimit = data + len;
    
    memset(buff + 2, ' ', 48);
    while(data < glimit) {
        limit = data + 16;
        if(limit > glimit) {
            limit = glimit;
            memset(buff, ' ', 48);
        }
        
        p     = buff;
        bytes = p + 50;
        while(data < limit) {
            chr = *data;
            *p++ = hex[chr >> 4];
            *p++ = hex[chr & 15];
            p++;
            *bytes++ = ((chr < ' ') || (chr >= 0x7f)) ? '.' : chr;
            data++;
        }
        *bytes++ = '\n';
        //fwrite(buff, bytes - buff, 1, stream);
    }
}

char *message_delta_packet_to_string_table[] = { //loc_1bcc21 [56]
    (char *)"_message_delta_object_deletion",         //000000
    (char *)"_message_delta_projectile_update",       //100000
    (char *)"_message_delta_equipment_update",        //010000
    (char *)"_message_delta_weapon_update",           //110000
    (char *)"_message_delta_biped_update",            //001000
    (char *)"_message_delta_vehicle_update",          //101000
    (char *)"_message_delta_hud_add_item",            //011000
    (char *)"_message_delta_player_create",           //111000
    (char *)"_message_delta_player_spawn",            //100100
    (char *)"_message_delta_player_exit_vehicle",     //010100
    (char *)"_message_delta_player_set_action_result",//110100
    (char *)"_message_delta_player_effect_start",     //001100
    (char *)"_message_delta_unit_kill",               //101100
    (char *)"_message_delta_client_game_update",      //011100
    (char *)"_message_delta_player_handle_powerup",   //111100
    (char *)"_message_delta_hud_chat",                //000010
    (char *)"_message_delta_slayer_update",
    (char *)"_message_delta_ctf_update", // ctf update?
    (char *)"_message_delta_oddball_update",
    (char *)"_message_delta_king_update",
    (char *)"_message_delta_race_update",
    (char *)"_message_delta_player_score_update",
    (char *)"_message_delta_game_engine_change_mode",
    (char *)"_message_delta_game_engine_map_reset",
    (char *)"_message_delta_multiplayer_hud_message",
    (char *)"_message_delta_multiplayer_sound",
    (char *)"_message_delta_team_change",           //001011
    (char *)"_message_delta_unit_drop_current_weapon",
    (char *)"_message_delta_vehicle_new",
    (char *)"_message_delta_biped_new",
    (char *)"_message_delta_projectile_new",
    (char *)"_message_delta_equipment_new",
    (char *)"_message_delta_weapon_new",
    (char *)"_message_delta_game_settings_update",
    (char *)"_message_delta_parameters_protocol",
    (char *)"_message_delta_local_player_update",
    (char *)"_message_delta_local_player_vehicle_update",
    (char *)"_message_delta_remote_player_action_update",
    (char *)"_message_delta_super_remote_players_action_update",
    (char *)"_message_delta_remote_player_position_update",
    (char *)"_message_delta_remote_player_vehicle_update",
    (char *)"_message_delta_remote_player_total_update_biped",
    (char *)"_message_delta_remote_player_total_update_vehicle",
    (char *)"_message_delta_weapon_start_reload",
    (char *)"_message_delta_weapon_ammo_pickup_mid_reload",
    (char *)"_message_delta_weapon_finish_reload",
    (char *)"_message_delta_weapon_cancel_reload",
    (char *)"_message_delta_netgame_equipment_new",
    (char *)"_message_delta_projectile_detonate",
    (char *)"_message_delta_item_accelerate",
    (char *)"_message_delta_damage_dealt",
    (char *)"_message_delta_projectile_attach",
    (char *)"_message_delta_client_to_server_pong",
    (char *)"_message_delta_super_ping_update",
    (char *)"_message_delta_sv_motd",
    (char *)"_message_delta_rcon_request",
    (char *)"_message_delta_rcon_response",
};

enum message_delta
{
    _message_delta_object_deletion,     //0 [DONE]
    _message_delta_projectile_update,   //1
    _message_delta_equipment_update,    //2
    _message_delta_weapon_update,       //3
    _message_delta_biped_update,        //4 => 4?
    _message_delta_vehicle_update,      //5
    _message_delta_hud_add_item,        //6 [DONE]
    _message_delta_player_create,       //7 [DONE]
    _message_delta_player_spawn,        //8 [DONE] probably contains team change? (000100)
    /*
     
     
     
     */
    _message_delta_player_exit_vehicle, // 9
    _message_delta_player_set_action_result, //10
    _message_delta_player_effect_start, // 11
    _message_delta_unit_kill,           // 12
    _message_delta_client_game_update,  // 13
    /*
     [  1]
     [  1] set jump bit
     [  1] set x-turn bit
     [  1] set y-turn bit
     [  1] set movement bit
     [  1] set shooting bit
     [  1] set weapon switching bit
     [  1]
     [  1]
     [  6] tick (0-63)
     
     // JUMP FIELD (10 bits)
     [  1] crouching
     [  1] jumping
     [  1] flashlight
     [  1] action
     [  1] melee
     [  1]
     [  1] shooting
     [  1]
     [  1]
     [  1] action long
     
     // X-TURN FIELD (32 bits)
     [ 32] x-turn
     
     // Y-TURN FIELD (32 bits)
     [ 32] y-turn
     
     // MOVEMENT FIELD (4 bits)
     [  1] right
     [  1] left
     [  1] backwards
     [  1] forwards
     */
    _message_delta_player_handle_powerup,   //14
    _message_delta_hud_chat,                //15
    _message_delta_slayer_update,           //16
    _message_delta_ctf_update,              //17
    _message_delta_oddball_update,          //18
    _message_delta_king_update,             //19
    _message_delta_race_update,             //20
    _message_delta_player_score_update,     //21
    _message_delta_game_engine_change_mode, //22
    _message_delta_game_engine_map_reset,   //23
    _message_delta_multiplayer_hud_message, //24
    _message_delta_multiplayer_sound,       //25
    _message_delta_team_change,             //26 [DONE]
    /*
     [  8] player id
     [  8] team id
     */
    _message_delta_unit_drop_current_weapon,//27
    _message_delta_vehicle_new,             //28
    _message_delta_biped_new,               //29
    /*
     [ 16] biped tag_index
     [ 16] biped table_id
     ...
     */
    _message_delta_projectile_new,          //30
    _message_delta_equipment_new, //server  //31
    /*
     [  7]
     [  2]
     [ 16] eqip tag_index
     [ 16] eqip table_id
     [ 50]
     [ 32] x (float)
     [ 32] y (float)
     [ 32] z (float)
     */
    _message_delta_weapon_new, //server     //32
    /*
     [ 16] weap tag_index
     [ 16] weap table_id
     [278] ?
     */
    _message_delta_game_settings_update,    //33
    _message_delta_parameters_protocol,     //34
    _message_delta_local_player_update,     //35
    /*
     [ 11]
     [ 32] x (float)
     [ 32] y (float)
     [ 32] z (float)
     [  8]
     [ 11] bitmask
     ...
     */
    _message_delta_local_player_vehicle_update, //36
    _message_delta_remote_player_action_update, //37
    _message_delta_super_remote_players_action_update, //38 //0110010
    
    _message_delta_remote_player_position_update, //39
    _message_delta_remote_player_vehicle_update,  //40
    _message_delta_remote_player_total_update_biped, //41       //server [no team]
    /*
     [  5] player number
     [ 10]
     [  1]
     [ 14] control mask?
     [ 15] rotation?
     [  4] weapon index
     [  1] nade index
     [ 25] X (int) * 6710.87548805
     [ 25] Y (int) * 6710.87548805
     [ 25] Z (int) * 6710.87548805
     */
    _message_delta_remote_player_total_update_vehicle,  //42  //score update, _message_delta_remote_player_total_update_vehicle
    _message_delta_weapon_start_reload,                 //43
    _message_delta_weapon_ammo_pickup_mid_reload,       //44
    _message_delta_weapon_finish_reload,                //45
    _message_delta_weapon_cancel_reload,                //46
    _message_delta_netgame_equipment_new,               //47
    _message_delta_projectile_detonate,                 //48
    _message_delta_item_accelerate,                     //49
    _message_delta_damage_dealt,                        //50
    _message_delta_projectile_attach,                   //51
    _message_delta_client_to_server_pong,               //52
    /*
     [  8] player number
     */
    _message_delta_super_ping_update,
    _message_delta_sv_motd,
    _message_delta_rcon_request,
    _message_delta_rcon_response,
    k_message_deltas_count
};

uint32_t (*oldnetworkPack)() = NULL;
uint32_t networkPack(uint32_t arg0, uint8_t *arg1) {
    uint8_t packet_type = *(*(uint8_t **)arg1 + 0x4);
    uint32_t ret = oldnetworkPack(arg0, arg1);
    return ret;
}


uint32_t (*oldnetworkPack2)() = NULL;
uint32_t networkPack2(uint32_t arg1) {
    uint32_t ret = oldnetworkPack2(arg1);
    return ret;
}

uint32_t (*oldnetworkPack3)() = NULL;
uint32_t networkPack3(uint32_t arg0, uint8_t *arg1) {
    uint8_t packet_type = *(*(uint8_t **)arg1 + 0x4);
    fprintf(stderr, "PARSE %s\n", message_delta_packet_to_string_table[packet_type]);
    uint32_t ret = oldnetworkPack3(arg0, arg1);
    return ret;
}

uint32_t (*oldnetworkPack4)() = NULL;
uint32_t networkPack4(uint8_t *arg1) {
    uint8_t packet_type = *(*(uint8_t **)arg1 + 0x4);
    uint32_t ret = oldnetworkPack4( arg1);
    return ret;
}
uint32_t (*sub_1afef4)(uint32_t arg0, uint32_t arg1) = (void *)0x1afef4;
uint32_t (*sub_1b6f94)() = (void *)0x1b6f94;

-(void)connectServer {
    if (switchCE) {
        uint32_t proxy = (*(uint32_t*)0x3daf80);
        uint32_t status = proxy ? sub_1afef4(proxy, 0x0) : 0x0;
        if (status == 0x0) {
            switchCE = false;
            
            // Connect
            char *new_command = malloc(1024);
            char *error_result = malloc(1024);
            snprintf(new_command, 1024, "connectce %s:%d \"%s\"\n", (char*)0x453760, *(uint16_t*)0x466066, (char*)0x466090);
            runCommand(new_command, error_result, "connectce");
            free(new_command);
            free(error_result);
        } else {
            consolePrintf(WHITE, "Busy (%d)", status);
            // Disconnect
            
            char *new_command = malloc(1024);
            char *error_result = malloc(1024);
            snprintf(new_command, 1024, "disconnect");
            runCommand(new_command, error_result, "disconnect");
            free(new_command);
            free(error_result);
            
            [NSTimer scheduledTimerWithTimeInterval:0.1 target:updateSelf selector:@selector(connectServer) userInfo:nil repeats:NO];
        }
    }
}

-(void)disconnectServer {
}

bool switchCE = false;
char servkey[8];
uint32_t (*oldnetworkRecv)() = NULL;
uint32_t networkRecv(uint32_t arg0, uint8_t *arg1, uint32_t arg2, uint32_t arg3, uint32_t arg4) {
    if (*(uint16_t*)arg1 == 0xfefe && *(uint16_t*)(arg1 + 0x2) == 0x64 && *(uint16_t*)(arg1 + 0x4) == 0x3 && *(uint8_t*)(arg1 + 0x6) == 0x2 && serverType == ServerMD) {
        consolePrintf(WHITE, "Connecting to Custom Edition server... ");
        
        // Connect
        char *new_command = malloc(1024);
        char *error_result = malloc(1024);
        snprintf(new_command, 1024, "connectce %s:%d \"%s\"\n", (char*)0x453760, *(uint16_t*)0x466066, (char*)0x466090);
        runCommand(new_command, error_result, "connectce");
        free(new_command);
        free(error_result);
        
        switchCE = true;
        @autoreleasepool {
            [NSTimer scheduledTimerWithTimeInterval:0.1 target:updateSelf selector:@selector(connectServer) userInfo:nil repeats:NO];
        }
    }
    
    uint32_t ret = oldnetworkRecv(arg0, arg1, arg2, arg3, arg4);
    //fprintf(stderr, "RECV 0x%x 0x%x 0x%x 0x%x 0x%x\n", arg0, arg1, arg2, arg3, arg4);
    //fprintf(stderr, "PASS 0x%x 0x%x 0x%x 0x%x\n", *(uint16_t*)arg1, *(uint16_t*)(arg1 + 0x2), *(uint16_t*)(arg1 + 0x4), *(uint8_t*)(arg1 + 0x6));
    
    if (*(uint16_t*)arg1 == 0xfefe && *(uint16_t*)(arg1 + 0x2) == 0x0 && *(uint16_t*)(arg1 + 0x4) == 0x2 && *(uint8_t*)(arg1 + 0x6) == 0x2) {
        uint8_t *data = malloc(10000);
        haloreturnbits(arg1 + 7, data, arg2 - 11);
        
        char *key = malloc(8);
        key[0] = data[3];
        key[1] = data[4];
        key[2] = data[5];
        key[3] = data[6];
        key[4] = data[7];
        key[5] = data[8];
        key[6] = data[9];
        key[7] = '\0';
        //fprintf(stderr, "KEY: %s\n", key);
        
        memcpy(servkey, key, 8);
        free(key);
        free(data);
    }
    
    
    // debugging
    /*
    uint8_t *packet = arg1 + 7;
    int packet_len = arg2 - 11;
    if (packet_len > 0) {
        packet_len *= 8; // bit length
        uint8_t str[1 << 11];
        uint8_t *buff = packet;
        
        int b, n, o;
        for(b = 0;;) {
            if((b + 11) > packet_len) break;
            n = read_bits(11, buff, b);     b += 11;
            if((b + 1) > packet_len) break;
            o = read_bits(1, buff, b);     b += 1;
            if((b + n) > packet_len) break;
            b = read_bstr(str, n, buff, b);
            
            int bit = 0;
            while (bit < n*8 && (n*8 - bit - 12) > 8) {
                int message_mode = sread_bits(str, &bit, 1);
                int message_type = sread_bits(str, &bit, 6);
                printf("DELTA %s (%d, %d)\n", message_delta_packet_to_string_table[message_type], message_mode, message_type);
                
                if (message_type == _message_delta_weapon_new) {
                    fprintf(stderr, "definition_index = ");
                    uint16_t unknown0_tagIndex = sread_bits(str, &bit, 16); 		// definition_index
                    uint16_t unknown0_tagId = sread_bits(str, &bit, 16); 		//
                    fprintf(stderr, "0x%x 0x%x", unknown0_tagIndex, unknown0_tagId);
                    fprintf(stderr, "\n");
                    fprintf(stderr, "object_index = ");
                    uint32_t unknown1 = sread_bits(str, &bit, 9); 		// object_index
                    fprintf(stderr, "%d", unknown1);
                    fprintf(stderr, "\n");
                    fprintf(stderr, "integer_medium = ");
                    uint16_t unknown2 = sread_bits(str, &bit, 16); 		// integer_medium
                    fprintf(stderr, "%d", unknown2);
                    fprintf(stderr, "\n");
                    fprintf(stderr, "player_index = ");
                    uint32_t unknown3 = sread_bits(str, &bit, 5); 		// player_index
                    fprintf(stderr, "%d", unknown3);
                    fprintf(stderr, "\n");
                    fprintf(stderr, "object_index = ");
                    uint32_t unknown4 = sread_bits(str, &bit, 9); 		// object_index
                    fprintf(stderr, "%d", unknown4);
                    fprintf(stderr, "\n");
                    fprintf(stderr, "integer_large = ");
                    uint32_t unknown5 = sread_bits(str, &bit, 32); 		// integer_large
                    fprintf(stderr, "%d", unknown5);
                    fprintf(stderr, "\n");
                    fprintf(stderr, "fixed_width_normal_8bit = ");
                    int8_t unknown6_0 = sread_bits(str, &bit, 8); 		// fixed_width_normal_8bit
                    int8_t unknown6_1 = sread_bits(str, &bit, 8); 		// fixed_width_normal_8bit
                    fprintf(stderr, "%d %d", unknown6_0, unknown6_1);
                    fprintf(stderr, "\n");
                    fprintf(stderr, "fixed_width_normal_8bit = ");
                    int8_t unknown7_0 = sread_bits(str, &bit, 8); 		// fixed_width_normal_8bit
                    int8_t unknown7_1 = sread_bits(str, &bit, 8); 		// fixed_width_normal_8bit
                    fprintf(stderr, "%d %d", unknown7_0, unknown7_1);
                    fprintf(stderr, "\n");
                    fprintf(stderr, "integer_small = ");
                    uint8_t unknown8 = sread_bits(str, &bit, 8); 		// integer_small
                    fprintf(stderr, "%d", unknown8);
                    fprintf(stderr, "\n");
                    fprintf(stderr, "point3d = ");
                    float unknown9_x = sread_float(str, &bit, 32); 		// point3d
                    float unknown9_y = sread_float(str, &bit, 32); 		//
                    float unknown9_z = sread_float(str, &bit, 32); 		//
                    fprintf(stderr, "%f %f %f", unknown9_x, unknown9_y, unknown9_z);
                    fprintf(stderr, "\n");
                    fprintf(stderr, "translational_velocity = ");
                    uint8_t unknown10_exist = sread_float(str, &bit, 2); 		// translational_velocity
                    float unknown10_v[unknown10_exist];
                    for (int i = 0; i < unknown10_exist; i++) {
                        unknown10_v[i] = sread_float(str, &bit, 16);
                        fprintf(stderr, "%f ", unknown10_v[i]);
                    }
                    fprintf(stderr, "\n");
                    fprintf(stderr, "integer_medium = ");
                    uint16_t unknown11 = sread_bits(str, &bit, 16); 		// integer_medium
                    fprintf(stderr, "%d", unknown11);
                    fprintf(stderr, "\n");
                    fprintf(stderr, "integer_medium = ");
                    uint16_t unknown12 = sread_bits(str, &bit, 16); 		// integer_medium
                    fprintf(stderr, "%d", unknown12);
                    fprintf(stderr, "\n");
                    fprintf(stderr, "fixed_width_6bits = ");
                    uint32_t unknown13 = sread_bits(str, &bit, 6); 		// fixed_width_6bits
                    fprintf(stderr, "%d", unknown13);
                    fprintf(stderr, "\n");
                    fprintf(stderr, "integer_medium = ");
                    uint16_t unknown14 = sread_bits(str, &bit, 16); 		// integer_medium
                    fprintf(stderr, "%d", unknown14);
                    fprintf(stderr, "\n");
                    fprintf(stderr, "integer_medium = ");
                    uint16_t unknown15 = sread_bits(str, &bit, 16); 		// integer_medium
                    fprintf(stderr, "%d", unknown15);
                    fprintf(stderr, "\n");
                    fprintf(stderr, "\n");
                }
                break;
            }
        }
    }
    */
    
    return ret;
}

#include <sys/types.h>
#include <pwd.h>

uint32_t crc32OfMap(const char *data) {
    uint32_t meta_offset = *(uint32_t *)(data + 0x10);
    uint32_t meta_size = *(uint32_t *)(data + 0x14);
    uint32_t magic = 0x40440000;
    
    const char *meta_data = data + meta_offset;
    uint32_t scnr_tag_id = *(uint32_t *)(meta_data + 4);
    if(scnr_tag_id == 0xFFFFFFFF) {
        return 0;
    }
    uint32_t scnr_tag_index = scnr_tag_id & 0xFFFF;
    const char *model_data = data + *(uint32_t *)(meta_data + 0x14);
    uint32_t model_data_size = *(uint32_t *)(meta_data + 0x20);
    const char *tags = meta_data + (*(uint32_t *)(meta_data + 0x0) - magic);
    const char *scnr_tag = tags + 0x20 * scnr_tag_index;
    const char *scnr_tag_data = meta_data + (*(uint32_t *)(scnr_tag + 0x14) - magic);
    const char *scnr_tag_bsp_reflexive = scnr_tag_data + 0x5A4;
    uint32_t bsp_count = *(uint32_t *)(scnr_tag_bsp_reflexive + 0x0);
    const char *bsps = meta_data + (*(uint32_t *)(scnr_tag_bsp_reflexive + 0x4) - magic);
    uint32_t bsp_start_offset = 0xFFFFFFFF;
    uint32_t bsp_end_offset = 0;
    for(uint32_t i=0;i<bsp_count;i++) {
        const char *bsp = bsps + i * 32;
        uint32_t bsp_start = *(uint32_t *)(bsp + 0x0);
        uint32_t bsp_end = bsp_start + *(uint32_t *)(bsp + 0x4);
        if(bsp_start_offset > bsp_start) {
            bsp_start_offset = bsp_start;
        }
        if(bsp_end_offset < bsp_end) {
            bsp_end_offset = bsp_end;
        }
    }
    if(bsp_start_offset == 0xFFFFFFFF) {
        return 0;
    }
    const char *bsp_data = data + bsp_start_offset;
    size_t bsp_size = bsp_end_offset - bsp_start_offset;
    
    size_t c_data_size = meta_size + bsp_size + model_data_size;
    char *c_data = malloc(c_data_size);
    memcpy(c_data, bsp_data, bsp_size);
    memcpy(c_data + bsp_size, model_data, model_data_size);
    memcpy(c_data + bsp_size + model_data_size, meta_data, meta_size);
    
    uint32_t crc = halo_crc32(c_data, c_data_size);
    
    free(c_data);
    return crc;
}

uint32_t (*oldnetworkSend)() = NULL;
uint32_t networkSend(uint8_t *arg0, uint8_t *arg1, uint32_t arg2, uint32_t arg3) {
    if ((arg2 == 0x196 || arg2 == 0x92) && serverType == ServerCE) {
        uint32_t mapCRC = *(uint32*)0x3AFD94;
        if (true || mapCRC == 0x0) {
            char *string = (char *)0x3D7B35;

            // read entire map file into memory
            struct passwd *pw = getpwuid(getuid());
            const char *homedir = pw->pw_dir;
            
            char fileLocation[1024];
            sprintf(fileLocation, "%s/Library/Application Support/HaloMD/GameData/Maps/%s.map", homedir, string);
            
            char *data = NULL;
            long length = 0;
            FILE * f = fopen (fileLocation, "rb");
            if (f) {
                fseek (f, 0, SEEK_END);
                length = (long)ftell(f);
                fseek (f, 0, SEEK_SET);
                data = (char*)malloc (length);
                if (data) {
                    fread (data, 1, length, f);
                }
                fclose (f);
                
                uint32_t type = *(uint32_t*)(data + 0x4);
                if (type == 0x7) { //PC
                           if (strcmp(string, "beavercreek") == 0) {        mapCRC = 0x7b3876a;
                    } else if (strcmp(string, "bloodgulch") == 0) {         mapCRC = 0x7b309554;
                    } else if (strcmp(string, "boardingaction") == 0) {     mapCRC = 0xf4deef94;
                    } else if (strcmp(string, "carousel") == 0) {           mapCRC = 0x9c301a08;
                    } else if (strcmp(string, "chillout") == 0) {           mapCRC = 0x93c53c27;
                    } else if (strcmp(string, "damnation") == 0) {          mapCRC = 0xfba059d;
                    } else if (strcmp(string, "dangercanyon") == 0) {       mapCRC = 0xc410cd74;
                    } else if (strcmp(string, "deathisland") == 0) {        mapCRC = 0x1df8c97f;
                    } else if (strcmp(string, "gephyrophobia") == 0) {      mapCRC = 0xd2872165;
                    } else if (strcmp(string, "hangemhigh") == 0) {         mapCRC = 0xa7c8b9c6;
                    } else if (strcmp(string, "icefields") == 0) {          mapCRC = 0x5ec1deb7;
                    } else if (strcmp(string, "infinity") == 0) {           mapCRC = 0xe7f7fe7;
                    } else if (strcmp(string, "longest") == 0) {            mapCRC = 0xc8f48ff6;
                    } else if (strcmp(string, "prisoner") == 0) {           mapCRC = 0x43b81a8b;
                    } else if (strcmp(string, "putput") == 0) {             mapCRC = 0xaf2f0b84;
                    } else if (strcmp(string, "ratrace") == 0) {            mapCRC = 0xf7f8e14c;
                    } else if (strcmp(string, "sidewinder") == 0) {         mapCRC = 0xbd95cf55;
                    } else if (strcmp(string, "timberland") == 0) {         mapCRC = 0x54446470;
                    } else if (strcmp(string, "wizard") == 0) {             mapCRC = 0xcf3359b1; }
                    else {
                        consolePrintf(WHITE, "The bridge crumbles beneath your feet.");
                    }
                } else if (type == 0x261) { //CE
                    mapCRC = crc32OfMap(data);
                } else {
                    consolePrintf(WHITE, "The bridge is flooded and cannot be crossed.");
                }
                free(data);
            } else {
                consolePrintf(WHITE, "Died to the bridge troll.");
            }
        }
        
        uint8_t b0 = (mapCRC >> (8*3)) & 0x000000FF;
        uint8_t b1 = (mapCRC >> (8*2)) & 0x000000FF;
        uint8_t b2 = (mapCRC >> (8*1)) & 0x000000FF;
        uint8_t b3 = (mapCRC >> (8*0)) & 0x000000FF;
        uint8_t num0 = servkey[3] ^ b0;
        uint8_t num1 = servkey[2] ^ servkey[6] ^ b1;
        uint8_t num2 = servkey[1] ^ servkey[5] ^ b2;
        uint8_t num3 = servkey[0] ^ servkey[4] ^ b3;
        
        // replace the
        int head = 7;
        int len = arg2 + head;
        int packet_len = (int)(len - head);
        packet_len *= 8; // bit length
        uint8_t str[1 << 11];
        
        // dump the packet
        halobits(arg1, arg2, false);
        
        uint8_t *data = malloc(10000);
        haloreturnbits(arg1, data, arg2);
        int b, n, o;
        for(b = 0;;) {
            if((b + 11) > packet_len) break;
            n = read_bits(11, arg1, b);    b += 11;
            if((b + 1) > packet_len) break;
            o = read_bits(1, arg1, b);     b += 1;
            if((b + n) > packet_len) break;
            b = read_bstr(str, n, arg1, b);
            
            int bit = 0;
            while (bit < n*8 && (n*8 - bit - 12) > 8) {
                int message_type = sread_bits(str, &bit, 6);
                //fprintf(stderr, "PACKET: %d\n", message_type);
                
                if (message_type == 12 || message_type == 6) {
                    //fprintf(stderr, "modifying packets\n");
                    sread_bits(str, &bit, 1);
                    
                    // modify the packet type
                    int b = 13;
                    uint32_t type = 38;
                    swrite_bits(arg1, &b, (uint8_t*)&type, 6);
                    len = arg2 + head + 4;
                    
                    // inject server key
                    b = 12 + 7 + 17 + 34 * 8 + 74 * 8 + 24 * 8 + 8 * 8; //1156
                    swrite_bits(arg1, &b, (uint8_t*)&num0, 8);
                    b += 8;
                    swrite_bits(arg1, &b, (uint8_t*)&num1, 8);
                    b += 8;
                    swrite_bits(arg1, &b, (uint8_t*)&num2, 8);
                    b += 8;
                    swrite_bits(arg1, &b, (uint8_t*)&num3, 8);
                    b += 8; type = 0xe;
                    swrite_bits(arg1, &b, (uint8_t*)&type, 8);
                    b += 8; type = 0x98;
                    swrite_bits(arg1, &b, (uint8_t*)&type, 8);
                    b += 8; type = 0x20;
                    swrite_bits(arg1, &b, (uint8_t*)&type, 8);
                    b += 8; type = 0x2;
                    swrite_bits(arg1, &b, (uint8_t*)&type, 9);
                    b += 9;
                    
                    if (arg2 == 0x196) {
                        char *string = (char *)0x3D7B35;
                        for (int c = 0; c < strlen(string); c++) {
                            type = string[c];
                            swrite_bits(arg1, &b, (uint8_t*)&type, 8);
                            b += 8;
                        }
                    }
                    
                        // clear bytes
                        for (int c = 0; c < 15 + 16*14 + 7; c++) {
                            type = 0;
                            swrite_bits(arg1, &b, (uint8_t*)&type, 8);
                            b += 8;
                        }
                    
                    if (arg2 == 0x196) {
                        b = 12 + (len - head- 3) * 8;
                        type = 0x2a;
                        swrite_bits(arg1, &b, (uint8_t*)&type, 8);
                    }
                    
                    // write new length
                    b = 0; type = len - head;
                    swrite_bits(arg1, &b, (uint8_t*)&type, 11);
                }
                break;
            }
        }
        free(data);
        arg2 = len - head;
        halobits(arg1, arg2, false);
    }
    
    return oldnetworkSend(arg0, arg1, arg2, arg3);
}

bool prefix(const char *pre, const char *str) {
    return strncmp(pre, str, strlen(pre)) == 0;
}

uint32_t (*oldhaloReadBits)(uint32_t arg0, uint8_t *arg1, uint32_t arg2); // = (void *)0x19c81c;
uint32_t halo_read_bits(uint32_t arg0, uint8_t *arg1, uint32_t arg2) {
    fprintf(stderr, "BITS - 0x%x, 0x%x, 0x%x\n", arg0, arg1, arg2);
    return oldhaloReadBits(arg0, arg1, arg2);
}

uint32_t (*oldsub_19c600)(uint32_t arg0, uint8_t *arg1, uint32_t arg2); // = (void *)0x19c81c;
uint32_t sub_19c600(uint32_t arg0, uint8_t *arg1, uint32_t arg2) {
    fprintf(stderr, "BITS - 0x%x, 0x%x, 0x%x\n", arg0, arg1, arg2);
    return oldhaloReadBits(arg0, arg1, arg2);
}

uint32_t (*oldsub_19c798)(uint32_t arg0, uint32_t arg1); // = (void *)0x19c81c;
uint32_t sub_19c798(uint32_t arg0, uint32_t arg1) {
    fprintf(stderr, "BITS2 - 0x%x, 0x%x\n", arg0, arg1);
    return oldsub_19c798(arg0, arg1);
}

//uint32_t (*oldsub_19c600)(uint32_t arg0, uint8_t *arg1, uint32_t arg2); // = (void *)0x19c81c;
//uint32_t sub_19c600(uint32_t arg0, uint8_t *arg1, uint32_t arg2) {
//    fprintf(stderr, "BITS2 - 0x%x, 0x%x\n", arg0, arg1);
//    return oldsub_19c600(arg0, arg1, arg2);/
//}

uint32_t packet_motd(uint32_t arg0, uint32_t arg4, uint32_t arg8, uint32_t argC) {
    uint8_t length = 0;
    uint32_t esi = halo_read_bits(argC, &length, 0x8);
    
    uint8_t c[length + 1];
    for (int i = 0; i < length; i++) {
        esi += halo_read_bits(argC, &c[i], 0x8);
    }
    c[length] = '\0';
    consolePrintf(WHITE, "%s", c);
    return esi;
}
uint32_t packet_rcon(uint32_t arg0, uint32_t arg4, uint32_t arg8, uint32_t argC) {
    uint8_t length = 0;
    uint32_t esi = halo_read_bits(argC, &length, 0x7);
    
    uint8_t c[length + 1];
    for (int i = 0; i < length; i++) {
        esi += halo_read_bits(argC, &c[i], 0x8);
    }
    c[length] = '\0';
    
    
    if (prefix((char*)c, "x_ai") == 0) {
        // Find the biped
        uint32_t object = *(uint32_t *)0x47871C;
        uint16_t count = *(uint16_t *)(object + 0x2E);
        uint32_t table = *(uint32_t *)(object + 0x34);
        for (int i = 0; i < count; i++) {
            uint8_t *memory = *(uint8_t **)(table + i * 0xC + 0x8);
            if (memory != 0 && (uint32_t)memory != 0xFFFFFFFF) {
                uint16_t type = *(uint16_t *)(memory + 0xB4);
                if (type != 0) {
                    continue;
                }
               
                uint16_t player = *(uint16_t *)(memory + 0xC0);
                if (player != 0xFFFF) {
                    continue;
                }
                
                uint16_t biped = *(uint16_t *)(memory + 0xC4);
                
                // AI
                consolePrintf(GREEN, "BIPED 0x%x", biped);
            }
        }
    } else {
        consolePrintf(WHITE, "%s", c);
    }
    return esi;
}

uint8_t *rcon_class = NULL;
uint8_t *motd_class = NULL;
uint8_t *motd_packet = NULL;
uint8_t *rcon_packet = NULL;
void (*oldrenderObjects)() = NULL;
void renderObjects(int32_t a, int32_t b, int32_t c, int32_t d, int32_t e, int32_t f, int32_t g) {
    
    // Packet classes
    // New packet
    uint16_t buffer = 1024;
    if (!motd_class) {
        motd_class = (uint8_t *)malloc(buffer);
        memset(motd_class, 0, buffer);
        *(uint32_t*)(motd_class + 0x0)  = 0x5; // something with a 1
        *(uint8_t *)(motd_class + 0x4)  = 'm';
        *(uint8_t *)(motd_class + 0x5)  = 'o';
        *(uint8_t *)(motd_class + 0x6)  = 't';
        *(uint8_t *)(motd_class + 0x7)  = 'd';
        *(uint32_t*)(motd_class + 0x50) = (uint32_t)packet_motd; // will cause a crash?
        *(uint32_t*)(motd_class + 0x54) = (uint32_t)packet_motd;
        *(uint32_t*)(motd_class + 0x58) = 0x37a088;
        
        motd_packet = (uint8_t *)malloc(buffer);
        memset(motd_packet, 0, buffer);
        *(uint32_t*)(motd_packet + 0x0)  = 0x36;
        *(uint32_t*)(motd_packet + 0x04) = 0x01;
        *(uint32_t*)(motd_packet + 0x08) = 0x100B;
        *(uint32_t*)(motd_packet + 0x0C) = 0x08;
        *(uint32_t*)(motd_packet + 0x10) = 0x1012;
        *(uint32_t*)(motd_packet + 0x14) = 0x1;
        *(uint32_t*)(motd_packet + 0x18) = 0x1;
        *(uint32_t*)(motd_packet + 0x1C) = 0x377280; //?
        *(uint32_t*)(motd_packet + 0x20) = 0x1;
        *(uint32_t*)(motd_packet + 0x24) = 0x1008;
        *(uint32_t*)(motd_packet + 0x28) = (uint32_t)motd_class; // offset to subpacket type
        //... zeroes ...
    }
    
    // New packet
    if (!rcon_class) {
        rcon_class = (uint8_t *)malloc(buffer);
        memset(rcon_class, 0, buffer);
        *(uint32_t*)(rcon_class + 0x0)  = 0x5; // something with a 1
        *(uint8_t *)(rcon_class + 0x4)  = 'm';
        *(uint8_t *)(rcon_class + 0x5)  = 'o';
        *(uint8_t *)(rcon_class + 0x6)  = 't';
        *(uint8_t *)(rcon_class + 0x7)  = 'd';
        *(uint32_t*)(rcon_class + 0x50) = (uint32_t)packet_rcon; // will cause a crash?
        *(uint32_t*)(rcon_class + 0x54) = (uint32_t)packet_rcon;
        *(uint32_t*)(rcon_class + 0x58) = 0x37a088;
        
        rcon_packet = (uint8_t *)malloc(buffer);
        memset(rcon_packet, 0, buffer);
        *(uint32_t*)(rcon_packet + 0x0)  = 0x36;
        *(uint32_t*)(rcon_packet + 0x04) = 0x01;
        *(uint32_t*)(rcon_packet + 0x08) = 0x100B;
        *(uint32_t*)(rcon_packet + 0x0C) = 0x08;
        *(uint32_t*)(rcon_packet + 0x10) = 0x1012;
        *(uint32_t*)(rcon_packet + 0x14) = 0x1;
        *(uint32_t*)(rcon_packet + 0x18) = 0x1;
        *(uint32_t*)(rcon_packet + 0x1C) = 0x377280; //?
        *(uint32_t*)(rcon_packet + 0x20) = 0x1;
        *(uint32_t*)(rcon_packet + 0x24) = 0x1008;
        *(uint32_t*)(rcon_packet + 0x28) = (uint32_t)rcon_class; // offset to subpacket type
        //... zeroes ...
    }
    
    // Override
    if (serverType != ServerCE) {
        *(uint32_t*)0x35F628 = 0x18;
        *(uint32_t*)0x3A5738 = (uint32_t)0x37A0A0; // rcon request
        *(uint32_t*)0x3A573C = (uint32_t)rcon_packet; // rcon response
        *(uint32_t*)0x3A5740 = (uint32_t)0x32DD84; // motd
        
        mprotect((void *)0x34c000,0x2000, PROT_READ|PROT_WRITE);
        *(uint32_t*)0x34c200 = (uint32_t)0x1b060f;
        *(uint32_t*)(0x34c060 + 4 * 54) = 0x1B061E;
        *(uint32_t*)(0x34c060 + 4 * 55) = 0x1B0562;
        mprotect((void *)0x34c000,0x2000, PROT_READ|PROT_EXEC);
    } else if (serverType == ServerCE) {
        *(uint32_t*)0x35F628 = 0x38;
        mprotect((void *)0xE0000,0x1FFFFE, PROT_READ|PROT_WRITE);
        *(uint8_t*)(0x1AE04C + 3) = 0x38; // packet count
        *(uint8_t*)(0x1b0594 + 2) = (0x38 - 6);
        *(uint8_t*)(0x1b027a + 3) = 0x38; // packet count
        mprotect((void *)0xE0000,0x1FFFFE, PROT_READ|PROT_EXEC);
       
        mprotect((void *)0x34c000,0x2000, PROT_READ|PROT_WRITE);
        *(uint32_t*)0x34c200 = (uint32_t)0x1b060f;
        *(uint32_t*)(0x34c060 + 4 * 54) = 0x1B0562; // handle the 'response' packet
        *(uint32_t*)(0x34c060 + 4 * 55) = 0x1B061E;
        *(uint32_t*)(0x34c060 + 4 * 56) = 0x1B0562;
        *(uint32_t*)(0x34c140 + 4 * 49) = 0x1B0562;
        *(uint32_t*)(0x34c140 + 4 * 50) = 0x1B0562;
        mprotect((void *)0x34c000,0x2000, PROT_READ|PROT_EXEC);
        
        *(uint32_t*)0x3A5738 = (uint32_t)motd_packet; //54
        *(uint32_t*)0x3A573C = (uint32_t)0x37A0A0; // rcon request - 55
        *(uint32_t*)0x3A5740 = (uint32_t)rcon_packet; // rcon response - 56
    }
    
    return oldrenderObjects(a,b,c,d,e,f,g);
}

void *(*oldRunCommand)(char *command,char *error_result, char *command_name) = NULL;
void runCommand(char *command,char *error_result, char *command_name) {
    if(strcmp(command_name,"connect") == 0) {
        serverType = ServerMD; // change to MD
        oldRunCommand(command, error_result, command_name);
    } else if(strcmp(command_name,"connectce") == 0) {
        serverType = ServerCE;
        uint32_t limit = 1024;
        char new_command[limit];
        snprintf(new_command, limit, "connect %s", &command[strlen(command_name) + 1]);
        oldRunCommand(new_command, error_result, "connect");
    } else if(strcmp(command_name,"bridge") == 0) {
        consolePrintf(WHITE, "Bridge");
        char *new_command = "connectce 127.0.0.1:4000 \"\"";
        runCommand(new_command, error_result, "connectce");
    } else if(strcmp(command_name,"rcon") == 0) {
        if (serverType == ServerCE) {
            consolePrintf(WHITE, "You cannot use rcon commands on CE servers in HaloMD at this time.");
        } else {
            oldRunCommand(command, error_result, command_name);
        }
    } else {
        oldRunCommand(command, error_result, command_name);
    }
}

-(void)CENetcode {
    mach_override_ptr((void *)0x2305E0, renderObjects, (void **)&oldrenderObjects);
    mach_override_ptr((void *)0x2d0a2a, networkSend, (void **)&oldnetworkSend);
    mach_override_ptr((void *)0x2cf7c4, networkRecv, (void **)&oldnetworkRecv);
    mach_override_ptr((void *)0x1ae5e4, networkPack, (void **)&oldnetworkPack);
    mach_override_ptr((void *)0x1ad190, networkPack2, (void **)&oldnetworkPack2);
    mach_override_ptr((void *)0x1b0258, networkPack3, (void **)&oldnetworkPack3);
    mach_override_ptr((void *)0x1ad142, networkPack4, (void **)&oldnetworkPack4);
    mach_override_ptr((void *)0x19c81c, halo_read_bits,  (void **)&oldhaloReadBits);
    //mach_override_ptr((void *)0x19c600, sub_19c600,  (void **)&oldsub_19c600);
    //mach_override_ptr((void *)0x19c798, sub_19c798,  (void **)&oldsub_19c798);
    
    

    ////sub_19c69a(*(edi + 0x10), 0x1) == 0x0)?
    //eax = *0x5b5130; <-- object index
    //sub_19c600(eax, stack[1518], 0x0);
    //eax = sub_1a96c6(eax, stack[2038]);
    //eax = sub_19ddb4(eax, arg0); <-- get object
    
    mach_override_ptr((void *)0x11e3de, runCommand, (void **)&oldRunCommand);
}


#pragma mark DECALS
uint32_t (*oldsub_19df28)() = NULL;
uint32_t sub_19df28(uint32_t a, uint32_t b) {
    return oldsub_19df28(a, b);
}

-(void)decal_limit {
    mach_override_ptr((void *)0x19df28, sub_19df28, (void **)&oldsub_19df28);
}


#pragma mark SERVER LIST

/*
 int sub_2c7524(int arg0) {
 sub_2c7503(arg0);
 eax = sub_2ee0a4(arg0 + 0x48);
 return eax;
 
 }
 
 
 
 int sub_15dd18() {
     *(int8_t *)0x3d50e4 = 0x1;
     *0x3d50f4 = sub_11524c(0xa, 0x15d450, *0x5b5198, 0x0, 0x1);
     while ((*(int8_t *)0x3d5124 & 0x2) == 0x0) {
        if (*0x3d50d8 == 0x0) {
            sub_15d790(); // clears?
        }
        sub_2add6c(0xa);
     }
     eax = *0x3d50f4;
     sub_2c7059(eax);
     *0x3d50f4 = 0x0;
     return 0x0;
 }

 int sub_2c7085(int arg0, int arg1, int arg2, int arg3, int arg4, int arg5, int arg6, int arg7) {
 sub_336330(); //<-- crash
 var_11C = arg1;
 var_118 = *(int8_t *)(ebx + 0xc0eab) & 0xff;
 memset(var_117, 0x0, 0xff);
 *(int8_t *)(arg0 + 0x608) = arg2 & 0xff;
 *(arg0 + 0x3c) = 0x0;
 while (0x0 < arg4) {
 var_18 = 0x0;
 ecx = 0xffffffff;
 var_128 = *(*(ebx + 0x2ee50b) + (*(int8_t *)(0x0 + arg3) & 0xff & 0xff) * 0x4);
 eax = 0x0;
 asm{ cld         };
 asm{ repne scasb al, byte [es:edi] };
 if (0x1 + (!ecx - 0x1) + var_18 > 0xff) {
 break;
 }
 *0x0 = *0x0 + sprintf(var_118 + 0x0, ebx + 0xc0fab);
 eax = *(int8_t *)(0x0 + arg3) & 0xff;
 sub_2eb62f(arg0, eax & 0xff); // doesn't do shit
 *0x0 = *0x0 + 0x1;
 }
 var_9 = sub_2ebe43(arg0 + 0x48, var_118, arg5, arg6, arg7); /// essential for scanning
 if (var_9 != 0x0) {
 var_124 = var_9 & 0xff;
 }
 else {
 if (var_11C == 0x0) {
 do {
 if ((*(int8_t *)(arg0 + 0x48) & 0xff) == 0x3) goto (null);
 sub_2e0fcf(0xa);
 var_9 = sub_2c74df(arg0);
 } while (true);
 }
 var_124 = var_9 & 0xff;
 }
 eax = var_124;
 return eax;
 }

 
 
 
*/


//0x2C753E	call 0x2ee0a4	E8 61 6B 02 00
//0x15DA49	call 0x2c7524	E8 D6 9A 16 00
//0x15DD70	call 0x15d790	E8 1B FA FF FF
//mov dword [0x3d510c], 0x0…	0x15DA8E	C7 05 0C 51 3D 00 00 00 00 00

uint32_t (*oldsub_2ee0a4)() = NULL;
uint32_t sub_2ee0a4(uint32_t a, uint32_t b, uint32_t c, uint32_t d, uint32_t e) {
    

    
    return oldsub_2ee0a4(a, b, c, d, e);
}

uint32_t (*oldaddServer)() = NULL;
uint32_t addServer(uint32_t a, uint32_t b, uint32_t c) {
    //fprintf(stderr, "ADD SERVER 0x%x, 0x%x, 0x%x\n", a, b, c);
    return oldaddServer(a,b,c);
}

-(void)serverCE {
    /*
     0x3d50f4 <-- pointer to struct
     [0x3d50f4]+0x1c <-- number of servers to check
     [0x3d50f4]+0x4 <-- number of sockets used to scan
     [0x3D510C] <-- servers in the list
     [0x3d5108] <-- server array
     [0x3d50f8] <--- display offset
     */
    mach_override_ptr((void *)0x2ebe43, sub_2ee0a4, (void **)&oldsub_2ee0a4);
    mach_override_ptr((void *)0x15d450, addServer, (void **)&oldaddServer);
}

#pragma mark CONSOLE_PACKETS
-(void)playerLimit {
    //NXArgc, Halo __DATA (static), rw-	0x37A2AC	13 <-- server size
    
    //0x378b58 - tiny locality reference position
    //0x378b5c - large locality reference position
    
    
}

#pragma mark SETUP
- (id)initWithMode:(MDPluginMode)mode
{
	self = [super init];
	if (self != nil)
	{
        updateSelf = self;
        map_mode = mode;
        
        //[self increaseTables];
        mprotect((void *)0xE0000,0x1FFFFE, PROT_READ|PROT_WRITE);
        [self elcap_fix];
        [self bsp];
        [self object_limit];
        [self ansi];
        //[self extra_resolutions];
        [self cpufix];
        //[self pixelAttributes]; <-- broken
        [self integratedGraphics];
        [self CENetcode];
        [self serverCE];
        [self playerLimit];
        //[self decal_limit];
        mprotect((void *)0xE0000,0x1FFFFE, PROT_READ|PROT_EXEC);
	}
	return self;
}

// Shameless self promotion
typedef enum
{
    NONE = 0x0,
    WHITE = 0x343aa0,
    GREY = 0x343ab0,
    BLACK = 0x343ac0,
    RED = 0x343ad0,
    GREEN = 0x343ae0,
    BLUE = 0x343af0,
    CYAN = 0x343b00,
    YELLOW = 0x343b10,
    MAGENTA = 0x343b20,
    PINK = 0x343b30,
    COBALT = 0x343b40,
    ORANGE = 0x343b50,
    PURPLE = 0x343b60,
    TURQUOISE = 0x343b70,
    DARK_GREEN = 0x343b80,
    SALMON = 0x343b90,
    DARK_PINK = 0x343ba0
} ConsoleColor;




void (*consolePrintf)(int color, const char *format, ...) = (void *)0x1588a8;
-(void)activatePlugin
{
    if (!shownMessage) {
        /*
        consolePrintf(WHITE, "Halo+ by Samuco & 002");
        consolePrintf(GREEN, "BSP Limit: 65536");
        consolePrintf(GREEN, "Visible Object Limit: 8192");
        consolePrintf(GREEN, "Anisotropic Filtering: 16x");
        consolePrintf(GREEN, "Custom Edition Servers: Enabled");
        */
    }
    shownMessage = YES;
    pluginIsActive = YES;
    
    // Start ansiotropical
    aa_enable();
}

- (void)mapDidBegin:(NSString *)mapName
{
    [self performSelector:@selector(activatePlugin) withObject:nil afterDelay:1];
}

- (void)mapDidEnd:(NSString *)mapName
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activatePlugin) object:nil];
}

@end
