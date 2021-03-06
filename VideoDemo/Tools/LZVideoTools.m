//
//  LZVideoTools.m
//  laziz_Merchant
//
//  Created by biyuhuaping on 2017/3/29.
//  Copyright © 2017年 XBN. All rights reserved.
//

#import "LZVideoTools.h"

@implementation LZVideoTools

/**
 视频压缩+剪切+导出
 
 @param segment 视频资源
 @param filePath 文件路径
 @param completion 完成回调
 */
+ (void)cutVideoWith:(LZSessionSegment *)segment filePath:(NSURL *)filePath completion:(void (^)(void))completion{
    
//    1.将素材拖入到素材库中
    AVAsset *asset = segment.asset;
    AVAssetTrack *videoAssetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];//素材的视频轨
    AVAssetTrack *audioAssetTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];//素材的音频轨
    
    
//    2.将素材的视频插入视频轨，音频插入音频轨
    AVMutableComposition *composition = [[AVMutableComposition alloc] init];//这是工程文件
    AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];//视频轨道
    [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:videoAssetTrack atTime:kCMTimeZero error:nil];//在视频轨道插入一个时间段的视频

    AVMutableCompositionTrack *audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];//音频轨道
    [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:audioAssetTrack atTime:kCMTimeZero error:nil];//插入音频数据，否则没有声音

    
    
//    3.裁剪视频，就是要将所有视频轨进行裁剪，就需要得到所有的视频轨，而得到一个视频轨就需要得到它上面所有的视频素材
    AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    
    CGFloat videoAssetTrackNaturalWidth = videoAssetTrack.naturalSize.width;
    CGFloat videoAssetTrackNaturalHeight = videoAssetTrack.naturalSize.height;
    CGSize renderSize = CGSizeMake(videoAssetTrackNaturalWidth, videoAssetTrackNaturalHeight);
    
    CGFloat renderW = MAX(renderSize.width, renderSize.height);
    CGFloat rate = renderW / MIN(videoAssetTrackNaturalWidth, videoAssetTrackNaturalHeight);
    CGAffineTransform layerTransform = CGAffineTransformMake(videoAssetTrack.preferredTransform.a, videoAssetTrack.preferredTransform.b, videoAssetTrack.preferredTransform.c, videoAssetTrack.preferredTransform.d, videoAssetTrack.preferredTransform.tx * rate, videoAssetTrack.preferredTransform.ty * rate);
    //    layerTransform = CGAffineTransformConcat(layerTransform, CGAffineTransformMake(1, 0, 0, 1, 0, -(videoAssetTrackNaturalWidth - videoAssetTrackNaturalHeight) / 2.0));//zhoubo fix 2017.03.31
    layerTransform = CGAffineTransformScale(layerTransform, rate, rate);
    [layerInstruction setTransform:layerTransform atTime:kCMTimeZero];//得到视频素材

    
//    //设置淡出时间
//    CMTime start = CMTimeMake(composition.duration.value - composition.duration.timescale * 2, composition.duration.timescale);
//    CMTimeRange timeRange = CMTimeRangeFromTimeToTime(start, composition.duration);
//
//    //设置不透明度，从开始不透明
//    [layerInstruction setOpacityRampFromStartOpacity:1 toEndOpacity:0 timeRange:timeRange];
//
//    //设置音频输出参数
//    AVMutableAudioMixInputParameters *parameters = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:audioTrack];
//    [parameters setVolumeRampFromStartVolume:1 toEndVolume:0 timeRange:timeRange];
//    
//    AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
//    audioMix.inputParameters = @[parameters];
    
    
    
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);//得到视频轨道（这里只有一个轨道）
    instruction.layerInstructions = @[layerInstruction];
    
    //整合视频合成的参数
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.instructions = @[instruction];
    videoComposition.frameDuration = CMTimeMake(1, 30);// 30 fps
    videoComposition.renderSize = CGSizeMake(renderW, renderW);//渲染（剪裁）出对应的大小
    
    
//    4.导出
    CMTime start1 = CMTimeMakeWithSeconds(segment.startTime, segment.duration.timescale);
    CMTime duration1 = CMTimeMakeWithSeconds(segment.endTime - segment.startTime, segment.asset.duration.timescale);
    CMTimeRange range = CMTimeRangeMake(start1, duration1);
    
    
    //导出
    AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetHighestQuality];
    session.videoComposition = videoComposition;
