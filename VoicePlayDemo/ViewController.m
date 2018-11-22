//
//  ViewController.m
//  VoicePlayDemo
//
//  Created by 小龙 on 2018/11/20.
//  Copyright © 2018年 L. All rights reserved.
//

#import "ViewController.h"
#import "PCMDataPlayer.h"
#import "PCMFilePlayer.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIButton *btn=[[UIButton alloc] initWithFrame:CGRectMake(0, 150, self.view.frame.size.width, 40)];
    [self.view addSubview:btn];
    [btn setTitle:@"播放本地PCM文件" forState:UIControlStateNormal];
    btn.backgroundColor=[UIColor grayColor];
    [btn addTarget:self action:@selector(playFile) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *btn2=[[UIButton alloc] initWithFrame:CGRectMake(0, 220, self.view.frame.size.width, 40)];
    [self.view addSubview:btn2];
    btn2.backgroundColor=[UIColor grayColor];
    [btn2 setTitle:@"播放后台传来的PCM流" forState:UIControlStateNormal];
    [btn2 addTarget:self action:@selector(playStreamData) forControlEvents:UIControlEventTouchUpInside];
    
}

//播放本地文件
-(void)playFile{
    
    [[PCMFilePlayer sharePlayer] player];
    
}

//播放后台传来的声音流
-(void)playStreamData{
    //如果后台传过来数据，只需要一句    [[PCMDataPlayer sharePlayer] playWithData:subData];就可以正常播放
    NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle]pathForResource:@"16k" ofType:@"pcm"]];
    NSData *data = [[NSData alloc] initWithContentsOfURL:url];
    NSMutableData *mData=[[NSMutableData alloc] initWithData:data];
    NSInteger tem=5000;
    NSInteger count=mData.length/tem+1;
    for (int i=0; i<count; i++) {
        NSData *subData ;
        if (i==count-1) {
            subData  =[mData subdataWithRange:NSMakeRange(i*tem, mData.length-i*tem)];
        }else{
            subData  =[mData subdataWithRange:NSMakeRange(i*tem, tem)];
        }
        NSLog(@"数据i------：%d",i);
        [[PCMDataPlayer sharePlayer] playWithData:subData];
    }
    
}
@end
