//
//  ZZTSapphire.m
//  Sapphire
//
//  Created by Paul Whitcomb on 7/24/16.
//  Copyright © 2016 Paul Whitcomb. All rights reserved.
//

#import "ZZTSapphire.h"
#import "mach_override.h"

@implementation ZZTSapphire

extern void *map_from_pointer(const void *pointer, size_t size);
extern void *get_tag(const void *map, const char *tag_path, uint32_t class, size_t tag_id);
extern void free_map(void *map);

static bool fix = true;
static void *map = NULL;

static void *map_file = NULL;
static size_t map_size = 0;

static uint32_t *sdiff_file = NULL;
static size_t sdiff_size = 0;

static uint32_t *bdiff_file = NULL;
static size_t bdiff_size = 0;

typedef struct MapResource {
    uint32_t resource_name_offset;
    uint32_t who_fucking_cares[2];
} MapResource;

static void *bitmaps = NULL;
static char *bitmaps_strings = NULL;
static MapResource *bitmaps_resources = NULL;
static uint32_t bitmaps_count = 0;

static void *loc = NULL;
static char *loc_strings = NULL;
static MapResource *loc_resources = NULL;
static uint32_t loc_count = 0;

typedef struct Tag {
    uint32_t classA;
    uint32_t dontCare[2];
    uint32_t tagId;
    char *tagName;
    void *tagData;
    uint32_t notInMap;
    uint32_t dontCareAboutThisEither;
} Tag;

typedef struct TagDependency {
    uint32_t classA;
    char *tagName;
    uint32_t whoCares;
    uint32_t tagId;
} TagDependency;

typedef struct TagReflexive {
    uint32_t count;
    void *data;
} TagReflexive;

Tag **tag_array = (Tag **)0x40440000;

static bool tag_exists(uint32_t tag_id) {
    return tag_id != 0xFFFFFFFF && (tag_id & 0xFFFF) < *(uint32_t *)(0x4044000C) && (tag_id & 0xFFFF) != *(uint16_t *)(0x40440004);
}

static Tag *tag_from_id(uint32_t tag_id) {
    if(!tag_exists(tag_id)) return NULL;
    return *tag_array + (tag_id & 0xFFFF);
}

static void set_tag_class(uint32_t tag_id, uint32_t class) {
    Tag *tag = tag_from_id(tag_id);
    if(tag == NULL) return;
    tag->classA = class;
}

