//
//  SPBreakpointsUpload.m
//  ESignature_HD
//
//  Created by SimonDing on 14-9-30.
//  Copyright (c) 2014年 china-sss. All rights reserved.
//

#import "SPBreakpointsUpload.h"


@implementation SPBreakpointsUpload
/*
- (NSData*) bodyData {
    NSMutableData *body = [NSMutableData data];
    if (self.filesToBePosted.count == 0) {
        NSString *boundary = @"0xKhTmLbOuNdArY";
        [self.fieldsToBePosted enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            
            NSString *thisFieldString = [NSString stringWithFormat:
                                         @"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n%@",
                                         boundary, key, obj];
            
            [body appendData:[thisFieldString dataUsingEncoding:[self stringEncoding]]];
            [body appendData:[@"\r\n" dataUsingEncoding:[self stringEncoding]]];
        }];
        [body appendData: [[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:self.stringEncoding]];
    }
    else {
        PKMultipartInputStream *mutiBody = [[PKMultipartInputStream alloc] init];
        [self.fieldsToBePosted enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [mutiBody addPartWithName:key string:obj];
        }];
        
        [self.filesToBePosted enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSDictionary *thisFile = (NSDictionary*) obj;
            [mutiBody addPartWithName:thisFile[@"name"] path:thisFile[@"filepath"]];
        }];
        [self.request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", [mutiBody boundary]] forHTTPHeaderField:@"Content-Type"];
        [self.request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[mutiBody length]] forHTTPHeaderField:@"Content-Length"];
        [self.request setHTTPBodyStream:mutiBody];
        body = nil;
    }
    return body;
}
 */
@end