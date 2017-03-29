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

//
//  MDChatWindowController.m
//  HaloMD
//
//  Created by null on 2/23/13.
//

#import "MDChatWindowController.h"
#import "MDChatRosterElement.h"
#ifdef USE_GROWL
#import <Growl/Growl.h>
#endif
#import <CommonCrypto/CommonDigest.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import "AppDelegate.h"
#import "MDServer.h"
#import "MDHashDigest.h"

@interface MDChatWindowController ()

@property (nonatomic) MDChatConnection *connection;
@property (nonatomic) BOOL attemptedSignOnBefore;
@property (nonatomic) NSString *desiredNickname;
@property (nonatomic) NSString *desiredUserIdentifier;
@property (nonatomic) NSString *userIdentifier;
@property (nonatomic) NSUInteger authTag;
@property (nonatomic) BOOL sleeping;
@property (nonatomic) BOOL succeededInDelayingSleep;
@property (nonatomic) IOPMAssertionID sleepAssertionID;
@property (nonatomic) BOOL closingWindow;
@property (nonatomic) BOOL showJIDOnBan;

@property (nonatomic) NSScrollView *scrollView;
@property (nonatomic) BOOL isChangingWebFrame;
@property (nonatomic) NSPoint oldScrollPosition;

@end

@implementation MDChatWindowController

@synthesize myNick;

#define MD_STATUS_PREFIX @"!MD"
#define AUTO_SCROLL_PIXEL_THRESHOLD 20.0

#define CHAT_TEXT_CHECKING_TYPES_KEY @"CHAT_TEXT_CHECKING_TYPES"

#define CHAT_MAX_DEFAULT_BACKLOG_KEY @"CHAT_MAX_DEFAULT_BACKLOG_KEY"
#define CHAT_MAX_DEFAULT_BACKLOG 300U

#define CHAT_MAX_MESSAGE_LENGTH 500U

+ (void)initialize
{
	// Use empty strings as our "null" value
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{ CHAT_TEXT_CHECKING_TYPES_KEY : @"", CHAT_MAX_DEFAULT_BACKLOG_KEY : @(CHAT_MAX_DEFAULT_BACKLOG)}];
}

- (id)init
{
	self = [super initWithWindowNibName:NSStringFromClass([self class])];
	if (self)
	{
		roster = [[NSMutableArray alloc] init];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillBecomeActive:) name:NSApplicationWillBecomeActiveNotification object:nil];
		
		[(AppDelegate *)[NSApp delegate] addObserver:self forKeyPath:@"inGameServer" options:NSKeyValueObservingOptionNew context:NULL];
		
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(systemWillSleep:) name:NSWorkspaceWillSleepNotification object:nil];
		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(systemDidWake:) name:NSWorkspaceDidWakeNotification object:nil];
		
		NSMutableString *strippedNickname = [NSMutableString string];
		NSString *profileName = [(AppDelegate *)[NSApp delegate] profileName];
		
		if (![profileName canBeConvertedToEncoding:NSUTF8StringEncoding])
		{
			for (NSUInteger profileNameIndex = 0; profileNameIndex < [profileName length]; profileNameIndex++)
			{
				unichar character = [profileName characterAtIndex:profileNameIndex];
				NSString *unicodeString = [NSString stringWithCharacters:&character length:1];
				if ([unicodeString canBeConvertedToEncoding:NSUTF8StringEncoding])
				{
					[strippedNickname appendString:unicodeString];
				}
			}
		}
		else
		{
			[strippedNickname setString:profileName];
		}
		
		NSMutableString *nickname = [NSMutableString stringWithString:strippedNickname];
		if (!nickname || [nickname length] == 0)
		{
			nickname = [NSMutableString stringWithString:@"HaloNewb"];
		}
		
		[nickname replaceOccurrencesOfString:@" " withString:@"_" options:NSLiteralSearch range:NSMakeRange(0, [nickname length])];
		
		NSString *serialKey = [(AppDelegate *)[NSApp delegate] machineSerialKey];
		if (serialKey == nil)
		{
			serialKey = [(AppDelegate *)[NSApp delegate] serialKey];
		}
		if (serialKey == nil)
		{
			serialKey = [(AppDelegate *)[NSApp delegate] randomSerialKey];
		}
		
		_desiredNickname = [nickname copy];
		_desiredUserIdentifier = [[MDHashDigest md5HashFromBytes:[serialKey UTF8String] length:(CC_LONG)strlen([serialKey UTF8String])] copy];
		_userIdentifier = _desiredUserIdentifier;
	}
	return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"inGameServer"])
	{
		[self updateMyStatus];
	}
}

