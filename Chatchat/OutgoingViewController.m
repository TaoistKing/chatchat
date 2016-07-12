//
//  OutgoingViewController.m
//  Chatchat
//
//  Created by WangRui on 16/7/11.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import "OutgoingViewController.h"

#import "RTCICECandidate+JSON.h"

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
    NSArray *mandatoryConstraints = @[
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"],
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"false"]
                                      ];
    NSArray *optionalConstraints = @[
                                     [[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"false"]
                                     ];
    
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
                                          optionalConstraints:optionalConstraints];
    return constraints;
}

#pragma mark -- RTCSessionDescriptionDelegate override --
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didCreateSessionDescription:(RTCSessionDescription *)sdp error:(NSError *)error
{
    [super peerConnection:peerConnection didCreateSessionDescription:sdp error:error];
    
    // Send offer through the signaling channel of our application
    Message *message = [[Message alloc] initWithPeerUID:self.peer.uniqueID
                                                   Type:@"signal"
                                                SubType:@"offer"
                                                Content:sdp.description];
    
    [self.socketIODelegate sendMessage:message];
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
            
            RTCSessionDescription *remoteDesc = [[RTCSessionDescription alloc] initWithType:@"answer" sdp:message.content];
            [self.peerConnection setRemoteDescriptionWithDelegate:self sessionDescription:remoteDesc];
            
        }else if([message.subtype isEqualToString:@"candidate"]){
            NSError *error = nil;
            NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:[message.content dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:&error];
            if (error) {
                NSLog(@"error serialize candidate string!");
            }else{
                NSLog(@"got candidate from peer: %@", message.content);
                
                RTCICECandidate *candidate = [RTCICECandidate candidateFromJSONDictionary:dic];
                [self.peerConnection addICECandidate:candidate];
            }
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
