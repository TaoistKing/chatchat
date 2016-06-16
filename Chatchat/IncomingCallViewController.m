//
//  IncomingCallViewController.m
//  Chatchat
//
//  Created by WangRui on 16/6/8.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import "IncomingCallViewController.h"

#import "RTCPeerConnectionFactory.h"
#import "RTCPeerConnection.h"
#import "RTCPeerConnectionDelegate.h"
#import "RTCMediaConstraints.h"
#import "RTCMediaStream.h"
#import "RTCAudioTrack.h"
#import "RTCVideoTrack.h"
#import "RTCVideoCapturer.h"
#import "RTCPair.h"
#import "RTCSessionDescription.h"
#import "RTCSessionDescriptionDelegate.h"
#import "RTCEAGLVideoView.h"
#import "RTCICEServer.h"
#import "RTCICECandidate.h"

#import "RTCICECandidate+JSON.h"

#import "constants.h"


@interface IncomingCallViewController () <RTCPeerConnectionDelegate, RTCSessionDescriptionDelegate>
{
    RTCPeerConnectionFactory *_factory;
    RTCPeerConnection *_peerConnection;
    BOOL _accepted;
}

@property (strong) IBOutlet UIButton *acceptButton;
@property (strong) IBOutlet UIButton *denyButton;

@end

@implementation IncomingCallViewController

- (RTCMediaConstraints *)defaultMediaConstraints{
    return [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil optionalConstraints:nil];
}

- (RTCMediaConstraints *)defaultAnswerConstraints{
    NSArray *mandatoryConstraints = @[
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"],
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"false"]
                                      ];
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
                                          optionalConstraints:nil];
    return constraints;
}


- (NSArray *)defaultIceServers{
    NSURL *defaultSTUNServerURL = [NSURL URLWithString:kDefaultSTUNServerUrl];
    
    return @[[[RTCICEServer alloc] initWithURI:defaultSTUNServerURL
                                      username:@""
                                      password:@""]];
}

- (void)viewDidLoad{
    [super viewDidLoad];
    
    [RTCPeerConnectionFactory initializeSSL];
    _factory = [[RTCPeerConnectionFactory alloc] init];
    
    _peerConnection = [_factory peerConnectionWithICEServers:[self defaultIceServers]
                                                constraints:[self defaultMediaConstraints]
                                                   delegate:self];
    _accepted = NO;
    
    NSLog(@"%s, presenting view with offer: %@", __FILE__, self.offer.content);
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    //deal with any pending signal message after view loaded
    for (Message *item in self.pendingMessages) {
        [self onMessage:item];
    }
}

