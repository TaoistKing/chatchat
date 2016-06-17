//
//  ContactsTableViewController.m
//  Chatchat
//
//  Created by WangRui on 16/5/31.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import "ContactsTableViewController.h"
#import <SocketIOClientSwift/SocketIOClientSwift-Swift.h>
#import "ChatViewController.h"
#import "CommonDefines.h"
#import "ChatSessionManager.h"
#import "UserManager.h"
#import "VoiceCallViewController.h"
#import "IncomingCallViewController.h"

@interface ContactsTableViewController () <UISearchControllerDelegate,
UISearchResultsUpdating, SocketIODelegate>
{
    SocketIOClient *_sio;
    NSString *_hostAddr;
    UISearchController *_searchController;
    BOOL _serverConnected;
    NSTimer *_connectionTimer;
    UITextField *_inputTextField;
    
    ChatSessionManager *_sessionManager;
    UserManager *_userManager;
    
    NSMutableArray <Message *> *_unReadSignalingMessages;
}

@property (weak) IBOutlet UILabel *footerLabel;
@end

@implementation ContactsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    _serverConnected = false;
    _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    _searchController.searchResultsUpdater = self;
    _searchController.delegate = self;
    self.tableView.tableHeaderView = _searchController.searchBar;
    
    _sessionManager = [ChatSessionManager sharedManager];
    _userManager = [UserManager sharedManager];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)didBecomeActive : (NSNotification *)notification{
    if (_serverConnected) {
        [self.tableView reloadData];
    }
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    if (_serverConnected) {
        [self.tableView reloadData];
    }else{
        
#ifdef TEST
        _hostAddr = @"192.168.127.241";
        [self setupSocketIO];
#else
         UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Input Your Host" message:nil preferredStyle:UIAlertControllerStyleAlert];
         [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
             textField.textAlignment = NSTextAlignmentCenter;
             textField.clearButtonMode = UITextFieldViewModeWhileEditing;
             textField.placeholder = @"e.g. 192.168.1.100";
             [textField setKeyboardType:UIKeyboardTypeDecimalPad];
             _inputTextField = textField;
         }];
         [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
             _hostAddr = _inputTextField.text;
             NSLog(@"server addr : %@", _hostAddr);
             dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                 [self setupSocketIO];
             });
         }]];
         [self presentViewController:alert animated:YES completion:nil];
    }
#endif

    if (!_connectionTimer) {
        _connectionTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                            target:self
                                                          selector:@selector(checkConnection)
                                                          userInfo:nil
                                                           repeats:YES];
    }
}

- (void)checkConnection{
    if (!_serverConnected) {
        [_sio connect];
    }
}

- (void)setupSocketIO{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:3000", _hostAddr]];
    _sio = [[SocketIOClient alloc] initWithSocketURL:url options:@{@"voipEnabled" : @YES,
                                                                   @"log": @NO,
                                                                   @"forceWebsockets" : @YES,
                                                                   //                                                                   @"secure" : @YES,
                                                                   @"forcePolling": @YES}];
    [_sio on:@"connect" callback:^(NSArray * _Nonnull data, SocketAckEmitter * _Nonnull ack) {
        NSLog(@"connected");
        _serverConnected = YES;
        NSString *deviceName = [[UIDevice currentDevice] name];
        NSDictionary *dic = @{@"name" : deviceName, @"uuid" : [UIDevice currentDevice].identifierForVendor.UUIDString};
        [_sio emit:@"register" withItems:@[dic]];
    }];
    
    [_sio on:@"disconnect" callback:^(NSArray * _Nonnull data, SocketAckEmitter * _Nonnull ack) {
        _serverConnected = NO;
        
        [_userManager removeAllUsers];
        [self.tableView reloadData];
    }];
    
    [_sio on:@"register succeed" callback:^(NSArray * _Nonnull data, SocketAckEmitter * _Nonnull ack) {
        //get self back
        NSLog(@"self is %@", data);
        [_userManager setLocalUserWithName:[[data lastObject] objectForKey:@"name"]
                                       UID:[[data lastObject] objectForKey:@"id"]];
        
        [self getOnlineContacts];
    }];

    [_sio on:@"chat message" callback:^(NSArray * _Nonnull data, SocketAckEmitter * _Nonnull ack) {
        NSLog(@"message received : %@", data);
        [self handleNewMessage:[data lastObject]];
    }];
    
    [_sio on:@"new user" callback:^(NSArray * _Nonnull data, SocketAckEmitter * _Nonnull ack) {
        [_userManager addUserWithUID:[[data lastObject] objectForKey:@"id"]
                                name:[[data lastObject] objectForKey:@"name"]];
        
        //reload contacts
        [self getOnlineContacts];
    }];
    
    [_sio on:@"user leave" callback:^(NSArray * _Nonnull data, SocketAckEmitter * _Nonnull ack) {
        //reload contacts
        
        //TODO delete chat session with this user
        if ([data count] > 0) {
            [self deleteChatSessionWithUser: [data lastObject]];
            
            [self getOnlineContacts];
        }
    }];
    
    [_sio connect];
}

