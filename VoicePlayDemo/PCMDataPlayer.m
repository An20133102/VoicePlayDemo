//
//  PCMDataPlayer.m
//  VoicePlayDemo
//
//  Created by 小龙 on 2018/11/20.
//  Copyright © 2018年 L. All rights reserved.
//

#import "PCMDataPlayer.h"

#define MIN_SIZE_PER_FRAME 5000   //每个包的大小,室内机要求为960,具体看下面的配置信息
#define QUEUE_BUFFER_SIZE  3      //缓冲器个数
#define SAMPLE_RATE        16000 //采样频率

@interface PCMDataPlayer() {
    AudioQueueRef audioQueue;                                 //音频播放队列
    AudioStreamBasicDescription _audioDescription;
    AudioQueueBufferRef audioQueueBuffers[QUEUE_BUFFER_SIZE]; //音频缓存
    BOOL audioQueueBufferUsed[QUEUE_BUFFER_SIZE];             //判断音频缓存是否在使用
    NSLock *sysnLock;
    NSMutableData *tempData;
    OSStatus osState;
}
@end
@implementation PCMDataPlayer
+ (instancetype)sharePlayer{
    static dispatch_once_t onceToken;
    static id shareInstance;
    dispatch_once(&onceToken, ^{
        shareInstance = [[self alloc] init];
    });
    return shareInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        sysnLock = [[NSLock alloc]init];
        //设置音频参数 具体的信息需要问后台
        _audioDescription.mSampleRate = SAMPLE_RATE;
        _audioDescription.mFormatID = kAudioFormatLinearPCM;
        // 下面这个是保存音频数据的方式的说明，如可以根据大端字节序或小端字节序，浮点数或整数以及不同体位去保存数据
        _audioDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        //1单声道 2双声道
        _audioDescription.mChannelsPerFrame = 1;
        //每一个packet一侦数据,每个数据包下的桢数，即每个数据包里面有多少桢
        _audioDescription.mFramesPerPacket = 1;
        //每个采样点16bit量化 语音每采样点占用位数
        _audioDescription.mBitsPerChannel = 16;
        _audioDescription.mBytesPerFrame = (_audioDescription.mBitsPerChannel / 8) * _audioDescription.mChannelsPerFrame;
        //每个数据包的bytes总数，每桢的bytes数*每个数据包的桢数
        _audioDescription.mBytesPerPacket = _audioDescription.mBytesPerFrame * _audioDescription.mFramesPerPacket;
        // 使用player的内部线程播放 新建输出
        AudioQueueNewOutput(&_audioDescription, AudioPlayerAQInputCallback, (__bridge void * _Nullable)(self), nil, 0, 0, &audioQueue);
        // 设置音量
        AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, 1.0);
        // 初始化需要的缓冲区
        for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
            audioQueueBufferUsed[i] = false;
            osState = AudioQueueAllocateBuffer(audioQueue, MIN_SIZE_PER_FRAME, &audioQueueBuffers[i]);
            printf("第 %d 个AudioQueueAllocateBuffer 初始化结果 %d (0表示成功)", i + 1, osState);
        }
        osState = AudioQueueStart(audioQueue, NULL);
        if (osState != noErr) {
            NSLog(@"AudioQueueStart Error");
        }
    }
    return self;
}

- (void)resetPlay {
    if (audioQueue != nil) {
        AudioQueueReset(audioQueue);
    }
}

// 播放相关
-(void)playWithData:(NSData *)data {
    
    [sysnLock lock];
    tempData = [NSMutableData new];
    [tempData appendData: data];
    // 得到数据
    NSUInteger len = tempData.length;
    Byte *bytes = (Byte*)malloc(len);
    [tempData getBytes:bytes length: len];
    
    int i = 0;
    while (true) {
        if (!audioQueueBufferUsed[i]) {
            audioQueueBufferUsed[i] = true;
            break;
        }else {
            i++;
            if (i >= QUEUE_BUFFER_SIZE) {
                i = 0;
            }
        }
    }
    
    audioQueueBuffers[i] -> mAudioDataByteSize =  (unsigned int)len;
    // 把bytes的头地址开始的len字节给mAudioData
    memcpy(audioQueueBuffers[i] -> mAudioData, bytes, len);
    
    //
    if (bytes) {
        free(bytes);
    }
    
    AudioQueueEnqueueBuffer(audioQueue, audioQueueBuffers[i], 0, NULL);
    
    printf("本次播放数据大小: %lu", len);
    [sysnLock unlock];
}

// ************************** 回调 **********************************

// 回调回来把buffer状态设为未使用
static void AudioPlayerAQInputCallback(void* inUserData,AudioQueueRef audioQueueRef, AudioQueueBufferRef audioQueueBufferRef) {
    
    PCMDataPlayer* player = (__bridge PCMDataPlayer*)inUserData;
    
    [player resetBufferState:audioQueueRef and:audioQueueBufferRef];
}

- (void)resetBufferState:(AudioQueueRef)audioQueueRef and:(AudioQueueBufferRef)audioQueueBufferRef {
    
    for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
        // 将这个buffer设为未使用
        if (audioQueueBufferRef == audioQueueBuffers[i]) {
            audioQueueBufferUsed[i] = false;
        }
    }
}

// ************************** 内存回收 **********************************

- (void)dealloc {
    
    if (audioQueue != nil) {
        AudioQueueStop(audioQueue,true);
    }
    
    audioQueue = nil;
    sysnLock = nil;
}

@end
