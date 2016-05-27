//
//  ViewController.m
//  Chatchat
//
//  Created by wangruihit@gmail.com on 5/26/16.
//  Copyright © 2016 Beta.Inc. All rights reserved.
//

#import "ViewController.h"
#import "Chatchat-Swift.h"
#import "constants.h"

@interface ViewController () <UITextFieldDelegate, UITextViewDelegate>
{
    SocketIOClient *_sio;
    UITextField *_activeField;
}

@property (strong) IBOutlet UITextField *textField;
@property (strong) IBOutlet UITextView *textView;
@property (strong) IBOutlet UIScrollView *scrollView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self setupSocketio];
    _activeField = self.textField;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
}


- (void)setupSocketio{
    NSURL *url = [NSURL URLWithString:kServerURL];
    _sio = [[SocketIOClient alloc] initWithSocketURL:url options:@{@"voipEnabled" : @YES,
                                                                   @"log": @YES,
                                                                   @"forceWebsockets" : @YES,
//                                                                   @"secure" : @YES,
                                                                   @"forcePolling": @YES}];
    [_sio on:@"connect" callback:^(NSArray * _Nonnull data, SocketAckEmitter * _Nonnull ack) {
        NSLog(@"connected");
    }];
    
    [_sio on:@"chat message" callback:^(NSArray * _Nonnull data, SocketAckEmitter * _Nonnull ack) {
        NSLog(@"message received : %@", data);
        [self handleNewMessage:[data lastObject]];
    }];
    
    [_sio connect];
    
}

- (void)handleNewMessage : (NSString *)message{
    self.textView.text = [self.textView.text stringByAppendingFormat:@"\n%@", message];
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        [self showLocalNotification : message];
    }
}

-(void)showLocalNotification : (NSString *)message {
    NSLog(@"showLocalNotification");
    
    UILocalNotification *notification = [[UILocalNotification alloc] init];
//    notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:7];
    notification.alertBody = message;
    notification.timeZone = [NSTimeZone defaultTimeZone];
    notification.soundName = UILocalNotificationDefaultSoundName;
    notification.applicationIconBadgeNumber = [UIApplication sharedApplication].applicationIconBadgeNumber + 1;
    
    [[UIApplication sharedApplication] scheduleLocalNotification:notification];
}

- (void)sendMessage : (NSString *)message{
    [_sio emit:@"chat message" withItems:@[message]];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField{
    [self sendMessage:textField.text];
    //    self._textView.text = [self._textView.text stringByAppendingFormat:@"\n%@", textField.text];
    
    textField.text = nil;
}

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
    
    // If active text field is hidden by keyboard, scroll it so it's visible
    // Your app might not need or want this behavior.
    CGRect aRect = self.view.frame;
    aRect.size.height -= kbSize.height;
    if (!CGRectContainsPoint(aRect, _activeField.frame.origin) ) {
        [self.scrollView scrollRectToVisible:_activeField.frame animated:YES];
    }
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
}

@end
