//
//  ViewController.m
//  kxmovieapp
//
//  Created by Kolyvan on 11.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxmovie
//  this file is part of KxMovie
//  KxMovie is licenced under the LGPL v3, see lgpl-3.0.txt

#import "KxMovieViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import "KxMovieDecoder.h"
#import "KxAudioManager.h"
#import "KxMovieGLView.h"
#import "KxLogger.h"
#import <MediaPlayer/MPVolumeView.h>
#import "TranslucentToolbar.h"
#import "mkNetworkKit/MKNetworkOperation.h"
#import "MKNetworkEngine.h"
#import "SPBreakpointsDownload.h"



NSString * const KxMovieParameterMinBufferedDuration = @"KxMovieParameterMinBufferedDuration";
NSString * const KxMovieParameterMaxBufferedDuration = @"KxMovieParameterMaxBufferedDuration";
NSString * const KxMovieParameterDisableDeinterlacing = @"KxMovieParameterDisableDeinterlacing";
CGFloat const gestureMinimumTranslation = 20.0;
////////////////////////////////////////////////////////////////////////////////

static NSString * formatTimeInterval(CGFloat seconds, BOOL isLeft)
{
    seconds = MAX(0, seconds);
    
    NSInteger s = seconds;
    NSInteger m = s / 60;
    NSInteger h = m / 60;
    
    s = s % 60;
    m = m % 60;

    NSMutableString *format = [(isLeft && seconds >= 0.5 ? @"-" : @"") mutableCopy];
    if (h != 0) [format appendFormat:@"%d:%0.2d", h, m];
    else        [format appendFormat:@"%d", m];
    [format appendFormat:@":%0.2d", s];

    return format;
}

////////////////////////////////////////////////////////////////////////////////

typedef enum : NSInteger {
    kPanMoveDirectionNone,
    kPanMoveDirectionUp,
    kPanMoveDirectionDown,
    kPanMoveDirectionRight,
    kPanMoveDirectionLeft
} PanMoveDirection;

enum {

    KxMovieInfoSectionGeneral,
    KxMovieInfoSectionVideo,
    KxMovieInfoSectionAudio,
    KxMovieInfoSectionSubtitles,
    KxMovieInfoSectionMetadata,    
    KxMovieInfoSectionCount,
};

enum {

    KxMovieInfoGeneralFormat,
    KxMovieInfoGeneralBitrate,
    KxMovieInfoGeneralCount,
};

////////////////////////////////////////////////////////////////////////////////

static NSMutableDictionary * gHistory;

#define LOCAL_MIN_BUFFERED_DURATION   1.2
#define LOCAL_MAX_BUFFERED_DURATION   1.4
#define NETWORK_MIN_BUFFERED_DURATION 2.0
#define NETWORK_MAX_BUFFERED_DURATION 4.0

@interface KxMovieViewController () {

    KxMovieDecoder      *_decoder;    
    dispatch_queue_t    _dispatchQueue;
    NSMutableArray      *_videoFrames;
    NSMutableArray      *_audioFrames;
    NSMutableArray      *_subtitles;
    NSData              *_currentAudioFrame;
    NSUInteger          _currentAudioFramePos;
    CGFloat             _moviePosition;
    BOOL                _disableUpdateHUD;
    NSTimeInterval      _tickCorrectionTime;
    NSTimeInterval      _tickCorrectionPosition;
    NSUInteger          _tickCounter;
    BOOL                _fullscreen;
    BOOL                _hiddenHUD;
    BOOL                _fitMode;
    BOOL                _infoMode;
    BOOL                _restoreIdleTimer;
    BOOL                _interrupted;

    KxMovieGLView       *_glView;
    UIImageView         *_imageView;
    UIView              *_topHUD;
    UIToolbar           *_topBar;
    UIToolbar           *_bottomBar;
    UISlider            *_progressSlider;

    
    UIBarButtonItem     *_voiceBtn;
    UIBarButtonItem     *_playBtn;
    UIBarButtonItem     *_pauseBtn;
    UIBarButtonItem     *_rewindBtn;
    UIBarButtonItem     *_fforwardBtn;
    UIBarButtonItem     *_spaceItem;
    UIBarButtonItem     *_fixedSpaceItem;

    UIButton            *_voiceButton;
    UIButton            *_doneButton;
    UILabel             *_progressLabel;
    UILabel             *_leftLabel;
    UIButton            *_infoButton;
    UITableView         *_tableView;
    UIActivityIndicatorView *_activityIndicatorView;
    UILabel             *_subtitlesLabel;
    
    UITapGestureRecognizer *_tapGestureRecognizer;
    UITapGestureRecognizer *_doubleTapGestureRecognizer;
    UIPanGestureRecognizer *_panGestureRecognizer;
        
#ifdef DEBUG
    UILabel             *_messageLabel;
    NSTimeInterval      _debugStartTime;
    NSUInteger          _debugAudioStatus;
    NSDate              *_debugAudioStatusTS;
#endif

    CGFloat             _bufferedDuration;
    CGFloat             _minBufferedDuration;
    CGFloat             _maxBufferedDuration;
    BOOL                _buffered;
    
    BOOL                _savedIdleTimer;
    
    NSDictionary        *_parameters;
    MPVolumeView        * myVolumeView;
    UIView              * volumeHolder;
    BOOL                isVoiceSliderShow;// 是否隐藏调节声音状态条
    
    UIView         *lockView;// 播放页面加锁解锁背景图
    UIButton       *lockBtn; // 播放页面加锁解锁按钮
    UIImageView    *lockImageView;// 播放页面加锁解锁图像
    BOOL           isLocked;// 是否已经加锁
    //BOOL           isLocking;// 正在解锁或者加锁显示提醒时间内
    UIView         *lockAlertView;// 提示加锁解锁
    UILabel        *lockAlertLabel;// 提示加锁解锁
    
    int            timerInit;
    NSTimer        *timer;
    
    int            timerInit2;//5秒后隐藏上下toolbar
    NSTimer        *timer2;
    
    //拖动 快进后退
    UIView         *fforwarBackground;//背景视图
    UIImageView    *rewindOrFforwarImageView;// 快进后退图像
    UILabel        *statusLabel;// 显示进度状态
    
    CGFloat postionForPan;// 拖动快进后退 记录位置 初始为_moviePosition
    CGFloat currentVoicePostion;// 当前声音大小位置
    
    UISlider *volumeSlider;// MPVolumeView中调节声音slider
    
    
    PanMoveDirection direction;
    
    NSString *saveFilePath;// 根据网络链接确定下载文件保存路径
    
    UIButton           * downloadBtn;// 下载按钮
    UIBarButtonItem    * downloadBtnItem;// 下载按钮BarButtonItem
    
    CGFloat             _theoryMoviePosition; //理论上的播放位置
}

@property (readwrite) BOOL playing;
@property (readwrite) BOOL decoding;
@property (readwrite, strong) KxArtworkFrame *artworkFrame;
@property (nonatomic,strong)UISlider *volumeSlider;



@end

@implementation KxMovieViewController

@synthesize volumeSlider;

+ (void)initialize
{
    if (!gHistory)
        gHistory = [NSMutableDictionary dictionary];
}

- (BOOL)prefersStatusBarHidden { return YES; }

+ (id) movieViewControllerWithContentPath: (NSString *) path
                               parameters: (NSDictionary *) parameters
{    
    id<KxAudioManager> audioManager = [KxAudioManager audioManager];
    [audioManager activateAudioSession];    
    return [[KxMovieViewController alloc] initWithContentPath: path parameters: parameters];
}

- (id) initWithContentPath: (NSString *) path
                parameters: (NSDictionary *) parameters
{
    NSAssert(path.length > 0, @"empty path");
    
    saveFilePath = path;// 初始赋值SaveFilePath
    
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        
        _moviePosition = 0;
        _theoryMoviePosition = _moviePosition;
//        self.wantsFullScreenLayout = YES;

        _parameters = parameters;
        
        __weak KxMovieViewController *weakSelf = self;
        
        KxMovieDecoder *decoder = [[KxMovieDecoder alloc] init];
        
        decoder.interruptCallback = ^BOOL(){
            
            __strong KxMovieViewController *strongSelf = weakSelf;
            return strongSelf ? [strongSelf interruptDecoder] : YES;
        };
        
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
    
            NSError *error = nil;
            [decoder openFile:path error:&error];
                        
            __strong KxMovieViewController *strongSelf = weakSelf;
            if (strongSelf) {
                
                dispatch_sync(dispatch_get_main_queue(), ^{
                    
                    [strongSelf setMovieDecoder:decoder withError:error];                    
                });
            }
        });
    }
    return self;
}

- (void) dealloc
{
    [self pause];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_dispatchQueue) {
        _dispatchQueue = NULL;
    }
    
    //LoggerStream(1, @"%@ dealloc", self);
}



