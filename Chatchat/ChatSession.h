//
//  ChatSession.h
//  Chatchat
//
//  Created by WangRui on 16/6/2.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "User.h"
#import "Message.h"

@interface ChatSession : NSObject

@property (strong) User *peer;

- (instancetype)initWithPeer: (User *)peer;

- (NSArray<Message *> *)listAllMessages;
- (NSArray<Message *> *)listUnread;
- (NSUInteger)unreadCount;

- (void)onMessage: (Message *)message;
- (void)onUnreadMessage: (Message *)message;

@end
