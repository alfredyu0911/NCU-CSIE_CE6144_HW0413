//
//  MainVC.m
//  ServerSocketTest
//
//  Created by Alfred Yu on 2018/4/24.
//  Copyright © 2018年 Alfred Yu. All rights reserved.
//

#include <CoreFoundation/CoreFoundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#import "MainVC.h"

CFWriteStreamRef m_cfWriteStream;

#define Notification_Normal @"NOTI_MAINVC"
#define Notification_ClientOffLine @"NOTI_MAINVC_DISCONNECT"

@interface MainVC ()

@property (assign, nonatomic) CFSocketRef m_serverSocket;
@property (retain, nonatomic) NSInputStream *m_inputStream;
@property (retain, nonatomic) NSOutputStream *m_outputStream;

@end

@implementation MainVC

#pragma mark - View Life Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.m_btn_connect addTarget:self action:@selector(onButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.m_btn_disConnect addTarget:self action:@selector(onButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.m_btn_send addTarget:self action:@selector(onButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.m_btn_clear addTarget:self action:@selector(onButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(viewRefreshNotification:)
                                                 name:Notification_Normal
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(viewRefreshNotification:)
                                                 name:Notification_ClientOffLine
                                               object:nil];
    
    [self.m_btn_connect setEnabled:NO];
    [self.m_btn_disConnect setEnabled:NO];
    [self.m_txtView_IP setEditable:NO];
    [self.m_txtView_output setEditable:NO];
}

-(void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ( YES == [self serverInit] )
    {
        [self.m_txtView_output setText:@"Srevice open, start listening on port 5050"];
    }
}

-(void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

-(void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:Notification_Normal
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:Notification_ClientOffLine
                                                  object:nil];
}

#pragma mark - Button event, notification

-(void) onButtonClick:(UIButton*)btn
{
    if ( btn == self.m_btn_connect )
    {
        
    }
    else if ( btn == self.m_btn_disConnect )
    {
        
    }
    else if ( btn == self.m_btn_clear )
    {
        [self.m_txtView_output setText:@""];
    }
    else if ( btn == self.m_btn_send )
    {
        NSString *str = [NSString stringWithFormat:@"%@\n", self.m_txtView_input.text];
        NSData *data = [[NSData alloc] initWithData:[str dataUsingEncoding:NSASCIIStringEncoding]];
        CFWriteStreamWrite(m_cfWriteStream, [data bytes], [data length]);
        [self.m_txtView_input setText:@""];
    }
}

- (void) viewRefreshNotification:(NSNotification *) notification
{
    if ( [notification.name isEqualToString:Notification_Normal] )
    {
        NSString *str = notification.object;
        [self textView:self.m_txtView_output appendMessage:str];
    }
    else if ( [notification.name isEqualToString:Notification_ClientOffLine] )
    {
        [self textView:self.m_txtView_output appendMessage:@"Client is Disconnected"];
    }
}

#pragma mark - Private

-(void) textView:(UITextView*)txtView appendMessage:(NSString*)strMessage
{
    NSString *strOutput;
    if ( NO == [txtView.text hasSuffix:@"\n"] )
    {
        strOutput = [NSString stringWithFormat:@"%@\n%@", txtView.text, strMessage];
    }
    else
    {
        strOutput = [NSString stringWithFormat:@"%@%@", txtView.text, strMessage];
    }
    
    [txtView setText:strOutput];
}

#pragma mark - Net Work

-(BOOL) serverInit
{
    self.m_serverSocket = CFSocketCreate(kCFAllocatorDefault,
                                         PF_INET,
                                         SOCK_STREAM,IPPROTO_TCP,
                                         kCFSocketAcceptCallBack,
                                         TCPServerAcceptCallBack,
                                         NULL);
    
     if ( NULL == self.m_serverSocket )
         return NO;
    
    int optval = 1;
    setsockopt(CFSocketGetNative(self.m_serverSocket),
               SOL_SOCKET,
               SO_REUSEADDR,
               (void *)&optval,
               sizeof(optval));
    
    struct sockaddr_in addr4;
    memset(&addr4, 0, sizeof(addr4));
    
    addr4.sin_len = sizeof(addr4);
    addr4.sin_family = AF_INET;
    addr4.sin_port = htons(5050);
    addr4.sin_addr.s_addr = htonl(INADDR_ANY);
    CFDataRef address = CFDataCreate(kCFAllocatorDefault, (UInt8*)&addr4, sizeof(addr4));
    
    if ( kCFSocketSuccess != CFSocketSetAddress(self.m_serverSocket, address) )
    {
        if ( self.m_serverSocket != NULL )
            CFRelease(self.m_serverSocket);
        
        return NO;
    }
    
    CFRunLoopRef cfRunLoop = CFRunLoopGetCurrent();
    CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, self.m_serverSocket, 0);
    CFRunLoopAddSource(cfRunLoop, source, kCFRunLoopCommonModes);
    CFRelease(source);
    
    return YES;
}

void TCPServerAcceptCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info)
{
    if ( kCFSocketAcceptCallBack == type )
    {
        CFSocketNativeHandle nativeSocketHandle = *(CFSocketNativeHandle *)data;
        uint8_t name[SOCK_MAXADDRLEN];
        socklen_t nameLen = sizeof(name);
        
        if ( 0 != getpeername(nativeSocketHandle, (struct sockaddr *)name, &nameLen) )
        {
            NSLog(@"error");
            return;
        }
        
        NSLog(@"connect!");
        [[NSNotificationCenter defaultCenter] postNotificationName:Notification_Normal
                                                            object:@"Client is connected\n"];
        
        CFReadStreamRef iStream;
        
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocketHandle, &iStream, &m_cfWriteStream);
        if ( iStream && m_cfWriteStream )
        {
            CFStreamClientContext streamContext = {0, NULL, NULL, NULL};
            if ( !CFReadStreamSetClient(iStream, kCFStreamEventHasBytesAvailable, readStream, &streamContext) )
                return;
            
            if ( !CFWriteStreamSetClient(m_cfWriteStream, kCFStreamEventCanAcceptBytes, writeStream, &streamContext) )
                return;
            
            CFReadStreamScheduleWithRunLoop(iStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
            CFWriteStreamScheduleWithRunLoop(m_cfWriteStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
            
            CFReadStreamOpen(iStream);
            CFWriteStreamOpen(m_cfWriteStream);
        }
        else
        {
            close(nativeSocketHandle);
        }
    }
}

void readStream(CFReadStreamRef stream,CFStreamEventType eventType, void *clientCallBackInfo)
{
    UInt8 buff[255];
    CFReadStreamRead(stream, buff, 255);
    NSString *strReceive = [NSString stringWithFormat:@"%s", buff];
    NSString *str = [NSString stringWithFormat:@"received data from client: %@", strReceive];
    
    if ( eventType == kCFStreamEventHasBytesAvailable )
    {
        if ( [strReceive isEqualToString:@""] )
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:Notification_ClientOffLine
                                                                object:nil];
        }
        else
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:Notification_Normal
                                                                object:str];
        }
    }
}

void writeStream(CFWriteStreamRef stream, CFStreamEventType eventType, void *clientCallBackInfo)
{
    NSLog(@"writeStream call back");
    m_cfWriteStream = stream;
}

@end
