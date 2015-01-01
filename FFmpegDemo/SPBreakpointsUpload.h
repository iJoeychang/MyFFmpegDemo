//
//  SPBreakpointsUpload.h
//  ESignature_HD
//
//  Created by SimonDing on 14-9-30.
//  Copyright (c) 2014年 china-sss. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MKNetworkOperation.h"
@interface SPBreakpointsUpload : MKNetworkOperation
@property (nonatomic)NSInteger uploadTag;//上传的标签
@property (nonatomic, strong)NSString *uploadFilePath;//上传文件的路径
@property (nonatomic, strong)NSString *uploadURL;//上传URL
@property (nonatomic, strong)NSDictionary *uploadParams;//上传需要的参数
@property (nonatomic) NSInteger startIndex;
@end
