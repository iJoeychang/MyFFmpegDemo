//
//  BaseEngine.m
//  NewNetworkDemo
//
//  Created by Simon.Ding on 14-3-20.
//  Copyright (c) 2014年 china-sss. All rights reserved.
//

#import "BaseEngine.h"

@implementation BaseEngine
#pragma mark -
#pragma mark - Property Methods
//获取默认设置的实例
- (id)initWithDefaultSetting
{
    self = [super initWithHostName:@"http://baidu.com:8080/"];
    return self;
}
#pragma mark -
#pragma mark - Rewrite Methods
-(MKNetworkOperation*) operationWithURLString:(NSString*) urlString {
    
    return [self operationWithURLString:urlString params:nil httpMethod:@"POST"];
}

-(MKNetworkOperation*) operationWithURLString:(NSString*) urlString
                                       params:(NSDictionary*) body {
    
    return [self operationWithURLString:urlString params:body httpMethod:@"POST"];
}
@end