- (void)setNumberOfUnreadMentions:(uint64_t)newNumberOfUnreadMentions
{
	numberOfUnreadMentions = newNumberOfUnreadMentions;
	if (numberOfUnreadMentions == 0)
	{
		[[NSApp dockTile] setBadgeLabel:@""];
	}
	else
	{
		[[NSApp dockTile] setBadgeLabel:[NSString stringWithFormat:@"%llu", numberOfUnreadMentions]];
	}
}

- (void)applicationWillBecomeActive:(NSNotification *)notification
{
	[self setNumberOfUnreadMentions:0];
}

- (void)signOn
{
	_attemptedSignOnBefore = YES;
	
	if (_closingWindow || _sleeping)
	{
		return;
	}
	
	if (!self.window.isVisible)
	{
		[_connection disconnect];
		return;
	}
	
	if (_connection.isInRoom)
	{
		return;
	}
	
	_connection = [[MDChatConnection alloc] initWithNickname:_desiredNickname userIdentifier:_userIdentifier delegate:self];
	_connection.showJIDOnBan = _showJIDOnBan;
	
	BOOL connected = [_connection joinRoom];
	if (!connected)
	{
		[_connection disconnect];
	}
}

- (void)cleanup
{
	[[NSUserDefaults standardUserDefaults] setObject:@(textView.enabledTextCheckingTypes) forKey:CHAT_TEXT_CHECKING_TYPES_KEY];
	
	willTerminate = YES;
}

- (void)signOff
{
	if (!willTerminate)
	{
		[_connection leaveRoom];
		[_connection disconnect];
		[roster removeAllObjects];
		[rosterTableView reloadData];
	}
}

- (void)systemWillSleep:(NSNotification *)notification
{
	_sleeping = YES;
	if ([[self window] isVisible])
	{
		IOReturn success = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep, kIOPMAssertionLevelOn, (CFStringRef)@"MD Disconnecting Chat", &_sleepAssertionID);
		
		_succeededInDelayingSleep = (success == kIOReturnSuccess);
		
		[self signOff];
		
		if (!_succeededInDelayingSleep)
		{
			NSLog(@"Error: Failed to delay sleep");
		}
	}
}

- (void)systemDidWake:(NSNotification *)notification
{
	_sleeping = NO;
	[self signOn];
}

- (NSString *)currentStatus
{
	MDServer *inGameServer = [(AppDelegate *)[NSApp delegate] inGameServer];
	
	if ([(AppDelegate *)[NSApp delegate] isHaloOpen])
	{
		if (!inGameServer)
		{
			return MD_STATUS_PREFIX;
		}
		
		return [[NSArray arrayWithObjects:MD_STATUS_PREFIX, [inGameServer ipAddress], [NSString stringWithFormat:@"%d", [inGameServer portNumber]], nil] componentsJoinedByString:@":"];
	}
	
	return nil;
}

- (void)updateMyStatus
{
	NSString *currentStatus = [self currentStatus];
	[_connection setStatus:currentStatus != nil ? currentStatus : @""];
}

- (NSArray *)textAndNewlineTokensFromTextAndURLTokens:(NSArray *)tokens
{
	NSMutableArray *newTokens = [NSMutableArray array];
	BOOL foundNewline = NO;
	
	for (NSString *token in tokens)
	{
		if ([token hasPrefix:@"http://"] || [token hasPrefix:@"https://"])
		{
			[newTokens addObject:token];
		}
		else
		{
			NSString *iteratingString = token;
			while (YES)
			{
				NSRange newlineRange = [iteratingString rangeOfString:@"\n" options:NSLiteralSearch | NSCaseInsensitiveSearch];
				if (newlineRange.location == NSNotFound)
				{
					[newTokens addObject:iteratingString];
					break;
				}
				
				NSString *before = [iteratingString substringToIndex:newlineRange.location];
				if (before.length > 0) [newTokens addObject:before];
				
				[newTokens addObject:[iteratingString substringWithRange:newlineRange]];
				foundNewline = YES;
				
				iteratingString = [iteratingString substringFromIndex:newlineRange.location + newlineRange.length];
			}
		}
	}
	
	return newTokens;
}

