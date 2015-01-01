//
//  SPBreakpointsDownload.h
//  ESignature_HD
//
//  Created by SimonDing on 14-9-24.
//  Copyright (c) 2014年 china-sss. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MKNetworkOperation.h"

@interface SPBreakpointsDownload : MKNetworkOperation
@property (nonatomic)NSInteger downloadTag;//下载的标签
@property (nonatomic, strong)NSString *downloadTempPath;//下载的文件的临时路径
+ (SPBreakpointsDownload *) operationWithURLString:(NSString *) urlString
                                            params:(NSMutableDictionary *) body
                                        httpMethod:(NSString *)method
                                      tempFilePath:(NSString *)tempFilePath
                                  downloadFilePath:(NSString *)downloadFilePath
                                       rewriteFile:(BOOL)rewrite;
@end
