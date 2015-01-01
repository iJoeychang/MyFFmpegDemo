//
//  SPBreakpointsDownload.m
//  ESignature_HD
//
//  Created by SimonDing on 14-9-24.
//  Copyright (c) 2014年 china-sss. All rights reserved.
//

#import "SPBreakpointsDownload.h"


@implementation SPBreakpointsDownload



+ (SPBreakpointsDownload *) operationWithURLString:(NSString *) urlString
                                            params:(NSMutableDictionary *) body
                                        httpMethod:(NSString *)method
                                      tempFilePath:(NSString *)tempFilePath
                                  downloadFilePath:(NSString *)downloadFilePath
                                       rewriteFile:(BOOL)rewrite;
{
    // 获得临时文件的路径
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableDictionary *newHeadersDict = [[NSMutableDictionary alloc] init];
    
    // 如果是重新下载，就要删除之前下载过的文件
    if (rewrite && [fileManager fileExistsAtPath:tempFilePath]) {
        NSError *error = nil;
        [fileManager removeItemAtPath:tempFilePath error:&error];
        if (error) {
            NSLog(@"%@ file remove failed!\nError:%@", tempFilePath, error);
        }
    }
    if(rewrite && [fileManager fileExistsAtPath:downloadFilePath]){
        NSError *error = nil;
        [fileManager removeItemAtPath:downloadFilePath error:&error];
        if (error) {
            NSLog(@"%@ file remove failed!\nError:%@", downloadFilePath, error);
        }
    }
    
    NSString *userAgentString = [NSString stringWithFormat:@"%@/%@",
                                 [[[NSBundle mainBundle] infoDictionary]
                                  objectForKey:(NSString *)kCFBundleNameKey],
                                 [[[NSBundle mainBundle] infoDictionary]
                                  objectForKey:(NSString *)kCFBundleVersionKey]];
    [newHeadersDict setObject:userAgentString forKey:@"User-Agent"];
    
    // 判断之前是否下载过 如果有下载重新构造Header
    if ([fileManager fileExistsAtPath:tempFilePath]) {
        NSError *error = nil;
        unsigned long long fileSize = [[fileManager attributesOfItemAtPath:tempFilePath
                                                                     error:&error]
                                       fileSize];
        if (error) {
            NSLog(@"get %@ fileSize failed!\nError:%@", tempFilePath, error);
        }
        NSString *headerRange = [NSString stringWithFormat:@"bytes=%llu-", fileSize];
        [newHeadersDict setObject:headerRange forKey:@"Range"];
        
    }
    
    // 初始化opertion
    SPBreakpointsDownload *operation = [[SPBreakpointsDownload alloc] initWithURLString:urlString
                                                                                 params:body
                                                                             httpMethod:method];
    
    [operation addDownloadStream:[NSOutputStream outputStreamToFileAtPath:tempFilePath append:YES]];
    [operation addDownloadStream:[NSOutputStream outputStreamToFileAtPath:downloadFilePath append:YES]];
    [operation addHeaders:newHeadersDict];
    return operation;
}




@end
