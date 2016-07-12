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
    
    UIView *_cameraPreviewView;
    AVCaptureSession *_captureSession;
}
@end


@implementation VideoCallViewController

- (RTCMediaConstraints *)defaultOfferConstraints {
    NSArray *mandatoryConstraints = @[
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"],
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"true"]
                                      ];
    NSArray *optionalConstraints = @[
                                     [[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"false"]
                                     ];
    
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
                                          optionalConstraints:optionalConstraints];
    return constraints;
}

- (void)viewDidLoad{
    [super viewDidLoad];
    
    _callingTitle.text = [NSString stringWithFormat:@"Calling %@", self.peer.name];
    _cameraPreviewView = nil;
    _captureSession = nil;

    RTCMediaStream *localStream = [self.factory mediaStreamWithLabel:@"localStream"];
    RTCAudioTrack *audioTrack = [self.factory audioTrackWithID:@"audio0"];
    [localStream addAudioTrack : audioTrack];
    
    RTCAVFoundationVideoSource *source = [[RTCAVFoundationVideoSource alloc]
                                           initWithFactory:self.factory
                                           constraints:[self defaultMediaConstraints]];
    
    RTCVideoTrack *localVideoTrack = [[RTCVideoTrack alloc]
                                       initWithFactory:self.factory
                                       source:source
                                       trackId:@"video0"];
    
    [localStream addVideoTrack:localVideoTrack];
    _localVideoTrack = localVideoTrack;
    
    [self.peerConnection addStream:localStream];
    
    [self.peerConnection createOfferWithDelegate:self constraints:[self defaultOfferConstraints]];
    
    //add camera preview layer
    _captureSession = source.captureSession;
    [_captureSession addObserver:self
                      forKeyPath:@"running"
                         options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                         context:nil];
}

- (void)dealloc{
    
    [_captureSession removeObserver:self forKeyPath:@"running"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context{
    if ([keyPath isEqualToString:@"running"]) {
        NSInteger running = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        if (running == 1) {
            //I have to start preview after capturesession is running
            NSLog(@"AVCaptureSession is running");
            dispatch_async(dispatch_get_main_queue(), ^{
                [self startPreviewWithSession: object];
            });
        }
    }
}

- (void)startPreviewWithSession : (id)obj{
    if (_cameraPreviewView.superview == self.view) {
        return;
    }
    
    AVCaptureSession *session = (AVCaptureSession *)obj;
    AVCaptureVideoPreviewLayer *layer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    _cameraPreviewView = [[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 100, 0, 100, 150)];
    layer.frame = _cameraPreviewView.bounds;//I have no idea why I have to add this line.
    [_cameraPreviewView.layer addSublayer:layer];
    
    [self.view addSubview:_cameraPreviewView];
    
    [self.view bringSubviewToFront:_callingTitle];
    [self.view bringSubviewToFront:_hangupButton];

}


#pragma mark -- RTCEAGLVideoViewDelegate --
- (void)videoView:(RTCEAGLVideoView*)videoView didChangeVideoSize:(CGSize)size{
    NSLog(@"Video size changed to: %d, %d", (int)size.width, (int)size.height);
}


#pragma mark -- peerConnection delegate override --

- (void)peerConnection:(RTCPeerConnection *)peerConnection
           addedStream:(RTCMediaStream *)stream{
    [super peerConnection:peerConnection addedStream:stream];
    
    NSLog(@"%s, video tracks: %lu", __FILE__, (unsigned long)stream.videoTracks.count);

    if (stream.videoTracks.count) {
        _remoteVideoTrack = [stream.videoTracks lastObject];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Create a new render view with a size of your choice
            RTCEAGLVideoView *renderView = [[RTCEAGLVideoView alloc] initWithFrame:self.view.bounds];
            renderView.delegate = self;
            [_remoteVideoTrack addRenderer:renderView];
            [self.view addSubview:renderView];
            
            [self startPreviewWithSession:_captureSession];

            if (_cameraPreviewView) {
                [self.view bringSubviewToFront:_cameraPreviewView];
            }
            [self.view bringSubviewToFront:_callingTitle];
            [self.view bringSubviewToFront:_hangupButton];
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
