//
//  User.h
//  Chatchat
//
//  Created by WangRui on 16/6/1.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Message.h"

@interface User : NSObject
@property NSString *uniqueID;
@property NSString *name;

- (instancetype)initWithName: (NSString *)name UID: (NSString *)uid;
@end