- (void)loadView
{
    // LoggerStream(1, @"loadView");
    CGRect bounds = [[UIScreen mainScreen] applicationFrame];
    
    self.view = [[UIView alloc] initWithFrame:bounds];
    self.view.backgroundColor = [UIColor blackColor];
    self.view.tintColor = [UIColor blackColor];

    _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: UIActivityIndicatorViewStyleWhiteLarge];
    _activityIndicatorView.center = self.view.center;
    _activityIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    
    [self.view addSubview:_activityIndicatorView];
    
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    
#ifdef DEBUG
    _messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(20,40,width-40,40)];
    _messageLabel.backgroundColor = [UIColor clearColor];
    _messageLabel.textColor = [UIColor redColor];
    _messageLabel.hidden = YES;
    _messageLabel.font = [UIFont systemFontOfSize:14];
    _messageLabel.numberOfLines = 2;
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    _messageLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_messageLabel];
#endif

    CGFloat topH = 50;
    CGFloat botH = 50;

    _topHUD    = [[UIView alloc] initWithFrame:CGRectMake(0,0,0,0)];
  
    // 设置透明toolbar
    _topBar    =[[TranslucentToolbar alloc] initWithFrame:CGRectMake(0, 0, width, topH)];
    _bottomBar =[[TranslucentToolbar alloc] initWithFrame:CGRectMake(0, height-botH, width, botH)];


    _topHUD.frame = CGRectMake(0,0,width,_topBar.frame.size.height);
   
    _topHUD.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _topBar.translucent = YES;
    _bottomBar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    _bottomBar.translucent = YES;
    
    [self.view addSubview:_topBar];
    [self.view addSubview:_topHUD];
    [self.view addSubview:_bottomBar];
    [self.view bringSubviewToFront:_bottomBar];
    
    
    //bottom bar
    _voiceButton = [[UIButton alloc] init];
    _voiceButton.frame = CGRectMake(2, 0, 30, 30);
    _voiceButton.backgroundColor = [UIColor clearColor];
    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.frame = _voiceButton.frame;
    imageView.image = [UIImage imageNamed:@"player_btn_volume.png"];
    [_voiceButton addSubview:imageView];
    
    [_voiceButton addTarget:self action:@selector(changeVoice:)
          forControlEvents:UIControlEventTouchUpInside];
    
    // 下载按钮
    downloadBtn = [[UIButton alloc] init];
    downloadBtn.frame = CGRectMake(2, 1, 26, 26);
    downloadBtn.backgroundColor = [UIColor clearColor];
    UIImageView * downloadBtnImageView = [[UIImageView alloc] init];
    downloadBtnImageView.frame = downloadBtn.frame;
    downloadBtnImageView.image = [UIImage imageNamed:@"player_icon_download"];
    [downloadBtn addSubview:downloadBtnImageView];
    [downloadBtn addTarget:self action:@selector(downloadFile:)
          forControlEvents:UIControlEventTouchUpInside];
    downloadBtnItem = [[UIBarButtonItem alloc] initWithCustomView:downloadBtn];
    
    
    
    // top hud
    _doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _doneButton.frame = CGRectMake(0, 1, 50, topH);
    _doneButton.backgroundColor = [UIColor clearColor];
    [_doneButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [_doneButton setTitle:NSLocalizedString(@"OK", nil) forState:UIControlStateNormal];
    _doneButton.titleLabel.font = [UIFont systemFontOfSize:18];
    _doneButton.showsTouchWhenHighlighted = YES;
    [_doneButton addTarget:self action:@selector(doneDidTouch:)
          forControlEvents:UIControlEventTouchUpInside];
    //[_doneButton setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];

    _progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(46, 1, 50, topH)];
    _progressLabel.backgroundColor = [UIColor clearColor];
    _progressLabel.opaque = NO;
    _progressLabel.adjustsFontSizeToFitWidth = NO;
    _progressLabel.textAlignment = NSTextAlignmentRight;
    _progressLabel.textColor = [UIColor blackColor];
    _progressLabel.text = @"";
    _progressLabel.font = [UIFont systemFontOfSize:12];
    
    _progressSlider = [[UISlider alloc] initWithFrame:CGRectMake(100, 2, width-197, topH)];
    _progressSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _progressSlider.continuous = NO;
    _progressSlider.value = 0;
//    [_progressSlider setThumbImage:[UIImage imageNamed:@"kxmovie.bundle/sliderthumb"]
//                          forState:UIControlStateNormal];


    
    _leftLabel = [[UILabel alloc] initWithFrame:CGRectMake(width-92, 1, 60, topH)];
    _leftLabel.backgroundColor = [UIColor clearColor];
    _leftLabel.opaque = NO;
    _leftLabel.adjustsFontSizeToFitWidth = NO;
    _leftLabel.textAlignment = NSTextAlignmentLeft;
    _leftLabel.textColor = [UIColor blackColor];
    _leftLabel.text = @"";
    _leftLabel.font = [UIFont systemFontOfSize:12];
    _leftLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
   
    
    _infoButton = [UIButton buttonWithType:UIButtonTypeInfoDark];
    _infoButton.frame = CGRectMake(width-31, (topH-20)/2+1, 20, 20);
    _infoButton.showsTouchWhenHighlighted = YES;
    _infoButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_infoButton addTarget:self action:@selector(infoDidTouch:) forControlEvents:UIControlEventTouchUpInside];
    
    [_topHUD addSubview:_doneButton];
    [_topHUD addSubview:_progressLabel];
    [_topHUD addSubview:_progressSlider];
    [_topHUD addSubview:_leftLabel];
    [_topHUD addSubview:_infoButton];

    // bottom hud

    _spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                               target:nil
                                                               action:nil];
    
    _fixedSpaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                                                                    target:nil
                                                                    action:nil];
    _fixedSpaceItem.width = 30;
    
    _rewindBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRewind
                                                               target:self
                                                               action:@selector(rewindDidTouch:)];

    _playBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
                                                             target:self
                                                             action:@selector(playDidTouch:)];
    _playBtn.width = 50;
    
    _pauseBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause
                                                              target:self
                                                              action:@selector(playDidTouch:)];
    _pauseBtn.width = 50;

    _fforwardBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFastForward
                                                                 target:self
                                                                 action:@selector(forwardDidTouch:)];
    
    _voiceBtn = [[UIBarButtonItem alloc] initWithCustomView:_voiceButton];
    
    
    

    [self updateBottomBar];

    if (_decoder) {
        
        [self setupPresentView];
        
    } else {
        
        _progressLabel.hidden = YES;
        _progressSlider.hidden = YES;
        _leftLabel.hidden = YES;
        _infoButton.hidden = YES;
    }
    
    // 初始化VoiceSlider进度条
    [self createVoiceSlider:nil];
    
    // 添加视图 加锁解锁
    lockView = [[UIView alloc] init];
    if (self.interfaceOrientation==UIInterfaceOrientationPortrait) {
        lockView.frame = CGRectMake(20, height/2-15, 40, 40);
    }else{
        lockView.frame = CGRectMake(20, width/2-15, 40, 40);
    }

    lockImageView = [[UIImageView alloc] init];
    lockImageView.image = [UIImage imageNamed:@"PlayerFullScreen-Icon-Unlock-Normal.png"];
    lockImageView.frame = lockView.bounds;
    
    lockBtn = [[UIButton alloc] init];
    [lockBtn addTarget:self action:@selector(lockBtnOnOrOff:) forControlEvents:UIControlEventTouchUpInside];
    lockBtn.frame = lockView.bounds;
    [lockView addSubview:lockImageView];
    [lockView addSubview:lockBtn];
    [self.view addSubview:lockView];
    [self.view bringSubviewToFront:lockView];
    lockView.hidden = YES;
    lockImageView.hidden = YES;
    lockBtn.hidden = YES;

    lockAlertView = [[UIView alloc] initWithFrame:CGRectMake(50, height/2-30, 200, 44)];
    lockAlertLabel = [[UILabel alloc] init];
    if (self.interfaceOrientation == UIInterfaceOrientationPortrait) {
        lockAlertView.frame = CGRectMake(width/2-50, height/2-22,  100, 44);
    }else{
        lockAlertView.frame = CGRectMake(height/2-50, width/2-22,  100, 44);
    }
    lockAlertView.backgroundColor = [UIColor colorWithRed:21.0/255.0 green:21.0/255.0  blue:21.0/255.0  alpha:0.7];
    [lockAlertView addSubview:lockAlertLabel];
    lockAlertView.layer.cornerRadius = 3.0;
    lockAlertView.layer.masksToBounds = YES;
    lockAlertLabel.textColor=[UIColor whiteColor];
    lockAlertLabel.font = [UIFont systemFontOfSize:16];
    lockAlertLabel.textAlignment = NSTextAlignmentCenter;
    lockAlertLabel.frame = CGRectMake(0, 0, 100, 44);
    [self.view addSubview:lockAlertView];
    lockAlertView.hidden = YES;
    lockAlertLabel.hidden = YES;
    
    
    //添加拖动手势操作 快进后退
    fforwarBackground = [[UIView alloc] init];
    if (self.interfaceOrientation == UIInterfaceOrientationPortrait) {
        fforwarBackground.frame = CGRectMake(width/2-70,height/2-70 , 140, 100);
    }else{
        fforwarBackground.frame = CGRectMake(height/2-70,width/2-70 , 140, 100);
    }
    fforwarBackground.backgroundColor = [UIColor colorWithRed:21.0/255.0 green:21.0/255.0 blue:21.0/255.0 alpha:0.8];
    fforwarBackground.layer.cornerRadius = 3;
    fforwarBackground.layer.masksToBounds = YES;
    rewindOrFforwarImageView = [[UIImageView alloc] init];
    rewindOrFforwarImageView.frame = CGRectMake(50, 2, 52, 60);
    rewindOrFforwarImageView.image = [UIImage imageNamed:@"PlayerFullScreen-Img-fast-forward.png"];
    [fforwarBackground addSubview:rewindOrFforwarImageView];
    
    statusLabel = [[UILabel alloc] init];
    statusLabel.text = @"";
    statusLabel.textAlignment = NSTextAlignmentCenter;
    statusLabel.textColor = [UIColor whiteColor];
    statusLabel.font = [UIFont systemFontOfSize:26];
    statusLabel.frame = CGRectMake(10, 64, 120, 34);
    [fforwarBackground addSubview:statusLabel];
    [self.view addSubview:fforwarBackground];
    fforwarBackground.hidden = YES;