- (NSArray *)textAndUrlTokensFromString:(NSString *)string
{
	NSMutableArray *tokens = [NSMutableArray array];
	NSString *iteratingString = string;
	
	while (YES)
	{
		NSRange httpRange = [iteratingString rangeOfString:@"http://" options:NSLiteralSearch | NSCaseInsensitiveSearch];
		NSRange httpsRange = [iteratingString rangeOfString:@"https://" options:NSLiteralSearch | NSCaseInsensitiveSearch];
		
		NSRange bestRange;
		if (httpRange.location == NSNotFound && httpsRange.location == NSNotFound)
		{
			// Stop here
			[tokens addObject:iteratingString];
			break;
		}
		else if (httpRange.location == NSNotFound && httpsRange.location != NSNotFound)
		{
			bestRange = httpsRange;
		}
		else if (httpRange.location != NSNotFound && httpsRange.location == NSNotFound)
		{
			bestRange = httpRange;
		}
		else if (httpRange.location < httpsRange.location)
		{
			bestRange = httpRange;
		}
		else /* if (httpsRange.location < httpRange) */
		{
			bestRange = httpsRange;
		}
		
		[tokens addObject:[iteratingString substringToIndex:bestRange.location]];
		
		NSString *url = [[[iteratingString substringFromIndex:bestRange.location] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] objectAtIndex:0];
		
		[tokens addObject:url];
		
		iteratingString = [iteratingString substringFromIndex:bestRange.location+[url length]];
	}
	
	return tokens;
}

