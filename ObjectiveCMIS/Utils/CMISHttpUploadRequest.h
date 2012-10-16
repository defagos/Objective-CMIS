//
//  CMISHttpUploadRequest.h
//  ObjectiveCMIS
//
//  Created by Eberlein, Peter on 12.10.12.
//  Copyright (c) 2012 Alfresco. All rights reserved.
//

#import "CMISHttpRequest.h"

@interface CMISHttpUploadRequest : CMISHttpRequest

@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, assign) unsigned long long bytesExpected; // optional; if not set, expected content length from HTTP header is used
@property (nonatomic, readonly) unsigned long long bytesUploaded;

+ (CMISHttpUploadRequest*)startRequest:(NSMutableURLRequest *)urlRequest
                        withHttpMethod:(CMISHttpRequestMethod)httpRequestMethod
                           inputStream:(NSInputStream*)inputStream
                               headers:(NSDictionary*)addionalHeaders
                         bytesExpected:(unsigned long long)bytesExpected
                       completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
                         progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock;

- (id)initWithHttpMethod:(CMISHttpRequestMethod)httpRequestMethod
         completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
           progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock;

@end
