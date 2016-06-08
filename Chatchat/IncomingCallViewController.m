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

static NSString * const kARDDefaultSTUNServerUrl =
@"stun:stun.l.google.com:19302";

@interface IncomingCallViewController () <RTCPeerConnectionDelegate, RTCSessionDescriptionDelegate>
{
    RTCPeerConnection *_peerConnection;
}

@property (strong) IBOutlet UIButton *acceptButton;
@property (strong) IBOutlet UIButton *denyButton;

@end

@implementation IncomingCallViewController

- (RTCMediaConstraints *)defaultMediaConstraints{
    return [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil optionalConstraints:nil];
}

- (NSArray *)defaultIceServers{
    NSURL *defaultSTUNServerURL = [NSURL URLWithString:kARDDefaultSTUNServerUrl];
    
    return @[[[RTCICEServer alloc] initWithURI:defaultSTUNServerURL
                                      username:@""
                                      password:@""]];
}

- (void)viewDidLoad{
    [super viewDidLoad];
    
    [RTCPeerConnectionFactory initializeSSL];
    RTCPeerConnectionFactory *factory = [[RTCPeerConnectionFactory alloc] init];
    
    _peerConnection = [factory peerConnectionWithICEServers:[self defaultIceServers]
                                                constraints:[self defaultMediaConstraints]
                                                   delegate:self];
    
    RTCMediaStream *localStream = [factory mediaStreamWithLabel:@"localStream"];
    RTCAudioTrack *audioTrack = [factory audioTrackWithID:@"audio0"];
    [localStream addAudioTrack : audioTrack];

    RTCSessionDescription *offer = [[RTCSessionDescription alloc] initWithType:@"offer" sdp:self.offer.content];
    [_peerConnection setRemoteDescriptionWithDelegate:self sessionDescription:offer];
}


#pragma mark -- RTCSessionDescriptionDelegate --
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didCreateSessionDescription:(RTCSessionDescription *)sdp error:(NSError *)error
{
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
    if (peerConnection.signalingState == RTCSignalingHaveLocalOffer) {
        NSLog(@"have local offer");
    }else if (peerConnection.signalingState == RTCSignalingHaveRemoteOffer){
        NSLog(@"have remote offer");
        [_peerConnection createAnswerWithDelegate:self constraints:[self defaultMediaConstraints]];
        
    }else if(peerConnection.signalingState == RTCSignalingHaveRemotePrAnswer){
        NSLog(@"have remote answer");
    }
}


#pragma mark -- peerConnection delegate --

- (void)peerConnection:(RTCPeerConnection *)peerConnection
           addedStream:(RTCMediaStream *)stream{
    // Create a new render view with a size of your choice
    RTCEAGLVideoView *renderView = [[RTCEAGLVideoView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    [stream.videoTracks.lastObject addRenderer:renderView];
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
    NSLog(@"got candidate from stun");
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
                NSLog(@"got candidate from peer");

                RTCICECandidate *candidate = [RTCICECandidate candidateFromJSONDictionary:dic];
                [_peerConnection addICECandidate:candidate];
            }
        }
    }
}

@end

