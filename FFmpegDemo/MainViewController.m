//
//  MainViewController.m
//  FFmpegDemo
//
//  Created by chang on 14-7-8.
//  Copyright (c) 2014年 chang. All rights reserved.
//

#import "MainViewController.h"
#import "KxMovieViewController.h"
#import "MKNetworkOperation.h"
#import "MKNetworkEngine.h"
#import "SPBreakpointsDownload.h"

/*
#ifdef DEBUG
#define LoggerApp(level, ...)           LogMessageF(__FILE__, __LINE__, __FUNCTION__, @"App", level, __VA_ARGS__)
#else
#define LoggerApp(level, ...)           while(0) {}
#endif
*/




@interface MainViewController ()
{
    NSMutableArray *_localMovies;
    NSArray *_remoteMovies;
    
    NSString *downPath;
    NSString *downTempPath ;
    NSMutableDictionary *params;
    NSString * remotePath ;
}
@property (strong, nonatomic) UITableView *tableView;
@property ( nonatomic) long long expectedContentLength; // 下载文件总大小

@end

@implementation MainViewController

- (id)init
{
    self = [super init];
    if (self) {
        self.title = @"FFmpegPlayer";
        self.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemFeatured tag: 0];
        
        _remoteMovies = @[@"http://localhost2:44447/huidaoguoqu.mp4",@"http://media.china-sss.com/springairlines/intospring/xuanchuanpian.flv",
                          @"http://media.china-sss.com/springairlines/intospring/201354biaoyan.flv",
                          @"http://media.china-sss.com/springairlines/intospring/2013waijibainian.flv",
                          @"http://media.china-sss.com/springairlines/intospring/30zhounian.flv",
                          @"http://192.168.210.52:8085/spring3g/Ulysses.avi",
                          @"http://192.168.210.52:8085/spring3g/201354biaoyan.flv",
                          @"http://livecdn.cdbs.com.cn/fmvideo.flv",
                          @"http://192.168.210.52:8085/spring3g/huidaoguoqu.mp4"
                          ];
        
    }
    return self;
}


- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.backgroundColor = [UIColor whiteColor];
    //self.tableView.backgroundView = [[UIImageView alloc] initWithImage:image];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    
    [self.view addSubview:self.tableView];
}

- (BOOL)prefersStatusBarHidden { return YES; }

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    #ifdef DEBUG_AUTOPLAY
    [self performSelector:@selector(launchDebugTest) withObject:nil afterDelay:0.5];
    #endif
}

- (void)launchDebugTest
{
    [self tableView:self.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:4
                                                                              inSection:1]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self reloadMovies];
    [self.tableView reloadData];
}



- (void) reloadMovies
{
    NSMutableArray *ma = [NSMutableArray array];
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString *folder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                            NSUserDomainMask,
                                                            YES) lastObject];
    NSLog(@"------folder------%@",folder);
    NSString * saveFolder = [NSString stringWithFormat:@"%@/DownloadedFiles",folder];
    
    NSArray *contents = [fm contentsOfDirectoryAtPath:saveFolder error:nil];
    
    for (NSString *filename in contents) {
        
        if (filename.length > 0 &&
            [filename characterAtIndex:0] != '.') {
            
            NSString *path = [saveFolder stringByAppendingPathComponent:filename];
            NSDictionary *attr = [fm attributesOfItemAtPath:path error:nil];
            if (attr) {
                id fileType = [attr valueForKey:NSFileType];
                if ([fileType isEqual: NSFileTypeRegular] ||
                    [fileType isEqual: NSFileTypeSymbolicLink]) {
                    
                    NSString *ext = path.pathExtension.lowercaseString;
                    
                    if ([ext isEqualToString:@"mp3"] ||
                        [ext isEqualToString:@"caff"]||
                        [ext isEqualToString:@"aiff"]||
                        [ext isEqualToString:@"ogg"] ||
                        [ext isEqualToString:@"wma"] ||
                        [ext isEqualToString:@"m4a"] ||
                        [ext isEqualToString:@"m4v"] ||
                        [ext isEqualToString:@"wmv"] ||
                        [ext isEqualToString:@"3gp"] ||
                        [ext isEqualToString:@"mp4"] ||
                        [ext isEqualToString:@"mov"] ||
                        [ext isEqualToString:@"avi"] ||
                        [ext isEqualToString:@"mkv"] ||
                        [ext isEqualToString:@"mpeg"]||
                        [ext isEqualToString:@"mpg"] ||
                        [ext isEqualToString:@"flv"] ||
                        [ext isEqualToString:@"vob"]) {
                        
                        [ma addObject:path];
                    }
                }
            }
        }
    }
    
    // Add all the movies present in the app bundle.
    NSBundle *bundle = [NSBundle mainBundle];
    [ma addObjectsFromArray:[bundle pathsForResourcesOfType:@"mp4" inDirectory:@"SampleMovies"]];
    [ma addObjectsFromArray:[bundle pathsForResourcesOfType:@"mov" inDirectory:@"SampleMovies"]];
    [ma addObjectsFromArray:[bundle pathsForResourcesOfType:@"m4v" inDirectory:@"SampleMovies"]];
    [ma addObjectsFromArray:[bundle pathsForResourcesOfType:@"wav" inDirectory:@"SampleMovies"]];
    
    [ma sortedArrayUsingSelector:@selector(compare:)];
    
    _localMovies = ma;
    //_localMovies = [NSMutableArray arrayWithArray:ma];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0:     return @"Remote";
        case 1:     return @"Local";
    }
    return @"";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0:     return _remoteMovies.count;
        case 1:     return _localMovies.count;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"Cell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:cellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    NSString *path;
    
    if (indexPath.section == 0) {
        
        path = _remoteMovies[indexPath.row];
        
    } else {
        
        path = _localMovies[indexPath.row];
    }
    
    cell.textLabel.text = path.lastPathComponent;
    return cell;
}