//    rewindOrFforwarImageView.hidden = YES;
//    statusLabel.hidden = YES;
    
}





- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    if (self.playing) {
        
        [self pause];
        [self freeBufferedFrames];
        
        if (_maxBufferedDuration > 0) {
            
            _minBufferedDuration = _maxBufferedDuration = 0;
            [self play];
            
            //LoggerStream(0, @"didReceiveMemoryWarning, disable buffering and continue playing");
            
        } else {
            
            // force ffmpeg to free allocated memory
            [_decoder closeFile];
            [_decoder openFile:nil error:nil];
            
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", nil)
                                        message:NSLocalizedString(@"Out of memory", nil)
                                       delegate:nil
                              cancelButtonTitle:NSLocalizedString(@"Close", nil)
                              otherButtonTitles:nil] show];
        }
        
    } else {
        
        [self freeBufferedFrames];
        [_decoder closeFile];
        [_decoder openFile:nil error:nil];
    }
}

- (void) viewDidAppear:(BOOL)animated
{
    // LoggerStream(1, @"viewDidAppear");
    
    [super viewDidAppear:animated];
        
    if (self.presentingViewController)
        [self fullscreenMode:YES];
    
    if (_infoMode)
        [self showInfoView:NO animated:NO];
    
    _savedIdleTimer = [[UIApplication sharedApplication] isIdleTimerDisabled];
    
    [self showHUD: YES];
    
    if (_decoder) {
        
        [self restorePlay];
        
    } else {

        [_activityIndicatorView startAnimating];
    }
   
        
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:[UIApplication sharedApplication]];
}

- (void) viewWillDisappear:(BOOL)animated
{    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super viewWillDisappear:animated];
    
    [_activityIndicatorView stopAnimating];
    
    if (_decoder) {
        
        [self pause];
        
        if (_moviePosition == 0 || _decoder.isEOF)
            [gHistory removeObjectForKey:_decoder.path];
        else if (!_decoder.isNetwork)
            [gHistory setValue:[NSNumber numberWithFloat:_moviePosition]
                        forKey:_decoder.path];
    }
    
    if (_fullscreen)
        [self fullscreenMode:NO];
        
    [[UIApplication sharedApplication] setIdleTimerDisabled:_savedIdleTimer];
    
    [_activityIndicatorView stopAnimating];
    _buffered = NO;
    _interrupted = YES;
    
    //LoggerStream(1, @"viewWillDisappear %@", self);
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);

    
}


#pragma mark- 屏幕旋转方法
-(void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration{

    CGRect  bounds = [[UIScreen mainScreen] applicationFrame];
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    
    volumeHolder.hidden = YES;
    if (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft || toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
        
        // 调节声音
        if (volumeHolder) {
            [volumeHolder removeFromSuperview];
        }
        volumeHolder = [[UIView alloc] initWithFrame:CGRectMake(-32, width-128, 142, 20)];
        lockView.frame = CGRectMake(20, width/2-15, 32, 32);
        lockAlertView.frame = CGRectMake(height/2-50, width/2-22,  100, 44);
        
        //拖动 快进后退
        fforwarBackground.frame = CGRectMake(height/2-70,width/2-70 , 140, 100);

       
    }
    
//    else if(toInterfaceOrientation == UIInterfaceOrientationLandscapeRight){
//        if (volumeHolder) {
//            [volumeHolder removeFromSuperview];
//        }
//        volumeHolder = [[UIView alloc] initWithFrame:CGRectMake(-32, width-128, 142, 20)];
//        lockView.frame = CGRectMake(20, width/2-15, 32, 32);
//        lockAlertView.frame = CGRectMake(height/2-50, width/2-22,  100, 44);
//        
//        //拖动 快进后退
//        fforwarBackground.frame = CGRectMake(height/2-70,width/2-70 , 140, 100);
//        
//    }
    
    else if (toInterfaceOrientation == UIInterfaceOrientationPortrait ){
        
        UIView *frameView = [self frameView];
        if (frameView.contentMode == UIViewContentModeScaleAspectFill)
            frameView.contentMode = UIViewContentModeScaleAspectFit;
        
        
        if (volumeHolder) {
            [volumeHolder removeFromSuperview];
        }
        volumeHolder = [[UIView alloc] initWithFrame:CGRectMake(-32, height-126, 142, 20)];
        lockView.frame = CGRectMake(20, height/2-15, 32, 32);
        lockAlertView.frame = CGRectMake(width/2-50, height/2-22,  100, 44);
        
        //拖动 快进后退
        fforwarBackground.frame = CGRectMake(width/2-70,height/2-50 , 140, 100);
        
    }else{
    
    }
    
    [self.view addSubview:volumeHolder];
    CGAffineTransform trans = CGAffineTransformMakeRotation(-M_PI_2);
    volumeHolder.transform = trans;
    
    if (myVolumeView.superview) {
        [myVolumeView removeFromSuperview];
    }
    myVolumeView = [[MPVolumeView alloc] init];
    myVolumeView.frame = volumeHolder.bounds;
    myVolumeView.showsVolumeSlider = YES;
    myVolumeView.showsRouteButton = NO;
    // 设置调节条背景
    [myVolumeView setMinimumVolumeSliderImage:[UIImage imageNamed:@"player_volume_color_middle.png"] forState:UIControlStateNormal];
    [myVolumeView setVolumeThumbImage:[UIImage imageNamed:@"player_volume_thumb.png"] forState:UIControlStateNormal];
    [myVolumeView setMaximumVolumeSliderImage:[UIImage imageNamed:@"statusBackground@2x.png"] forState:UIControlStateNormal];
    [myVolumeView sizeToFit];
    [volumeHolder addSubview:myVolumeView];
    isVoiceSliderShow = NO;
    volumeHolder.hidden = !isVoiceSliderShow;
}


- (void) applicationWillResignActive: (NSNotification *)notification
{
    [self showHUD:YES];
    [self pause];
    
    //LoggerStream(1, @"applicationWillResignActive");
}

#pragma mark - gesture recognizer

- (void) handleTap: (UITapGestureRecognizer *) sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        
        if (sender == _tapGestureRecognizer) {

            [self showHUD: _hiddenHUD];
            
        } else if (sender == _doubleTapGestureRecognizer) {
            UIView *frameView = [self frameView];
            if (self.interfaceOrientation !=UIInterfaceOrientationPortrait){
                if (frameView.contentMode == UIViewContentModeScaleAspectFit)
                    frameView.contentMode = UIViewContentModeScaleAspectFill;
                else
                    frameView.contentMode = UIViewContentModeScaleAspectFit;

            }else {
                if (frameView.contentMode == UIViewContentModeScaleAspectFill)
                    frameView.contentMode = UIViewContentModeScaleAspectFit;
            }
            
//            if (lockImageView.hidden) {
//            
//                lockImageView.hidden = NO;
//            }else{
//                lockImageView.hidden = YES;
//            }
        }
    }
}





#pragma mark- 拖动手势
- (void) handlePan: (UIPanGestureRecognizer *) sender
{

    CGPoint translation = [sender translationInView:self.view];
    
    const CGPoint vt = [sender velocityInView:self.view];
    const CGPoint pt = [sender translationInView:self.view];
    const CGFloat sp = MAX(0.1, log10(fabsf(vt.x)) - 1.0);
    const CGFloat sc = fabsf(pt.x) * 0.1 * sp * 0.2;//0.33
    
    
    if (sender.state == UIGestureRecognizerStateBegan)
    {
        direction = kPanMoveDirectionNone;
        direction = [self determineCameraDirectionIfNeeded:translation];
        if (direction==kPanMoveDirectionRight||direction==kPanMoveDirectionLeft) {
            [self pause];
        }
        direction = kPanMoveDirectionNone;
        postionForPan  = _moviePosition;
        currentVoicePostion = [self getCurrentVolume:nil];
    }
    else if (sender.state == UIGestureRecognizerStateChanged )
    {
        direction = [self determineCameraDirectionIfNeeded:translation];

        
        if (direction==kPanMoveDirectionDown) {
            
            CGFloat sp2 = MAX(0.1, log10(fabsf(vt.y)) - 1.0);
            CGFloat sc2 = fabsf(pt.y) * 0.1 * sp2 * 0.2;//0.33
            
            CGFloat f1 = -1.0;
            currentVoicePostion += 0.005 * f1 * sc2;
            currentVoicePostion = MIN(1 - 0.01, MAX(0, currentVoicePostion));
        }else if(direction ==kPanMoveDirectionUp){
        
            CGFloat sp2 = MAX(0.1, log10(fabsf(vt.y)) - 1.0);
            CGFloat sc2 = fabsf(pt.y) * 0.1 * sp2 * 0.2;//0.33
            
            CGFloat f2 = 1.0;
            currentVoicePostion += 0.005 * f2 * sc2;
            currentVoicePostion = MIN(1 - 0.01, MAX(0, currentVoicePostion));
        }else if(direction ==kPanMoveDirectionRight){
            fforwarBackground.hidden = NO;
            
            rewindOrFforwarImageView.image = [UIImage imageNamed:@"PlayerFullScreen-Img-fast-forward.png"];
            rewindOrFforwarImageView.frame = CGRectMake(50, 2, 52, 60);
            if (sc > 1) {
                CGFloat ff = 0.0;
                if (pt.x > 0) {
                    ff = 1.0;
                    
                    //NSLog(@"---------- %f", ff);
                    CGFloat duration = _decoder.duration;
                    postionForPan += ff * MIN(sc, 600.0);//_moviePosition -_decoder.startTime;
                    
                    postionForPan = MIN(_decoder.duration - 1, MAX(0, postionForPan));
                    
                    // 动态显示时间 拖动快进后退
                    statusLabel.text = [NSString stringWithFormat:@"%@/%@",formatTimeInterval(postionForPan, NO),formatTimeInterval(duration, NO)];
                    statusLabel.textAlignment = NSTextAlignmentCenter;
                    statusLabel.textColor = [UIColor whiteColor];
                    statusLabel.font = [UIFont systemFontOfSize:26];
                }
            }

        }else if(direction ==kPanMoveDirectionLeft){
            fforwarBackground.hidden = NO;
            if (sc > 1) {
                
                CGFloat ff = 0.0;
                //const CGFloat ff = pt.x > 0 ? 1.0 : -1.0;
                
                if (pt.x < 0) {
                    ff = -1.0;
                    //NSLog(@"---------- %f", ff);
                    CGFloat duration = _decoder.duration;
                    postionForPan += ff * MIN(sc, 600.0);//_moviePosition -_decoder.startTime;
                    
                    postionForPan = MIN(_decoder.duration - 1, MAX(0, postionForPan));
                    
                    // 动态显示时间 拖动快进后退
                    statusLabel.text = [NSString stringWithFormat:@"%@/%@",formatTimeInterval(postionForPan, NO),formatTimeInterval(duration, NO)];
                    statusLabel.textAlignment = NSTextAlignmentCenter;
                    statusLabel.textColor = [UIColor whiteColor];
                    statusLabel.font = [UIFont systemFontOfSize:26];
                }
            }
        
        }else{

        }
        
     }
    else if (sender.state == UIGestureRecognizerStateEnded)
    {
        
        fforwarBackground.hidden = YES;
        switch (direction) {
            case kPanMoveDirectionDown:
                [self handleVolumeChanged:nil];
                [self play];
                break;
                
            case  kPanMoveDirectionUp:
                [self handleVolumeChanged:nil];
                [self play];
                break;
                
            case  kPanMoveDirectionRight:
                [self setMoviePosition: postionForPan];
                [self play];
                break;
                
            case  kPanMoveDirectionLeft:
                [self setMoviePosition: postionForPan];
                [self play];
                break;
                
            default:
                break;
        }
        
    }else if(sender.state == UIGestureRecognizerStateCancelled){
    
        [self play];
    }
}

