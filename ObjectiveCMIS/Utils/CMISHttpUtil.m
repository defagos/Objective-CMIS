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

#import "CMISHttpUtil.h"
#import "CMISAuthenticationProvider.h"
#import "CMISErrors.h"
#import "CMISHttpRequest.h"
#import "CMISHttpDownloadRequest.h"
#import "CMISHttpUploadRequest.h"
#import "CMISRequest.h"
#import "CMISSessionParameters.h"
#import "CMISHttpRequestDelegate.h"
#import "CMISNetworkProvider.h"

@implementation HttpUtil

#pragma mark block based methods

+ (void)invoke:(NSURL *)url
withHttpMethod:(CMISHttpRequestMethod)httpRequestMethod
   withSession:(CMISBindingSession *)session
          body:(NSData *)body
       headers:(NSDictionary *)additionalHeaders
completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
{
    CMISNetworkProvider *provider = [session objectForKey:kCMISSessionNetworkProvider];
    Class requestClass = provider.requestClass;
    if (nil != requestClass)
    {
        [requestClass startRequestWithURL:url
                               httpMethod:httpRequestMethod
                              requestBody:body
                                  headers:additionalHeaders
                                  session:session
                          completionBlock:completionBlock];
    }
}

+ (void)invoke:(NSURL *)url
withHttpMethod:(CMISHttpRequestMethod)httpRequestMethod
   withSession:(CMISBindingSession *)session
   inputStream:(NSInputStream *)inputStream
       headers:(NSDictionary *)additionalHeaders
completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
{
    CMISNetworkProvider *provider = [session objectForKey:kCMISSessionNetworkProvider];
    Class uploadClass = provider.uploadRequestClass;
    if (nil != uploadClass)
    {
        [uploadClass startUploadRequestWithURL:url
                                    httpMethod:httpRequestMethod
                                   inputStream:inputStream
                                       headers:additionalHeaders
                                       session:session
                                 bytesExpected:0
                               completionBlock:completionBlock
                                 progressBlock:nil];
        
    }
}

+ (void)invoke:(NSURL *)url
withHttpMethod:(CMISHttpRequestMethod)httpRequestMethod
   withSession:(CMISBindingSession *)session
   inputStream:(NSInputStream *)inputStream
       headers:(NSDictionary *)additionalHeaders
 bytesExpected:(unsigned long long)bytesExpected
completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
 progressBlock:(void (^)(unsigned long long bytesDownloaded, unsigned long long bytesTotal))progressBlock
 requestObject:(CMISRequest *)requestObject
{
    CMISNetworkProvider *provider = [session objectForKey:kCMISSessionNetworkProvider];
    Class uploadClass = provider.uploadRequestClass;
    if (nil != uploadClass && !requestObject.isCancelled)
    {
        id<CMISHttpRequestDelegate> uploadRequest = [uploadClass startUploadRequestWithURL:url
                                                                                httpMethod:httpRequestMethod
                                                                               inputStream:inputStream
                                                                                   headers:additionalHeaders
                                                                                   session:session
                                                                             bytesExpected:bytesExpected
                                                                           completionBlock:completionBlock
                                                                             progressBlock:progressBlock];
        requestObject.httpRequest = uploadRequest;
    }
    else
    {
        if (completionBlock)
        {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeCancelled
                                             withDetailedDescription:@"Request was cancelled"]);
        }
    }
}

+ (void)invoke:(NSURL *)url
   withHttpMethod:(CMISHttpRequestMethod)httpRequestMethod
      withSession:(CMISBindingSession *)session
     outputStream:(NSOutputStream *)outputStream
    bytesExpected:(unsigned long long)bytesExpected
  completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
    progressBlock:(void (^)(unsigned long long bytesDownloaded, unsigned long long bytesTotal))progressBlock
    requestObject:(CMISRequest *)requestObject
{
    CMISNetworkProvider *provider = [session objectForKey:kCMISSessionNetworkProvider];
    Class downloadClass = provider.downloadRequestClass;
    if (nil != downloadClass && !requestObject.isCancelled)
    {
        id<CMISHttpRequestDelegate> downloadRequest = [downloadClass startDownloadRequestWithURL:url
                                                                                      httpMethod:httpRequestMethod
                                                                                    outputStream:outputStream
                                                                                         session:session
                                                                                   bytesExpected:bytesExpected
                                                                                 completionBlock:completionBlock
                                                                                   progressBlock:progressBlock];
        requestObject.httpRequest = downloadRequest;
    }
    else
    {
        if (completionBlock)
        {
            completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeCancelled
                                             withDetailedDescription:@"Request was cancelled"]);
        }
        
    }
}

+ (void)invokeGET:(NSURL *)url
      withSession:(CMISBindingSession *)session
  completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
{
    return [self invoke:url
         withHttpMethod:HTTP_GET
            withSession:session
                   body:nil
                headers:nil
        completionBlock:completionBlock];
}

+ (void)invokePOST:(NSURL *)url
       withSession:(CMISBindingSession *)session
              body:(NSData *)body
           headers:(NSDictionary *)additionalHeaders
   completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
{
    return [self invoke:url
         withHttpMethod:HTTP_POST
            withSession:session
                   body:body
                headers:additionalHeaders
        completionBlock:completionBlock];
}

+ (void)invokePUT:(NSURL *)url
      withSession:(CMISBindingSession *)session
             body:(NSData *)body
          headers:(NSDictionary *)additionalHeaders
  completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
{
    return [self invoke:url
         withHttpMethod:HTTP_PUT
            withSession:session
                   body:body
                headers:additionalHeaders
        completionBlock:completionBlock];
}

+ (void)invokeDELETE:(NSURL *)url
         withSession:(CMISBindingSession *)session
     completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
{
    return [self invoke:url
         withHttpMethod:HTTP_DELETE
            withSession:session
                   body:nil
                headers:nil
        completionBlock:completionBlock];
}
@end