- (void)processMessage:(NSString *)messageString type:(NSString *)typeString nickname:(NSString *)nickString text:(NSString *)textString
{
	DOMDocument *document = [[webView mainFrame] DOMDocument];
	DOMElement *contentBlock = [document getElementById:@"content"];
	
	NSMutableArray *messageDOMComponents = [NSMutableArray array];
	
	if (messageString)
	{
		NSArray *textTokens = [self textAndNewlineTokensFromTextAndURLTokens:[self textAndUrlTokensFromString:messageString]];
		
		for (id textToken in textTokens)
		{
			if ([textToken hasPrefix:@"http://"] || [textToken hasPrefix:@"https://"])
			{
				DOMElement *anchor = [document createElement:@"a"];
				[anchor setAttribute:@"href" value:textToken];
				[anchor setTextContent:textToken];
				[messageDOMComponents addObject:anchor];
			}
			else if ([textToken isEqualToString:@"\n"])
			{
				[messageDOMComponents addObject:[document createElement:@"br"]];
			}
			else
			{
				[messageDOMComponents addObject:[document createTextNode:textToken]];
			}
		}
	}
	
	if ([@[@"on_message", @"on_private_message", @"my_message", @"my_private_message", @"on_leave", @"on_self_leave", @"on_join", @"connection_disconnected", @"removed", @"auth_failed", @"failed_room_auth", @"muc_join_failed", @"connection_initiating", @"muc_joined", @"roster", @"subject", @"voice", @"muc_nick_change", @"connection_reconnect"] containsObject:typeString])
	{
		MDChatRosterElement *foundRosterElement = nil;
		if (nickString != nil && [@[@"on_join", @"muc_joined", @"on_leave", @"on_self_leave", @"voice", @"muc_nick_change"] containsObject:typeString])
		{
			for (MDChatRosterElement *rosterElement in roster)
			{
				if ([[rosterElement name] isEqualToString:nickString])
				{
					foundRosterElement = rosterElement;
					break;
				}
			}
		}
		
		BOOL canWriteMessage = YES;
		if (nickString != nil && [@[@"on_join", @"muc_joined"] containsObject:typeString])
		{
			if (foundRosterElement == nil)
			{
				MDChatRosterElement *newRosterElement = [[MDChatRosterElement alloc] init];
				[newRosterElement setName:nickString];
				newRosterElement.status = textString;
				
				[roster addObject:newRosterElement];
				[rosterTableView reloadData];
				
				if ([typeString isEqualToString:@"on_join"] && _connection.subject == nil)
				{
					canWriteMessage = NO;
				}
			}
			else
			{
				foundRosterElement.status = textString;
				[rosterTableView reloadData];
				
				canWriteMessage = NO;
			}
		}
		else if (nickString != nil && [@[@"on_leave"] containsObject:typeString])
		{
			if (foundRosterElement != nil)
			{
				[roster removeObject:foundRosterElement];
				[rosterTableView reloadData];
			}
			else
			{
				canWriteMessage = NO;
			}
		}
		else if (nickString != nil && [typeString isEqualToString:@"muc_nick_change"])
		{
			if (foundRosterElement != nil)
			{
				if ([foundRosterElement.name isEqualToString:myNick])
				{
					myNick = [textString copy];
				}
				foundRosterElement.name = textString;
				[rosterTableView reloadData];
			}
			else
			{
				canWriteMessage = NO;
			}
		}
		else if (nickString != nil && [@[@"voice"] containsObject:typeString])
		{
			if ([textString isEqualToString:@"visitor"])
			{
				if (!foundRosterElement.muted)
				{
					foundRosterElement.muted = YES;
				}
				else
				{
					canWriteMessage = NO;
				}
			}
			else if ([textString isEqualToString:@"participant"])
			{
				if (foundRosterElement.muted)
				{
					foundRosterElement.muted = NO;
				}
				else
				{
					canWriteMessage = NO;
				}
			}
		}
		
		NSNumber *maxBacklog = [[NSUserDefaults standardUserDefaults] objectForKey:CHAT_MAX_DEFAULT_BACKLOG_KEY];
		if (maxBacklog != nil)
		{
			[self clearMessages:[maxBacklog unsignedIntValue]];
		}
		
		if (canWriteMessage)
		{
			DOMElement *newParagraph = [document createElement:@"p"];
			[newParagraph setAttribute:@"class" value:[typeString stringByAppendingString:@" message"]];
			
			for (id messageDOMComponent in messageDOMComponents)
			{
				[newParagraph appendChild:messageDOMComponent];
			}
			
			[contentBlock appendChild:newParagraph];
		}
		
		if ([@[@"muc_joined", @"on_subject"] containsObject:typeString])
		{
			if (nickString)
			{
				[self setMyNick:nickString];
			}
			
			[self updateMyStatus];
		}
		
		if ([@[@"on_message", @"on_private_message"] containsObject:typeString])
		{
			if (textString)
			{
				if ([typeString isEqualToString:@"on_private_message"])
				{
#ifdef USE_GROWL
					[NSClassFromString(@"GrowlApplicationBridge")
					 notifyWithTitle:nickString ?: @""
					 description:textString
					 notificationName:@"Private Message"
					 iconData:nil
					 priority:0
					 isSticky:NO
					 clickContext:@"MessageNotification"];
#endif
					if (![NSApp isActive])
					{
						[self setNumberOfUnreadMentions:numberOfUnreadMentions+1];
					}
				}
				else
				{
					BOOL foundMention = NO;
					for (id word in [textString componentsSeparatedByString:@" "])
					{
						if ([[word stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]] caseInsensitiveCompare:myNick] == NSOrderedSame)
						{
							foundMention = YES;
							break;
						}
					}
					
					if (foundMention)
					{
#ifdef USE_GROWL
						[NSClassFromString(@"GrowlApplicationBridge")
						 notifyWithTitle:nickString ? nickString : @""
						 description:textString
						 notificationName:@"Mention"
						 iconData:nil
						 priority:0
						 isSticky:NO
						 clickContext:@"MessageNotification"];
#endif
						if (![NSApp isActive])
						{
							[self setNumberOfUnreadMentions:numberOfUnreadMentions+1];
						}
					}
					else if (![NSApp isActive] && [[NSUserDefaults standardUserDefaults] boolForKey:CHAT_SHOW_MESSAGE_RECEIVE_NOTIFICATION] && ![(AppDelegate *)[NSApp delegate] isHaloOpenAndRunningFullscreen])
					{
#ifdef USE_GROWL
						[NSClassFromString(@"GrowlApplicationBridge")
						 notifyWithTitle:nickString ? nickString : @""
						 description:textString
						 notificationName:@"MessageReceived"
						 iconData:nil
						 priority:0
						 isSticky:NO
						 clickContext:@"MessageNotification"];
#endif
					}
				}
				
				if (![(AppDelegate *)[NSApp delegate] isHaloOpenAndRunningFullscreen] && [[NSUserDefaults standardUserDefaults] boolForKey:CHAT_PLAY_MESSAGE_SOUNDS])
				{
					NSSound *receiveSound = [[NSSound alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"CRcv" ofType:@"aif"] byReference:YES];
					[receiveSound play];
				}
			}
		}
		
		if ([@[@"muc_join_failed", @"on_self_leave", @"auth_failed", @"connection_disconnected", @"failed_room_auth", @"on_self_leave"] containsObject:typeString])
		{
			if ([typeString isEqualToString:@"auth_failed"])
			{
				++_authTag;
				if (_authTag >= 3)
				{
					_authTag = 0;
					_userIdentifier = _desiredUserIdentifier;
				}
				else
				{
					_userIdentifier = [_desiredUserIdentifier stringByAppendingFormat:@"_%lu", _authTag];
				}
				if (!_closingWindow && !_sleeping)
				{
					[_connection reauthenticateWithUserID:_userIdentifier];
				}
			}
			else
			{
				BOOL isDisconnected = [typeString isEqualToString:@"connection_disconnected"];
				if (isDisconnected)
				{
					if (_closingWindow || _sleeping)
					{
						_connection = nil;
						[self signOff];
						
						if (_sleeping && _succeededInDelayingSleep)
						{
							if (IOPMAssertionRelease(_sleepAssertionID) != kIOReturnSuccess)
							{
								NSLog(@"Error: Failed to release sleep assertion");
							}
							_succeededInDelayingSleep = NO;
						}
					}
					else
					{
						[roster removeAllObjects];
						[rosterTableView reloadData];
					}
				}
				else
				{
					[self signOff];
				}
			}
		}
	}
	else if ([typeString isEqualToString:@"on_subject"])
	{
		DOMElement *newHeader = [document createElement:@"h1"];
		[newHeader setAttribute:@"class" value:[typeString stringByAppendingString:@" message"]];
		
		for (id messageDOMComponent in messageDOMComponents)
		{
			[newHeader appendChild:messageDOMComponent];
		}
		
		[contentBlock appendChild:newHeader];
	}
}

