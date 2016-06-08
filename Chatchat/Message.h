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
@property NSString *type;//text, signal
@property NSString *subtype;//offer, answer, candidate, close

- (NSDictionary *)toDictionary;

- (instancetype)initWithPeerUID : (NSString *)peerUID
                            Type: (NSString *)type
                         SubType: (NSString *)subtype
                         Content: (NSString *)content;

@end