- (void)deleteChatSessionWithUser : (id)userDic{
    NSString *uid = [userDic objectForKey:@"id"];
    UIViewController *topVc = self.navigationController.topViewController;
    if ([topVc isKindOfClass:[ChatViewController class]]) {
        //in chat view
        ChatViewController *chatVc = (ChatViewController *)topVc;
        if ([chatVc.peer.uniqueID isEqualToString: uid]) {
            //this is the exact session i'm talking in
            [self.navigationController popViewControllerAnimated:YES];
        }else{
            //i'm in a different chat session
        }
    }else{
        //in contacts view
    }
    
    [_userManager removeUserByUID:uid];
}

- (void)sendMessage : (Message *)message{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    message.time = [formatter stringFromDate:[NSDate date]];;

    [_sio emit:@"chat message" withItems:@[[message toDictionary]]];
}

- (void)handleNewMessage : (id)data{
    NSDictionary *dic;
    if ([data isKindOfClass:[NSDictionary class]]) {
        //data is dic
        dic = data;
    }else if([data isKindOfClass:[NSString class]]){
        //data is string
        dic = [NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding]
                                              options:NSJSONReadingAllowFragments
                                                error:nil];
    }
    
    Message *message = [[Message alloc] init];
    message.from = [dic objectForKey:@"from"];
    message.to = [dic objectForKey:@"to"];
    message.content = [dic objectForKey:@"content"];
    message.time = [dic objectForKey:@"time"];
    message.type = [dic objectForKey:@"type"];
    message.subtype = [dic objectForKey:@"subtype"];
    
    if (![message.to isEqualToString:[_userManager localUser].uniqueID] &&
        ![message.to isEqualToString:@"all"]) {
        //not my message
        return;
    }

    if ([message.type isEqualToString:@"signal"]) {
        [self handleSignalMessage : message];
    }else if([message.type isEqualToString:@"text"]){
        [self handleTextMessage:message];
    }
}

- (void)handleSignalMessage : (Message *)message{
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        if ([message.subtype isEqualToString:@"offer"]) {
            //got offer in background
            [self handleIncomingCallInBackground : message];
        }
    }else{
        if ([message.subtype isEqualToString:@"offer"]) {
            //got offer
            [self presentIncomingCallViewController:message];
        }else if ([message.subtype isEqualToString:@"candidate"] ||
                  [message.subtype isEqualToString:@"answer"] ||
                  [message.subtype isEqualToString:@"close"]){
            //handle candidate when IncomingCallVC is not created yet.
            UIViewController *vc = self.presentedViewController;
            if ([vc isKindOfClass:[IncomingCallViewController class]]) {
                IncomingCallViewController *icvc = (IncomingCallViewController *)vc;
                [icvc onMessage:message];
            }else if([vc isKindOfClass:[VoiceCallViewController class]]){
                VoiceCallViewController *vcvc = (VoiceCallViewController *)vc;
                [vcvc onMessage:message];
            }else{
                //received candidates when calling view not presented
                [_unReadSignalingMessages addObject:message];
            }
        }
    }
}

