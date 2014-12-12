//
//  DZNotificationCenterPlugin.m
//  DZNotificationCenterPlugin
//
//  Created by Zachary Waldowski on 5/16/12.
//  Copyright (c) 2012 Zachary Waldowski. All rights reserved.
//

#import "DZNotificationCenterPlugin.h"
#import <Adium/AIChatControllerProtocol.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIStatusControllerProtocol.h>
#import <Adium/AIAccount.h>
#import <Adium/AIChat.h>
#import <Adium/AIContentObject.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListObject.h>
#import <Adium/AIStatus.h>
#import <Adium/ESFileTransfer.h>
#import <AIUtilities/AIStringUtilities.h>
#import <AIUtilities/AIStringAdditions.h>
#import <AIUtilities/AIImageAdditions.h>

static NSString *const DZNotificationPluginIdentifier = @"NotificationCenterPlugin";
static NSString *const DZNotificationUserInfoEventKey = @"eventID";
static NSString *const DZNotificationFileTransferKey = @"fileTransferUniqueID";
static NSString *const DZNotificationChatKey = @"uniqueChatID";
static NSString *const DZNotificationListKey = @"internalObjectID";

@implementation DZNotificationCenterPlugin

- (void) installPlugin {
	[adium.contactAlertsController registerActionID: DZNotificationPluginIdentifier withHandler: self];
	[[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate: self];
}

#pragma mark - AIActionHandler

- (NSString *)shortDescriptionForActionID:(NSString *)actionID
{
	return AILocalizedString(@"DisplayNotificationShort", @"Display a system notification");
}

- (NSString *)longDescriptionForActionID:(NSString *)actionID withDetails:(NSDictionary *)details
{
	return AILocalizedString(@"DisplayNotificationLong", @"Display a system notification in Notification Center");
}

/*!
 * @brief Returns the image associated with the Growl event
 */
- (NSImage *)imageForActionID:(NSString *)actionID
{
	return [NSImage imageNamed: DZNotificationPluginIdentifier forClass: [self class]];
}

- (BOOL)performActionID:(NSString *)actionID forListObject:(AIListObject *)listObject withDetails:(NSDictionary *)details triggeringEventID:(NSString *)eventID userInfo:(id)userInfo {
	if ([adium.statusController.activeStatusState silencesGrowl])
		return NO;
	
	AIChat *chat = nil;
	
	if ([userInfo respondsToSelector:@selector(objectForKey:)]) {
		chat = [userInfo objectForKey:@"AIChat"];
		AIContentObject *contentObject = [userInfo objectForKey:@"AIContentObject"];
		if (contentObject.source) {
			listObject = contentObject.source;
		}
	}
	
	BOOL hasActionButton = NO;
	NSString			*title = nil, *subtitle = nil, *description = nil, *actionButtonText = @"";
	NSMutableDictionary	*clickContext = [NSMutableDictionary dictionary];
	
	[clickContext setObject: eventID forKey: DZNotificationUserInfoEventKey];
	
	if (listObject) {
		if ([listObject isKindOfClass: [AIListContact class]]) {
			listObject = [(id)listObject parentContact];
			title = [listObject longDisplayName];
		} else {
			title = listObject.displayName;
		}
		
		if (chat) {
			[clickContext setObject:chat.uniqueChatID forKey:DZNotificationChatKey];
			
			if (chat.isGroupChat)
				subtitle = chat.displayName;
			
			hasActionButton = YES;
			actionButtonText = AILocalizedString(@"ReadTITLE", @"Read");
		} else if ([userInfo isKindOfClass:[ESFileTransfer class]] && [eventID isEqualToString:FILE_TRANSFER_COMPLETE]) {
			[clickContext setObject:[(ESFileTransfer *)userInfo uniqueID] forKey:DZNotificationFileTransferKey];
			
			if ([(ESFileTransfer *)userInfo displayFilename])
				subtitle = [(ESFileTransfer *)userInfo displayFilename];
			
			hasActionButton = YES;
			actionButtonText = AILocalizedString(@"ShowTITLE", @"Show");
		} else {
			[clickContext setObject:listObject.internalObjectID forKey:DZNotificationListKey];
		}
	} else if (chat) {
		title = chat.displayName;
			
		[clickContext setObject:chat.uniqueChatID forKey:DZNotificationChatKey];
		
		hasActionButton = YES;
		actionButtonText = AILocalizedString(@"ReadTITLE", @"Read");
	} else {
		title = @"Adium";
	}
    
	description = [[adium contactAlertsController] naturalLanguageDescriptionForEventID:eventID listObject:listObject userInfo:userInfo includeSubject:NO];
    
	if (([eventID isEqualToString:CONTACT_STATUS_ONLINE_YES] || [eventID isEqualToString:CONTACT_STATUS_ONLINE_NO] || [eventID isEqualToString:CONTACT_STATUS_AWAY_YES] || [eventID isEqualToString:CONTACT_SEEN_ONLINE_YES] || [eventID isEqualToString:CONTACT_SEEN_ONLINE_NO]) && [(AIListContact *)listObject contactListStatusMessage]) {
		subtitle = description;
		description = [[[adium.contentController filterAttributedString: [(AIListContact *)listObject contactListStatusMessage] usingFilterType: AIFilterContactList direction: AIFilterIncoming context: listObject] string] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
	}
	
	NSUserNotification *notification = [NSUserNotification new];
	notification.deliveryDate = [NSDate dateWithTimeIntervalSinceNow:1];
	notification.soundName = nil;
	notification.title = title;
	notification.subtitle = subtitle;
	notification.informativeText = description;
	notification.userInfo = clickContext;
	notification.hasActionButton = hasActionButton;
	notification.actionButtonTitle = actionButtonText;
    
    NSImage *chatImage = chat.chatImage;
    if (chatImage) {
        notification.contentImage = chatImage;
    }
	
    [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification: notification];
	
	return YES;
}

- (AIActionDetailsPane *)detailsPaneForActionID:(NSString *)actionID {
	return nil;
}

- (BOOL)allowMultipleActionsWithID:(NSString *)actionID {
	return NO;
}

#pragma mark - NSUserNotificationCenterDelegate

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
	NSString *internalObjectID = [notification.userInfo objectForKey: DZNotificationListKey],
			 *uniqueChatID = [notification.userInfo objectForKey: DZNotificationChatKey],
			 *fileTransferID = [notification.userInfo objectForKey: DZNotificationFileTransferKey];
	AIListObject	*listObject;
	AIChat			*chat = nil;
		
	if (internalObjectID.length) {
		if ((listObject = [adium.contactController existingListObjectWithUniqueID:internalObjectID]) &&
			([listObject isKindOfClass:[AIListContact class]])) {
			
			//First look for an existing chat to avoid changing anything
			if (!(chat = [adium.chatController existingChatWithContact:(AIListContact *)listObject])) {
				//If we don't find one, create one
				chat = [adium.chatController openChatWithContact:(AIListContact *)listObject
												onPreferredAccount:YES];
			}
		}

	} else if (uniqueChatID.length) {
		chat = [adium.chatController existingChatWithUniqueChatID:uniqueChatID];
		
		//If we didn't find a chat, it may have closed since the notification was posted.
		//If we have an appropriate existing list object, we can create a new chat.
		if ((!chat) &&
			(listObject = [adium.contactController existingListObjectWithUniqueID:uniqueChatID]) &&
			([listObject isKindOfClass:[AIListContact class]])) {
		
			//If the uniqueChatID led us to an existing contact, create a chat with it
			chat = [adium.chatController openChatWithContact:(AIListContact *)listObject
											onPreferredAccount:YES];
		}
	}
	
	if (fileTransferID.length) {
		//If a file transfer notification is clicked, reveal the file
		[[ESFileTransfer existingFileTransferWithID:fileTransferID] reveal];
	}

	if (chat) {
		//Make the chat active
		[adium.interfaceController setActiveChat:chat];
	}

	//Make Adium active (needed if, for example, our notification was clicked with another app active)
	[NSApp activateIgnoringOtherApps:YES];
}


@end