//    session.audioMix = audioMix;
    session.outputURL = filePath;
    session.shouldOptimizeForNetworkUse = YES;
    session.outputFileType = AVFileTypeQuickTimeMovie;
    session.timeRange = range;
    [session exportAsynchronouslyWithCompletionHandler:^{
        if ([session status] == AVAssetExportSessionStatusCompleted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion();
                    DLog(@"视频导出成功：%@", [session.outputURL path]);
                }
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion();
                    DLog(@"视频导出失败：%@", [session.outputURL path]);
                }
            });
        }
    }];
}


/**
 导出视频
 
 @param asset 视频资源
 @param filePath 文件路径
 @param range 时长范围
 @param duration 淡出时长
 @param completion 完成回调
 */
+ (void)exportVideo:(AVAsset *)asset filePath:(NSURL *)filePath timeRange:(CMTimeRange)range duration:(Float64)duration completion:(void (^)(NSURL *savedPath))completion {
    AVPlayerItem *item = nil;
    
    if (duration > 0) {
        item = [self videoFadeOut:asset duration:duration];
    }
    //导出
    AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetHighestQuality];
    session.videoComposition = item.videoComposition;
    session.audioMix = item.audioMix;
    session.outputURL = filePath;
    session.shouldOptimizeForNetworkUse = YES;
    session.outputFileType = AVFileTypeQuickTimeMovie;
    session.timeRange = range;
    [session exportAsynchronouslyWithCompletionHandler:^{
        if ([session status] == AVAssetExportSessionStatusCompleted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(session.outputURL);
                    DLog(@"视频导出成功：%@", [session.outputURL path]);
                }
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(nil);
                    DLog(@"视频导出失败：%@", [session.outputURL path]);
                }
            });
        }
    }];
}



/**
 视频、声音淡出

 @param asset    视频资源
 @param duration 淡出时长
 @return 返回AVPlayerItem
 */
+ (AVPlayerItem *)videoFadeOut:(AVAsset *)asset duration:(Float64)duration{
//    1.将素材拖入到素材库中
    AVAssetTrack *videoAssetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];//素材的视频轨
    AVAssetTrack *audioAssertTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];//素材的音频轨
    
    
//    2.将素材的视频插入视频轨，音频插入音频轨
    AVMutableComposition *composition = [[AVMutableComposition alloc] init];//这是工程文件
    AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];//视频轨道
    AVMutableCompositionTrack *audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];//音频轨道
    [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:videoAssetTrack atTime:kCMTimeZero error:nil];//在视频轨道插入一个时间段的视频
    [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:audioAssertTrack atTime:kCMTimeZero error:nil];//插入音频数据，否则没有声音
    
    
//    3.设置声音淡出时间
    CMTime start = CMTimeMake(composition.duration.value - composition.duration.timescale * duration, composition.duration.timescale);
    CMTimeRange fadeOutTimeRange = CMTimeRangeFromTimeToTime(start, composition.duration);
    
    //视频淡出
    AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoAssetTrack];
    [layerInstruction setOpacityRampFromStartOpacity:1 toEndOpacity:0 timeRange:fadeOutTimeRange];
    
    //音频淡出
    AVMutableAudioMixInputParameters *parameters = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:audioTrack];
    [parameters setVolumeRampFromStartVolume:1 toEndVolume:0 timeRange:fadeOutTimeRange];
    
    AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
    audioMix.inputParameters = @[parameters];//配置到播放器中
    
    
    
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, videoAssetTrack.timeRange.duration);//得到视频轨道（这里只有一个轨道）
    instruction.layerInstructions = @[layerInstruction];
    
    //整合视频合成的参数
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.instructions = @[instruction];
    videoComposition.frameDuration = CMTimeMake(1, 30);
    videoComposition.renderSize = videoTrack.naturalSize;

    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:composition];
    item.videoComposition = videoComposition;
    item.audioMix = audioMix;
    return item;
}


/**
 视频速度

 @param segment 视频资源
 @param scale 速度比率
 @return 返回AVPlayerItem
 */
+ (AVPlayerItem *)videoSpeed:(LZSessionSegment *)segment scale:(CGFloat)scale{
//    1.将素材拖入到素材库中
    AVAsset *asset = segment.asset;
    AVAssetTrack *videoAssetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];//素材的视频轨
    AVAssetTrack *audioAssertTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];//素材的音频轨
    
