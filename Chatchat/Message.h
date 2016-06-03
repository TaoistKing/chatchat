//
//  Message.h
//  Chatchat
//
//  Created by WangRui on 16/6/1.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Message : NSObject
@property NSString *from;
@property NSString *to;
@property NSString *content;
@property NSString *time;

- (NSDictionary *)toDictionary;

@end