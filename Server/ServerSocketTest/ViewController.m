//
//  ViewController.m
//  ServerSocketTest
//
//  Created by Alfred Yu on 2018/4/24.
//  Copyright © 2018年 Alfred Yu. All rights reserved.
//

#import <CFNetWork/CFNetWork.h>
#import <arpa/inet.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <netdb.h>
#import "ViewController.h"

@interface ViewController ()

@property (assign, nonatomic) CFSocketRef m_server;
@property (assign, nonatomic) NSInteger m_nServerPort;
@property (assign, nonatomic) CFMutableDictionaryRef m_inComingRequest;
@property (strong, nonatomic) NSFileHandle *m_listeningHandle;

@end

@implementation ViewController

-(instancetype) init
{
    self.m_nServerPort = 5566;
    return [super init];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.m_txtView_console setText:@""];
    [self.m_btn_sned addTarget:self
                        action:@selector(onButtonClick:)
              forControlEvents:UIControlEventTouchUpInside];
    
    [self connectStart];
}

-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.view setNeedsLayout];
}

- (void)clientHandleClose:(NSFileHandle *)incomingFileHandle close:(BOOL)closeFileHandle
{
    [self consoleAppendMessage:@"socket close"];
    if (closeFileHandle)
    {
        [incomingFileHandle closeFile];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleDataAvailableNotification object:incomingFileHandle];
    CFDictionaryRemoveValue(self.m_inComingRequest, incomingFileHandle);
}

- (void)clientDataReceiveNotification:(NSNotification *)notification
{
    NSFileHandle *incomingFileHandle = [notification object];
    NSData *data = [incomingFileHandle availableData];
    
    if ([data length] == 0)
    {
        [self clientHandleClose:incomingFileHandle close:NO];
        return;
    }
    NSString *formatedData = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    NSString *newString = [formatedData substringToIndex:[formatedData length]-1];
    NSString *str = [NSString stringWithFormat:@"received message: %@", newString];
    [self consoleAppendMessage:str];
    [formatedData release];
    
    [self clientHandleClose:incomingFileHandle close:NO];
}

- (void)clientAcceptNotification:(NSNotification *)notification
{
    [self consoleAppendMessage:@"Client connected!"];
    
    NSDictionary *userInfo = [notification userInfo];
    NSFileHandle *incomingFileHandle = [userInfo objectForKey:NSFileHandleNotificationFileHandleItem];
    
    if(incomingFileHandle)
    {
        CFDictionaryAddValue(self.m_inComingRequest, incomingFileHandle, [(id)CFHTTPMessageCreateEmpty(kCFAllocatorDefault, TRUE) autorelease]);
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clientDataReceiveNotification:) name:NSFileHandleDataAvailableNotification object:incomingFileHandle];
        [incomingFileHandle waitForDataInBackgroundAndNotify];
    }
    
    [self.m_listeningHandle acceptConnectionInBackgroundAndNotify];
}

- (void) connectStart
{
    int socketSetupContinue = 1;
    struct sockaddr_in addr;
    
    if( !(self.m_server = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM,IPPROTO_TCP, 0, NULL, NULL) ) )
    {
        [self consoleAppendMessage:@"CFSocketCreate failed"];
        socketSetupContinue = 0;
    }
    
    if( socketSetupContinue )
    {
        int yes = 1;
        if( setsockopt(CFSocketGetNative(self.m_server), SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(int)) )
        {
            [self consoleAppendMessage:@"setsockopt failed"];
            CFRelease(self.m_server);
            socketSetupContinue = 0;
        }
    }
    
    if( socketSetupContinue )
    {
        memset(&addr, 0, sizeof(addr));
        addr.sin_len = sizeof(struct sockaddr_in);
        addr.sin_family = AF_INET;
        addr.sin_port = htons(self.m_nServerPort);
        addr.sin_addr.s_addr = htonl(INADDR_ANY);
        
        NSData *address = [NSData dataWithBytes:&addr length:sizeof(addr)];
        if (CFSocketSetAddress(self.m_server, (CFDataRef)address) != kCFSocketSuccess)
        {
            NSLog(@"CFSocketSetAddress failed");
            CFRelease(self.m_server);
            socketSetupContinue =0;
        }
    }
    
    if( socketSetupContinue )
    {
        self.m_inComingRequest = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        
        self.m_listeningHandle = [[NSFileHandle alloc] initWithFileDescriptor:CFSocketGetNative(self.m_server)
                                                               closeOnDealloc:YES];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clientAcceptNotification:)
                                                     name:NSFileHandleConnectionAcceptedNotification object:nil];
        
        [self.m_listeningHandle acceptConnectionInBackgroundAndNotify];
        
        [self consoleAppendMessage:[NSString stringWithFormat:@"Socket listening on %s:%ld", addr2ascii(AF_INET, &(addr.sin_addr.s_addr),sizeof(addr.sin_addr.s_addr),NULL), self.m_nServerPort]];
    }
}

-(void) consoleAppendMessage:(NSString*)strMessage
{
    NSString *str = [NSString stringWithFormat:@"%@\n%@", self.m_txtView_console.text, strMessage];
    [self.m_txtView_console setText:str];
}

-(void) onButtonClick:(UIButton*)sender
{
    NSString *str = @"ttttttttaaaaaa";
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    send(CFSocketGetNative(self.m_server), data, [data length]+1, 0);
    
    CFReadStreamRef readStreamRef  = NULL;
    CFWriteStreamRef writeStreamRef = NULL;
    
    // ----创建一个和Socket对象相关联的读取数据流
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, //内存分配器
                                 CFSocketGetNative(self.m_server), //准备使用输入输出流的socket
                                 &readStreamRef, //输入流
                                 &writeStreamRef);//输出流
    
    CFWriteStreamWrite(writeStreamRef, (UInt8 *)str, [data length]+1);
}

@end
