//
//  RTCICECandidate+JSON.h
//  Chatchat
//
//  Created by WangRui on 16/6/8.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import "RTCICECandidate.h"

@interface RTCICECandidate (JSON)

+ (RTCICECandidate *)candidateFromJSONDictionary:(NSDictionary *)dictionary;
- (NSData *)JSONData;
- (NSString *)JSONString;
- (NSDictionary *)toDictionary;

@end