- (void)clearMessages:(unsigned int)maxNumberOfMessagesLeft
{
	DOMDocument *document = [[webView mainFrame] DOMDocument];
	DOMElement *contentBlock = [document getElementById:@"content"];
	
	DOMNodeList *nodeList = nil;
	while (maxNumberOfMessagesLeft < (nodeList = contentBlock.childNodes).length)
	{
		[contentBlock removeChild:[nodeList item:0]];
	}
}

- (void)executeCommand:(NSString *)command
{
	NSArray *commandComponents = [command componentsSeparatedByString:@" "];
	if (commandComponents.count == 0) return;
	
	NSString *commandType = [[commandComponents objectAtIndex:0] lowercaseString];
	
	if ([@[@"msg", @"message"] containsObject:commandType])
	{
		if (commandComponents.count > 2)
		{
			NSString *nickname = [commandComponents objectAtIndex:1];
			NSString *message = [[commandComponents subarrayWithRange:NSMakeRange(2, commandComponents.count - 2)] componentsJoinedByString:@" "];
			
			[_connection sendPrivateMessage:message toUser:nickname];
		}
	}
	else if ([@[@"users", @"roster"] containsObject:commandType])
	{
		NSArray *nicknames = [roster valueForKey:NSStringFromSelector(@selector(name))];
		[self processMessage:[NSString stringWithFormat:@"Users: %@", [nicknames componentsJoinedByString:@", "]] type:@"roster" nickname:nil text:nil];
	}
	else if ([@[@"subject", @"topic"] containsObject:commandType])
	{
		if (_connection.subject != nil)
		{
			[self processMessage:[NSString stringWithFormat:@"Topic: %@", _connection.subject] type:@"on_subject" nickname:nil text:nil];
		}
	}
	else if ([commandType isEqualToString:@"clear"])
	{
		[self clearMessages:0];
	}
}

