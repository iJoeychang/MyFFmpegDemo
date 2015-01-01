//
//  ViewController.h
//  kxmovieapp
//
//  Created by Kolyvan on 11.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxmovie
//  this file is part of KxMovie
//  KxMovie is licenced under the LGPL v3, see lgpl-3.0.txt

#import <UIKit/UIKit.h>

@class KxMovieDecoder;

extern NSString * const KxMovieParameterMinBufferedDuration;    // Float
extern NSString * const KxMovieParameterMaxBufferedDuration;    // Float
extern NSString * const KxMovieParameterDisableDeinterlacing;   // BOOL

@interface KxMovieViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>

+ (id) movieViewControllerWithContentPath: (NSString *) path
                               parameters: (NSDictionary *) parameters;

@property (readonly) BOOL playing;
@property(nonatomic) BOOL isShowDownloadBtn;// 是否显示下载按钮，本地视频不显示，网络请求时候显示

@property(nonatomic,strong) NSString * tempFilePath;// 缓冲文件保存路径 chang
@property(nonatomic,strong) NSString * saveFilePath;// 文件保存路径 
@property ( nonatomic) long long expectedContentLength; // 下载文件总大小//  下载文件总大小
@property(nonatomic,strong) NSString * remotePath;// 网络链接
@property(nonatomic,strong) NSMutableDictionary * params;//  传递参数


- (void) play;
- (void) pause;

@end