#pragma mark - public

-(void) play
{
    if (self.playing)
        return;
    
    if (!_decoder.validVideo &&
        !_decoder.validAudio) {
        
        return;
    }
    
    if (_interrupted)
        return;

    self.playing = YES;
    _interrupted = NO;
    _disableUpdateHUD = NO;
    _tickCorrectionTime = 0;
    _tickCounter = 0;

#ifdef DEBUG
    _debugStartTime = -1;
#endif

    [self asyncDecodeFrames];
    [self updatePlayButton];

    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self tick];
    });

    if (_decoder.validAudio)
        [self enableAudio:YES];
}

- (void) pause
{
    if (!self.playing)
        return;

    self.playing = NO;
    //_interrupted = YES;
    [self enableAudio:NO];
    [self updatePlayButton];
}

- (void) setMoviePosition: (CGFloat) position
{
    BOOL playMode = self.playing;
    
    self.playing = NO;
    _disableUpdateHUD = YES;
    [self enableAudio:NO];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){

        [self updatePosition:position playMode:playMode];
    });
}

#pragma mark - actions

- (void) doneDidTouch: (id) sender
{
    
    // 如果不注销时间计时器，则viewcontroller不会被注销不执行dealloc方法
    // 如果view controller中有计时器、循环引用、监听事件时，View controller不被销毁
    if (timer) {
        [timer invalidate];
        timer = nil;
    }
    if (timer2) {
        [timer2 invalidate];
        timer2 = nil;
    }
    
    if (self.presentingViewController || !self.navigationController)
        [self dismissViewControllerAnimated:YES completion:nil];
    else
        [self.navigationController popViewControllerAnimated:YES];
}

- (void) infoDidTouch: (id) sender
{
    [self showInfoView: !_infoMode animated:YES];
}

- (void) playDidTouch: (id) sender
{
    if (self.playing)
        [self pause];
    else
        [self play];
}



#pragma mark- 快进
- (void) forwardDidTouch: (id) sender
{
    NSLog(@"======= 001 %f", _moviePosition);
    
    NSLog(@"======= 002 %f", _theoryMoviePosition);
    if (_moviePosition < _theoryMoviePosition) {
        _theoryMoviePosition += 10;
        //return;
    }
    else {
        _theoryMoviePosition = _moviePosition + 10;
    }
    if (_theoryMoviePosition > _decoder.duration) {
        _theoryMoviePosition = _decoder.duration;
    }
    NSLog(@"======= 003 %f", _theoryMoviePosition);
    [self setMoviePosition: _theoryMoviePosition];
     
    //[self setMoviePosition: _moviePosition + 10];
}

#pragma mark- 后退
- (void) rewindDidTouch: (id) sender
{
    if (_moviePosition > _theoryMoviePosition) {
        _theoryMoviePosition -= 10;
        //return;
    }
    else {
        _theoryMoviePosition = _moviePosition - 10;
    }
    if (_theoryMoviePosition < 0) {
        _theoryMoviePosition = 0;
    }
    [self setMoviePosition: _theoryMoviePosition];
}

- (void) progressDidChange: (id) sender
{
    NSAssert(_decoder.duration != MAXFLOAT, @"bugcheck");
    UISlider *slider = sender;
    [self setMoviePosition:slider.value * _decoder.duration];
}

#pragma mark - private

- (void) setMovieDecoder: (KxMovieDecoder *) decoder
               withError: (NSError *) error
{
    //LoggerStream(2, @"setMovieDecoder");
            
    if (!error && decoder) {
        
        _decoder        = decoder;
        _dispatchQueue  = dispatch_queue_create("KxMovie", DISPATCH_QUEUE_SERIAL);
        _videoFrames    = [NSMutableArray array];
        _audioFrames    = [NSMutableArray array];
        
        if (_decoder.subtitleStreamsCount) {
            _subtitles = [NSMutableArray array];
        }
    
        if (_decoder.isNetwork) {
            
            _minBufferedDuration = NETWORK_MIN_BUFFERED_DURATION;
            _maxBufferedDuration = NETWORK_MAX_BUFFERED_DURATION;
            
        } else {
            
            _minBufferedDuration = LOCAL_MIN_BUFFERED_DURATION;
            _maxBufferedDuration = LOCAL_MAX_BUFFERED_DURATION;
        }
        
        if (!_decoder.validVideo)
            _minBufferedDuration *= 10.0; // increase for audio
                
        // allow to tweak some parameters at runtime
        if (_parameters.count) {
            
            id val;
            
            val = [_parameters valueForKey: KxMovieParameterMinBufferedDuration];
            if ([val isKindOfClass:[NSNumber class]])
                _minBufferedDuration = [val floatValue];
            
            val = [_parameters valueForKey: KxMovieParameterMaxBufferedDuration];
            if ([val isKindOfClass:[NSNumber class]])
                _maxBufferedDuration = [val floatValue];
            
            val = [_parameters valueForKey: KxMovieParameterDisableDeinterlacing];
            if ([val isKindOfClass:[NSNumber class]])
                _decoder.disableDeinterlacing = [val boolValue];
            
            if (_maxBufferedDuration < _minBufferedDuration)
                _maxBufferedDuration = _minBufferedDuration * 2;
        }
        
        //LoggerStream(2, @"buffered limit: %.1f - %.1f", _minBufferedDuration, _maxBufferedDuration);
        
        if (self.isViewLoaded) {
            
            [self setupPresentView];
            
            _progressLabel.hidden   = NO;
            _progressSlider.hidden  = NO;
            _leftLabel.hidden       = NO;
            _infoButton.hidden      = NO;
            
            if (_activityIndicatorView.isAnimating) {
                
                [_activityIndicatorView stopAnimating];
                // if (self.view.window)
                [self restorePlay];
            }
        }
        
    } else {
        
         if (self.isViewLoaded && self.view.window) {
        
             [_activityIndicatorView stopAnimating];
             if (!_interrupted)
                 [self handleDecoderMovieError: error];
         }
    }
}

- (void) restorePlay
{
    NSNumber *n = [gHistory valueForKey:_decoder.path];
    if (n)
        [self updatePosition:n.floatValue playMode:YES];
    else
        [self play];
}

- (void) setupPresentView
{
    CGRect bounds = self.view.bounds;
    
    if (_decoder.validVideo) {
        _glView = [[KxMovieGLView alloc] initWithFrame:bounds decoder:_decoder];
    } 
    
    if (!_glView) {
        
        LoggerVideo(0, @"fallback to use RGB video frame and UIKit");
        [_decoder setupVideoFrameFormat:KxVideoFrameFormatRGB];
        _imageView = [[UIImageView alloc] initWithFrame:bounds];
        _imageView.backgroundColor = [UIColor blackColor];
    }
    
    UIView *frameView = [self frameView];
    frameView.contentMode = UIViewContentModeScaleAspectFit;
    frameView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    
    [self.view insertSubview:frameView atIndex:0];
        
    if (_decoder.validVideo) {
    
        [self setupUserInteraction];
    
    } else {
       
        _imageView.image = [UIImage imageNamed:@"kxmovie.bundle/music_icon.png"];
        _imageView.contentMode = UIViewContentModeCenter;
    }
    
    self.view.backgroundColor = [UIColor clearColor];
    
    if (_decoder.duration == MAXFLOAT) {
        
        _leftLabel.text = @"\u221E"; // infinity
        _leftLabel.font = [UIFont systemFontOfSize:14];
        
        CGRect frame;
        
        frame = _leftLabel.frame;
        frame.origin.x += 40;
        frame.size.width -= 40;
        _leftLabel.frame = frame;
        
        frame =_progressSlider.frame;
        frame.size.width += 40;
        _progressSlider.frame = frame;
        
    } else {
        
        [_progressSlider addTarget:self
                            action:@selector(progressDidChange:)
                  forControlEvents:UIControlEventValueChanged];
    }
    
    if (_decoder.subtitleStreamsCount) {
        
        CGSize size = self.view.bounds.size;
        
        _subtitlesLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, size.height, size.width, 0)];
        _subtitlesLabel.numberOfLines = 0;
        _subtitlesLabel.backgroundColor = [UIColor clearColor];
        _subtitlesLabel.opaque = NO;
        _subtitlesLabel.adjustsFontSizeToFitWidth = NO;
        _subtitlesLabel.textAlignment = NSTextAlignmentCenter;
        _subtitlesLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _subtitlesLabel.textColor = [UIColor whiteColor];
        _subtitlesLabel.font = [UIFont systemFontOfSize:16];
        _subtitlesLabel.hidden = YES;

        [self.view addSubview:_subtitlesLabel];
    }
}