#pragma mark -- RTCSessionDescriptionDelegate --
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didCreateSessionDescription:(RTCSessionDescription *)sdp error:(NSError *)error
{
    NSLog(@"%s, didCreateSessionDescription : %@:%@", __FILE__, sdp.type, sdp.description);
    
    [_peerConnection setLocalDescriptionWithDelegate:self sessionDescription:sdp];
    
    // Send answer through the signaling channel of our application
    Message *message = [[Message alloc] initWithPeerUID:self.peer.uniqueID
                                                   Type:@"signal"
                                                SubType:@"answer"
                                                Content:sdp.description];
    
    [self.socketIODelegate sendMessage:message];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didSetSessionDescriptionWithError:(NSError *)error
{
    NSLog(@"%s, %s is called", __FILE__, __FUNCTION__);

    if (peerConnection.signalingState == RTCSignalingHaveLocalOffer) {
        NSLog(@"%s, have local offer", __FILE__);
    }else if (peerConnection.signalingState == RTCSignalingHaveRemoteOffer){
        NSLog(@"%s, have remote offer", __FILE__);
        [_peerConnection createAnswerWithDelegate:self constraints:[self defaultAnswerConstraints]];
        
    }else if(peerConnection.signalingState == RTCSignalingHaveRemotePrAnswer){
        NSLog(@"%s, have remote answer", __FILE__);
    }
}


#pragma mark -- peerConnection delegate --

- (void)peerConnection:(RTCPeerConnection *)peerConnection
           addedStream:(RTCMediaStream *)stream{
    // Create a new render view with a size of your choice
    NSLog(@"%s, %s is called", __FILE__, __FUNCTION__);
    NSLog(@"%s, audio tracks: %lu", __FILE__, (unsigned long)stream.audioTracks.count);

//    RTCEAGLVideoView *renderView = [[RTCEAGLVideoView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
//    [stream.videoTracks.lastObject addRenderer:renderView];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
 signalingStateChanged:(RTCSignalingState)stateChanged{
    
}

// Triggered when a remote peer close a stream.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
         removedStream:(RTCMediaStream *)stream{
    
}

// Triggered when renegotiation is needed, for example the ICE has restarted.
- (void)peerConnectionOnRenegotiationNeeded:(RTCPeerConnection *)peerConnection{
    
}

// Called any time the ICEConnectionState changes.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
  iceConnectionChanged:(RTCICEConnectionState)newState{
    
}

// Called any time the ICEGatheringState changes.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
   iceGatheringChanged:(RTCICEGatheringState)newState{
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
       gotICECandidate:(RTCICECandidate *)candidate{
    NSLog(@"%s, got candidate : %@", __FILE__, candidate.sdp);
    Message *message = [[Message alloc] initWithPeerUID:self.peer.uniqueID
                                                   Type:@"signal"
                                                SubType:@"candidate"
                                                Content:[candidate JSONString]];
    [self.socketIODelegate sendMessage:message];
}

// New data channel has been opened.
- (void)peerConnection:(RTCPeerConnection*)peerConnection
    didOpenDataChannel:(RTCDataChannel*)dataChannel{
    
}


- (void)onMessage: (Message *)message{
    if ([message.type isEqualToString:@"signal"]) {
        if ([message.subtype isEqualToString:@"offer"]) {
            //
            //create peerconnection
            //set remote desc
            //I'm calling in, so I don't accept offer right now
            
        }else if([message.subtype isEqualToString:@"answer"]){

        }else if([message.subtype isEqualToString:@"candidate"]){
            NSError *error = nil;
            NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:[message.content dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:&error];
            if (error) {
                NSLog(@"error serialize candidate string!");
            }else{
                NSLog(@"%s, got candidate from peer: %@", __FILE__, message.content);

                RTCICECandidate *candidate = [RTCICECandidate candidateFromJSONDictionary:dic];
                [_peerConnection addICECandidate:candidate];
            }
        }else if([message.subtype isEqualToString:@"close"]){
            [self handleRemoteHangup];
        }
    }
}

- (void)handleRemoteHangup{
    [_peerConnection close];
    
    //TODO play busy tone
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (IBAction)acceptButtonPressed:(id)sender{
    if (_accepted) {
        //close pc
        //dismiss this vc
        [self sendCloseSignal];
        [_peerConnection close];
        
        [self dismissViewControllerAnimated:YES completion:nil];
        
    }else{
        NSLog(@"call accepted");
        RTCSessionDescription *offer = [[RTCSessionDescription alloc] initWithType:@"offer" sdp:self.offer.content];
        [_peerConnection setRemoteDescriptionWithDelegate:self sessionDescription:offer];
        
        RTCMediaStream *localStream = [_factory mediaStreamWithLabel:@"localStream"];
        RTCAudioTrack *audioTrack = [_factory audioTrackWithID:@"audio0"];
        [localStream addAudioTrack : audioTrack];
        
        [_peerConnection addStream:localStream];
        
        _accepted = YES;
        
        self.denyButton.hidden = YES;
        
        [self.acceptButton setTitle:@"Hangup" forState:UIControlStateNormal];
    }
}

- (IBAction)denyButtonPressed:(id)sender{
    //signal denied
    //close pc
    //dismiss this vc
    NSLog(@"call denied");

    [self sendCloseSignal];
    [_peerConnection close];
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

