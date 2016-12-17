//
//  VideoCallViewController.m
//  Chatchat
//
//  Created by WangRui on 16/6/24.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import "VideoCallViewController.h"

#import <AVFoundation/AVFoundation.h>

@interface VideoCallViewController () <RTCEAGLVideoViewDelegate>
{
    RTCVideoTrack *_localVideoTrack;
    RTCVideoTrack *_remoteVideoTrack;

    IBOutlet UILabel *_callingTitle;
    IBOutlet UIButton *_hangupButton;
    
    RTCEAGLVideoView *_cameraPreviewView;
}
@end


@implementation VideoCallViewController

- (RTCMediaConstraints *)defaultOfferConstraints {
  NSDictionary *mandatoryConstraints = @{@"OfferToReceiveAudio": @"true",
                                         @"OfferToReceiveVideo": @"true"};
  NSDictionary *optionalConstraints = @{@"DtlsSrtpKeyAgreement" : @"false"};
  
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
                                          optionalConstraints:optionalConstraints];
    return constraints;
}

- (void)viewDidLoad{
    [super viewDidLoad];
    
    _callingTitle.text = [NSString stringWithFormat:@"Calling %@", self.peer.name];
    _cameraPreviewView = nil;

    [self startLocalStream];
}

- (void)startLocalStream{
    RTCMediaStream *localStream = [self.factory mediaStreamWithStreamId:@"localStream"];
    RTCAudioTrack *audioTrack = [self.factory audioTrackWithTrackId:@"audio0"];
    [localStream addAudioTrack : audioTrack];
  
    //How to initialize souce??
    RTCVideoSource *source = [self.factory avFoundationVideoSourceWithConstraints:[self defaultVideoConstraints]];
    RTCVideoTrack *localVideoTrack = [self.factory videoTrackWithSource:source trackId:@"video0"];
    [localStream addVideoTrack:localVideoTrack];
    _localVideoTrack = localVideoTrack;
    
    [self.peerConnection addStream:localStream];
    
    [self.peerConnection offerForConstraints:[self defaultOfferConstraints]
                           completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
                             [self didCreateSessionDescription:sdp error:error];
    }];
    
    [self startPreview];
}

- (void)startPreview{
    if (_cameraPreviewView.superview == self.view) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        _cameraPreviewView = [[RTCEAGLVideoView alloc] initWithFrame: self.view.bounds];
        _cameraPreviewView.delegate = self;
        
        [self.view addSubview:_cameraPreviewView];
        [_localVideoTrack addRenderer:_cameraPreviewView];
        
        [self.view bringSubviewToFront:_callingTitle];
        [self.view bringSubviewToFront:_hangupButton];

    });
}


#pragma mark -- RTCEAGLVideoViewDelegate --
- (void)videoView:(RTCEAGLVideoView*)videoView didChangeVideoSize:(CGSize)size{
    NSLog(@"Video size changed to: %d, %d", (int)size.width, (int)size.height);
}


#pragma mark -- peerConnection delegate override --

- (void)peerConnection:(RTCPeerConnection *)peerConnection
           didAddStream:(RTCMediaStream *)stream{
    [super peerConnection:peerConnection didAddStream:stream];
    
    NSLog(@"%s, video tracks: %lu", __FILE__, (unsigned long)stream.videoTracks.count);

    if (stream.videoTracks.count) {
        _remoteVideoTrack = [stream.videoTracks lastObject];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Scale local view to upright corner
            if (_cameraPreviewView) {
                [UIView animateWithDuration:0.5 animations:^{
                    NSUInteger width = 100;
                    float screenRatio = [[UIScreen mainScreen] bounds].size.height / [[UIScreen mainScreen] bounds].size.width;
                    NSUInteger height = width * screenRatio;
                    _cameraPreviewView.frame = CGRectMake(self.view.bounds.size.width - 100, 0, width, height);
                } completion:^(BOOL finished) {
                    // Create a new render view with a size of your choice
                    RTCEAGLVideoView *renderView = [[RTCEAGLVideoView alloc] initWithFrame:self.view.bounds];
                    renderView.delegate = self;
                    [_remoteVideoTrack addRenderer:renderView];
                    [self.view addSubview:renderView];
                    
                    if (_cameraPreviewView) {
                        [self.view bringSubviewToFront:_cameraPreviewView];
                    }
                    [self.view bringSubviewToFront:_callingTitle];
                    [self.view bringSubviewToFront:_hangupButton];

                }];
            }
        });
    }
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
