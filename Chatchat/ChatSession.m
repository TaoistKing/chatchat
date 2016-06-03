//
//  ChatSession.m
//  Chatchat
//
//  Created by WangRui on 16/6/2.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import "ChatSession.h"

@interface ChatSession ()
{
    NSMutableArray<Message *> *_messages;
    NSMutableArray<Message *> *_unreadMessages;
}

@end

@implementation ChatSession

- (instancetype)initWithPeer: (User *)peer{
    if (self = [super init]) {
        self.peer = peer;
    }
    
    _messages = [NSMutableArray array];
    _unreadMessages = [NSMutableArray array];
    
    return self;
}

- (NSArray<Message *> *)listAllMessages{
    return _messages;
}

- (NSArray<Message *> *)listUnread{
    return _unreadMessages;
}

- (NSUInteger)unreadCount{
    return _unreadMessages.count;
}

- (void)onMessage: (Message *)message{
    [_messages addObject:message];
}

- (void)onUnreadMessage: (Message *)message{
    [_messages addObject:message];
    [_unreadMessages addObject:message];
}

@end
