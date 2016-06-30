//
//  VideoCallViewController.h
//  Chatchat
//
//  Created by WangRui on 16/6/24.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CommonDefines.h"

@interface VideoCallViewController : UIViewController <MessageReciver>

@property (weak) id<SocketIODelegate> socketIODelegate;
@property (weak) User *peer;

@end
