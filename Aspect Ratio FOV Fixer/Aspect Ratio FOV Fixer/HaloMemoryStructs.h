//
//  HaloMemoryStructs.h
//  DarkAetherII
//
//  Created by Paul Whitcomb on 12/26/13.
//  Copyright (c) 2013 Paul Whitcomb. All rights reserved.
//

#include <stdlib.h>

typedef uint16_t unichar;

#ifndef DarkAetherII_HaloMemoryStructs_h
#define DarkAetherII_HaloMemoryStructs_h

typedef struct ColorARGB {
    float alpha;
    float red;
    float green;
    float blue;
} ColorARGB;

struct ObjectId {
    uint16_t objectTableIndex;
    uint16_t objectIndex;
};

struct TagID {
    uint16_t tagTableIndex;
    uint16_t tableIndex;
};

struct TagDependency {
    char className[4];
    void *tagMeta;
    uint32_t zero;
    struct TagID identity;
};

struct Vector {
    float x;
    float y;
    float z;
};

struct Orientation {
    float yaw;
    float pitch;
    float roll;
};

struct Player {
    uint16_t headerId;                          //0x0
    uint16_t isHost;                            //0x2
    unichar name1[0xC];                         //0x4
    uint32_t unknown0;                          //0x1C
    uint32_t team;                              //0x20
    struct ObjectId interactionObjectId;        //0x24
    uint16_t interactionObjectIdType;           //0x28
    uint16_t unknown11;                         //0x2A
    uint32_t respawnTime;                       //0x2C
    uint32_t respawnTimeGrowth;                 //0x30
    struct ObjectId objectId;                   //0x34
    uint16_t objectType;                        //0x38
    uint16_t unknown12;                         //0x3A
    char unknown1[0xC];                         //0x3C
    unichar name2[0xC];                         //0x48
    uint32_t color;                             //0x60
    uint16_t machineIndex;                      //0x64
    uint16_t machineTeam;                       //0x66
    uint32_t invisibleTime;                     //0x68
    float speedMultiplier;                      //0x6C
    char unknown2[0x14];                        //0x70
    uint32_t lastDeathTime;                     //0x84
    uint32_t slayerTarget;                      //0x88
    char oddManOut;                             //0x8C
    char filler3a[0x3];                         //0x8E
    char unknown3[0x6];                         //0x90
    uint16_t killstreak;                        //0x96
    uint16_t multikill;                         //0x98
    uint16_t lastKillTime;                      //0x9A
    uint16_t kills;                             //0x9C
    uint16_t unknown4[3];                       //0x9E
    uint16_t assists;                           //0xA4
    uint16_t unknown5[3];                       //0xA6
    uint16_t betraysAndSuicides;                //0xAC
    uint16_t deaths;                            //0xAE
    uint16_t suicides;                          //0xB0
    char unknown6[0xE];                         //0xB4
    uint32_t teamkills;                         //0xC0
    uint16_t flagStealsHillRaceTime;            //0xC4
    uint16_t flagReturnsOddballKillsRaceLaps;   //0xC6
    uint16_t ctfScoreOddballKillsRaceBestTime;  //0xC8
    uint16_t filler7;                           //0xCA
    uint32_t telefragTimer;                     //0xCC
    char unknown7[0x4];                         //0xD0
    char telefragEnabled;                       //0xD4
    char unknown10[0x7];                        //0xD5
    uint16_t ping;                              //0xDC
    uint16_t filler10;                          //0xDE
    uint32_t teamkillCount;                     //0xE0
    uint32_t teamkillTimer;                     //0xE4
    char unknown8[0x10];                        //0xE8
    struct Vector vector;                       //0x98
    char unknown9[0xFC];                        //0x104
};

struct BaseObject {
    struct TagID tagId;                         //0x0
    char unknown0[0x58];                        //0x4
    struct Vector location;                     //0x5C
    struct Vector acceleration;                 //0x68
    struct Orientation orientation;             //0x74
    char unknown1[0xC];                         //0x80
    struct Orientation orientationAcceleration; //0x8C
    char unknown2[0x20];                        //0x98
    uint16_t team;                              //0xB8
    uint16_t unknown7;                          //0xBA
    char unknown3[0x8];                         //0xBC
    uint32_t player;                            //0xC4
    struct ObjectId owner;                      //0xC8
    char unknown4[0xC];                         //0xCC
    float maxHealth;                            //0xD8
    float maxShield;                            //0xDC
    float health;                               //0xE0
    float shield;                               //0xE4
    char unknown5[0x1C];                        //0xE8
    uint32_t shieldsRechargeDelay;              //0x104
    char unknown6[0x10];                        //0x108
    struct ObjectId heldWeaponIndex;            //0x118
    struct ObjectId vehicleIndex;               //0x11C
    uint32_t vehicleSeat;                       //0x120
}; //0x124 - incomplete

