//
//  OutgoingViewController.m
//  Chatchat
//
//  Created by WangRui on 16/7/11.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import "OutgoingViewController.h"

#import "RTCICECandidate+JSON.h"

#import "RTCSessionDescription+JSON.h"

@interface OutgoingViewController ()

@end

@implementation OutgoingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (RTCMediaConstraints *)defaultOfferConstraints {
  NSDictionary *mandatoryConstraints = @{@"OfferToReceiveAudio": @"true",
                                         @"OfferToReceiveVideo": @"true"};
  NSDictionary *optionalConstraints = @{@"DtlsSrtpKeyAgreement" : @"false"};
  
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
                                          optionalConstraints:optionalConstraints];
    return constraints;
}


- (void)onMessage: (Message *)message{
    [super onMessage:message];
    
    if ([message.type isEqualToString:@"signal"]) {
        if ([message.subtype isEqualToString:@"offer"]) {
            //
            //create peerconnection
            //set remote desc
            //I'm calling out, so I don't accept offer right now
            
        }else if([message.subtype isEqualToString:@"answer"]){
          __weak OutgoingViewController *weakSelf = self;
          
            RTCSessionDescription *remoteDesc = [RTCSessionDescription sdpFromJSONDictionary:message.content];
            [self.peerConnection setRemoteDescription:remoteDesc completionHandler:^(NSError * _Nullable error) {
              [weakSelf didSetSessionDescriptionWithError:error];
            }];
            
        }else if([message.subtype isEqualToString:@"candidate"]){
            NSLog(@"got candidate from peer: %@", message.content);
            
            RTCIceCandidate *candidate = [RTCIceCandidate candidateFromJSONDictionary:message.content];
            [self.peerConnection addIceCandidate:candidate];
        }else if ([message.subtype isEqualToString:@"close"]){
            [self handleRemoteHangup];
        }
    }
}

- (void)handleRemoteHangup{
    [self.peerConnection close];
    
    //TODO play busy tone
    [self dismissViewControllerAnimated:YES completion:nil];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
