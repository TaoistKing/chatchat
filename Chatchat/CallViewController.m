//
//  CallViewController.m
//  Chatchat
//
//  Created by WangRui on 16/7/11.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import "CallViewController.h"

#import "RTCICECandidate+JSON.h"

#import "RTCStatsDelegate.h"

//enum to string.
//Modify these names when defination changed
NSString *const RTCIceStateNames[] = {
    @"RTCICEConnectionNew",
    @"RTCICEConnectionChecking",
    @"RTCICEConnectionConnected",
    @"RTCICEConnectionCompleted",
    @"RTCICEConnectionFailed",
    @"RTCICEConnectionDisconnected",
    @"RTCICEConnectionClosed",
    @"RTCICEConnectionMax"
};

@interface CallViewController () <RTCStatsDelegate>
{
    RTCFileLogger *_logger;
    NSTimer *_statTimer;
}

@end

@implementation CallViewController

- (RTCMediaConstraints *)defaultMediaConstraints{
    return [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil optionalConstraints:nil];
}

- (RTCMediaConstraints *)defaultVideoConstraints{
    float screenRatio = [[UIScreen mainScreen] bounds].size.height / [[UIScreen mainScreen] bounds].size.width;
    NSArray *mandatoryConstraints = @[
                                      [[RTCPair alloc] initWithKey:@"minAspectRatio" value:[NSString stringWithFormat:@"%.1f", screenRatio - 0.1]],
                                      [[RTCPair alloc] initWithKey:@"maxAspectRatio" value:[NSString stringWithFormat:@"%.1f", screenRatio + 0.1]]
                                      ];
    
    return [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints optionalConstraints:nil];
}

- (NSArray *)defaultIceServers{
    NSURL *defaultSTUNServerURL = [NSURL URLWithString:kDefaultSTUNServerUrl];
    
    return @[[[RTCICEServer alloc] initWithURI:defaultSTUNServerURL
                                      username:@""
                                      password:@""]];
}

- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    NSString *value = @"true";
    NSArray *optionalConstraints = @[
                                     [[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:value]
                                     ];
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:nil
     optionalConstraints:optionalConstraints];
    return constraints;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _logger = [[RTCFileLogger alloc] init];
    [_logger start];

    [RTCPeerConnectionFactory initializeSSL];
    _factory = [[RTCPeerConnectionFactory alloc] init];
    
    _peerConnection = [_factory peerConnectionWithICEServers:[self defaultIceServers]
                                                 constraints:[self defaultMediaConstraints]
                                                    delegate:self];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion{
    [super dismissViewControllerAnimated:flag completion:completion];
    
    if (_statTimer) {
        [_statTimer invalidate];
    }
}

#pragma mark -- RTCSessionDescriptionDelegate --
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didCreateSessionDescription:(RTCSessionDescription *)sdp error:(NSError *)error
{
    NSLog(@"didCreateSessionDescription : %@:%@", sdp.type, sdp.description);
    
    [self.peerConnection setLocalDescriptionWithDelegate:self sessionDescription:sdp];
    
    // Send offer through the signaling channel of our application
    // Implemented by Subclass
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didSetSessionDescriptionWithError:(NSError *)error
{
    if (peerConnection.signalingState == RTCSignalingHaveLocalOffer) {
        NSLog(@"have local offer");
    }else if (peerConnection.signalingState == RTCSignalingHaveRemoteOffer){
        NSLog(@"have remote offer");
    }else if(peerConnection.signalingState == RTCSignalingHaveRemotePrAnswer){
        NSLog(@"have remote answer");
    }
}


#pragma mark -- peerConnection delegate --

- (void)peerConnection:(RTCPeerConnection *)peerConnection
           addedStream:(RTCMediaStream *)stream{
    NSLog(@"%s is called", __FUNCTION__);
    NSLog(@"audio tracks: %lu", (unsigned long)stream.audioTracks.count);
    // Create a new render view with a size of your choice
    //    RTCEAGLVideoView *renderView = [[RTCEAGLVideoView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    //    [stream.videoTracks.lastObject addRenderer:renderView];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
 signalingStateChanged:(RTCSignalingState)stateChanged{
    NSLog(@"signaling state changed: %d", stateChanged);
}

// Triggered when a remote peer close a stream.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
         removedStream:(RTCMediaStream *)stream{
    NSLog(@"removed stream");
}

// Triggered when renegotiation is needed, for example the ICE has restarted.
- (void)peerConnectionOnRenegotiationNeeded:(RTCPeerConnection *)peerConnection{
    
}

// Called any time the ICEConnectionState changes.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
  iceConnectionChanged:(RTCICEConnectionState)newState{
    NSLog(@"Ice changed: %@", RTCIceStateNames[newState]);
    
    if (newState == RTCICEConnectionConnected) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!_statTimer) {
                _statTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(statTimerFired:) userInfo:nil repeats:YES];
                [_statTimer fire];
            }
        });
    }
}

// Called any time the ICEGatheringState changes.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
   iceGatheringChanged:(RTCICEGatheringState)newState{
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
       gotICECandidate:(RTCICECandidate *)candidate{
    NSLog(@"got candidate: %@", candidate.sdp);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        Message *message = [[Message alloc] initWithPeerUID:self.peer.uniqueID
                                                       Type:@"signal"
                                                    SubType:@"candidate"
                                                    Content:[candidate JSONString]];
        [self.socketIODelegate sendMessage:message];
    });
}

// New data channel has been opened.
- (void)peerConnection:(RTCPeerConnection*)peerConnection
    didOpenDataChannel:(RTCDataChannel*)dataChannel{
    
}


- (void)onMessage: (Message *)message{
    NSLog(@"onMessage:");
    NSLog(@"%@", message);
}

#pragma mark -- Stat Report --
- (void)statTimerFired: (id)sender{
    [_peerConnection getStatsWithDelegate:self
                         mediaStreamTrack:nil
                         statsOutputLevel:RTCStatsOutputLevelStandard];
}

- (void)peerConnection:(RTCPeerConnection*)peerConnection
           didGetStats:(NSArray*)stats{
    NSLog(@"stats: %@", stats);
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
