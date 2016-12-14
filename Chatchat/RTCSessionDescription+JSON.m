//
//  RTCSessionDescription+JSON.m
//  Chatchat
//
//  Created by WangRui on 16/12/14.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import "RTCSessionDescription+JSON.h"

NSString *const kSDPTypeString[] = {
  @"offer",
  @"pranswer",
  @"answer"
};

@implementation RTCSessionDescription (JSON)


+ (RTCSessionDescription *)sdpFromJSONDictionary:(NSDictionary *)dictionary{
  NSString *sdp = [dictionary objectForKey:@"sdp"];
  NSString *type = [dictionary objectForKey:@"type"];
  
  RTCSdpType sdpType;
  if ([type isEqualToString:@"offer"]) {
    sdpType = RTCSdpTypeOffer;
  }else if ([type isEqualToString:@"answer"]){
    sdpType = RTCSdpTypeAnswer;
  }else if ([type isEqualToString:@"pranswer"]){
    sdpType = RTCSdpTypePrAnswer;
  }
  
  return [[RTCSessionDescription alloc] initWithType:sdpType sdp:sdp];
}

+ (RTCSessionDescription *)sdpFromJSONString:(NSString *)sdp{
  RTCSessionDescription *outcome = nil;
  
  NSData *data = [sdp dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error;
  NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
  if (!error) {
    outcome = [self sdpFromJSONDictionary:dic];
  }
  
  return outcome;
}

- (NSData *)JSONData{
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

- (NSDictionary *)toDictionary{
  return @{@"type" : kSDPTypeString[self.type],
           @"sdp"  : self.sdp};
}



@end
