//
//  OutgoingViewController.h
//  Chatchat
//
//  Created by WangRui on 16/7/11.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import "CallViewController.h"

@interface OutgoingViewController : CallViewController

- (RTCMediaConstraints *)defaultOfferConstraints;

@end
