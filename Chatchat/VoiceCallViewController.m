//
//  VoiceCallViewController.m
//  Chatchat
//
//  Created by WangRui on 16/6/7.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

#import "VoiceCallViewController.h"

@interface VoiceCallViewController ()
{
    IBOutlet UILabel *_callingTitle;
    IBOutlet UIButton *_hangupButton;
}
@end

@implementation VoiceCallViewController

- (void)viewDidLoad{
    [super viewDidLoad];
    
    _callingTitle.text = [NSString stringWithFormat:@"Calling %@", self.peer.name];
    
    RTCMediaStream *localStream = [self.factory mediaStreamWithLabel:@"localStream"];
    RTCAudioTrack *audioTrack = [self.factory audioTrackWithID:@"audio0"];
    [localStream addAudioTrack : audioTrack];
    
    [self.peerConnection addStream:localStream];

    [self.peerConnection createOfferWithDelegate:self constraints:[self defaultOfferConstraints]];
}


- (IBAction)hangupButtonPressed:(id)sender{
    [self sendCloseSignal];

    if (self.peerConnection) {
        [self.peerConnection close];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)sendCloseSignal{
    Message *message = [[Message alloc] initWithPeerUID:self.peer.uniqueID
                                                   Type:@"signal"
                                                SubType:@"close"
                                                Content:@"call is denied"];
    [self.socketIODelegate sendMessage:message];
}


@end
