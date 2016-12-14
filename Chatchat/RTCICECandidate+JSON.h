//
//  RTCICECandidate+JSON.h
//  Chatchat
//
//  Created by WangRui on 16/6/8.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import <WebRTC/RTCIceCandidate.h>

@interface RTCIceCandidate (JSON)

+ (RTCIceCandidate *)candidateFromJSONDictionary:(NSDictionary *)dictionary;
- (NSData *)JSONData;
- (NSString *)JSONString;
- (NSDictionary *)toDictionary;

@end