#pragma mark - Table view delegate

-(BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath{

    if (indexPath.section ==0) {
        return NO;
    }
    return YES;
}


-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath{


    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        NSString *path;
        if (indexPath.section == 1) {
             path = _localMovies[indexPath.row];
             [_localMovies removeObjectAtIndex:indexPath.row];
            [tableView beginUpdates];
           
            NSFileManager *defauleManager = [NSFileManager defaultManager];
            [defauleManager removeItemAtPath:path error:nil];
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:indexPath.row inSection:1]] withRowAnimation:UITableViewRowAnimationFade];
            
            [tableView endUpdates];
        }
        
        
    }else if (editingStyle == UITableViewCellEditingStyleInsert){
    
    }else {
    
    }

}



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *path;
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    KxMovieViewController *vc;
    if (indexPath.section == 0) {
        
        if (indexPath.row >= _remoteMovies.count) return;
        remotePath = _remoteMovies[indexPath.row];
        [self downloadFile:remotePath];
        
        path = [self createfileSavePath:path isTempPath:YES];;// 如果临时文件存在，不读网络数据，读临时文件，实现边播放边缓冲
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
         if ([fileManager fileExistsAtPath:path]) {
                vc = [KxMovieViewController movieViewControllerWithContentPath:path parameters:parameters];
                vc.expectedContentLength = self.expectedContentLength;
                vc.remotePath = remotePath;
                vc.params = params;
                vc.tempFilePath = downTempPath;
                vc.saveFilePath = downPath;
         }
    } else {
        
        if (indexPath.row >= _localMovies.count) return;
        path = _localMovies[indexPath.row];
        vc = [KxMovieViewController movieViewControllerWithContentPath:path parameters:parameters];
    }
    
    // increase buffering for .wmv, it solves problem with delaying audio frames
    if ([path.pathExtension isEqualToString:@"wmv"])
        parameters[KxMovieParameterMinBufferedDuration] = @(5.0);
    
    // disable deinterlacing for iPhone, because it's complex operation can cause stuttering
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        parameters[KxMovieParameterDisableDeinterlacing] = @(YES);
    
    // disable buffering
    //parameters[KxMovieParameterMinBufferedDuration] = @(0.0f);
    //parameters[KxMovieParameterMaxBufferedDuration] = @(0.0f);
    

    // NSString *tempFilePath = [self createfileSavePath:path isTempPath:YES];
    
    
    if (indexPath.section ==0) {
        vc.isShowDownloadBtn = YES;
    }else{
        vc.isShowDownloadBtn = NO;
    }

    [self presentViewController:vc animated:YES completion:nil];
    //[self.navigationController pushViewController:vc animated:YES];
    
    //LoggerApp(1, @"Playing a movie: %@", path);
}


#pragma mark- 下载文件并保存至本地
-(void)downloadFile:(NSString *)path{
    
   downPath = [self createfileSavePath:path isTempPath:NO];
    downTempPath = [self createfileSavePath:path isTempPath:YES];
    // MKNetworkEngine *downloadOperation= [MainViewController downloadFatAssFileFrom:path toFile:downloadPath toTempFile:downloadTempPath];
    
    params = [[NSMutableDictionary alloc] init];
    [params setObject:@"YES" forKey:@"isBufferDownload"];// 是否缓冲下载
    SPBreakpointsDownload *downloadOperation= [SPBreakpointsDownload operationWithURLString:path
                                                                                     params:params
                                                                                 httpMethod:@"GET"
                                                                               tempFilePath:downTempPath
                                                                           downloadFilePath:downPath
                                                                                rewriteFile:NO];
    
    self.expectedContentLength = downloadOperation.readonlyResponse.expectedContentLength;
    

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

+(MKNetworkOperation*) downloadFatAssFileFrom:(NSString*) remoteURL toFile:(NSString*) filePath toTempFile:(NSString*) tempPath{
    MKNetworkEngine *engine = [[MKNetworkEngine alloc] initWithHostName:@"" customHeaderFields:nil];
    MKNetworkOperation *op = [engine operationWithURLString:remoteURL
                                                     params:nil
                                                 httpMethod:@"GET"];
    
    // [op addDownloadStream:[NSOutputStream outputStreamToFileAtPath:filePath
    //                                                        append:YES]];
    [op addDownloadStream:[NSOutputStream outputStreamToFileAtPath:tempPath append:YES]];
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


@end





































