//
//  User.m
//  Chatchat
//
//  Created by WangRui on 16/6/1.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import "User.h"

@implementation User

- (instancetype)initWithName: (NSString *)name UID: (NSString *)uid{
    if (self = [super init]) {
        self.name = name;
        self.uniqueID = uid;
    }
    
    return self;
}
@end
