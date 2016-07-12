//
//  IncomingCallViewController.h
//  Chatchat
//
//  Created by WangRui on 16/6/8.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "CommonDefines.h"
#import "CallViewController.h"

@interface IncomingCallViewController : CallViewController <MessageReciver>

@property (strong) Message *offer;
@property (strong) NSArray<Message *> *pendingMessages;

@end
