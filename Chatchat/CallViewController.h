//
//  CallViewController.h
//  Chatchat
//
//  Created by WangRui on 16/7/11.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "RTCFileLogger.h"
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
#import "RTCVideoCapturer.h"

#import "constants.h"
#import "CommonDefines.h"

@interface CallViewController : UIViewController <MessageReciver, RTCPeerConnectionDelegate, RTCSessionDescriptionDelegate>

@property (strong, nonatomic) RTCPeerConnectionFactory *factory;
@property (strong, nonatomic) RTCPeerConnection *peerConnection;

@property (strong) id<SocketIODelegate> socketIODelegate;
@property (strong) User *peer;

- (RTCMediaConstraints *)defaultMediaConstraints;
- (RTCMediaConstraints *)defaultVideoConstraints;
- (NSArray *)defaultIceServers;
- (RTCMediaConstraints *)defaultPeerConnectionConstraints;

@end
