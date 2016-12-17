//
//  IncomingCallViewController.m
//  Chatchat
//
//  Created by WangRui on 16/6/8.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//
#import <AVFoundation/AVFoundation.h>

#import "IncomingCallViewController.h"
#import "RTCICECandidate+JSON.h"
#import "RTCSessionDescription+JSON.h"

@interface IncomingCallViewController () <RTCEAGLVideoViewDelegate>
{
    RTCVideoTrack *_localVideoTrack;
    RTCVideoTrack *_remoteVideoTrack;

    BOOL _accepted;
    
    BOOL _videoEnabled;
    RTCEAGLVideoView *_cameraPreviewView;

}

@property (strong) IBOutlet UIButton *acceptButton;
@property (strong) IBOutlet UIButton *denyButton;
@property (strong) IBOutlet UILabel  *callTitle;
@end

@implementation IncomingCallViewController

- (RTCMediaConstraints *)defaultAnswerConstraints{
  NSDictionary *mandatoryConstraints = @{@"OfferToReceiveAudio": @"true",
                                         @"OfferToReceiveVideo": @"true"};
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
                                          optionalConstraints:nil];
    return constraints;
}

- (RTCMediaConstraints *)defaultVideoAnswerConstraints{
  NSDictionary *mandatoryConstraints = @{@"OfferToReceiveAudio": @"true",
                                         @"OfferToReceiveVideo": @"true"};
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
                                          optionalConstraints:nil];
    return constraints;
}

- (void)viewDidLoad{
    [super viewDidLoad];
    
    _videoEnabled = NO;
    _cameraPreviewView = nil;
    _accepted = NO;
    
    _localVideoTrack = nil;
    _remoteVideoTrack = nil;

    NSString *title = [NSString stringWithFormat:@"Call From %@", self.peer.name];
  NSString *sdp = [self.offer.content objectForKey:@"sdp"];
    if ([sdp containsString:@"video"]) {
        _videoEnabled = YES;
        title = [NSString stringWithFormat:@"Video Call From %@", self.peer.name];
    }

    self.callTitle.text = title;
  
  __weak IncomingCallViewController *weakSelf = self;
    RTCSessionDescription *offer = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeOffer sdp:sdp];
    [self.peerConnection setRemoteDescription:offer
                            completionHandler:^(NSError * _Nullable error) {
                              [weakSelf didSetSessionDescriptionWithError:error];
    }];
    
  RTCMediaStream *localStream = [self.factory mediaStreamWithStreamId:@"localStream"];
  RTCAudioTrack *audioTrack = [self.factory audioTrackWithTrackId:@"audio0"];
  [localStream addAudioTrack : audioTrack];
  
    if (_videoEnabled) {
      RTCVideoSource *source = [self.factory avFoundationVideoSourceWithConstraints:[self defaultVideoConstraints]];
      RTCVideoTrack *localVideoTrack = [self.factory videoTrackWithSource:source trackId:@"video0"];
      [localStream addVideoTrack:localVideoTrack];
      
        _localVideoTrack = localVideoTrack;
      
        [self startPreview];
    }
    
    [self.peerConnection addStream:localStream];

    NSLog(@"%s, presenting view with offer: %@", __FILE__, self.offer.content);
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    //deal with any pending signal message after view loaded
    for (Message *item in self.pendingMessages) {
        [self onMessage:item];
    }
}

- (void)startPreview{
    if (_cameraPreviewView.superview == self.view) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        NSUInteger width = 100;
        float screenRatio = [[UIScreen mainScreen] bounds].size.height / [[UIScreen mainScreen] bounds].size.width;
        NSUInteger height = width * screenRatio;
        _cameraPreviewView = [[RTCEAGLVideoView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - width, 0, width, height)];
        _cameraPreviewView.delegate = self;
        [_localVideoTrack addRenderer:_cameraPreviewView];
        
        [self.view addSubview:_cameraPreviewView];
        [self.view bringSubviewToFront:self.callTitle];
        [self.view bringSubviewToFront:self.acceptButton];
        
    });
}

- (void)startRemoteVideo{
    dispatch_async(dispatch_get_main_queue(), ^{
        RTCEAGLVideoView *renderView = [[RTCEAGLVideoView alloc] initWithFrame:self.view.bounds];
        renderView.delegate = self;
        [_remoteVideoTrack addRenderer:renderView];
        [self.view addSubview:renderView];
        
        if (_cameraPreviewView) {
            [self.view bringSubviewToFront:_cameraPreviewView];
        }
        [self.view bringSubviewToFront:self.acceptButton];
        [self.view bringSubviewToFront:self.callTitle];

    });
}

#pragma mark -- RTCEAGLVideoViewDelegate --
- (void)videoView:(RTCEAGLVideoView*)videoView didChangeVideoSize:(CGSize)size{
    NSLog(@"Video size changed to: %d, %d", (int)size.width, (int)size.height);
}

#pragma mark -- peerConnection delegate override --

- (void)peerConnection:(RTCPeerConnection *)peerConnection
           didAddStream:(RTCMediaStream *)stream{
    // Create a new render view with a size of your choice
    [super peerConnection:peerConnection didAddStream:stream];
    
    if (stream.videoTracks.count) {
        _remoteVideoTrack = [stream.videoTracks lastObject];
    }
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
            NSLog(@"%s, got candidate from peer: %@", __FILE__, message.content);
            RTCIceCandidate *candidate = [RTCIceCandidate candidateFromJSONDictionary:message.content];
            [self.peerConnection addIceCandidate:candidate];
          
        }else if([message.subtype isEqualToString:@"close"]){
            [self handleRemoteHangup];
        }
    }
}

- (void)handleRemoteHangup{
    [self.peerConnection close];
    
    //TODO play busy tone
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (IBAction)acceptButtonPressed:(id)sender{
    if (_accepted) {
        //close pc
        //dismiss this vc
        [self sendCloseSignal];
        [self.peerConnection close];
        
        [self dismissViewControllerAnimated:YES completion:nil];
        
    }else{
        NSLog(@"call accepted");
        
        RTCMediaConstraints *constraints = [self defaultAnswerConstraints];
        if (_videoEnabled) {
            constraints = [self defaultVideoAnswerConstraints];
        }
        [self.peerConnection answerForConstraints:constraints
                                completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
                                  [self didCreateSessionDescription:sdp error:error];
        }];

        _accepted = YES;
        
        self.denyButton.hidden = YES;
        
        [self.acceptButton setTitle:@"Hangup" forState:UIControlStateNormal];
        
        if (_videoEnabled) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self startPreview];
                [self startRemoteVideo];
            });
        }
    }
}

- (IBAction)denyButtonPressed:(id)sender{
    //signal denied
    //close pc
    //dismiss this vc
    NSLog(@"call denied");

    [self sendCloseSignal];
    [self.peerConnection close];
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

