//
//  RTCSessionDescription+JSON.h
//  Chatchat
//
//  Created by WangRui on 16/12/14.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import <WebRTC/WebRTC.h>

@interface RTCSessionDescription (JSON)

+ (RTCSessionDescription *)sdpFromJSONDictionary:(NSDictionary *)dictionary;
+ (RTCSessionDescription *)sdpFromJSONString:(NSString *)sdp;
- (NSData *)JSONData;
- (NSString *)JSONString;
- (NSDictionary *)toDictionary;

@end