- (void)handleTextMessage : (Message *)message{
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        [self handleBackgroundMessage: message];
    }else{
        //in chat view controller
        UIViewController *topVc = self.navigationController.topViewController;
        if ([topVc isKindOfClass:[ChatViewController class]]) {
            //in chat view
            ChatViewController *chatVc = (ChatViewController *)topVc;
            if ([chatVc.peer.uniqueID isEqualToString: message.from]) {
                //this is the exact session i'm talking in
                [chatVc onMessage:message];
            }else{
                //i'm in a different chat session
                [self handleUnReadMessage:message];
            }
        }else{
            //in contacts view
            [self handleUnReadMessage:message];
        }
    }
}

- (void)handleUnReadMessage : (Message *)message{
    //TODO update tableview cell status, and store this message to db.
    User *user = [_userManager findUserByUID:message.from];
    ChatSession *session = [_sessionManager createSessionWithPeer:user];

    [session onUnreadMessage:message];
    
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self markChatCellUnread : session];
        });
    }
}

- (void)markChatCellUnread : (ChatSession *)session{
    [self.tableView reloadData];
    
    //why refresh a single cell not working?
    /*
    UITableViewCell *cell = [self cellForChatSession:session];
    cell.tintColor = [UIColor redColor];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu unread", (unsigned long)[session unreadCount]];
//    [cell reloadInputViews];
    [self.tableView beginUpdates];
    [self.tableView reloadRowsAtIndexPaths:@[[self.tableView indexPathForCell:cell]] withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView endUpdates];
     */
}

- (UITableViewCell *)cellForChatSession : (ChatSession *)session{
    User *peer = session.peer;
    NSUInteger index = [[_userManager listUsers] indexOfObject:peer];
    return [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
}

- (void)getOnlineContacts{
    //restful
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:3000/listUsers", _hostAddr]];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url
                                completionHandler:^(NSData * _Nullable data,
                                                    NSURLResponse * _Nullable response,
                                                    NSError * _Nullable error) {
        //jsonlize data
                                    if (error) {
                                        NSLog(@"%@", error);
                                    }else{
                                        NSError *error2 = nil;
                                        NSArray *users = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error2];
                                        if (error2) {
                                            NSLog(@"error jsonserialize : %@", error2);
                                        }
                                        NSLog(@"all users: %@", users);
                                        for (NSDictionary *item in users) {
                                            if ([_userManager findUserByUID:[item objectForKey:@"id"]] == nil) {
                                                [_userManager addUserWithUID:[item objectForKey:@"id"] name:[item objectForKey:@"name"]];
                                            }
                                        }
                                        
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            [self.tableView reloadData];
                                        });
                                        
                                    }
    }];
    
    [task resume];
}

- (void)handleBackgroundMessage : (Message *)message{
    User *user = [_userManager findUserByUID:message.from];
    ChatSession *session = [_sessionManager findSessionByPeer:user];
    [session onUnreadMessage:message];
    
    NSString *notificationString = [NSString stringWithFormat:@"%@:%@", user.name, message.content];
    [self showLocalNotification: notificationString];
}

- (void)handleIncomingCallInBackground : (Message *)message{
    User *user = [_userManager findUserByUID:message.from];

    NSString *notificationString = [NSString stringWithFormat:@"%@ is calling you", user.name];
    [self showLocalNotification: notificationString];
}

