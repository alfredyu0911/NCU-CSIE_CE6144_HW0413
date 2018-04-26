//
//  MainVC.h
//  ServerSocketTest
//
//  Created by Alfred Yu on 2018/4/24.
//  Copyright © 2018年 Alfred Yu. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MainVC : UIViewController

@property (retain, nonatomic) IBOutlet UIButton *m_btn_connect;
@property (retain, nonatomic) IBOutlet UIButton *m_btn_disConnect;
@property (retain, nonatomic) IBOutlet UIButton *m_btn_send;
@property (retain, nonatomic) IBOutlet UIButton *m_btn_clear;
@property (retain, nonatomic) IBOutlet UITextView *m_txtView_IP;
@property (retain, nonatomic) IBOutlet UITextView *m_txtView_output;
@property (retain, nonatomic) IBOutlet UITextView *m_txtView_input;

void TCPServerAcceptCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info);
void readStream(CFReadStreamRef stream,CFStreamEventType eventType, void *clientCallBackInfo);
void writeStream(CFWriteStreamRef stream, CFStreamEventType eventType, void *clientCallBackInfo);

@end