struct BipedObject {
    struct BaseObject objectData;               //0x0
    char unknown0[0xA8];                        //0x124
    struct ColorARGB tint;                      //0x1cc
    char unknown7[0x28];                        //0x1dc
    uint8_t camouflageData;                     //0x204
    char unknown6[0x3];                         //0x205
    uint32_t controlsBitmask;                   //0x208
    char unknown5[0xE6];                        //0x20C
    uint16_t weaponSlot;                        //0x2F2
    uint16_t nextWeaponSlot;                    //0x2F4
    uint16_t unknown1;                          //0x2F6
    struct ObjectId weapons[4];                 //0x2F8
    char unknown2[0x14];                        //0x308
    uint8_t nadeType;                           //0x31C
    char unknown3;                              //0x31D
    int8_t nadeCount[2];                        //0x31E
    uint16_t zoom;                              //0x320
    char unknown4[0x22];                        //0x322
    float flashlightBattery;                    //0x344
}; //0x348 - incomplete

struct WeaponObject {
    struct BaseObject objectData;               //0x0
    float fuel;                                 //0x124
    char unknown0[0x18];                        //0x128
    float charging;                             //0x140
    char unknown1[0xF8];                        //0x144
    float heat;                                 //0x23C
    float age;                                  //0x240
    uint32_t unknown2;                          //0x244
    float luminosity;                           //0x248
    char unknown3[0x6A];                        //0x24C
    uint16_t primaryAmmo;                       //0x2B6
    uint16_t primaryClip;                       //0x2B8
    char unknown4[0x8];                         //0x2BA
    uint16_t secondaryAmmo;                     //0x2C2
    uint16_t secondaryClip;                     //0x2C4
}; //0x2C6 - incomplete

struct ObjectIndex {
    struct TagID tagId;                         //0x0
    uint32_t mumboJumbo;                        //0x4
    struct BaseObject *object;                  //0x8
};


struct ObjectsTable {
    char objectString[0x20];
    uint16_t maximumObjectsPossible;
    uint16_t objectIndexStructSize;
    uint32_t one;
    char dataString[0x4];
    uint16_t numberOfObjects;
    uint16_t numberOfObjects1;
    struct ObjectId nextObject;
    struct ObjectIndex *objects;
};

struct Particle {
    uint32_t data0;
    char data[0x70 - 0x4];
};

struct ParticlesTable {
    char particlesString[0x20];
    uint16_t maximumParticlesPossible;
    uint16_t particleStructSize;
    uint32_t one;
    char dataString[0x4];
    uint16_t numberOfParticles;
    uint16_t numberOfParticles1;
    uint32_t unknown1;
    struct Particle *particles;
};

struct PlayersTable {
    char playersString[0x20];
    uint16_t maximumPlayersPossible;
    uint16_t playerStructSize;
    uint32_t one;
    char dataString[0x4];
    uint16_t numberOfPlayers;
    uint16_t numberOfObjects1;
    uint32_t unknown1;
    struct Player *players;
};

typedef enum {
    FADE_LINEAR = 0,
    FADE_EARLY = 1,
    FADE_VERY_EARLY = 2,
    FADE_LATE = 3,
    FADE_VERY_LATE = 4,
    FADE_COSINE = 5
} FadeFunction;

typedef enum {
    FUNCT_ONE = 0,
    FUNCT_ZERO = 1,
    FUNCT_COS = 2,
    FUNCT_COS_VARIABLE = 3,
    FUNCT_DIAGONAL_WAVE = 4,
    FUNCT_DIAGONAL_WAVE_VARIABLE = 5,
    FUNCT_SLIDE = 6,
    FUNCT_SLIDE_VARIABLE = 7,
    FUNCT_NOISE = 8,
    FUNCT_JITTER = 9,
    FUNCT_WANDER = 10,
    FUNCT_SPARK = 11
} HaloFunction;

struct DamageScreenFlash {
    uint16_t type;                              //0x24
    uint16_t priority;                          //0x26
    char unknown0[0xC];                         //0x28
    float duration;                             //0x34
    FadeFunction fadeFunction;                  //0x38
    char unknown1[0x8];                         //0x3C
    float intensity;                            //0x44
    uint32_t unknown2;                          //0x48
    struct ColorARGB color;                     //0x4C
}; //0x5C


