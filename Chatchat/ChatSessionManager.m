//
//  ChatSessionManager.m
//  Chatchat
//
//  Created by WangRui on 16/6/2.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import "ChatSessionManager.h"


@interface ChatSessionManager()
{
    NSMutableArray<ChatSession *> *_sessions;
}

@end


@implementation ChatSessionManager

+ (instancetype)sharedManager{
    static ChatSessionManager *singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [[ChatSessionManager alloc] init];
    });
    
    return singleton;
}

- (instancetype)init{
    if (self = [super init]) {
        _sessions = [NSMutableArray array];
    }
    
    return self;
}

- (ChatSession *)findSessionByPeer: (User *)user{
    ChatSession *session = nil;
    
    for (ChatSession *item in _sessions) {
        if ([item.peer.uniqueID isEqualToString:user.uniqueID]) {
            session = item;
            break;
        }
    }
    
    return session;
}

- (ChatSession *)findSessionByUID: (NSString *)uid{
    ChatSession *session = nil;
    
    for (ChatSession *item in _sessions) {
        if ([item.peer.uniqueID isEqualToString:uid]) {
            session = item;
            break;
        }
    }
    
    return session;
}


- (ChatSession *)createSessionWithPeer: (User *)user{
    ChatSession *session = [self findSessionByPeer:user];
    if (session) {
        return session;
    }
    
    session = [[ChatSession alloc] initWithPeer:user];
    [_sessions addObject:session];
    
    return session;
}

- (void)removeSession: (ChatSession *)session{
    [_sessions removeObject:session];
}

- (void)removeSessionByPeer: (User *)user{
    ChatSession *session = [self findSessionByPeer:user];
    
    if (session) {
        [self removeSession:session];
    }
}
- (void)removeSessionByUID: (NSString *)uid{
    ChatSession *session = [self findSessionByUID:uid];
    
    if (session) {
        [self removeSession:session];
    }
}


@end
