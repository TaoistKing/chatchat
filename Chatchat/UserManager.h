//
//  UserManager.h
//  Chatchat
//
//  Created by WangRui on 16/6/2.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "User.h"

@interface UserManager : NSObject

+ (instancetype)sharedManager;

- (BOOL)isUserExist : (NSString *)uid;

- (void)addUser : (User *)user;
- (void)addUserWithUID: (NSString *)uid name: (NSString *)name;
- (void)removeUserByUID: (NSString *)uid;
- (void)removeUser: (User *)user;

- (NSArray<User *> *)listUsers;
- (NSUInteger)numberUsers;

- (User *)findUserByUID: (NSString *)uid;
- (User *)localUser;
- (void)setLocalUserWithName: (NSString *)name UID: (NSString *)uid;

@end
