/*
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import <Foundation/Foundation.h>
#import "CMISBindingSession.h"
#import "CMISHttpUtil.h"
#import "CMISHttpResponse.h"

@protocol CMISHttpRequestDelegate <NSObject>

- (void)cancel;

+ (id<CMISHttpRequestDelegate>)startRequestWithURL:(NSURL *)url
                                        httpMethod:(CMISHttpRequestMethod)httpRequestMethod
                                       requestBody:(NSData*)requestBody
                                           headers:(NSDictionary*)additionalHeaders
                                           session:(CMISBindingSession *)session
                                   completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock;

@optional
+ (id<CMISHttpRequestDelegate>)startDownloadRequestWithURL:(NSURL*)url
                                                httpMethod:(CMISHttpRequestMethod)httpRequestMethod
                                              outputStream:(id)outputStream
                                                   session:(CMISBindingSession *)session
                                             bytesExpected:(unsigned long long)bytesExpected
                                           completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
                                             progressBlock:(void (^)(unsigned long long bytesDownloaded, unsigned long long bytesTotal))progressBlock;

+ (id<CMISHttpRequestDelegate>)startUploadRequestWithURL:(NSURL *)url
                                              httpMethod:(CMISHttpRequestMethod)httpRequestMethod
                                             inputStream:(id)inputStream
                                                 headers:(NSDictionary*)addionalHeaders
                                                 session:(CMISBindingSession *)session
                                           bytesExpected:(unsigned long long)bytesExpected
                                         completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
                                           progressBlock:(void (^)(unsigned long long bytesUploaded, unsigned long long bytesTotal))progressBlock;
@end