struct DamageTag {
    float radiusFrom;                           //0x0
    float radiusTo;                             //0x4
    float cutoffScale;                          //0x8
    uint16_t flagsBitmask;                      //0xC
    char unknown0[0x14];                        //0x10
    struct DamageScreenFlash damageScreenFlash; //0x24
    float lowFrequencyVibrateFrequency;         //0x5C
    float lowFrequencyVibrateDuration;          //0x60
    FadeFunction lowFrequencyFadeFunction;      //0x64
    char unknown1[0x8];                         //0x68
    float highFrequencyVibrateFrequency;        //0x70
    float highFrequencyVibrateDuration;         //0x74
    FadeFunction highFrequencyFadeFunction;     //0x78
    char unknown2[0x1C];                        //0x7C
    float tempCameraImpulseDuration;            //0x98
    FadeFunction tempCameraImpulseFadeFunction; //0x9C
    float tempCameraImpulseRotation;            //0xA0
    float tempCameraImpulsePushback;            //0xA4
    float tempCameraImpulseJitterFrom;          //0xA8
    float tempCameraImpulseJitterTo;            //0xAC
    char unknown3[0x8];                         //0xB0
    float permanentImpulseCameraAngle;          //0xB8
    char unknown4[0x10];                        //0xBC
    float cameraShakeDuration;                  //0xCC
    FadeFunction cameraShakeFalloffFunction;    //0xD0
    float cameraShakeRandomTranslation;         //0xD4
    float cameraShakeRandomRotation;            //0xD8
    char unknown5[0xC];                         //0xDC
    HaloFunction cameraShakeWobbleFunction;     //0xE8
    float cameraShakeWobblePeriod;              //0xEC
    float cameraShakeWobbleWeight;              //0xF0
    char unknown6[0x20];                        //0xF4
    struct TagDependency sound;                 //0x114
    char unknown7[0x70];                        //0x124
    float breakingEffectForwardVelocity;        //0x194
    float breakingEffectForwardRadius;          //0x198
    float breakingEffectForwardExponent;        //0x19C
    char unknown8[0xC];                         //0x1A0
    float breakingEffectOutwardVelocity;        //0x1AC
    float breakingEffectOutwardRadius;          //0x1B0
    float breakingEffectOutwardExponent;        //0x1B4
    char unknown9[0xC];                         //0x1B8
    uint16_t damageSideEffect;                  //0x1C4
    uint16_t damageCategory;                    //0x1C6
    uint32_t damageFlags;                       //0x1C8
    float AOECoreRadius;                        //0x1CC
    float damageLowerBound;                     //0x1D0
    float damageUpperBoundFrom;                 //0x1D4
    float damageUpperBoundTo;                   //0x1D8
    float damageVehicleFraction;                //0x1DC
    float damageActiveCamouflageDamage;         //0x1E0
    float damageStun;                           //0x1E4
    float damageStunMax;                        //0x1E8
    float damageStunTime;                       //0x1EC
    uint32_t unknown10;                         //0x1F0
    float damageForce;                          //0x1F4
    char unknown11[0x8];                        //0x1F8
    float damageScaleDirt;                      //0x200
    float damageScaleSand;
    float damageScaleStone;
    float damageScaleSnow;
    float damageScaleWood;
    float damageScaleMetalHollow;
    float damageScaleMetalThin;
    float damageScaleMetalTick;
    float damageScaleRubber;
    float damageScaleGlass;
    float damageScaleForceField;
    float damageScaleGrunt;
    float damageScaleHunterArmor;
    float damageScaleHunterSkin;
    float damageScaleElite;
    float damageScaleJackal;
    float damageScaleJackalShield;
    float damageScaleEngineer;
    float damageScaleEngineerForceField;
    float damageScaleFloodCombatForm;
    float damageScaleFloodCarrierForm;
    float damageScaleCyborg;
    float damageScaleCyborgEnergyShield;
    float damageScaleArmoredHuman;
    float damageScaleHuman;
    float damageScaleSentinel;
    float damageScaleMonitor;
    float damageScalePlastic;
    float damageScaleWater;
    float damageScaleLeaves;
    float damageScaleEliteEnergyShield;
    float damageScaleIce;
    float damageScaleHunterShield;              //0x280
    char unknown[0x1C];                         //0x284
}; //0x2A0


struct PlayersTable *GetPlayersTable();
struct ObjectsTable *GetObjectsTable();
struct ParticlesTable *GetParticlesTable();
struct Player *GetPlayer(int player);
struct BaseObject *ObjectFromObjectTableIndex(uint16_t objectTableIndex);
struct BaseObject *ObjectFromObjectId(struct ObjectId objectId);
void *TagDataFromTagID(struct TagID tagID);

#endif
