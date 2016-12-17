//
//  CallViewController.m
//  Chatchat
//
//  Created by WangRui on 16/7/11.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import "CallViewController.h"

#import "RTCICECandidate+JSON.h"

#import "ARDSDPUtils.h"

#import "RTCSessionDescription+JSON.h"

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

@interface CallViewController ()
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
    NSDictionary *mandatoryConstraints = @{@"minAspectRatio" : [NSString stringWithFormat:@"%.1f", screenRatio - 0.1],
                                @"maxAspectRatio" : [NSString stringWithFormat:@"%.1f", screenRatio + 0.1]};
    return [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints optionalConstraints:nil];
}

- (NSArray *)defaultIceServers{
  return @[[[RTCIceServer alloc] initWithURLStrings:@[kDefaultSTUNServerUrl] username:@"" credential:@""]];
}

- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    NSDictionary *optionalConstraints = @{@"DtlsSrtpKeyAgreement" : @"true"};
    RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil
                                                                             optionalConstraints:optionalConstraints];
    return constraints;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _logger = [[RTCFileLogger alloc] init];
    [_logger start];

    RTCInitializeSSL();
  
    _factory = [[RTCPeerConnectionFactory alloc] init];
    
  RTCConfiguration *configure = [[RTCConfiguration alloc] init];
  configure.iceServers = [self defaultIceServers];
  
  _peerConnection = [_factory peerConnectionWithConfiguration:configure
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
  
  RTCCleanupSSL();
}

#pragma mark -- RTCSessionDescriptionDelegate --
- (void)didCreateSessionDescription:(RTCSessionDescription *)sdp error:(NSError *)error
{
    NSLog(@"didCreateSessionDescription : %ld:%@", (long)sdp.type, sdp.description);
  RTCSessionDescription *descriptionPreferH264 = [ARDSDPUtils descriptionForDescription:sdp preferredVideoCodec:@"H264"];

  __weak CallViewController *weakSelf = self;
    [self.peerConnection setLocalDescription:descriptionPreferH264
                           completionHandler:^(NSError * _Nullable error) {
                             [weakSelf didSetSessionDescriptionWithError:error];
    }];
  
  NSString *subtype = (sdp.type == RTCSdpTypeOffer) ? @"offer" : @"answer";
  // Send offer through the signaling channel of our application
  Message *message = [[Message alloc] initWithPeerUID:self.peer.uniqueID
                                                 Type:@"signal"
                                              SubType:subtype
                                              Content:[descriptionPreferH264 toDictionary]];
  
  [self.socketIODelegate sendMessage:message];
}

- (void)didSetSessionDescriptionWithError:(NSError *)error
{
    if (_peerConnection.signalingState == RTCSignalingStateHaveLocalOffer) {
        NSLog(@"have local offer");
    }else if (_peerConnection.signalingState == RTCSignalingStateHaveRemoteOffer){
        NSLog(@"have remote offer");
    }else if(_peerConnection.signalingState == RTCSignalingStateHaveRemotePrAnswer){
        NSLog(@"have remote answer");
    }
}


#pragma mark -- peerConnection delegate --

- (void)peerConnection:(RTCPeerConnection *)peerConnection
           didAddStream:(nonnull RTCMediaStream *)stream{
    NSLog(@"%s is called", __FUNCTION__);
    NSLog(@"audio tracks: %lu", (unsigned long)stream.audioTracks.count);
    // Create a new render view with a size of your choice
    //    RTCEAGLVideoView *renderView = [[RTCEAGLVideoView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    //    [stream.videoTracks.lastObject addRenderer:renderView];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeSignalingState:(RTCSignalingState)stateChanged{
    NSLog(@"signaling state changed: %ld", (long)stateChanged);
}

// Triggered when a remote peer close a stream.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
         didRemoveStream:(nonnull RTCMediaStream *)stream{
    NSLog(@"removed stream");
}

// Triggered when renegotiation is needed, for example the ICE has restarted.
- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection{
    
}

// Called any time the ICEConnectionState changes.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
  didChangeIceConnectionState:(RTCIceConnectionState)newState{
    NSLog(@"Ice changed: %@", RTCIceStateNames[newState]);
  
    if (newState == RTCIceConnectionStateConnected) {
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
   didChangeIceGatheringState:(RTCIceGatheringState)newState{
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
       didGenerateIceCandidate:(RTCIceCandidate *)candidate{
    NSLog(@"got candidate: %@", candidate.sdp);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        Message *message = [[Message alloc] initWithPeerUID:self.peer.uniqueID
                                                       Type:@"signal"
                                                    SubType:@"candidate"
                                                    Content:[candidate toDictionary]];
        [self.socketIODelegate sendMessage:message];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates{
  
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
  for (RTCMediaStream *stream in _peerConnection.localStreams) {
    for (RTCVideoTrack *track in stream.audioTracks) {
      [_peerConnection statsForTrack:track statsOutputLevel:RTCStatsOutputLevelStandard completionHandler:^(NSArray<RTCStatsReport *> * _Nonnull stats) {
        NSLog(@"%@", stats);
      }];
    }
    for (RTCVideoTrack *track in stream.videoTracks) {
      [_peerConnection statsForTrack:track statsOutputLevel:RTCStatsOutputLevelStandard completionHandler:^(NSArray<RTCStatsReport *> * _Nonnull stats) {
        NSLog(@"%@", stats);
      }];
    }
  }
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