static void deprotect_object(uint32_t object) {
    if(object == 0xFFFFFFFF) {
        return;
    }
    Tag *tag = tag_from_id(object);
    if(tag == NULL) return;
    uint16_t object_type = *(uint16_t *)(tag->tagData);
    
    // Vehicle or Biped
    if(object_type == 0 || object_type == 1) {
        TagReflexive *unhis = (TagReflexive *)(tag->tagData + 0x2A8);
        for(uint32_t i=0;i<unhis->count;i++) {
            set_tag_class(*(uint32_t *)(unhis->data + i * 48 + 0xC), 1970169961);
        }
        deprotect_object_reflexive((TagReflexive *)(tag->tagData + 0x2D8), 0, 36);
    }
    // Weapon
    else if(object_type == 2) {
        Tag *tag2 = tag_from_id(*(uint32_t *)(tag->tagData + 0x480 + 0xC));
        if(tag2 != NULL) {
            tag2->classA = 2003855465;
            set_tag_class(*(uint32_t *)(tag2->tagData + 0xC), 2003855465);
            deprotect_object_reflexive((TagReflexive *)(tag->tagData + 0x4FC), 0x94, 276);
        }
    }
    
    TagReflexive *attachments = (TagReflexive *)(tag->tagData + 0x140);
    
    for(uint32_t i=0;i<attachments->count;i++) {
        TagDependency *attachment = attachments->data + i * 72;
        Tag *tag2 = tag_from_id(attachment->tagId);
        if(tag2 != NULL) {
            tag2->classA = attachment->classA;
            
            // Fuzzy match for cont
            uint16_t flags = *(uint16_t *)(tag2->tagData + 0);
            uint16_t flags2 = *(uint16_t *)(tag2->tagData + 2);
            uint16_t render_type = *(uint16_t *)(tag2->tagData + 0x18);
            uint16_t render_shader_flags = *(uint16_t *)(tag2->tagData + 0xAC);
            uint16_t render_blend_function = *(uint16_t *)(tag2->tagData + 0xAE);
            uint16_t render_fade_mode = *(uint16_t *)(tag2->tagData + 0xB0);
            printf("%x %x %x %x %x %x %x\n", attachment->classA, flags, flags2, render_type, render_shader_flags, render_blend_function, render_fade_mode);
            TagReflexive *point_states = (TagReflexive *)(tag2->tagData + 0x138);
            TagDependency *render_bitmap = tag2->tagData + 0x30;
            if(flags <= 127 && flags2 <= 1023 && render_type <= 5 && tag_exists(render_bitmap->tagId) && render_shader_flags <= 7 && render_blend_function <= 7 && render_fade_mode <= 2 && point_states->count > 0 && point_states->data > (void *)0x40440000 && point_states->data <= (void *)(0x41B00000 - point_states->count * 104)) {
                tag2->classA = 1668247156;
                attachment->classA= 1668247156;
            }
            else {
                
            }
        }
    }
    
    TagReflexive *widgets = (TagReflexive *)(tag->tagData + 0x14C);
    
    for(uint32_t i=0;i<widgets->count;i++) {
        TagDependency *widget = widgets->data + i * 32;
        Tag *tag2 = tag_from_id(widget->tagId);
        if(tag2 != NULL) {
            // Fuzzy match for flag
            float cell_width = *(float *)(tag2->tagData + 0x10);
            float cell_height = *(float *)(tag2->tagData + 0x14);
            int16_t width = *(int16_t *)(tag2->tagData + 0xC);
            int16_t height = *(int16_t *)(tag2->tagData + 0xE);
            uint16_t trailing_edge_shape = *(uint16_t *)(tag2->tagData + 0x4);
            TagDependency *red_flag_shader = tag2->tagData + 0x18;
            TagDependency *blue_flag_shader = tag2->tagData + 0x44;
            if(cell_width > 0.0 && cell_width < 1.0 && cell_height > 0.0 && cell_height < 1.0 && height > 0 && width > 0 && trailing_edge_shape <= 4 && tag_exists(red_flag_shader->tagId) && tag_exists(blue_flag_shader->tagId)) {
                widget->classA = 1718378855;
                tag2->classA = 1718378855;
            }
            else {
                // Fuzzy match for ant!
                TagDependency *bitmaps = tag2->tagData + 0x20;
                TagDependency *physics = tag2->tagData + 0x30;
                TagReflexive *vertices = tag2->tagData + 0xC4;
                if(tag_exists(bitmaps->tagId) && tag_exists(physics->tagId) && vertices->count > 0 && vertices->data > (void *)0x40440000 && vertices->data < (void *)(0x41B00000 - vertices->count * 128)) {
                    widget->classA = 1634628641;
                    tag2->classA = 1634628641;
                }
                else {
                    // Fuzzy match for mgs2
                    uint16_t light_volume_flags = *(uint16_t *)(tag2->tagData + 0x22);
                    uint16_t brightness_scale_source = *(uint16_t *)(tag2->tagData + 0x44);
                    TagReflexive *frames = (TagReflexive *)(tag2->tagData + 0x120);
                    if(frames->count > 0 && frames->data > (void *)(0x40440000) && frames->data < (void *)(0x41B00000 - 176 * frames->count) && light_volume_flags <= 3 && brightness_scale_source <= 4) {
                        widget->classA = 1835496242;
                        tag2->classA = 1835496242;
                    }
                }
            }
        }
    }
}

static void deprotect_object_reflexive(TagReflexive *reflexive, size_t offset, uint32_t reflexive_size) {
    for(uint32_t i=0;i<reflexive->count;i++) {
        TagDependency *dependency = reflexive->data + offset + i * reflexive_size;
        deprotect_object(dependency->tagId);
    }
}


