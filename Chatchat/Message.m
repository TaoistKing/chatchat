//
//  Message.m
//  Chatchat
//
//  Created by WangRui on 16/6/1.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import "Message.h"

@implementation Message



- (NSDictionary *)toDictionary{
    return @{@"from": self.from,
             @"to"  : self.to,
             @"content" : self.content,
             @"time" : self.time
             };
}

@end
