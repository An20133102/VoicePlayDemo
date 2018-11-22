//
//  PCMFilePlayer.h
//  VoicePlayDemo
//
//  Created by 小龙 on 2018/11/20.
//  Copyright © 2018年 L. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface PCMFilePlayer : NSObject
+ (instancetype)sharePlayer;
- (void)player;
-(void)AudioQueueStop;
-(void)AudioQueuePause;
@end

NS_ASSUME_NONNULL_END
