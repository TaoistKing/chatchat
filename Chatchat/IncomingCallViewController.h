//
//  IncomingCallViewController.h
//  Chatchat
//
//  Created by WangRui on 16/6/8.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CommonDefines.h"
#import "RTCSessionDescription.h"

@interface IncomingCallViewController : UIViewController <MessageReciver>

@property (weak) id<SocketIODelegate> socketIODelegate;
@property (weak) User *peer;

@property (strong) Message *offer;
@property (strong) NSArray<Message *> *pendingMessages;

@end