- (void) setupUserInteraction
{
    UIView * view = [self frameView];
    view.userInteractionEnabled = YES;
    
    _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    _tapGestureRecognizer.numberOfTapsRequired = 1;
    
    _doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    _doubleTapGestureRecognizer.numberOfTapsRequired = 2;
    
    [_tapGestureRecognizer requireGestureRecognizerToFail: _doubleTapGestureRecognizer];
    
    [view addGestureRecognizer:_doubleTapGestureRecognizer];
    [view addGestureRecognizer:_tapGestureRecognizer];
    
    _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    //_panGestureRecognizer.enabled = NO;
    
    [view addGestureRecognizer:_panGestureRecognizer];
}

- (UIView *) frameView
{
    return _glView ? _glView : _imageView;
}

- (void) audioCallbackFillData: (float *) outData
                     numFrames: (UInt32) numFrames
                   numChannels: (UInt32) numChannels
{
    //fillSignalF(outData,numFrames,numChannels);
    //return;

    if (_buffered) {
        memset(outData, 0, numFrames * numChannels * sizeof(float));
        return;
    }

    @autoreleasepool {
        
        while (numFrames > 0) {
            
            if (!_currentAudioFrame) {
                
                @synchronized(_audioFrames) {
                    
                    NSUInteger count = _audioFrames.count;
                    
                    if (count > 0) {
                        
                        KxAudioFrame *frame = _audioFrames[0];

#ifdef DUMP_AUDIO_DATA
                        LoggerAudio(2, @"Audio frame position: %f", frame.position);
#endif
                        if (_decoder.validVideo) {
                        
                            const CGFloat delta = _moviePosition - frame.position;
                            
                            if (delta < -0.1) {
                                
                                memset(outData, 0, numFrames * numChannels * sizeof(float));
#ifdef DEBUG
                                //LoggerStream(0, @"desync audio (outrun) wait %.4f %.4f", _moviePosition, frame.position);
                                _debugAudioStatus = 1;
                                _debugAudioStatusTS = [NSDate date];
#endif
                                break; // silence and exit
                            }
                            
                            [_audioFrames removeObjectAtIndex:0];
                            
                            if (delta > 0.1 && count > 1) {
                                
#ifdef DEBUG
                                //LoggerStream(0, @"desync audio (lags) skip %.4f %.4f", _moviePosition, frame.position);
                                _debugAudioStatus = 2;
                                _debugAudioStatusTS = [NSDate date];
#endif
                                continue;
                            }
                            
                        } else {
                            
                            [_audioFrames removeObjectAtIndex:0];
                            _moviePosition = frame.position;
                            _bufferedDuration -= frame.duration;
                        }
                        
                        _currentAudioFramePos = 0;
                        _currentAudioFrame = frame.samples;                        
                    }
                }
            }
            
            if (_currentAudioFrame) {
                
                const void *bytes = (Byte *)_currentAudioFrame.bytes + _currentAudioFramePos;
                const NSUInteger bytesLeft = (_currentAudioFrame.length - _currentAudioFramePos);
                const NSUInteger frameSizeOf = numChannels * sizeof(float);
                const NSUInteger bytesToCopy = MIN(numFrames * frameSizeOf, bytesLeft);
                const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;
                
                memcpy(outData, bytes, bytesToCopy);
                numFrames -= framesToCopy;
                outData += framesToCopy * numChannels;
                
                if (bytesToCopy < bytesLeft)
                    _currentAudioFramePos += bytesToCopy;
                else
                    _currentAudioFrame = nil;                
                
            } else {
                
                memset(outData, 0, numFrames * numChannels * sizeof(float));
                //LoggerStream(1, @"silence audio");
#ifdef DEBUG
                _debugAudioStatus = 3;
                _debugAudioStatusTS = [NSDate date];
#endif
                break;
            }
        }
    }
}

- (void) enableAudio: (BOOL) on
{
    id<KxAudioManager> audioManager = [KxAudioManager audioManager];
            
    if (on && _decoder.validAudio) {
                
        audioManager.outputBlock = ^(float *outData, UInt32 numFrames, UInt32 numChannels) {
            
            [self audioCallbackFillData: outData numFrames:numFrames numChannels:numChannels];
        };
        
        [audioManager play];
        
        LoggerAudio(2, @"audio device smr: %d fmt: %d chn: %d",
                    (int)audioManager.samplingRate,
                    (int)audioManager.numBytesPerSample,
                    (int)audioManager.numOutputChannels);
        
    } else {
        
        [audioManager pause];
        audioManager.outputBlock = nil;
    }
}

- (BOOL) addFrames: (NSArray *)frames
{
    if (_decoder.validVideo) {
        
        @synchronized(_videoFrames) {
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeVideo) {
                    [_videoFrames addObject:frame];
                    _bufferedDuration += frame.duration;
                }
        }
    }
    
    if (_decoder.validAudio) {
        
        @synchronized(_audioFrames) {
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeAudio) {
                    [_audioFrames addObject:frame];
                    if (!_decoder.validVideo)
                        _bufferedDuration += frame.duration;
                }
        }
        
        if (!_decoder.validVideo) {
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeArtwork)
                    self.artworkFrame = (KxArtworkFrame *)frame;
        }
    }
    
    if (_decoder.validSubtitles) {
        
        @synchronized(_subtitles) {
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeSubtitle) {
                    [_subtitles addObject:frame];
                }
        }
    }
    
    return self.playing && _bufferedDuration < _maxBufferedDuration;
}

- (BOOL) decodeFrames
{
    //NSAssert(dispatch_get_current_queue() == _dispatchQueue, @"bugcheck");
    
    NSArray *frames = nil;
    
    if (_decoder.validVideo ||
        _decoder.validAudio) {
        
        frames = [_decoder decodeFrames:0];
    }
    
    if (frames.count) {
        return [self addFrames: frames];
    }
    return NO;
}

- (void) asyncDecodeFrames
{
    if (self.decoding)
        return;
    
    __weak KxMovieViewController *weakSelf = self;
    __weak KxMovieDecoder *weakDecoder = _decoder;
    
    const CGFloat duration = _decoder.isNetwork ? .0f : 0.1f;
    
    self.decoding = YES;
    dispatch_async(_dispatchQueue, ^{
        
        {
            __strong KxMovieViewController *strongSelf = weakSelf;
            if (!strongSelf.playing)
                return;
        }
        
        BOOL good = YES;
        while (good) {
            
            good = NO;
            
            @autoreleasepool {
                
                __strong KxMovieDecoder *decoder = weakDecoder;
                
                if (decoder && (decoder.validVideo || decoder.validAudio)) {
                    
                    NSArray *frames = [decoder decodeFrames:duration];
                    if (frames.count) {
                        
                        __strong KxMovieViewController *strongSelf = weakSelf;
                        if (strongSelf)
                            good = [strongSelf addFrames:frames];
                    }
                }
            }
        }
                
        {
            __strong KxMovieViewController *strongSelf = weakSelf;
            if (strongSelf) strongSelf.decoding = NO;
        }
    });
}

- (void) tick
{
    if (_buffered && ((_bufferedDuration > _minBufferedDuration) || _decoder.isEOF)) {
        
        _tickCorrectionTime = 0;
        _buffered = NO;
        [_activityIndicatorView stopAnimating];        
    }
    
    CGFloat interval = 0;
    if (!_buffered)
        interval = [self presentFrame];
    
    if (self.playing) {
        
        const NSUInteger leftFrames =
        (_decoder.validVideo ? _videoFrames.count : 0) +
        (_decoder.validAudio ? _audioFrames.count : 0);
        
        if (0 == leftFrames) {
            
            if (_decoder.isEOF) {
                
                [self pause];
                [self updateHUD];
                return;
            }
            
            if (_minBufferedDuration > 0 && !_buffered) {
                                
                _buffered = YES;
                [_activityIndicatorView startAnimating];
            }
        }
        
        if (!leftFrames ||
            !(_bufferedDuration > _minBufferedDuration)) {
            
            [self asyncDecodeFrames];
        }
        
        const NSTimeInterval correction = [self tickCorrection];
        const NSTimeInterval time = MAX(interval + correction, 0.01);
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self tick];
        });
    }
    
    if ((_tickCounter++ % 3) == 0) {
        [self updateHUD];
    }
}