//    2.将素材的视频插入视频轨，音频插入音频轨
    AVMutableComposition *composition = [[AVMutableComposition alloc] init];//这是工程文件
    AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];//视频轨道
    AVMutableCompositionTrack *audioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];//音频轨道
    [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:videoAssetTrack atTime:kCMTimeZero error:nil];//在视频轨道插入一个时间段的视频
    [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:audioAssertTrack atTime:kCMTimeZero error:nil];//插入音频数据，否则没有声音
    
//    3.根据速度比率调节音频和视频
//    scale = 0.2f;  // 快速 x5
//    scale = 4.0f;  // 慢速 x4
    CMTimeRange range = CMTimeRangeMake(kCMTimeZero, asset.duration);
    [videoTrack scaleTimeRange:range toDuration:CMTimeMake(asset.duration.value * scale, asset.duration.timescale)];
    [audioTrack scaleTimeRange:range toDuration:CMTimeMake(asset.duration.value * scale, asset.duration.timescale)];

    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:composition];
    return item;
}

//将多个视频合并为一个视频
- (void)mergeVideosWithPaths:(NSArray *)paths completed:(void(^)(NSString *videoPath))completed {
    if (!paths.count) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        AVMutableComposition* mixComposition = [[AVMutableComposition alloc] init];
        AVMutableCompositionTrack *audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        videoTrack.preferredTransform = CGAffineTransformRotate(CGAffineTransformIdentity, M_PI_2);
        
        CMTime totalDuration = kCMTimeZero;

//        NSMutableArray<AVMutableVideoCompositionLayerInstruction *> *instructions = [NSMutableArray array];
        
        for (int i = 0; i < paths.count; i++) {
            AVURLAsset *asset = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:paths[i]]];
            AVAssetTrack *assetAudioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
            AVAssetTrack *assetVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];

            NSLog(@"%lld", asset.duration.value/asset.duration.timescale);
            
            NSError *erroraudio = nil;
            BOOL ba = [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:assetAudioTrack atTime:totalDuration error:&erroraudio];
            NSLog(@"erroraudio:%@--%d", erroraudio, ba);

            NSError *errorVideo = nil;
            BOOL bl = [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofTrack:assetVideoTrack atTime:totalDuration error:&errorVideo];
            NSLog(@"errorVideo:%@--%d",errorVideo,bl);
        }

//        NSString *outPath = [kVideoPath stringByAppendingPathComponent:[self movieName]];
//        NSURL *mergeFileURL = [NSURL fileURLWithPath:outPath];
//        
//        AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
//        exporter.outputURL = mergeFileURL;
//        exporter.outputFileType = AVFileTypeQuickTimeMovie;
//        //        exporter.videoComposition = mixVideoComposition;
//        exporter.shouldOptimizeForNetworkUse = YES;
//        [exporter exportAsynchronouslyWithCompletionHandler:^{
//            dispatch_async(dispatch_get_main_queue(), ^{
//                completed(outPath);
//            });
//        }];
    });
}



/**
 配置文件路径
 
 @param fileName 文件名称
 @return 文件路径：..LZVideo/fileName
 */
+ (NSURL *)filePathWithFileName:(NSString *)fileName{
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"LZVideoFilter"];
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL exists = [manager fileExistsAtPath:tempPath isDirectory:NULL];
    if (!exists) {
        [manager createDirectoryAtPath:tempPath withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    
    tempPath = [tempPath stringByAppendingPathComponent:fileName];
    exists = [manager fileExistsAtPath:tempPath isDirectory:NULL];
    if (exists) {
        [manager removeItemAtPath:tempPath error:NULL];
    }
    return [NSURL fileURLWithPath:tempPath];
}


/**
 枚举路径
 */
+ (NSArray *)enumPathisFilter:(BOOL)isFilter{
    NSString *path = @"";
    if (isFilter) {
        path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"LZVideoFilter"];
    }else{
        path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"LZVideo"];
    }
    
    NSFileManager *myFileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *myDirectoryEnumerator;
    myDirectoryEnumerator = [myFileManager enumeratorAtPath:path];
    
    //列举目录内容，可以遍历子目录
    NSLog(@"目录下：%@",path);
    NSMutableArray *array = [NSMutableArray new];
    while((path = [myDirectoryEnumerator nextObject]) != nil){
        NSLog(@"%@",path);
        [array addObject:path];
    }
    return array;
}

@end