- (void)sendMessage
{
	NSString *message = [[[textView textStorage] mutableString] copy];
	
	if ([message hasPrefix:@"/"])
	{
		if ([message length] > 0)
		{
			[self executeCommand:[message substringFromIndex:1]];
			
			[[[textView textStorage] mutableString] setString:@""];
			[self adjustTextView];
		}
	}
	else
	{
		if ([_connection sendMessage:message])
		{
			[[[textView textStorage] mutableString] setString:@""];
			[self adjustTextView];
			
			if ([[NSUserDefaults standardUserDefaults] boolForKey:CHAT_PLAY_MESSAGE_SOUNDS] && ![message hasPrefix:@"/"])
			{
				NSSound *sendSound = [[NSSound alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"CSnd" ofType:@"aif"] byReference:YES];
				[sendSound play];
			}
		}
	}
}

- (void)textStorageWillProcessEditing:(NSNotification *)notification
{
	NSTextStorage *textStorage = textView.textStorage;
	if (textStorage.length > CHAT_MAX_MESSAGE_LENGTH)
	{
		[textStorage deleteCharactersInRange:NSMakeRange(CHAT_MAX_MESSAGE_LENGTH, textStorage.length - CHAT_MAX_MESSAGE_LENGTH)];
	}
}

- (void)windowDidLoad
{
    [super windowDidLoad];
	
	if ([[self window] respondsToSelector:@selector(animationBehavior)]) // easy way to tell if >= 10.7?
	{
		[[self window] setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];
	}
	
	id chatTextingTypes = [[NSUserDefaults standardUserDefaults] objectForKey:CHAT_TEXT_CHECKING_TYPES_KEY];
	if ([chatTextingTypes isKindOfClass:[NSNumber class]])
	{
		textView.enabledTextCheckingTypes = [chatTextingTypes unsignedLongLongValue];
	}
	
	textView.textStorage.delegate = self;
	
	[rosterTableView setDoubleAction:@selector(initiateUserFromRoster:)];
	
	NSScrollView *scrollView = nil;
	for (id view in webView.mainFrame.frameView.subviews)
	{
		if ([view isKindOfClass:[NSScrollView class]])
		{
			scrollView = view;
			break;
		}
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(webViewFrameChanged:) name:NSViewFrameDidChangeNotification object:scrollView.documentView];
	
	_scrollView = scrollView;
	
	webView.preferences.plugInsEnabled = NO;
	webView.preferences.javaScriptEnabled = NO;
	webView.preferences.javaEnabled = NO;
	
	[webView setDrawsBackground:NO];
    [webView setUIDelegate:self];
    [webView setFrameLoadDelegate:self];
	
	[[webView windowScriptObject] setValue:self forKey:NSStringFromClass([self class])];
	
    NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:nil];
    [[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:htmlPath]]];
}

- (IBAction)initiateUserFromRoster:(id)sender
{
	if ([rosterTableView selectedRow] >= 0 && [rosterTableView selectedRow] < [roster count])
	{
		MDChatRosterElement *rosterElement = [roster objectAtIndex:[rosterTableView selectedRow]];
		if (![[rosterElement name] isEqualToString:myNick])
		{
			NSArray *statusComponents = [[rosterElement status] componentsSeparatedByString:@":"];
			if ([[rosterElement status] hasPrefix:MD_STATUS_PREFIX] && [statusComponents count] >= 3)
			{
				// join user's game
				NSString *ipAddress = [statusComponents objectAtIndex:1];
				int portNumber = [[statusComponents objectAtIndex:2] intValue];
				for (id server in [(AppDelegate *)[NSApp delegate] servers])
				{
					if ([[server ipAddress] isEqualToString:ipAddress] && [server portNumber] == portNumber)
					{
						[(AppDelegate *)[NSApp delegate] joinServer:server];
						break;
					}
				}
			}
			else
			{
				// initiate private message to user
				[[[textView textStorage] mutableString] setString:[NSString stringWithFormat:@"/msg %@ ", [rosterElement name]]];
				[[self window] makeFirstResponder:textView];
			}
		}
	}
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	[self signOn];
}