- (CGFloat) tickCorrection
{
    if (_buffered)
        return 0;
    
    const NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    if (!_tickCorrectionTime) {
        
        _tickCorrectionTime = now;
        _tickCorrectionPosition = _moviePosition;
        return 0;
    }
    
    NSTimeInterval dPosition = _moviePosition - _tickCorrectionPosition;
    NSTimeInterval dTime = now - _tickCorrectionTime;
    NSTimeInterval correction = dPosition - dTime;
    
    //if ((_tickCounter % 200) == 0)
    //    LoggerStream(1, @"tick correction %.4f", correction);
    
    if (correction > 1.f || correction < -1.f) {
        
        //LoggerStream(1, @"tick correction reset %.2f", correction);
        correction = 0;
        _tickCorrectionTime = 0;
    }
    
    return correction;
}

- (CGFloat) presentFrame
{
    CGFloat interval = 0;
    
    if (_decoder.validVideo) {
        
        KxVideoFrame *frame;
        
        @synchronized(_videoFrames) {
            
            if (_videoFrames.count > 0) {
                
                frame = _videoFrames[0];
                [_videoFrames removeObjectAtIndex:0];
                _bufferedDuration -= frame.duration;
            }
        }
        
        if (frame)
            interval = [self presentVideoFrame:frame];
        
    } else if (_decoder.validAudio) {

        //interval = _bufferedDuration * 0.5;
                
        if (self.artworkFrame) {
            
            _imageView.image = [self.artworkFrame asImage];
            self.artworkFrame = nil;
        }
    }

    if (_decoder.validSubtitles)
        [self presentSubtitles];
    
#ifdef DEBUG
    if (self.playing && _debugStartTime < 0)
        _debugStartTime = [NSDate timeIntervalSinceReferenceDate] - _moviePosition;
#endif

    return interval;
}

- (CGFloat) presentVideoFrame: (KxVideoFrame *) frame
{
    if (_glView) {
        
        [_glView render:frame];
        
    } else {
        
        KxVideoFrameRGB *rgbFrame = (KxVideoFrameRGB *)frame;
        _imageView.image = [rgbFrame asImage];
    }
    
    _moviePosition = frame.position;
    return frame.duration;
}

- (void) presentSubtitles
{
    NSArray *actual, *outdated;
    
    if ([self subtitleForPosition:_moviePosition
                           actual:&actual
                         outdated:&outdated]){
        
        if (outdated.count) {
            @synchronized(_subtitles) {
                [_subtitles removeObjectsInArray:outdated];
            }
        }
        
        if (actual.count) {
            
            NSMutableString *ms = [NSMutableString string];
            for (KxSubtitleFrame *subtitle in actual.reverseObjectEnumerator) {
                if (ms.length) [ms appendString:@"\n"];
                [ms appendString:subtitle.text];
            }
            
            if (![_subtitlesLabel.text isEqualToString:ms]) {
                
                CGSize viewSize = self.view.bounds.size;
                CGSize size = [ms sizeWithFont:_subtitlesLabel.font
                             constrainedToSize:CGSizeMake(viewSize.width, viewSize.height * 0.5)
                                 lineBreakMode:NSLineBreakByTruncatingTail];
                _subtitlesLabel.text = ms;
                _subtitlesLabel.frame = CGRectMake(0, viewSize.height - size.height - 10,
                                                   viewSize.width, size.height);
                _subtitlesLabel.hidden = NO;
            }
            
        } else {
            
            _subtitlesLabel.text = nil;
            _subtitlesLabel.hidden = YES;
        }
    }
}

- (BOOL) subtitleForPosition: (CGFloat) position
                      actual: (NSArray **) pActual
                    outdated: (NSArray **) pOutdated
{
    if (!_subtitles.count)
        return NO;
    
    NSMutableArray *actual = nil;
    NSMutableArray *outdated = nil;
    
    for (KxSubtitleFrame *subtitle in _subtitles) {
        
        if (position < subtitle.position) {
            
            break; // assume what subtitles sorted by position
            
        } else if (position >= (subtitle.position + subtitle.duration)) {
            
            if (pOutdated) {
                if (!outdated)
                    outdated = [NSMutableArray array];
                [outdated addObject:subtitle];
            }
            
        } else {
            
            if (pActual) {
                if (!actual)
                    actual = [NSMutableArray array];
                [actual addObject:subtitle];
            }
        }
    }
    
    if (pActual) *pActual = actual;
    if (pOutdated) *pOutdated = outdated;
    
    return actual.count || outdated.count;
}

- (void) updateBottomBar
{
    UIBarButtonItem *playPauseBtn = self.playing ? _pauseBtn : _playBtn;
   
    // 网络视频显示下载按钮 本地视频不显示
    if (self.isShowDownloadBtn) {
        [_bottomBar setItems:@[_voiceBtn,_spaceItem, _rewindBtn, _fixedSpaceItem, playPauseBtn,
                               _fixedSpaceItem, _fforwardBtn, _spaceItem,downloadBtnItem] animated:NO];
    }else{
    
        [_bottomBar setItems:@[_voiceBtn,_spaceItem, _rewindBtn, _fixedSpaceItem, playPauseBtn,
                               _fixedSpaceItem, _fforwardBtn, _spaceItem] animated:NO];
    }
    
    
}

- (void) updatePlayButton
{
    [self updateBottomBar];
}

- (void) updateHUD
{
    if (_disableUpdateHUD)
        return;
    
    const CGFloat duration = _decoder.duration;
    const CGFloat position = _moviePosition -_decoder.startTime;
    
    if (_progressSlider.state == UIControlStateNormal)
        _progressSlider.value = position / duration;
    
    // 读取本地缓存文件，快播放至下载处，继续下载
       NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:_tempFilePath]) {
        NSError *error = nil;
        unsigned long long fileSize = [[fileManager attributesOfItemAtPath:_tempFilePath error:&error]  fileSize];
        if (error) {
            NSLog(@"get %@ fileSize failed!\nError:%@", _tempFilePath, error);
        }
        
        float   fileSizePer = fileSize/self.expectedContentLength;// 已下载文件占总文件大小百分比
        
        // 继续下载
        if(_progressSlider.value +0.1>= fileSizePer){
        
            [SPBreakpointsDownload operationWithURLString  :  _remotePath
                                                                                 params  : _params
                                                                          httpMethod  : @"GET"
                                                                        tempFilePath  : _tempFilePath
                                                                 downloadFilePath  : _saveFilePath
                                                                             rewriteFile  : NO];
        }
        
    
    
    _progressLabel.text = formatTimeInterval(position, NO);
    
    if (_decoder.duration != MAXFLOAT)
        _leftLabel.text = formatTimeInterval(duration - position, YES);

    /*
    // 动态显示时间 拖动快进后退
    statusLabel.text = [NSString stringWithFormat:@"%@/%@",formatTimeInterval(position, NO),formatTimeInterval(duration, NO)];
    statusLabel.textAlignment = NSTextAlignmentCenter;
    statusLabel.textColor = [UIColor whiteColor];
    statusLabel.font = [UIFont systemFontOfSize:26];*/
    
#ifdef DEBUG
    const NSTimeInterval timeSinceStart = [NSDate timeIntervalSinceReferenceDate] - _debugStartTime;
    NSString *subinfo = _decoder.validSubtitles ? [NSString stringWithFormat: @" %d",_subtitles.count] : @"";
    
    NSString *audioStatus;
    
//    if (_debugAudioStatus) {
//        
//        if (NSOrderedAscending == [_debugAudioStatusTS compare: [NSDate dateWithTimeIntervalSinceNow:-0.5]]) {
//            _debugAudioStatus = 0;
//        }
//    }
    
    if      (_debugAudioStatus == 1) audioStatus = @"\n(audio outrun)";
    else if (_debugAudioStatus == 2) audioStatus = @"\n(audio lags)";
    else if (_debugAudioStatus == 3) audioStatus = @"\n(audio silence)";
    else audioStatus = @"";

    _messageLabel.text = [NSString stringWithFormat:@"%d %d%@ %c - %@ %@ %@\n%@",
                          _videoFrames.count,
                          _audioFrames.count,
                          subinfo,
                          self.decoding ? 'D' : ' ',
                          formatTimeInterval(timeSinceStart, NO),
                          //timeSinceStart > _moviePosition + 0.5 ? @" (lags)" : @"",
                          _decoder.isEOF ? @"- END" : @"",
                          audioStatus,
                          _buffered ? [NSString stringWithFormat:@"buffering %.1f%%", _bufferedDuration / _minBufferedDuration * 100] : @""];
#endif
    }

}

- (void) showHUD: (BOOL) show
{
    _hiddenHUD = !show;    
    //_panGestureRecognizer.enabled = _hiddenHUD;
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:_hiddenHUD];
    
    [UIView animateWithDuration:0.2
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionNone
                     animations:^{
                         
                         if (!isLocked) {
                             CGFloat alpha = _hiddenHUD ? 0 : 1;
                             _topBar.alpha = alpha;
                             _topHUD.alpha = alpha;
                             _bottomBar.alpha = alpha;
                             
                             if (alpha==0) {
                                 isVoiceSliderShow = NO;
                                 volumeHolder.hidden = !isVoiceSliderShow;
                                 lockView.hidden = YES;
                                 lockAlertView.hidden = YES;
                             }else{
                                 lockView.hidden = NO;
                                 lockImageView.hidden = NO;
                                 lockBtn.hidden = NO;
                                 
                                 //倒计时 5秒后隐藏视图
                                 if (timer2) {
                                     [timer2 invalidate];
                                     timer2 = nil;
                                 }
                                 timerInit2= 5;
                                 timer2 =[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(dropTimer2) userInfo:nil repeats:YES];
                             }
                         }else{
                         
                             if (lockImageView.hidden) {
                                 
                                 lockImageView.hidden = NO;
                                 //lockAlertView.hidden = NO;
                                 
                             }else{
                                 lockImageView.hidden = YES;
                                 lockAlertView.hidden = YES;
                                 
                             }
                         }
                     }
                     completion:nil];
    
}

