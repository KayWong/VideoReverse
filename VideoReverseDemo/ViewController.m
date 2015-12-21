//
//  ViewController.m
//  VideoReverseDemo
//
//  Created by HuangKai on 15/12/22.
//  Copyright © 2015年 HuangKai. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "HKMediaOperationTools.h"
@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *startReverseButton;
@property (nonatomic , assign) BOOL isCancel;
@property (nonatomic , strong) AVAsset *asset;
@property (weak, nonatomic) IBOutlet UILabel *progressLabel;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    
    
    
    self.startReverseButton.enabled = NO;
    self.isCancel = NO;
    NSString *sourceMoviePath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"mp4"];
    NSURL *sourceMovieURL = [NSURL fileURLWithPath:sourceMoviePath];
    self.asset = [AVAsset assetWithURL:sourceMovieURL];
    [self.asset loadValuesAsynchronouslyForKeys:@[@"duration", @"tracks"] completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            self.startReverseButton.enabled = YES;
        });
    }];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)startReverse:(id)sender {
    self.isCancel = NO;
    NSString * temppath = NSTemporaryDirectory();
    temppath = [temppath stringByAppendingPathComponent:@"reversed.video"];
    BOOL exists =[[NSFileManager defaultManager] fileExistsAtPath:temppath isDirectory:NULL];
    if (!exists) {
        [[NSFileManager defaultManager] createDirectoryAtPath:temppath withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    NSString *filename = @"reversed.mp4";
    temppath = [temppath stringByAppendingPathComponent:filename];
    if ([[NSFileManager defaultManager] fileExistsAtPath:temppath isDirectory:NULL]) {
        [[NSFileManager defaultManager] removeItemAtPath:temppath error:NULL];
    }
    NSLog(@"%@",temppath);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [HKMediaOperationTools assetByReversingAsset:self.asset videoComposition:nil duration:self.asset.duration outputURL:[NSURL fileURLWithPath:temppath] progressHandle:^(CGFloat progress) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.progressLabel.text = [NSString stringWithFormat:@"%@ %%",@(progress*100)];
            });
            NSLog(@"%@",@(progress*100));
        } cancle:&_isCancel];
    });

}
- (IBAction)cancelReverse:(id)sender {
    self.isCancel = YES;
}

@end
