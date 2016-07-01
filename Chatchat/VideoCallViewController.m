//
//  VideoCallViewController.m
//  Chatchat
//
//  Created by WangRui on 16/6/24.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import "VideoCallViewController.h"

#import <AVFoundation/AVFoundation.h>

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
#import "RTCAVFoundationVideoSource.h"

#import "RTCICECandidate+JSON.h"

#import "constants.h"

@interface VideoCallViewController () <RTCPeerConnectionDelegate, RTCSessionDescriptionDelegate,
RTCEAGLVideoViewDelegate>
{
    RTCPeerConnectionFactory *_factory;
    RTCPeerConnection *_peerConnection;
    RTCVideoTrack *_localVideoTrack;
    RTCVideoTrack *_remoteVideoTrack;
    
    IBOutlet UILabel *_callingTitle;
    IBOutlet UIButton *_hangupButton;
    
    UIView *_cameraPreviewView;
    AVCaptureSession *_captureSession;
}
@end


@implementation VideoCallViewController

- (RTCMediaConstraints *)defaultMediaConstraints{
    return [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil optionalConstraints:nil];
}

- (NSArray *)defaultIceServers{
    NSURL *defaultSTUNServerURL = [NSURL URLWithString:kDefaultSTUNServerUrl];
    
    return @[[[RTCICEServer alloc] initWithURI:defaultSTUNServerURL
                                      username:@""
                                      password:@""]];
}

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


- (void)viewDidLoad{
    [super viewDidLoad];
    
    _callingTitle.text = [NSString stringWithFormat:@"Calling %@", self.peer.name];
    _cameraPreviewView = nil;
    _captureSession = nil;
    
    [RTCPeerConnectionFactory initializeSSL];
    _factory = [[RTCPeerConnectionFactory alloc] init];
    
    _peerConnection = [_factory peerConnectionWithICEServers:[self defaultIceServers]
                                                 constraints:[self defaultMediaConstraints]
                                                    delegate:self];
    
    RTCMediaStream *localStream = [_factory mediaStreamWithLabel:@"localStream"];
    RTCAudioTrack *audioTrack = [_factory audioTrackWithID:@"audio0"];
    [localStream addAudioTrack : audioTrack];
    /*
     // Find the device that is the front facing camera
     AVCaptureDevice *device;
     for (AVCaptureDevice *captureDevice in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] ) {
     if (captureDevice.position == AVCaptureDevicePositionFront) {
     device = captureDevice;
     break;
     }
     }
     
     // Create a video track and add it to the media stream
     if (device) {
     RTCVideoSource *videoSource;
     RTCVideoCapturer *capturer = [RTCVideoCapturer capturerWithDeviceName:device.localizedName];
     videoSource = [factory videoSourceWithCapturer:capturer constraints:nil];
     RTCVideoTrack *videoTrack = [factory videoTrackWithID:@"video0" source:videoSource];
     [localStream addVideoTrack:videoTrack];
     }
     */
    
    RTCAVFoundationVideoSource *source = [[RTCAVFoundationVideoSource alloc]
                                           initWithFactory:_factory
                                           constraints:[self defaultMediaConstraints]];
    
    RTCVideoTrack *localVideoTrack = [[RTCVideoTrack alloc]
                                       initWithFactory:_factory
                                       source:source
                                       trackId:@"video0"];
    
    [localStream addVideoTrack:localVideoTrack];
    _localVideoTrack = localVideoTrack;
    
    [_peerConnection addStream:localStream];
    
    [_peerConnection createOfferWithDelegate:self constraints:[self defaultOfferConstraints]];
    
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
            [self startPreviewWithSession: object];
        }
    }
}

- (void)startPreviewWithSession : (id)obj{
    if (_cameraPreviewView.superview == self.view) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        AVCaptureSession *session = (AVCaptureSession *)obj;
        AVCaptureVideoPreviewLayer *layer = [AVCaptureVideoPreviewLayer layerWithSession:session];
        _cameraPreviewView = [[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 100, 0, 100, 150)];
        layer.frame = _cameraPreviewView.bounds;//I have no idea why I have to add this line.
        [_cameraPreviewView.layer addSublayer:layer];
        
        [self.view addSubview:_cameraPreviewView];
        
        [self.view bringSubviewToFront:_callingTitle];
        [self.view bringSubviewToFront:_hangupButton];

    });
}


#pragma mark -- RTCEAGLVideoViewDelegate --
- (void)videoView:(RTCEAGLVideoView*)videoView didChangeVideoSize:(CGSize)size{
    NSLog(@"Video size changed to: %d, %d", (int)size.width, (int)size.height);
}


#pragma mark -- RTCSessionDescriptionDelegate --
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didCreateSessionDescription:(RTCSessionDescription *)sdp error:(NSError *)error
{
    NSLog(@"%s, didCreateSessionDescription : %@:%@", __FILE__, sdp.type, sdp.description);
    
    [_peerConnection setLocalDescriptionWithDelegate:self sessionDescription:sdp];
    
    // Send offer through the signaling channel of our application
    Message *message = [[Message alloc] initWithPeerUID:self.peer.uniqueID
                                                   Type:@"signal"
                                                SubType:@"offer"
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
    }else if(peerConnection.signalingState == RTCSignalingHaveRemotePrAnswer){
        NSLog(@"have remote answer");
    }
}


#pragma mark -- peerConnection delegate --

- (void)peerConnection:(RTCPeerConnection *)peerConnection
           addedStream:(RTCMediaStream *)stream{
    NSLog(@"%s, %s is called", __FILE__, __FUNCTION__);
    NSLog(@"%s, audio tracks: %lu", __FILE__, (unsigned long)stream.audioTracks.count);
    NSLog(@"%s, video tracks: %lu", __FILE__, (unsigned long)stream.videoTracks.count);

    if (stream.videoTracks.count) {
        _remoteVideoTrack = [stream.videoTracks lastObject];
        
        [self startPreviewWithSession:_captureSession];
        
        dispatch_async(dispatch_get_main_queue(), ^{
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
        });
    }
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
 signalingStateChanged:(RTCSignalingState)stateChanged{
    NSLog(@"signaling state changed: %d", stateChanged);
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
    NSLog(@"Ice changed: %d", newState);
}

// Called any time the ICEGatheringState changes.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
   iceGatheringChanged:(RTCICEGatheringState)newState{
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
       gotICECandidate:(RTCICECandidate *)candidate{
    NSLog(@"%s, got candidate: %@", __FILE__, candidate.sdp);
    
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
    if ([message.type isEqualToString:@"signal"]) {
        if ([message.subtype isEqualToString:@"offer"]) {
            //
            //create peerconnection
            //set remote desc
            //I'm calling out, so I don't accept offer right now
            
        }else if([message.subtype isEqualToString:@"answer"]){
            
            RTCSessionDescription *remoteDesc = [[RTCSessionDescription alloc] initWithType:@"answer" sdp:message.content];
            [_peerConnection setRemoteDescriptionWithDelegate:self sessionDescription:remoteDesc];
            
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
        }else if ([message.subtype isEqualToString:@"close"]){
            [self handleRemoteHangup];
        }
    }
}

- (void)handleRemoteHangup{
    [_peerConnection close];
    
    //TODO play busy tone
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (IBAction)hangupButtonPressed:(id)sender{
    [self sendCloseSignal];
    
    if (_peerConnection) {
        [_peerConnection close];
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