- (void)webViewFrameChanged:(NSNotification *)notification
{
	if (!_isChangingWebFrame)
	{
		// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/NSScrollViewGuide/Articles/Scrolling.html
		NSPoint newScrollPosition =
			[_scrollView.documentView isFlipped] ?
			NSMakePoint(0.0, NSMaxY([_scrollView.documentView frame]) - NSHeight(_scrollView.contentView.bounds)) :
			NSMakePoint(0.0, 0.0);
		
		NSPoint currentScrollPosition = _scrollView.contentView.bounds.origin;
		
		if (fabs(currentScrollPosition.y - _oldScrollPosition.y) <= AUTO_SCROLL_PIXEL_THRESHOLD)
		{
			// Avoid this notification handler being called recursively
			_isChangingWebFrame = YES;
			[self scrollToBottom];
			_isChangingWebFrame = NO;
		}
		
		_oldScrollPosition = newScrollPosition;
	}
}

- (IBAction)showWindow:(id)sender
{
	[super showWindow:sender];
	
	if (([[NSApp currentEvent] modifierFlags] & NSCommandKeyMask) != 0)
	{
		_showJIDOnBan = YES;
	}
	
	_closingWindow = NO;
	
	if (_attemptedSignOnBefore)
	{
		[self signOn];
	}
}

- (void)windowWillClose:(NSNotification *)notification
{
	if ([notification object] == [self window])
	{
		_showJIDOnBan = NO;
		_closingWindow = YES;
		[self signOff];
	}
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview
{
	if (splitView == chatSplitView || (splitView == rosterSplitView && subview == chatSplitView))
	{
		return NO;
	}
	
	return YES;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	if (splitView == chatSplitView)
	{
		return proposedMinimumPosition + 150;
	}

	return proposedMinimumPosition + 150;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	if (splitView == chatSplitView)
	{
		return proposedMaximumPosition - 20;
	}
	
	return proposedMaximumPosition - 115;
}

- (BOOL)splitView:(NSSplitView *)splitView shouldHideDividerAtIndex:(NSInteger)dividerIndex
{
	return splitView == chatSplitView;
}

- (void)scrollToBottom
{
	// this works better than [webView scrollToEndOfDocument:nil]
	[_scrollView.documentView scrollPoint:NSMakePoint(0.0, 1000000.0)];
}

- (void)adjustScrollingAndTextView
{
	[self adjustTextView];
	[self scrollToBottom];
}

- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
	if ([aNotification object] == rosterSplitView)
	{
		[self adjustScrollingAndTextView];
	}
}

- (void)windowDidResize:(NSNotification *)notification
{
	if ([notification object] == [self window])
	{
		[self adjustScrollingAndTextView];
	}
}

- (void)adjustTextView
{
	NSView *bottomSubview = [[chatSplitView subviews] objectAtIndex:1];
	
	NSLayoutManager *layoutManager = [textView layoutManager];
	NSTextContainer *textContainer = [textView textContainer];
	
	// Force layout
	[layoutManager ensureLayoutForBoundingRect:bottomSubview.frame inTextContainer:textContainer];
	NSRect usedRect = [layoutManager usedRectForTextContainer:textContainer];
	
	// Calculate height somehow
#warning This is definitely broken.. TODO: fix this
	CGFloat calculatedHeight = usedRect.size.height + 4;
	[bottomSubview setFrameSize:NSMakeSize(bottomSubview.frame.size.width, calculatedHeight)];
}

- (void)textDidChange:(NSNotification *)notification
{
	[self adjustTextView];
}

- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)selector
{
	if (selector == @selector(insertNewline:))
	{
		[self sendMessage];
		return YES;
	}
	else if (selector == @selector(insertTabIgnoringFieldEditor:) || selector == @selector(insertTab:))
	{
		[aTextView complete:nil];
		return YES;
	}
	
	return NO;
}

- (NSUInteger)webView:(WebView *)sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo
{
	return WebDragSourceActionNone; // disable drag destination
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
	return nil; // disable contextual menu for the webView
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector
{
    return YES; // disallow everything
}

// Make links open in user's web browser
// http://stackoverflow.com/questions/4530590/opening-webview-links-in-safari
- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id )listener
{
	NSString *host = [[request URL] host];
	if (host)
	{
		[[NSWorkspace sharedWorkspace] openURL:[request URL]];
	}
	else
	{
		[listener use];
	}
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [roster count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if (rowIndex >= 0 && (NSUInteger)rowIndex < [roster count])
	{
		CGFloat systemFontSize = [[NSFont systemFontOfSize:0] pointSize];
		
		static NSImage *inChatImage = nil;
		if (!inChatImage)
		{
			inChatImage = [[NSImage imageNamed:@"in_chat_icon.pdf"] copy];
			[inChatImage setSize:NSMakeSize(systemFontSize, systemFontSize)];
		}
		
		static NSImage *inGameImage = nil;
		if (!inGameImage)
		{
			inGameImage = [[NSImage imageNamed:@"game_icon.pdf"] copy];
			[inGameImage setSize:NSMakeSize(systemFontSize, systemFontSize)];
		}
		
		MDChatRosterElement *rosterElement = [roster objectAtIndex:rowIndex];
		if ([[tableColumn identifier] isEqualToString:@"player"])
		{
			NSMutableAttributedString *userItem = [[NSMutableAttributedString alloc] init];
			
			BOOL isInGame = [[rosterElement status] hasPrefix:MD_STATUS_PREFIX];
			
			NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
			id cell = [attachment attachmentCell];
			[cell setImage:isInGame ? inGameImage : inChatImage];
			NSAttributedString *imageString = [NSAttributedString attributedStringWithAttachment:attachment];
			[userItem appendAttributedString:imageString];
			[userItem appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@", [rosterElement name]]]];
			
			if (isInGame)
			{
				NSArray *statusComponents = [[rosterElement status] componentsSeparatedByString:@":"];
				if ([statusComponents count] >= 3)
				{
					NSString *ipAddress = [statusComponents objectAtIndex:1];
					int portNumber = [[statusComponents objectAtIndex:2] intValue];
					
					MDServer *foundServer = nil;
					for (MDServer *server in [(AppDelegate *)[NSApp delegate] servers])
					{
						if ([[server ipAddress] isEqualToString:ipAddress] && [server portNumber] == portNumber)
						{
							foundServer = server;
							break;
						}
					}
					
					if (foundServer)
					{
						NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:systemFontSize / 1.5], NSFontAttributeName, nil];
						NSAttributedString *serverName = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@", [foundServer name]] attributes:attributes];
						[userItem appendAttributedString:serverName];
					}
				}
			}
			return userItem;
		}
	}
	
	return nil;
}

- (NSArray *)textView:(NSTextView *)aTextView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index
{
	NSString *characters = [[[aTextView textStorage] mutableString] substringWithRange:charRange];
	NSMutableArray *newWords = [NSMutableArray array];
	
	BOOL foundMyNick = NO;
	for (id rosterElement in roster)
	{
		if ([[[rosterElement name] lowercaseString] hasPrefix:[characters lowercaseString]])
		{
			if ([[rosterElement name] isEqualToString:myNick])
			{
				foundMyNick = YES;
			}
			else
			{
				if (charRange.location == 0)
				{
					[newWords addObject:[[rosterElement name] stringByAppendingString:@": "]];
				}
				else
				{
					[newWords addObject:[rosterElement name]];
				}
			}
		}
	}
	
	if (foundMyNick)
	{
		if (charRange.location == 0)
		{
			[newWords addObject:[myNick stringByAppendingString:@": "]];
		}
		else
		{
			[newWords addObject:myNick];
		}
	}
	
	return newWords;
}

@end
