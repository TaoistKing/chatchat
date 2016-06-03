//
//  ContactsTableViewController.m
//  Chatchat
//
//  Created by WangRui on 16/5/31.
//  Copyright © 2016年 Beta.Inc. All rights reserved.
//

#import "ContactsTableViewController.h"
#import "Chatchat-Swift.h"
#import "ChatViewController.h"
#import "CommonDefines.h"
#import "ChatSessionManager.h"
#import "UserManager.h"

@interface ContactsTableViewController () <UISearchControllerDelegate,
UISearchResultsUpdating, SocketIODelegate>
{
    SocketIOClient *_sio;
    NSString *_hostAddr;
    UISearchController *_searchController;
    BOOL _serverConnected;
    NSTimer *_connectionTimer;
    
    ChatSessionManager *_sessionManager;
    UserManager *_userManager;
    
    NSMutableDictionary<NSString *, ChatViewController *> *_session_viewcontroller;
}

@property (weak) UITextField *inputTextField;
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
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    /*
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"input your host" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.textAlignment = NSTextAlignmentCenter;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        [textField setKeyboardType:UIKeyboardTypeDecimalPad];
        self.inputTextField = textField;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        _hostAddr = self.inputTextField.text;
        NSLog(@"server addr : %@", _hostAddr);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self setupSocketIO];
        });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
     */
    _hostAddr = @"192.168.127.241";
    [self setupSocketIO];
    
    _connectionTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                        target:self
                                                      selector:@selector(checkConnection)
                                                      userInfo:nil
                                                       repeats:YES];
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
        NSDictionary *dic = @{@"name" : @"iOS Client", @"uuid" : [NSUUID UUID].UUIDString};
        [_sio emit:@"register" withItems:@[dic]];
    }];
    
    [_sio on:@"disconnect" callback:^(NSArray * _Nonnull data, SocketAckEmitter * _Nonnull ack) {
        _serverConnected = NO;
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
        //reload contacts
        [self getOnlineContacts];
    }];
    
    [_sio on:@"user leave" callback:^(NSArray * _Nonnull data, SocketAckEmitter * _Nonnull ack) {
        //reload contacts
        [self getOnlineContacts];
        
        //TODO delete chat session with this user
        [self deleteChatSessionWithUser: [data lastObject]];
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
    NSData *data = [NSJSONSerialization dataWithJSONObject:[message toDictionary]
                                                   options:NSJSONWritingPrettyPrinted error:NULL];
    NSString *messageString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [_sio emit:@"chat message" withItems:@[messageString]];
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

    if (![message.to isEqualToString:[_userManager localUser].uniqueID] &&
        ![message.to isEqualToString:@"all"]) {
        //not my message
        return;
    }
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        [self showLocalNotification : message.content];
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
    ChatSession *session = [_sessionManager findSessionByPeer:user];
    
    [session onUnreadMessage:message];
    
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        [self markChatCellUnread : session];
    }
}

- (void)markChatCellUnread : (ChatSession *)session{
    UITableViewCell *cell = [self cellForChatSession:session];
    cell.tintColor = [UIColor redColor];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu unread", (unsigned long)[session unreadCount]];
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
    NSString *name = [users objectAtIndex:indexPath.row].name;
    cell.textLabel.text = name;
    cell.detailTextLabel.text = nil;
    
    if ([[users objectAtIndex:indexPath.row].uniqueID isEqualToString: [_userManager localUser].uniqueID]) {
        cell.detailTextLabel.text = @"me";
    }

    return cell;
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
        UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        ChatViewController *cvc = [sb instantiateViewControllerWithIdentifier:@"ChatViewController"];
        cvc.socketIODelegate = self;
        cvc.peer = selectedUser;
        cvc.title = @"Chat";
        [self.navigationController pushViewController:cvc animated:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Voice Chat" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        //Voice chat selected
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Video Chat" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        //Video Chat selected
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
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
