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

@interface IncomingCallViewController () <RTCEAGLVideoViewDelegate>
{
    RTCVideoTrack *_localVideoTrack;
    RTCVideoTrack *_remoteVideoTrack;

    BOOL _accepted;
    
    BOOL _videoEnabled;
    UIView *_cameraPreviewView;
    AVCaptureSession *_captureSession;

}

@property (strong) IBOutlet UIButton *acceptButton;
@property (strong) IBOutlet UIButton *denyButton;
@property (strong) IBOutlet UILabel  *callTitle;
@end

@implementation IncomingCallViewController

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

- (RTCMediaConstraints *)defaultVideoAnswerConstraints{
    NSArray *mandatoryConstraints = @[
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"],
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"true"]
                                      ];
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
                                          optionalConstraints:nil];
    return constraints;
}

- (void)viewDidLoad{
    [super viewDidLoad];
    
    _videoEnabled = NO;
    _cameraPreviewView = nil;
    _captureSession = nil;
    _accepted = NO;
    
    _localVideoTrack = nil;
    _remoteVideoTrack = nil;

    NSString *title = [NSString stringWithFormat:@"Call From %@", self.peer.name];
    if ([self.offer.content containsString:@"video"]) {
        _videoEnabled = YES;
        title = [NSString stringWithFormat:@"Video Call From %@", self.peer.name];
    }

    self.callTitle.text = title;
    
    RTCSessionDescription *offer = [[RTCSessionDescription alloc] initWithType:@"offer" sdp:self.offer.content];
    [self.peerConnection setRemoteDescriptionWithDelegate:self sessionDescription:offer];
    
    RTCMediaStream *localStream = [self.factory mediaStreamWithLabel:@"localStream"];
    RTCAudioTrack *audioTrack = [self.factory audioTrackWithID:@"audio0"];
    [localStream addAudioTrack : audioTrack];
    
    if (_videoEnabled) {
        RTCAVFoundationVideoSource *source = [[RTCAVFoundationVideoSource alloc]
                                              initWithFactory:self.factory
                                              constraints:[self defaultMediaConstraints]];
        
        RTCVideoTrack *localVideoTrack = [[RTCVideoTrack alloc]
                                          initWithFactory:self.factory
                                          source:source
                                          trackId:@"video0"];
        
        [localStream addVideoTrack:localVideoTrack];
        _captureSession = source.captureSession;
        _localVideoTrack = localVideoTrack;
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

- (void)startPreviewWithSession : (AVCaptureSession *)session{
    if (_cameraPreviewView.superview == self.view) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        AVCaptureVideoPreviewLayer *layer = [AVCaptureVideoPreviewLayer layerWithSession:session];
        _cameraPreviewView = [[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 100, 0, 100, 150)];
        layer.frame = _cameraPreviewView.bounds;//I have no idea why I have to add this line.
        [_cameraPreviewView.layer addSublayer:layer];
        
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

#pragma mark -- RTCSessionDescriptionDelegate override --
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didCreateSessionDescription:(RTCSessionDescription *)sdp error:(NSError *)error
{
    [super peerConnection:peerConnection didCreateSessionDescription:sdp error:error];
    
    // Send offer through the signaling channel of our application
    Message *message = [[Message alloc] initWithPeerUID:self.peer.uniqueID
                                                   Type:@"signal"
                                                SubType:@"answer"
                                                Content:sdp.description];
    
    [self.socketIODelegate sendMessage:message];
}

#pragma mark -- peerConnection delegate override --

- (void)peerConnection:(RTCPeerConnection *)peerConnection
           addedStream:(RTCMediaStream *)stream{
    // Create a new render view with a size of your choice
    [super peerConnection:peerConnection addedStream:stream];
    
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
            NSError *error = nil;
            NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:[message.content dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:&error];
            if (error) {
                NSLog(@"error serialize candidate string!");
            }else{
                NSLog(@"%s, got candidate from peer: %@", __FILE__, message.content);

                RTCICECandidate *candidate = [RTCICECandidate candidateFromJSONDictionary:dic];
                [self.peerConnection addICECandidate:candidate];
            }
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
        [self.peerConnection createAnswerWithDelegate:self constraints:constraints];

        _accepted = YES;
        
        self.denyButton.hidden = YES;
        
        [self.acceptButton setTitle:@"Hangup" forState:UIControlStateNormal];
        
        if (_videoEnabled) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self startPreviewWithSession:_captureSession];
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

