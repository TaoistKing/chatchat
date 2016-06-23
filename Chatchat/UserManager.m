//
//  UserManager.m
//  Chatchat
//
//  Created by WangRui on 16/6/2.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import "UserManager.h"

@interface UserManager ()
{
    User *_localUser;
    NSMutableArray<User *> *_users;
}
@end

@implementation UserManager

+ (instancetype)sharedManager{
    static UserManager *singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singleton = [[UserManager alloc] init];
    });
    
    return singleton;
}

- (instancetype)init{
    if (self = [super init]) {
        _users = [NSMutableArray array];
    }
    
    return self;
}

- (BOOL)isUserExist : (NSString *)uid{
    BOOL exist = NO;
    
    for (User *item in _users) {
        if ([item.uniqueID isEqualToString:uid]) {
            exist = YES;
            break;
        }
    }
    return exist;
}

- (void)addUser : (User *)user{
    [_users addObject:user];
}

- (void)addUserWithUID: (NSString *)uid name: (NSString *)name{
    User *user = [[User alloc] initWithName:name UID:uid];
    [_users addObject:user];
}

- (void)removeUserByUID: (NSString *)uid{
    User *user = [self findUserByUID:uid];
    [self removeUser:user];
}

- (void)removeUser: (User *)user{
    [_users removeObject:user];
}

- (void)removeAllUsers{
    [_users removeAllObjects];
}

- (NSArray<User *> *)listUsers{
    return _users;
}

- (NSUInteger)numberUsers{
    return _users.count;
}

- (User *)findUserByUID: (NSString *)uid{
    User *found = nil;
    for (User *item in _users) {
        if ([item.uniqueID isEqualToString:uid]) {
            found = item;
            break;
        }
    }

    return found;
}

- (User *)localUser{
    return _localUser;
}

- (void)setLocalUserWithName: (NSString *)name UID: (NSString *)uid{
    if ([self findUserByUID:uid]) {
        return;
    }
    
    _localUser = [[User alloc] initWithName:name UID:uid];
    [self addUser:_localUser];
}

- (void)replaceAllUsersWithNewUsers : (NSArray<User *> *)users{
    @synchronized(self) {
        [self removeAllUsers];
        for (User *item in users) {
            if (![self isUserExist:item.uniqueID]) {
                [self addUser:item];
            }
        }
    }
}


@end
