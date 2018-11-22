//
//  PCMDataPlayer.h
//  VoicePlayDemo
//
//  Created by 小龙 on 2018/11/20.
//  Copyright © 2018年 L. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface PCMDataPlayer : NSObject

+ (instancetype)sharePlayer;

// 播放并顺带附上数据
- (void)playWithData: (NSData *)data;

// 声音播放出现问题的时候可以重置一下
- (void)resetPlay;

@end

NS_ASSUME_NONNULL_END
