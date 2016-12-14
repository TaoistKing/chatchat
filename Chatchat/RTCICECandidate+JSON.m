//
//  RTCICECandidate+JSON.m
//  Chatchat
//
//  Created by WangRui on 16/6/8.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import "RTCICECandidate+JSON.h"

static NSString const *kRTCICECandidateTypeKey = @"type";
static NSString const *kRTCICECandidateTypeValue = @"candidate";
static NSString const *kRTCICECandidateMidKey = @"sdpMid";
static NSString const *kRTCICECandidateMLineIndexKey = @"sdpMLineIndex";
static NSString const *kRTCICECandidateSdpKey = @"candidate";

@implementation RTCIceCandidate (JSON)

+ (RTCIceCandidate *)candidateFromJSONDictionary:(NSDictionary *)dictionary {
    NSString *mid = dictionary[kRTCICECandidateMidKey];
    NSString *sdp = dictionary[kRTCICECandidateSdpKey];
    NSNumber *num = dictionary[kRTCICECandidateMLineIndexKey];
    int mLineIndex = (int)[num integerValue];
  return [[RTCIceCandidate alloc] initWithSdp:sdp sdpMLineIndex:mLineIndex sdpMid:mid];
}

- (NSDictionary *)toDictionary{
    NSDictionary *json = @{
                           kRTCICECandidateMLineIndexKey : @(self.sdpMLineIndex),
                           kRTCICECandidateMidKey : self.sdpMid,
                           kRTCICECandidateSdpKey : self.sdp
                           };

    return json;
}


- (NSData *)JSONData {
    NSDictionary *json = [self toDictionary];
    NSError *error = nil;
    NSData *data =
    [NSJSONSerialization dataWithJSONObject:json
                                    options:NSJSONWritingPrettyPrinted
                                      error:&error];
    if (error) {
        NSLog(@"Error serializing JSON: %@", error);
        return nil;
    }
    return data;
}

- (NSString *)JSONString{
    return [[NSString alloc] initWithData:[self JSONData] encoding:NSUTF8StringEncoding];
}

@end