static void *(*doStuff)(void *a, void *b, void *c, void *d, void *e, void *f, void *g, void *h) = NULL;
static void *overrideStuff(void *a, void *b, void *c, void *d, void *e, void *f, void *g, void *h) {
    //I don't know what this does, but Halo calls this before reading the map
    void *returnValue = doStuff(a,b,c,d,e,f,g,h);
    if (fix) {
        free_map(map);
        map = map_from_pointer(map_file, map_size);
        fix = false;
        
        Tag *tag_array = *((Tag **)0x40440000);
        uint32_t *tag_count = (uint32_t *)0x4044000C;
        
        for(uint32_t i=0;i<*tag_count;i++) {
            if(tag_array[i].notInMap == 1) {
                const char *tag_name;
                
                // if bitmap
                if(tag_array[i].classA == 1651078253) {
                    tag_name = bitmaps_strings + bitmaps_resources[(uint32_t)tag_array[i].tagData].resource_name_offset;
                }
                // if sound...
                else if(tag_array[i].classA == 1936614433) {
                    tag_name = tag_array[i].tagName;
                }
                // otherwise...
                else {
                    tag_name = loc_strings + loc_resources[(uint32_t)tag_array[i].tagData].resource_name_offset;
                }
                
                tag_array[i].tagData = get_tag(map, tag_name, tag_array[i].classA, tag_array[i].tagId);
                tag_array[i].notInMap = 0;
            }
            else if(*(uint32_t *)(0x3AD208) == 0x261) {
                bool found_it = true;
                // BITM
                if(tag_array[i].classA == 0x6269746D) {
                    uint32_t *bitmaps = tag_array[i].tagData + 0x60;
                    for(uint32_t i=0;i<bitmaps[0];i++) {
                        void *bitmap = (void *)(bitmaps[1] + i * 0x30);
                        if(*(uint8_t *)(bitmap + 0xF) == 0) {
                            continue;
                        }
                        bool failed = true;
                        uint32_t *data_offset = (uint32_t *)(bitmap + 0x18);
                        for(uint32_t b=0;b<bdiff_size/sizeof(uint32_t);b+=2) {
                            if(bdiff_file[b] == *data_offset) {
                                *data_offset = bdiff_file[b + 1];
                                failed = false;
                                break;
                            }
                        }
                        if(failed) {
                            found_it = false;
                        }
                    }
                }
                // SND!
                else if(tag_array[i].classA == 0x736E6421) {
                    uint32_t *ranges = tag_array[i].tagData + 0x98;
                    for(uint32_t i=0;i<ranges[0];i++) {
                        uint32_t *permutations = (uint32_t *)(ranges[1] + i * 0x48 + 0x3C);
                        for(uint32_t p=0;p<permutations[0];p++) {
                            void *permutation = (void *)(permutations[1] + p * 0x7C);
                            if(*(uint8_t *)(permutation + 0x44) == 0) {
                                continue;
                            }
                            bool failed = false;
                            for(uint32_t s=0;s<sdiff_size/sizeof(uint32_t);s+=2) {
                                uint32_t *data_offset = (uint32_t *)(permutation + 0x48);
                                if(sdiff_file[s] == *data_offset) {
                                    *data_offset = sdiff_file[s + 1];
                                    failed = false;
                                    break;
                                }
                            }
                            if(failed) {
                                found_it = false;
                            }
                        }
                    }
                }
                else if(tag_array[i].classA == 1835103335 && strcmp(tag_array[i].tagName,"globals\\globals") == 0) {
                    deprotect_object_reflexive(tag_array[i].tagData + 0x14C, 0, 16);
                    deprotect_object_reflexive(tag_array[i].tagData + 0x170, 0, 244);
                    deprotect_object_reflexive(tag_array[i].tagData + 0x164, 0, 160);
                    TagReflexive *grhis = tag_array[i].tagData + 0x128;
                    for(uint32_t i=0;i<grhis->count;i++) {
                        set_tag_class(*(uint32_t *)(grhis->data + 0x14 + 0xC + i * 68), 1735551081);
                    }
                    TagReflexive *interface_bitmaps = tag_array[i].tagData + 0x140;
                    for(uint32_t i=0;i<interface_bitmaps->count;i++) {
                        set_tag_class(*(uint32_t *)(interface_bitmaps->data + 0x60 + 0xC + i * 304), 1752523879);
                    }
                    TagReflexive *multiplayer_information = tag_array[i].tagData + 0x164;
                    for(uint32_t i=0;i<multiplayer_information->count;i++) {
                        deprotect_object(*(uint32_t *)(multiplayer_information->data + 0x0 + 0xC + i * 160));
                        deprotect_object(*(uint32_t *)(multiplayer_information->data + 0x10 + 0xC + i * 160));
                        deprotect_object_reflexive(multiplayer_information->data + 0x20 + i * 160, 0, 16);
                    }
                }
            }
        }
    }
    
    return returnValue;
}