- (void) fullscreenMode: (BOOL) on
{
    _fullscreen = on;
    UIApplication *app = [UIApplication sharedApplication];
    [app setStatusBarHidden:on withAnimation:UIStatusBarAnimationNone];
    // if (!self.presentingViewController) {
    //[self.navigationController setNavigationBarHidden:on animated:YES];
    //[self.tabBarController setTabBarHidden:on animated:YES];
    // }
}

- (void) setMoviePositionFromDecoder
{
    _moviePosition = _decoder.position;
    
}

- (void) setDecoderPosition: (CGFloat) position
{
    _decoder.position = position;
}

- (void) enableUpdateHUD
{
    _disableUpdateHUD = NO;
}

- (void) updatePosition: (CGFloat) position
               playMode: (BOOL) playMode
{
    [self freeBufferedFrames];
    
    position = MIN(_decoder.duration - 1, MAX(0, position));
    
    __weak KxMovieViewController *weakSelf = self;

    dispatch_async(_dispatchQueue, ^{
        
        if (playMode) {
        
            {
                __strong KxMovieViewController *strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf setDecoderPosition: position];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
        
                __strong KxMovieViewController *strongSelf = weakSelf;
                if (strongSelf) {
                    [strongSelf setMoviePositionFromDecoder];
                    [strongSelf play];
                }
            });
            
        } else {

            {
                __strong KxMovieViewController *strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf setDecoderPosition: position];
                [strongSelf decodeFrames];
            }
            
//            dispatch_async(dispatch_get_main_queue(), ^{
//                
//                __strong KxMovieViewController *strongSelf = weakSelf;
//                if (strongSelf) {
//                
//                    [strongSelf enableUpdateHUD];
//                    [strongSelf setMoviePositionFromDecoder];
//                    [strongSelf presentFrame];
//                    [strongSelf updateHUD];
//                }
//            });
        }
    });
}

- (void) freeBufferedFrames
{
    @synchronized(_videoFrames) {
        [_videoFrames removeAllObjects];
    }
    
    @synchronized(_audioFrames) {
        
        [_audioFrames removeAllObjects];
        _currentAudioFrame = nil;
    }
    
    if (_subtitles) {
        @synchronized(_subtitles) {
            [_subtitles removeAllObjects];
        }
    }
    
    _bufferedDuration = 0;
}

- (void) showInfoView: (BOOL) showInfo animated: (BOOL)animated
{
    if (!_tableView)
        [self createTableView];

    [self pause];
    
    CGSize size = self.view.bounds.size;
    CGFloat Y = _topHUD.bounds.size.height;
    
    if (showInfo) {
        
        _tableView.hidden = NO;
        
        if (animated) {
        
            [UIView animateWithDuration:0.4
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionNone
                             animations:^{
                                 
                                 _tableView.frame = CGRectMake(0,Y,size.width,size.height - Y);
                             }
                             completion:nil];
        } else {
            
            _tableView.frame = CGRectMake(0,Y,size.width,size.height - Y);
        }
    
    } else {
        
        if (animated) {
            
            [UIView animateWithDuration:0.4
                                  delay:0.0
                                options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionNone
                             animations:^{
                                 
                                 _tableView.frame = CGRectMake(0,size.height,size.width,size.height - Y);
                                 
                             }
                             completion:^(BOOL f){
                                 
                                 if (f) {
                                     _tableView.hidden = YES;
                                 }
                             }];
        } else {
        
            _tableView.frame = CGRectMake(0,size.height,size.width,size.height - Y);
            _tableView.hidden = YES;
        }
    }
    
    _infoMode = showInfo;    
}

- (void) createTableView
{    
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.hidden = YES;
    
    CGSize size = self.view.bounds.size;
    CGFloat Y = _topHUD.bounds.size.height;
    _tableView.frame = CGRectMake(0,size.height,size.width,size.height - Y);
    
    [self.view addSubview:_tableView];   
}

- (void) handleDecoderMovieError: (NSError *) error
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", nil)
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"Close", nil)
                                              otherButtonTitles:nil];
    
    [alertView show];
}

- (BOOL) interruptDecoder
{
    //if (!_decoder)
    //    return NO;
    return _interrupted;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return KxMovieInfoSectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case KxMovieInfoSectionGeneral:
            return NSLocalizedString(@"General", nil);
        case KxMovieInfoSectionMetadata:
            return NSLocalizedString(@"Metadata", nil);
        case KxMovieInfoSectionVideo: {
            NSArray *a = _decoder.info[@"video"];
            return a.count ? NSLocalizedString(@"Video", nil) : nil;
        }
        case KxMovieInfoSectionAudio: {
            NSArray *a = _decoder.info[@"audio"];
            return a.count ?  NSLocalizedString(@"Audio", nil) : nil;
        }
        case KxMovieInfoSectionSubtitles: {
            NSArray *a = _decoder.info[@"subtitles"];
            return a.count ? NSLocalizedString(@"Subtitles", nil) : nil;
        }
    }
    return @"";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case KxMovieInfoSectionGeneral:
            return KxMovieInfoGeneralCount;
            
        case KxMovieInfoSectionMetadata: {
            NSDictionary *d = [_decoder.info valueForKey:@"metadata"];
            return d.count;
        }
            
        case KxMovieInfoSectionVideo: {
            NSArray *a = _decoder.info[@"video"];
            return a.count;
        }
            
        case KxMovieInfoSectionAudio: {
            NSArray *a = _decoder.info[@"audio"];
            return a.count;
        }
            
        case KxMovieInfoSectionSubtitles: {
            NSArray *a = _decoder.info[@"subtitles"];
            return a.count ? a.count + 1 : 0;
        }
            
        default:
            return 0;
    }
}

