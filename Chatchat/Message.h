//
//  Message.h
//  Chatchat
//
//  Created by WangRui on 16/6/1.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kMessageType_Signal @"signal"
#define kMessageType_Text   @"text"

#define kMessageSubtype_Offer     @"offer"
#define kMessageSubtype_Answer    @"answer"
#define kMessageSubtype_Candidate @"candidate"
#define kMessageSubtype_Close     @"close"
#define kMessageSubtype_Placeholder     @"placehoder"

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

+ (instancetype)textMessageWithPeerUID : (NSString *)peerUID
                               content : (NSString *)content;

@end