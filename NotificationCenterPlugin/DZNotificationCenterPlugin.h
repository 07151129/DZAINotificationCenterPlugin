//
//  DZNotificationCenterPlugin.h
//  DZNotificationCenterPlugin
//
//  Created by Zachary Waldowski on 5/16/12.
//  Copyright (c) 2012 Zachary Waldowski. All rights reserved.
//

#import <Adium/AIPlugin.h>
#import <Adium/AIContactAlertsControllerProtocol.h>

@interface DZNotificationCenterPlugin : AIPlugin <AIActionHandler, NSUserNotificationCenterDelegate>

@end