- (id) mkCell: (NSString *) cellIdentifier
    withStyle: (UITableViewCellStyle) style
{
    UITableViewCell *cell = [_tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:cellIdentifier];
    }
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell;
    
    if (indexPath.section == KxMovieInfoSectionGeneral) {
    
        if (indexPath.row == KxMovieInfoGeneralBitrate) {
            
            int bitrate = [_decoder.info[@"bitrate"] intValue];
            cell = [self mkCell:@"ValueCell" withStyle:UITableViewCellStyleValue1];
            cell.textLabel.text = NSLocalizedString(@"Bitrate", nil);
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%d kb/s",bitrate / 1000];
            
        } else if (indexPath.row == KxMovieInfoGeneralFormat) {

            NSString *format = _decoder.info[@"format"];
            cell = [self mkCell:@"ValueCell" withStyle:UITableViewCellStyleValue1];
            cell.textLabel.text = NSLocalizedString(@"Format", nil);
            cell.detailTextLabel.text = format ? format : @"-";
        }
        
    } else if (indexPath.section == KxMovieInfoSectionMetadata) {
      
        NSDictionary *d = _decoder.info[@"metadata"];
        NSString *key = d.allKeys[indexPath.row];
        cell = [self mkCell:@"ValueCell" withStyle:UITableViewCellStyleValue1];
        cell.textLabel.text = key.capitalizedString;
        cell.detailTextLabel.text = [d valueForKey:key];
        
    } else if (indexPath.section == KxMovieInfoSectionVideo) {
        
        NSArray *a = _decoder.info[@"video"];
        cell = [self mkCell:@"VideoCell" withStyle:UITableViewCellStyleValue1];
        cell.textLabel.text = a[indexPath.row];
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.textLabel.numberOfLines = 2;
        
    } else if (indexPath.section == KxMovieInfoSectionAudio) {
        
        NSArray *a = _decoder.info[@"audio"];
        cell = [self mkCell:@"AudioCell" withStyle:UITableViewCellStyleValue1];
        cell.textLabel.text = a[indexPath.row];
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.textLabel.numberOfLines = 2;
        BOOL selected = _decoder.selectedAudioStream == indexPath.row;
        cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        
    } else if (indexPath.section == KxMovieInfoSectionSubtitles) {
        
        NSArray *a = _decoder.info[@"subtitles"];
        
        cell = [self mkCell:@"SubtitleCell" withStyle:UITableViewCellStyleValue1];
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.textLabel.numberOfLines = 1;
        
        if (indexPath.row) {
            cell.textLabel.text = a[indexPath.row - 1];
        } else {
            cell.textLabel.text = NSLocalizedString(@"Disable", nil);
        }
        
        const BOOL selected = _decoder.selectedSubtitleStream == (indexPath.row - 1);
        cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }
    
     cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == KxMovieInfoSectionAudio) {
        
        NSInteger selected = _decoder.selectedAudioStream;
        
        if (selected != indexPath.row) {

            _decoder.selectedAudioStream = indexPath.row;
            NSInteger now = _decoder.selectedAudioStream;
            
            if (now == indexPath.row) {
            
                UITableViewCell *cell;
                
                cell = [_tableView cellForRowAtIndexPath:indexPath];
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
                
                indexPath = [NSIndexPath indexPathForRow:selected inSection:KxMovieInfoSectionAudio];
                cell = [_tableView cellForRowAtIndexPath:indexPath];
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
        
    } else if (indexPath.section == KxMovieInfoSectionSubtitles) {
        
        NSInteger selected = _decoder.selectedSubtitleStream;
        
        if (selected != (indexPath.row - 1)) {
            
            _decoder.selectedSubtitleStream = indexPath.row - 1;
            NSInteger now = _decoder.selectedSubtitleStream;
            
            if (now == (indexPath.row - 1)) {
                
                UITableViewCell *cell;
                
                cell = [_tableView cellForRowAtIndexPath:indexPath];
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
                
                indexPath = [NSIndexPath indexPathForRow:selected + 1 inSection:KxMovieInfoSectionSubtitles];
                cell = [_tableView cellForRowAtIndexPath:indexPath];
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
            
            
            
            // clear subtitles
            _subtitlesLabel.text = nil;
            _subtitlesLabel.hidden = YES;
            @synchronized(_subtitles) {
                [_subtitles removeAllObjects];
            }
        }
    }
}


#pragma mark -  Image Resize 改变图像大小
-(UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize{
    
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
    
}


#pragma mark- 程序内改变声音
-(void)changeVoice:(id)sender{
    
    isVoiceSliderShow = !isVoiceSliderShow;
    volumeHolder.hidden = !isVoiceSliderShow;
    
}

#pragma mark - 加锁解锁事件
-(void)lockBtnOnOrOff:(id)sender{
    //if (!isLocking) {
        if (isLocked) {
            
            lockAlertLabel.text = @"已解锁";
            lockAlertView.hidden = NO;
            lockAlertLabel.hidden = NO;
            lockImageView.image = [UIImage imageNamed:@"PlayerFullScreen-Icon-Unlock-Normal.png"];
            _panGestureRecognizer.enabled = YES;
            
        }else{
            lockAlertLabel.text = @"已加锁";
            lockAlertView.hidden = NO;
            lockAlertLabel.hidden = NO;
            lockImageView.image = [UIImage imageNamed:@"PlayerFullScreen-Icon-Lock-Normal.png"];
            _panGestureRecognizer.enabled = NO;
            
            _topBar.alpha = 0;
            _topHUD.alpha = 0;
            _bottomBar.alpha = 0;
        }
        
        //倒计时 5秒后隐藏视图
        if (timer) {
        [timer invalidate];
        timer = nil;
        }
        timerInit= 5;
        timer =[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(dropTimer) userInfo:nil repeats:YES];
        isLocked = !isLocked;
    //}

}

#pragma mark- 倒计时 5秒后隐藏视图
-(void)dropTimer{

    timerInit --;
    //isLocking = YES;
    if (timerInit < 0) {
        lockAlertView.hidden = YES;
        lockAlertLabel.hidden = YES;
        lockImageView.hidden = YES;
        //isLocking = NO;
        [timer invalidate];
        timer=nil;
        return;
    }
    
    
}

#pragma mark- 倒计时 5秒后隐藏toolbar
-(void)dropTimer2{

    timerInit2 --;
    if (timerInit2 < 0) {
        
        
        if (!isLocked) {
            _hiddenHUD = YES;
            CGFloat alpha = _hiddenHUD ? 0 : 1;
            _topBar.alpha = alpha;
            _topHUD.alpha = alpha;
            _bottomBar.alpha = alpha;
            
            if (alpha==0) {
                isVoiceSliderShow = NO;
                volumeHolder.hidden = !isVoiceSliderShow;
                lockView.hidden = YES;
                //lockAlertView.hidden = YES;
            }
        }
        
        
        [timer2 invalidate];
        timer2=nil;
        return;
    }
    
    
}



#pragma mark - 获取volumeSlider当前声音值
-(float)getCurrentVolume:(id)sender{
    __weak __typeof(self) weakSelf = self;
    
    [[myVolumeView subviews] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        //__strong __typeof(weakSelf) strongSelf = weakSelf;
        weakSelf.volumeSlider = obj;
        *stop = YES;
        
    }];
    
    return weakSelf.volumeSlider.value;
}

#pragma mark - 上下滑动，改变系统声音
-(void)handleVolumeChanged:(id)sender{
    
    self.volumeSlider.value = currentVoicePostion;
}

#pragma mark - 判断拖动手势拖动方向
- (PanMoveDirection)determineCameraDirectionIfNeeded:(CGPoint)translation
{
    if (direction != kPanMoveDirectionNone)
        return direction;
    
    // determine if horizontal swipe only if you meet some minimum velocity
    
    if (fabs(translation.x) > gestureMinimumTranslation)
    {
        BOOL gestureHorizontal = NO;
        
        if (translation.y == 0.0)
            gestureHorizontal = YES;
        else
            gestureHorizontal = (fabs(translation.x / translation.y) > 5.0);
        
        if (gestureHorizontal)
        {
            if (translation.x > 0.0)
                return kPanMoveDirectionRight;
            else
                return kPanMoveDirectionLeft;
        }
    }
    // determine if vertical swipe only if you meet some minimum velocity
    
    else if (fabs(translation.y) > gestureMinimumTranslation)
    {
        BOOL gestureVertical = NO;
        
        if (translation.x == 0.0)
            gestureVertical = YES;
        else
            gestureVertical = (fabs(translation.y / translation.x) > 5.0);
        
        if (gestureVertical)
        {
            if (translation.y > 0.0)
                return kPanMoveDirectionDown;
            else
                return kPanMoveDirectionUp;
        }
    }
    
    return direction;
}


#pragma mark- 下载文件并保存至本地
-(void)downloadFile:(NSString *)path{
    
     path = saveFilePath;
     NSString *downloadPath = [self createfileSavePath:path isTempPath:NO];
     NSString *downloadTempPath = [self createfileSavePath:path isTempPath:YES];
    
     MKNetworkOperation *downloadOperation=[KxMovieViewController downloadFatAssFileFrom:path toFile:downloadPath];
    [downloadOperation addDownloadStream:[NSOutputStream outputStreamToFileAtPath:downloadTempPath append:YES]];
    [downloadOperation onDownloadProgressChanged:^(double progress) {
        //下载进度
        NSLog(@"下载进度 %.2f",progress*100);
        if (progress>=0.5) {
             NSLog(@"停止下载");
             [downloadOperation cancel];
        }
        
    }];
    //事件处理
    [downloadOperation addCompletionHandler:^(MKNetworkOperation* completedRequest) {
        
    }  errorHandler:^(MKNetworkOperation *errorOp, NSError* err) {
        
    }];

}


+(MKNetworkOperation*) downloadFatAssFileFrom:(NSString*) remoteURL toFile:(NSString*) filePath {
    MKNetworkEngine *engine = [[MKNetworkEngine alloc] initWithHostName:@"" customHeaderFields:nil];
    MKNetworkOperation *op = [engine operationWithURLString:remoteURL
                                                     params:nil
                                                 httpMethod:@"GET"];
    
    [op addDownloadStream:[NSOutputStream outputStreamToFileAtPath:filePath
                                                            append:YES]];
    [engine enqueueOperation:op];
    return op;
}


#pragma mark - 根据index确定保存文件路径
-(NSString *)createfileSavePath:(NSString *)path isTempPath:(BOOL)isTemp {
    
    NSArray * array = [path componentsSeparatedByString:@"/"];
    NSString *folder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                            NSUserDomainMask,
                                                            YES) lastObject];
    NSString * saveFolder = nil;
    if(!isTemp){
        saveFolder = [NSString stringWithFormat:@"%@/DownloadedFiles",folder];// 完整文件保存路径
        
    }else{
        saveFolder = [NSString stringWithFormat:@"%@/DownloadedFiles/TempFiles",folder];// 临时文件保存路径，请求网络视频时，不直接读取网络资源，而是先下载视频的一部分到本文件夹，然后读取本文件夹下文件，从而实现播放缓冲功能，解决网络不好时的视频卡顿现象
    }
    BOOL isDir = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL  existed = [fileManager fileExistsAtPath:saveFolder isDirectory:&isDir];
    if(!(isDir == YES && existed == YES)){
        
        [fileManager createDirectoryAtPath:saveFolder withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSMutableString *str = nil;
    if (array &&[array count]>1) {
       str = [array lastObject];
    }

    
    NSString *downloadPath = nil;
    if (str) {
        NSString * stringPath = [NSString stringWithFormat:@"/%@",str];
         downloadPath = [saveFolder stringByAppendingString:stringPath];
    }else{
    
         downloadPath = [saveFolder stringByAppendingString:@""] ;
    }
   
    return downloadPath;
}



#pragma mark - 初始化声音调节进度条
-(void)createVoiceSlider:(id)sender{
    CGRect bounds = [[UIScreen mainScreen] applicationFrame];
    CGFloat height = bounds.size.height;
    CGFloat width  = bounds.size.width;
    if (volumeHolder) {
        [volumeHolder removeFromSuperview];
    }
    if (self.interfaceOrientation==UIInterfaceOrientationPortrait) {
        volumeHolder = [[UIView alloc] initWithFrame:CGRectMake(-32, height-126, 142, 20)];
    }else{
        volumeHolder = [[UIView alloc] initWithFrame:CGRectMake(-32, width-128, 142, 20)];
    }
    
    
    [self.view addSubview:volumeHolder];
    CGAffineTransform trans = CGAffineTransformMakeRotation(-M_PI_2);
    volumeHolder.transform = trans;
    
    if (myVolumeView) {
        [myVolumeView removeFromSuperview];
    }
    myVolumeView = [[MPVolumeView alloc] init];
    myVolumeView.frame = volumeHolder.bounds;
    myVolumeView.showsVolumeSlider = YES;
    myVolumeView.showsRouteButton = NO;
    // 设置调节条背景
    [myVolumeView setMinimumVolumeSliderImage:[UIImage imageNamed:@"player_volume_color_middle.png"] forState:UIControlStateNormal];
    [myVolumeView setVolumeThumbImage:[UIImage imageNamed:@"player_volume_thumb.png"] forState:UIControlStateNormal];
    [myVolumeView setMaximumVolumeSliderImage:[UIImage imageNamed:@"statusBackground@2x.png"] forState:UIControlStateNormal];
    [myVolumeView sizeToFit];
    [volumeHolder addSubview:myVolumeView];
    isVoiceSliderShow = NO;
    volumeHolder.hidden = !isVoiceSliderShow;
}



@end

