//
//  CommonDefines.h
//  Chatchat
//
//  Created by WangRui on 16/6/1.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#ifndef CommonDefines_h
#define CommonDefines_h

#import <Foundation/Foundation.h>
#import "User.h"
#import "Message.h"

@protocol SocketIODelegate <NSObject>
- (void)sendMessage : (Message *)message;
@end

#endif /* CommonDefines_h */
