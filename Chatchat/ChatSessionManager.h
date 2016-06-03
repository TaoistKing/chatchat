//
//  ChatSessionManager.h
//  Chatchat
//
//  Created by WangRui on 16/6/2.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ChatSession.h"

@interface ChatSessionManager : NSObject

+ (instancetype)sharedManager;

- (ChatSession *)findSessionByPeer: (User *)user;
- (ChatSession *)findSessionByUID: (NSString *)uid;

- (ChatSession *)createSessionWithPeer: (User *)user;

- (void)removeSession: (ChatSession *)session;
- (void)removeSessionByPeer: (User *)user;
- (void)removeSessionByUID: (NSString *)uid;

@end