- (void)showLocalNotification : (NSString *)message {
    NSLog(@"showLocalNotification");
    
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    //    notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:7];
    notification.alertBody = message;
    notification.timeZone = [NSTimeZone defaultTimeZone];
    notification.soundName = UILocalNotificationDefaultSoundName;
    notification.applicationIconBadgeNumber = [UIApplication sharedApplication].applicationIconBadgeNumber + 1;
    
    [[UIApplication sharedApplication] scheduleLocalNotification:notification];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSUInteger numberUsers = [_userManager numberUsers];
    self.footerLabel.text = [NSString stringWithFormat:@"total %lu users", (unsigned long)numberUsers];
    return numberUsers;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ContactsTableViewCell" forIndexPath:indexPath];
    NSArray<User *> *users = [_userManager listUsers];
    
    // Configure the cell...
    User *user = [users objectAtIndex:indexPath.row];
    NSString *name = user.name;
    cell.textLabel.text = name;
    cell.detailTextLabel.text = nil;
    cell.accessoryView = nil;
    
    if ([[users objectAtIndex:indexPath.row].uniqueID isEqualToString: [_userManager localUser].uniqueID]) {
        cell.detailTextLabel.text = @"me";
    }else{
        ChatSession *session = [_sessionManager createSessionWithPeer:user];
        if (session.unreadCount > 0) {
            NSString *title = [NSString stringWithFormat:@"%lu unread", (unsigned long)[session unreadCount]];
            UIButton *detailButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
            [detailButton setTitle:title forState:UIControlStateNormal];
            [detailButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
            [detailButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentRight];
            [detailButton addTarget:self action:@selector(detailButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
            CGFloat height = [tableView rectForRowAtIndexPath:indexPath].size.height * 0.85;
            CGFloat width = [tableView rectForRowAtIndexPath:indexPath].size.width * 0.4;

            detailButton.frame = CGRectMake(0, 0, width, height);
            detailButton.tag = indexPath.row;
            cell.accessoryView = detailButton;
        }
    }

    return cell;
}

- (void)detailButtonPressed : (id)sender{
    UIButton *button = (UIButton *)sender;
    
    NSLog(@"button in row %ld pressed", (long)button.tag);
    User *selectedUser = [[_userManager listUsers] objectAtIndex:button.tag];

    [self presentChatViewControllerWithPeer:selectedUser];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    //show action sheet
    User *selectedUser = [[_userManager listUsers] objectAtIndex:indexPath.row];
    if ([selectedUser.uniqueID isEqualToString: [_userManager localUser].uniqueID]) {
        //do nothing on click myself
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Select Action" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"Chat" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        //chat selected
        [self presentChatViewControllerWithPeer:selectedUser];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Voice Chat" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        //Voice chat selected
        [self presentVoiceCallViewControllerWithPeer:selectedUser];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Video Chat" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        //Video Chat selected
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentChatViewControllerWithPeer: (User *)user{
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    ChatViewController *cvc = [sb instantiateViewControllerWithIdentifier:@"ChatViewController"];
    cvc.socketIODelegate = self;
    cvc.peer = user;
    cvc.title = @"Chat";
    [self.navigationController pushViewController:cvc animated:YES];
}

- (void)presentVoiceCallViewControllerWithPeer: (User *)user{
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    VoiceCallViewController *vcvc = [sb instantiateViewControllerWithIdentifier:@"VoiceCallViewController"];
    vcvc.socketIODelegate = self;
    vcvc.peer = user;
    
    [self presentViewController:vcvc animated:YES completion:nil];
}

- (void)presentIncomingCallViewController : (Message *)message{
    User *peer = [_userManager findUserByUID:message.from];

    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    IncomingCallViewController *icvc = [sb instantiateViewControllerWithIdentifier:@"IncomingCallViewController"];
    icvc.socketIODelegate = self;
    icvc.peer = peer;
    icvc.offer = message;
    
    [self presentViewController:icvc animated:YES completion:^(void){
        icvc.pendingMessages = _unReadSignalingMessages;
    }];

}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController{
    if (!searchController.active) {
        return;
    }
    
    NSString *searchText = searchController.searchBar.text;
    NSLog(@"search text: %@", searchText);
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
