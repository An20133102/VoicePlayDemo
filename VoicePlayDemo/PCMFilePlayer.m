//
//  PCMFilePlayer.m
//  VoicePlayDemo
//
//  Created by 小龙 on 2018/11/20.
//  Copyright © 2018年 L. All rights reserved.
//

#import "PCMFilePlayer.h"

#define QUEUE_BUFFER_SIZE 4         //队列缓冲个数
#define EVERY_READ_LENGTH 1024        //每次从文件读取的长度
#define MIN_SIZE_PER_FRAME  1024       //每侦最小数据长度

@interface PCMFilePlayer (){
    AudioStreamBasicDescription audioDescription;             //音频参数
    AudioQueueRef audioQueue;                                 //音频播放队列
    AudioQueueBufferRef audioQueueBuffers[QUEUE_BUFFER_SIZE]; //音频缓存
    NSLock *synlock ;                                         //同步控制
    Byte *pcmDataBuffer;                                      //pcm的读文件数据区
    FILE *file;                                               //pcm源文件
    BOOL isStaring;
}
@end
@implementation PCMFilePlayer

+ (instancetype)sharePlayer{
    static dispatch_once_t onceToken;
    static id shareInstance;
    dispatch_once(&onceToken, ^{
        shareInstance = [[self alloc] init];
    });
    return shareInstance;
}

// 初始化播放器
- (void)player{
    
    NSString *filePath =[ [NSBundle mainBundle]pathForResource:@"16k" ofType:@"pcm"];
    NSLog(@"filepath = %@",filePath);
    file = fopen([filePath UTF8String],"r");
    if (file) {
        fseek(file, 0, SEEK_SET);
        pcmDataBuffer = malloc(EVERY_READ_LENGTH);
    }else{
        NSLog(@"!!!!!!!!!!!!!!!!");
    }
    synlock = [[NSLock alloc] init];
    [self initAudio];
    AudioQueueStart(audioQueue, NULL);
    for(int i=0;i<QUEUE_BUFFER_SIZE;i++)
    {
        [self readPCMAndPlay:audioQueue buffer:audioQueueBuffers[i]];
    }
    /*
     audioQueue使用的是驱动回调方式，即通过AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);传入一个buff去播放，播放完buffer区后通过回调通知用户,
     用户得到通知后再重新初始化buff去播放，周而复始,当然，可以使用多个buff提高效率(测试发现使用单个buff会小卡)
     */
}

// 开始
-(void)AudioQueueStart
{
    AudioQueueStart(audioQueue, NULL);
    NSLog(@"onbutton2clicked");
}

// 结束
-(void)AudioQueueStop{
    AudioQueueStop(audioQueue, YES);
}

// 暂停
-(void)AudioQueuePause
{
    AudioQueuePause(audioQueue);
    NSLog(@"onbutton2clicked");
}

#pragma mark player call back
/*
 试了下其实可以不用静态函数，但是c写法的函数内是无法调用[self ***]这种格式的写法，所以还是用静态函数通过void *input来获取原类指针
 这个回调存在的意义是为了重用缓冲buffer区，当通过AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);函数放入queue里面的音频文件播放完以后，通过这个函数通知
 调用者，这样可以重新再使用回调传回的AudioQueueBufferRef
 */
static void AudioPlayerAQInputCallback(void *input, AudioQueueRef outQ, AudioQueueBufferRef outQB)
{
    NSLog(@"AudioPlayerAQInputCallback");
    PCMFilePlayer*play = (__bridge PCMFilePlayer *)input;
    [play checkUsedQueueBuffer:outQB];
    [play readPCMAndPlay:outQ buffer:outQB];
}


#pragma mark - 录音播放
-(void)initAudio
{
    ///设置音频参数
    audioDescription.mSampleRate = 16000;//采样率(每秒钟采集多少个信号样本)
    audioDescription.mFormatID = kAudioFormatLinearPCM;
    audioDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioDescription.mChannelsPerFrame = 1;///单声道
    audioDescription.mFramesPerPacket = 1;//每一个packet一侦数据
    audioDescription.mBitsPerChannel = 16;//每个采样点16bit量化
    audioDescription.mBytesPerFrame = (audioDescription.mBitsPerChannel/8) * audioDescription.mChannelsPerFrame;
    
    audioDescription.mBytesPerPacket = audioDescription.mBytesPerFrame ;
    ///创建一个新的从audioqueue到硬件层的通道
    
    // AudioQueueNewOutput(&audioDescription, AudioPlayerAQInputCallback, (__bridge void * )self, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &audioQueue);///使用当前线程播
    // 使用player的内部线程播放 新建输出
    AudioQueueNewOutput(&audioDescription, AudioPlayerAQInputCallback, (__bridge void * _Nullable)(self), nil, nil, 0, &audioQueue);//使用player的内部线程播
    
    // 设置音量
    AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, 1.0);
    ////添加buffer区，初始化需要的缓冲区
    for(int i=0;i<QUEUE_BUFFER_SIZE;i++)
    {
        int result =  AudioQueueAllocateBuffer(audioQueue, MIN_SIZE_PER_FRAME, &audioQueueBuffers[i]);///创建buffer区，MIN_SIZE_PER_FRAME为每一侦所需要的最小的大小，该大小应该比每次往buffer里写的最大的一次还大
        NSLog(@"AudioQueueAllocateBuffer i = %d,result = %d",i,result);
    }
}

-(void)readPCMAndPlay:(AudioQueueRef)outQ buffer:(AudioQueueBufferRef)outQB
{
    [synlock lock];
    int readLength = fread(pcmDataBuffer, 1, EVERY_READ_LENGTH, file);//读取文件
    if (readLength == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            //　　这里可以进行一些UI控件的刷新操作
        });
    }
    NSLog(@"read raw data size = %d",readLength);
    outQB->mAudioDataByteSize = readLength;
    Byte *audiodata = (Byte *)outQB->mAudioData;
    for(int i=0;i<readLength;i++)
    {
        audiodata[i] = pcmDataBuffer[i];
    }
    /*
     将创建的buffer区添加到audioqueue里播放
     AudioQueueBufferRef用来缓存待播放的数据区，AudioQueueBufferRef有两个比较重要的参数，AudioQueueBufferRef->mAudioDataByteSize用来指示数据区大小，AudioQueueBufferRef->mAudioData用来保存数据区
     */
    AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);
    [synlock unlock];
}

-(void)checkUsedQueueBuffer:(AudioQueueBufferRef) qbuf
{
    if(qbuf == audioQueueBuffers[0])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 0");
    }
    if(qbuf == audioQueueBuffers[1])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 1");
    }
    if(qbuf == audioQueueBuffers[2])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 2");
    }
    if(qbuf == audioQueueBuffers[3])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 3");
    }
}

@end
