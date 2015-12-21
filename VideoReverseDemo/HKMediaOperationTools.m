//
//  HKMediaOperationTools.m
//  YeahMV
//
//  Created by HuangKai on 15/12/18.
//  Copyright © 2015年 QiuShiBaiKe. All rights reserved.
//

#import "HKMediaOperationTools.h"

@implementation HKMediaOperationTools

+ (AVAsset *)assetByReversingAsset:(AVAsset *)asset videoComposition:(AVMutableVideoComposition *)videoComposition duration:(CMTime)duration outputURL:(NSURL *)outputURL progressHandle:(HKProgressHandle)progressHandle cancle:(BOOL *)cancle {
    if (*(cancle)) {
        return nil;
    }
    NSError *error;
    //获取视频的总轨道
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] lastObject];
    //按照每秒一个视频的长度，分割轨道，生成对应的时间范围
    NSMutableArray *timeRangeArray = [NSMutableArray array];
    NSMutableArray *startTimeArray = [NSMutableArray array];
    CMTime startTime = kCMTimeZero;
    for (NSInteger i = 0; i <(CMTimeGetSeconds(duration)); i ++) {
        CMTimeRange timeRange = CMTimeRangeMake(startTime, CMTimeMakeWithSeconds(1, duration.timescale));
        if (CMTimeRangeContainsTimeRange(videoTrack.timeRange, timeRange)) {
            [timeRangeArray addObject:[NSValue valueWithCMTimeRange:timeRange]];
        } else {
            timeRange = CMTimeRangeMake(startTime, CMTimeSubtract(duration, startTime));
            [timeRangeArray addObject:[NSValue valueWithCMTimeRange:timeRange]];
        }
        [startTimeArray addObject:[NSValue valueWithCMTime:startTime]];
        startTime = CMTimeAdd(timeRange.start, timeRange.duration);
    }
    
    NSMutableArray *tracks = [NSMutableArray array];
    NSMutableArray *assets = [NSMutableArray array];
    
    
    for (NSInteger i = 0; i < timeRangeArray.count; i ++) {
        AVMutableComposition *subAsset = [[AVMutableComposition alloc]init];
        AVMutableCompositionTrack *subTrack =   [subAsset addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        [subTrack  insertTimeRange:[timeRangeArray[i] CMTimeRangeValue] ofTrack:videoTrack atTime:[startTimeArray[i] CMTimeValue] error:nil];
        AVAsset *assetNew = [subAsset copy];
        AVAssetTrack *assetTrackNew = [[assetNew tracksWithMediaType:AVMediaTypeVideo] lastObject];
        [tracks addObject:assetTrackNew];
        [assets addObject:assetNew];
    }
    
    AVAssetReader *totalReader = nil ;;
    
    NSDictionary *totalReaderOutputSettings = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange], kCVPixelBufferPixelFormatTypeKey, nil];
    AVAssetReaderOutput *totalReaderOutput = nil;
    if (videoComposition) {
        totalReaderOutput = [AVAssetReaderVideoCompositionOutput assetReaderVideoCompositionOutputWithVideoTracks:@[videoTrack] videoSettings:totalReaderOutputSettings];
        ((AVAssetReaderVideoCompositionOutput *)totalReaderOutput).videoComposition = videoComposition;
    } else {
        totalReaderOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack outputSettings:totalReaderOutputSettings];
    }
    totalReader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
    if([totalReader canAddOutput:totalReaderOutput]){
        [totalReader addOutput:totalReaderOutput];
    } else {
        return nil;
    }
    [totalReader startReading];
    NSMutableArray *sampleTimes = [NSMutableArray array];
    CMSampleBufferRef totalSample;
    
    while((totalSample = [totalReaderOutput copyNextSampleBuffer])) {
        CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(totalSample);
        [sampleTimes addObject:[NSValue valueWithCMTime:presentationTime]];
        CFRelease(totalSample);
    }
    
    //配置Writer
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:outputURL
                                                      fileType:AVFileTypeMPEG4
                                                         error:&error];
    NSDictionary *videoCompressionProps = [NSDictionary dictionaryWithObjectsAndKeys:
                                           @(videoTrack.estimatedDataRate), AVVideoAverageBitRateKey,
                                           nil];
    CGFloat width = videoTrack.naturalSize.width;
    CGFloat height = videoTrack.naturalSize.height;
    if (videoComposition) {
        CGFloat tmp = width;
        width = height;
        height = tmp;
    }
    NSDictionary *writerOutputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                          AVVideoCodecH264, AVVideoCodecKey,
                                          [NSNumber numberWithInt:height], AVVideoHeightKey,
                                          [NSNumber numberWithInt:width], AVVideoWidthKey,
                                          videoCompressionProps, AVVideoCompressionPropertiesKey,
                                          nil];
    AVAssetWriterInput *writerInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo
                                                                     outputSettings:writerOutputSettings
                                                                   sourceFormatHint:(__bridge CMFormatDescriptionRef)[videoTrack.formatDescriptions lastObject]];
    [writerInput setExpectsMediaDataInRealTime:NO];
    
    // Initialize an input adaptor so that we can append PixelBuffer
    AVAssetWriterInputPixelBufferAdaptor *pixelBufferAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:writerInput sourcePixelBufferAttributes:nil];
    
    [writer addInput:writerInput];
    
    [writer startWriting];
    [writer startSessionAtSourceTime:videoTrack.timeRange.start];
    
    NSInteger counter = 0;
    size_t countOfFrames = 0;
    size_t totalCountOfArray = 40;
    size_t arrayIncreasment = 40;
    CMSampleBufferRef *sampleBufferRefs = (CMSampleBufferRef *) malloc(totalCountOfArray * sizeof(CMSampleBufferRef *));
    memset(sampleBufferRefs, 0, sizeof(CMSampleBufferRef *) * totalCountOfArray);
    for (NSInteger i = tracks.count -1; i <= tracks.count; i --) {
        if (*(cancle)) {
            [writer cancelWriting];
            free(sampleBufferRefs);
            return nil;
        }
        AVAssetReader *reader = nil;
        
        countOfFrames = 0;
        AVAssetReaderOutput *readerOutput = nil;
        if (videoComposition) {
            readerOutput = [AVAssetReaderVideoCompositionOutput assetReaderVideoCompositionOutputWithVideoTracks:@[tracks[i]] videoSettings:totalReaderOutputSettings];
            ((AVAssetReaderVideoCompositionOutput *)readerOutput).videoComposition = videoComposition;
        } else {
            readerOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:tracks[i] outputSettings:totalReaderOutputSettings];
        }
        
        reader = [[AVAssetReader alloc] initWithAsset:assets[i] error:&error];
        if([reader canAddOutput:readerOutput]){
            [reader addOutput:readerOutput];
        } else {
            break;
        }
        [reader startReading];
        
        CMSampleBufferRef sample;
        while((sample = [readerOutput copyNextSampleBuffer])) {
            CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sample);
            if (CMTIME_COMPARE_INLINE(presentationTime, >=, [startTimeArray[i] CMTimeValue])) {
                if (countOfFrames  + 1 > totalCountOfArray) {
                    totalCountOfArray += arrayIncreasment;
                    sampleBufferRefs = (CMSampleBufferRef *)realloc(sampleBufferRefs, totalCountOfArray);
                }
                *(sampleBufferRefs + countOfFrames) = sample;
                countOfFrames++;
            } else {
                if (sample != NULL) {
                    CFRelease(sample);
                }
            }
        }
        [reader cancelReading];
        for(NSInteger j = 0; j < countOfFrames; j++) {
            // Get the presentation time for the frame
            if (counter > sampleTimes.count - 1) {
                break;
            }
            CMTime presentationTime = [sampleTimes[counter] CMTimeValue];
            
            // take the image/pixel buffer from tail end of the array
            CMSampleBufferRef bufferRef = *(sampleBufferRefs + countOfFrames - j - 1);
            CVPixelBufferRef imageBufferRef = CMSampleBufferGetImageBuffer(bufferRef);
            
            while (!writerInput.readyForMoreMediaData) {
                [NSThread sleepForTimeInterval:0.1];
            }
            [pixelBufferAdaptor appendPixelBuffer:imageBufferRef withPresentationTime:presentationTime];
            progressHandle(((CGFloat)counter/(CGFloat)sampleTimes.count));
            counter++;
            CFRelease(bufferRef);
            *(sampleBufferRefs + countOfFrames - j - 1) = NULL;
        }
    }
    free(sampleBufferRefs);
    
    [writer finishWriting];
    return [AVAsset assetWithURL:outputURL];
}
@end
