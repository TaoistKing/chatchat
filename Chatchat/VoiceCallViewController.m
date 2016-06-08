//
//  VoiceCallViewController.m
//  Chatchat
//
//  Created by WangRui on 16/6/7.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

#import "VoiceCallViewController.h"

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


@interface VoiceCallViewController () <RTCPeerConnectionDelegate, RTCSessionDescriptionDelegate>
{
    RTCPeerConnection *_peerConnection;
}
@end

@implementation VoiceCallViewController

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
    
    [_peerConnection addStream:localStream];

    NSArray *mandatoryConstraints = @[
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"],
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:@"false"]
                                      ];
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints: mandatoryConstraints
                                                                             optionalConstraints: nil];
    
    [_peerConnection createOfferWithDelegate:self constraints:constraints];
}

#pragma mark -- RTCSessionDescriptionDelegate --
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didCreateSessionDescription:(RTCSessionDescription *)sdp error:(NSError *)error
{
    NSLog(@"got local sdp: %@", sdp);
    
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
    NSLog(@"Ice changed: %d", newState);
}

// Called any time the ICEGatheringState changes.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
   iceGatheringChanged:(RTCICEGatheringState)newState{
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
       gotICECandidate:(RTCICECandidate *)candidate{
    NSLog(@"got candidate: %@", candidate);
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
                RTCICECandidate *candidate = [RTCICECandidate candidateFromJSONDictionary:dic];
                [_peerConnection addICECandidate:candidate];
            }
        }
    }
}

@end
