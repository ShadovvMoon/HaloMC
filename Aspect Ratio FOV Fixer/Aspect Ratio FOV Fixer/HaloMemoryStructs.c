//
//  HaloMemoryStructs.c
//  DarkAetherII
//
//  Created by Paul Whitcomb on 12/26/13.
//  Copyright (c) 2013 Paul Whitcomb. All rights reserved.
//

#include <stdio.h>
#include "HaloMemoryStructs.h"

#define PLAYERS_TABLE_POINTER 0x45E5A8
#define OBJECT_TABLE_POINTER 0x47871C
#define PARTICLES_TABLE_POINTER 0x45DE00
#define MAP_INDEX 0x40440000

struct Tag {
	char classA[0x4];
	char classB[0x4];
	char classC[0x4];
	struct TagID identity;
	char *name;
	void *data;
	char padding[0x8];
};

struct MapIndex {
	struct Tag *tagArray;
	uint32_t baseId;
	uint32_t mapId;
	uint32_t tagCount;
	uint32_t vertexObjectCount;
	uint32_t vertexOffset;
	uint32_t indicesObjectCount;
	uint32_t vertexSize;
	uint32_t modelSize;
	char tagsSignature[0x4];
};

struct ParticlesTable *GetParticlesTable() {
    return (struct ParticlesTable *)(*(uint32_t *)PARTICLES_TABLE_POINTER);
}
struct PlayersTable *GetPlayersTable() {
    return (struct PlayersTable *)(*(uint32_t *)PLAYERS_TABLE_POINTER);
}
struct Player *GetPlayer(int player) {
    return &(*GetPlayersTable()).players[player];
}
struct ObjectsTable *GetObjectsTable() {
    return (struct ObjectsTable *)(*(uint32_t *)OBJECT_TABLE_POINTER);
}
struct BaseObject *ObjectFromObjectTableIndex(uint16_t objectTableIndex)
{
    return (GetObjectsTable())->objects[objectTableIndex].object;
}
struct BaseObject *ObjectFromObjectId(struct ObjectId objectId)
{
    return ObjectFromObjectTableIndex(objectId.objectTableIndex);
}
void *TagDataFromTagID(struct TagID tagID)
{
    struct MapIndex *index = (struct MapIndex *)(MAP_INDEX);
    if(tagID.tagTableIndex >= index->tagCount)
        return NULL;
    return index->tagArray[tagID.tagTableIndex].data;
}
