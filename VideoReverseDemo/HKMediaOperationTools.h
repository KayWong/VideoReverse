//
//  HKMediaOperationTools.h
//  YeahMV
//
//  Created by HuangKai on 15/12/18.
//  Copyright © 2015年 QiuShiBaiKe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

typedef void(^HKProgressHandle)(CGFloat progress);

@interface HKMediaOperationTools : NSObject
+ (AVAsset *)assetByReversingAsset:(AVAsset *)asset videoComposition:(AVMutableVideoComposition *)videoComposition duration:(CMTime)duration outputURL:(NSURL *)outputURL progressHandle:(HKProgressHandle)progressHandle cancle:(BOOL *)cancle;
@end