- (id) initWithMode:(MDPluginMode)mode {
    self = [super init];
    if(self != nil) {
        mach_override_ptr((void *)(0xc3150), overrideStuff, (void **)&doStuff);
        
        void *protectLocation = (void *)0x62000;
        mprotect(protectLocation, 0x1000, PROT_READ | PROT_WRITE); //make sure Halo doesn't reject a map because of its version
        void *memsetLocation = (void *)(0x62fd9);
        memset(memsetLocation,0x90,3);
        *(uint8_t *)(0x62fdc) = 0xEB;
        mprotect(protectLocation, 0x1000, PROT_READ | PROT_EXEC);
        NSData *resource_map = [NSData dataWithContentsOfURL:[[NSBundle bundleWithIdentifier:@"com.protonnebula.Sapphire"] URLForResource:@"resources" withExtension:@"map"]];
        map_size = [resource_map length];
        map_file = malloc(map_size);
        memcpy(map_file,[resource_map bytes],map_size);
        
        NSData *sounds_diff = [NSData dataWithContentsOfURL:[[NSBundle bundleWithIdentifier:@"com.protonnebula.Sapphire"] URLForResource:@"sounds_diff" withExtension:@"rmap"]];
        sdiff_size = [sounds_diff length];
        sdiff_file = malloc(sdiff_size);
        memcpy(sdiff_file,[sounds_diff bytes],sdiff_size);
        
        NSData *bitmaps_diff = [NSData dataWithContentsOfURL:[[NSBundle bundleWithIdentifier:@"com.protonnebula.Sapphire"] URLForResource:@"bitmaps_diff" withExtension:@"rmap"]];
        bdiff_size = [bitmaps_diff length];
        bdiff_file = malloc(bdiff_size);
        memcpy(bdiff_file,[bitmaps_diff bytes],bdiff_size);
        
        NSData *bitmap_data = [NSData dataWithContentsOfURL:[[NSBundle bundleWithIdentifier:@"com.protonnebula.Sapphire"] URLForResource:@"bitmaps" withExtension:@"map"]];
        size_t bitmaps_size = [bitmap_data length];
        bitmaps = malloc(bitmaps_size);
        memcpy(bitmaps,[bitmap_data bytes],bitmaps_size);
        bitmaps_count = *(uint32_t *)(bitmaps + 0xC);
        bitmaps_strings = bitmaps + *(uint32_t *)(bitmaps + 0x4);
        bitmaps_resources = bitmaps + *(uint32_t *)(bitmaps + 0x8);
        
        NSData *loc_data = [NSData dataWithContentsOfURL:[[NSBundle bundleWithIdentifier:@"com.protonnebula.Sapphire"] URLForResource:@"loc" withExtension:@"map"]];
        size_t loc_size = [loc_data length];
        loc = malloc(loc_size);
        memcpy(loc,[loc_data bytes],loc_size);
        loc_count = *(uint32_t *)(loc + 0xC);
        loc_strings = loc + *(uint32_t *)(loc + 0x4);
        loc_resources = loc + *(uint32_t *)(loc + 0x8);
    }
    return self;
}

- (void)mapDidBegin:(NSString *)mapName {
}
- (void)mapDidEnd:(NSString *)mapName {
    fix = true;
}

@end
