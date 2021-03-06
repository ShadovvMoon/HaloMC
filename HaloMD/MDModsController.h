//
//  MDModsController.h
//  HaloMD
//
//  Created by null on 5/26/12.
//

/*
 * Copyright (c) 2013, Null <foo.null@yahoo.com>
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

#import <Foundation/Foundation.h>
#import "SCEventListenerProtocol.h"

#define MODS_LIST_DOWNLOAD_TIME_KEY @"MODS_LIST_DOWNLOAD_TIME_KEY"
#define USES_MODS_MIRROR_KEY @"UsesModsMirror"

#define USES_MODS_MIRROR ([[NSUserDefaults standardUserDefaults] boolForKey:USES_MODS_MIRROR_KEY])

#define MODS_BASE_URL (USES_MODS_MIRROR ? @"https://halomdmirror.galaxyverge.com/mods" : @"https://halomd.macgamingmods.com/mods")

#define MAXIMUM_MAP_NAME_LENGTH 31

@class AppDelegate;
@class MDModPatch;
@class MDServer;
@class MDPluginListItem;

@interface MDModsController : NSObject <SCEventListenerProtocol, NSURLDownloadDelegate>
{
	__unsafe_unretained IBOutlet AppDelegate *appDelegate;
	IBOutlet NSMenu *onlineModsMenu;
	IBOutlet NSMenu *pluginsMenu;
	IBOutlet NSMenu *onlinePluginsMenu;
	IBOutlet NSButton *cancelButton;
	IBOutlet NSButton *refreshButton;
	NSMutableArray *localModItems;
	NSMutableDictionary *modListDictionary;
	NSMutableArray *pluginMenuItems;
	NSMutableDictionary *pluginListDictionary;
	
	NSURLDownload *modDownload;
	NSString *urlToOpen;
	
	NSString *currentDownloadingMapIdentifier;
	NSString *pendingDownload;
	
	NSMutableArray *pendingPlugins;
	
	MDModPatch *currentDownloadingPatch;
	
	MDPluginListItem *currentDownloadingPlugin;
	
	MDServer *joiningServer;
	
	NSTimer *downloadModListTimer;
	
	NSDate *resumeTimeoutDate;
	
	long long expectedContentLength;
	long long currentContentLength;
	
	BOOL isInitiated;
	BOOL isDownloadingModList;
	BOOL didDownloadModList;
	
	SCEvents *events;
}

@property (nonatomic, retain) NSMutableArray *localModItems;
@property (nonatomic, retain) NSMutableDictionary *modListDictionary;
@property (nonatomic, retain) NSMutableArray *pluginMenuItems;
@property (nonatomic, retain) NSMutableDictionary *pluginListDictionary;
@property (nonatomic, copy) NSString *currentDownloadingMapIdentifier;
@property (nonatomic, readwrite) BOOL isInitiated;
@property (nonatomic, retain) NSURLDownload *modDownload;
@property (nonatomic, copy) NSString *urlToOpen;
@property (nonatomic, readwrite) BOOL didDownloadModList;
@property (nonatomic, copy) NSString *pendingDownload;
@property (nonatomic, retain) NSMutableArray *pendingPlugins;
@property (nonatomic, retain) MDModPatch *currentDownloadingPatch;
@property (nonatomic, retain) MDPluginListItem *currentDownloadingPlugin;
@property (nonatomic, retain) MDServer *joiningServer;

+ (id)modsController;

- (void)openURL:(NSString *)url;

- (void)initiateAndForceDownloadList:(NSNumber *)shouldForceDownloadList;

- (BOOL)addModAtPath:(NSString *)filename;
- (BOOL)addPluginAtPath:(NSString *)filename preferringEnabledState:(BOOL)preferringEnabledState;

- (void)requestModDownload:(NSString *)mapIdentifier andJoinServer:(MDServer *)server;
- (BOOL)requestPluginDownloadIfNeededFromMod:(NSString *)mapIdentifier andJoinServer:(MDServer *)server;

- (IBAction)cancelInstallation:(id)sender;
- (IBAction)addMods:(id)sender;

- (IBAction)revealMapsInFinder:(id)sender;

@end
