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

#pragma mark HTTPRequest declaration

@interface HTTPRequest : NSObject <NSURLConnectionDataDelegate>

@property (nonatomic, assign) CMISHttpRequestMethod requestMethod;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, strong) NSHTTPURLResponse *response;
@property (nonatomic, copy) CMISHttpResponseCompletionBlock completionBlock;
@property (nonatomic, copy) CMISErrorFailureBlock failureBlock;

+ (void)startRequest:(NSURLRequest*)urlRequest 
      withHttpMethod:(CMISHttpRequestMethod)httpRequestMethod 
     completionBlock:(CMISHttpResponseCompletionBlock)completionBlock 
        failureBlock:(CMISErrorFailureBlock)failureBlock;

@end


@implementation HttpUtil

#pragma mark synchronous methods

+ (BOOL)checkStatusCodeForResponse:(HTTPResponse *)response withHttpRequestMethod:(CMISHttpRequestMethod)httpRequestMethod error:(NSError **)error
{
    if ( (httpRequestMethod == HTTP_GET && response.statusCode != 200)
      || (httpRequestMethod == HTTP_POST && response.statusCode != 201)
      || (httpRequestMethod == HTTP_DELETE && response.statusCode != 204)
      || (httpRequestMethod == HTTP_PUT && ((response.statusCode < 200 || response.statusCode > 299))))
    {
        NSString *errorContent = [[NSString alloc] initWithData:response.data encoding:NSUTF8StringEncoding];
        log(@"Error content: %@", errorContent);

        if (error) {
            switch (response.statusCode)
            {
                case 400:
                    *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:response.statusCodeMessage];
                    break;
                case 401:
                    *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeUnauthorized withDetailedDescription:response.statusCodeMessage];
                    break;
                case 403:
                    *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodePermissionDenied withDetailedDescription:response.statusCodeMessage];
                    break;
                case 404:
                    *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeObjectNotFound withDetailedDescription:response.statusCodeMessage];
                    break;
                case 405:
                    *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeNotSupported withDetailedDescription:response.statusCodeMessage];
                    break;
                case 407:
                    *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeProxyAuthentication withDetailedDescription:response.statusCodeMessage];
                    break;
                case 409:
                    // TODO: need more if-else here, see opencmis impl
                    *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeConstraint withDetailedDescription:response.statusCodeMessage];
                    break;
                default:
                    *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeRuntime withDetailedDescription:response.statusCodeMessage];
            }
        }
        return NO;
    } else {
        return YES;
    }
}

#pragma mark block based methods

+ (void)invoke:(NSURL *)url withHttpMethod:(CMISHttpRequestMethod)httpRequestMethod withSession:(CMISBindingSession *)session body:(NSData *)body headers:(NSDictionary *)additionalHeaders 
completionBlock:(CMISHttpResponseCompletionBlock)completionBlock failureBlock:(CMISErrorFailureBlock)failureBlock

{
    NSMutableURLRequest *urlRequest = [self createRequestForUrl:url withHttpMethod:[self stringForHttpRequestMethod:httpRequestMethod] usingSession:session];
    
    if (body)
    {
        [urlRequest setHTTPBody:body];
    }
    
    if (additionalHeaders)
    {
        [self addHeaders:additionalHeaders toURLRequest:urlRequest];
    }
    
    [HTTPRequest startRequest:urlRequest withHttpMethod:httpRequestMethod completionBlock:completionBlock failureBlock:failureBlock];
}

+ (void)invoke:(NSURL *)url withHttpMethod:(CMISHttpRequestMethod)httpRequestMethod withSession:(CMISBindingSession *)session bodyStream:(NSInputStream *)bodyStream headers:(NSDictionary *)additionalHeaders 
completionBlock:(CMISHttpResponseCompletionBlock)completionBlock failureBlock:(CMISErrorFailureBlock)failureBlock
{
    NSMutableURLRequest *urlRequest = [self createRequestForUrl:url withHttpMethod:[self stringForHttpRequestMethod:httpRequestMethod] usingSession:session];
    
    if (bodyStream)
    {
        [urlRequest setHTTPBodyStream:bodyStream];
    }
    
    if (additionalHeaders)
    {
        [self addHeaders:additionalHeaders toURLRequest:urlRequest];
    }
    
    [HTTPRequest startRequest:urlRequest withHttpMethod:httpRequestMethod completionBlock:completionBlock failureBlock:failureBlock];
}

+ (void)invokeGET:(NSURL *)url withSession:(CMISBindingSession *)session 
  completionBlock:(CMISHttpResponseCompletionBlock)completionBlock failureBlock:(CMISErrorFailureBlock)failureBlock
{
    return [self invoke:url withHttpMethod:HTTP_GET withSession:session body:nil headers:nil completionBlock:completionBlock failureBlock:failureBlock];
}

+ (void)invokePOST:(NSURL *)url withSession:(CMISBindingSession *)session body:(NSData *)body 
   completionBlock:(CMISHttpResponseCompletionBlock)completionBlock failureBlock:(CMISErrorFailureBlock)failureBlock
{
    return [self invokePOST:url withSession:session body:body headers:nil completionBlock:completionBlock failureBlock:failureBlock];
}

+ (void)invokePOST:(NSURL *)url withSession:(CMISBindingSession *)session body:(NSData *)body headers:(NSDictionary *)additionalHeaders 
   completionBlock:(CMISHttpResponseCompletionBlock)completionBlock failureBlock:(CMISErrorFailureBlock)failureBlock
{
    return [self invoke:url withHttpMethod:HTTP_POST withSession:session body:body headers:additionalHeaders completionBlock:completionBlock failureBlock:failureBlock];
}

+ (void)invokePOST:(NSURL *)url withSession:(CMISBindingSession *)session bodyStream:(NSInputStream *)bodyStream headers:(NSDictionary *)additionalHeaders 
   completionBlock:(CMISHttpResponseCompletionBlock)completionBlock failureBlock:(CMISErrorFailureBlock)failureBlock
{
    return [self invoke:url withHttpMethod:HTTP_POST withSession:session bodyStream:bodyStream headers:additionalHeaders completionBlock:completionBlock failureBlock:failureBlock];
}

+ (void)invokeDELETE:(NSURL *)url withSession:(CMISBindingSession *)session 
     completionBlock:(CMISHttpResponseCompletionBlock)completionBlock failureBlock:(CMISErrorFailureBlock)failureBlock
{
    return [self invoke:url withHttpMethod:HTTP_DELETE withSession:session bodyStream:nil headers:nil completionBlock:completionBlock failureBlock:failureBlock];
}

+ (void)invokePUT:(NSURL *)url withSession:(CMISBindingSession *)session bodyStream:(NSInputStream *)bodyStream headers:(NSDictionary *)additionalHeaders 
  completionBlock:(CMISHttpResponseCompletionBlock)completionBlock failureBlock:(CMISErrorFailureBlock)failureBlock
{
    return [self invoke:url withHttpMethod:HTTP_PUT withSession:session bodyStream:bodyStream headers:additionalHeaders completionBlock:completionBlock failureBlock:failureBlock];
}

+ (void)invokePUT:(NSURL *)url withSession:(CMISBindingSession *)session body:(NSData *)body headers:(NSDictionary *)additionalHeaders 
  completionBlock:(CMISHttpResponseCompletionBlock)completionBlock failureBlock:(CMISErrorFailureBlock)failureBlock
{
    return [self invoke:url withHttpMethod:HTTP_PUT withSession:session body:body headers:additionalHeaders completionBlock:completionBlock failureBlock:failureBlock];
}


#pragma mark asynchronous methods

+ (void)invokeAsynchronous:(NSURL *)url withHttpMethod:(CMISHttpRequestMethod)httpRequestMethod
                withSession:(CMISBindingSession *)session
                bodyStream:(NSInputStream *)bodyStream headers:(NSDictionary *)additionalHeaders
                withDelegate:(id <NSURLConnectionDataDelegate>)delegate
{
    NSMutableURLRequest *request = [self createRequestForUrl:url withHttpMethod:[self stringForHttpRequestMethod:httpRequestMethod] usingSession:session];

    if (bodyStream)
    {
        [request setHTTPBodyStream:bodyStream];
    }

    if (additionalHeaders)
    {
        [self addHeaders:additionalHeaders toURLRequest:request];
    }

    // See also: http://www.ddeville.me/2011/12/broken-NSURLConnection-on-ios/
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
//        [connection setDelegateQueue:[NSOperationQueue mainQueue]];
        [connection start];
    }];
}

+ (void)invokeAsynchronous:(NSURL *)url withHttpMethod:(CMISHttpRequestMethod)httpRequestMethod
                withSession:(CMISBindingSession *)session
                body:(NSData *)body headers:(NSDictionary *)additionalHeaders
                withDelegate:(id <NSURLConnectionDataDelegate>)delegate
{
    NSMutableURLRequest *request = [self createRequestForUrl:url withHttpMethod:[self stringForHttpRequestMethod:httpRequestMethod] usingSession:session];

    if (body)
    {
        [request setHTTPBody:body];
    }

    if (additionalHeaders)
    {
        [self addHeaders:additionalHeaders toURLRequest:request];
    }

    NSURLConnection *connection = [NSURLConnection connectionWithRequest:request delegate:delegate];
    [connection start];
}

+ (void)invokeGETAsynchronous:(NSURL *)url withSession:(CMISBindingSession *)session withDelegate:(id<NSURLConnectionDataDelegate>)delegate
{
    [self invokeAsynchronous:url withHttpMethod:HTTP_GET withSession:session body:nil headers:nil withDelegate:delegate];
}

+ (void)invokePOSTAsynchronous:(NSURL *)url withSession:(CMISBindingSession *)session body:(NSData *)body withDelegate:(id <NSURLConnectionDataDelegate>)delegate
{
    [self invokePOSTAsynchronous:url withSession:session body:body headers:nil withDelegate:delegate];
}

+ (void)invokePOSTAsynchronous:(NSURL *)url withSession:(CMISBindingSession *)session body:(NSData *)body
                       headers:(NSDictionary *)additionalHeaders withDelegate:(id <NSURLConnectionDataDelegate>)delegate
{
    [self invokeAsynchronous:url withHttpMethod:HTTP_POST withSession:session body:body headers:additionalHeaders withDelegate:delegate];
}

+ (void)invokePOSTAsynchronous:(NSURL *)url withSession:(CMISBindingSession *)session bodyStream:(NSInputStream *)bodyStream
                       headers:(NSDictionary *)additionalHeaders withDelegate:(id <NSURLConnectionDataDelegate>)delegate
{
    [self invokeAsynchronous:url withHttpMethod:HTTP_POST withSession:session bodyStream:bodyStream headers:additionalHeaders withDelegate:delegate];
}

+ (void)invokePUTAsynchronous:(NSURL *)url withSession:(CMISBindingSession *)session bodyStream:(NSInputStream *)bodyStream
                      headers:(NSDictionary *)additionalHeaders withDelegate:(id <NSURLConnectionDataDelegate>)delegate
{
    [self invokeAsynchronous:url withHttpMethod:HTTP_PUT withSession:session bodyStream:bodyStream headers:additionalHeaders withDelegate:delegate];
}


#pragma mark Helper methods

+ (NSMutableURLRequest *)createRequestForUrl:(NSURL *)url withHttpMethod:(NSString *)httpMethod usingSession:(CMISBindingSession *)session
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                        cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                        timeoutInterval:60];
    [request setHTTPMethod:httpMethod];
    log(@"HTTP %@: %@", httpMethod, [url absoluteString]);

    id <CMISAuthenticationProvider> authenticationProvider = session.authenticationProvider;
    NSDictionary *headers = authenticationProvider.httpHeadersToApply;
    if (headers)
    {
        [self addHeaders:headers toURLRequest:request];
    }

    return request;
}

+ (void)addHeaders:(NSDictionary *)headers toURLRequest:(NSMutableURLRequest *)urlRequest
{
    for (NSString *headerName in headers)
    {
        [urlRequest addValue:[headers objectForKey:headerName] forHTTPHeaderField:headerName];
    }
}

+ (NSString *)stringForHttpRequestMethod:(CMISHttpRequestMethod)httpRequestMethod
{
    switch (httpRequestMethod)
    {
        case HTTP_GET:
            return @"GET";
        case HTTP_POST:
            return @"POST";
        case HTTP_DELETE:
            return @"DELETE";
        case HTTP_PUT:
            return @"PUT";
    }

    log(@"Could not find matching http request for %u", httpRequestMethod);
    return nil;
}

@end


#pragma mark HTTPRequest implementation

@implementation HTTPRequest

@synthesize requestMethod = _requestMethod;
@synthesize data = _data;
@synthesize response = _response;
@synthesize completionBlock = _completionBlock;
@synthesize failureBlock = _failureBlock;
@synthesize connection = _connection;

+ (void)startRequest:(NSURLRequest *)urlRequest 
      withHttpMethod:(CMISHttpRequestMethod)httpRequestMethod 
     completionBlock:(CMISHttpResponseCompletionBlock)completionBlock 
        failureBlock:(CMISErrorFailureBlock)failureBlock
{
    HTTPRequest *httpRequest = [[HTTPRequest alloc] init];
    httpRequest.requestMethod = httpRequestMethod;
    httpRequest.completionBlock = completionBlock;
    httpRequest.failureBlock = failureBlock;
    httpRequest.connection = [NSURLConnection connectionWithRequest:urlRequest delegate:httpRequest];
    if (httpRequest.connection == nil) {
        if (httpRequest.failureBlock) {
            NSString *detailedDescription = [NSString stringWithFormat:@"Could not create connection to %@", urlRequest.URL];
            NSError *cmisError = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeConnection withDetailedDescription:detailedDescription];
            httpRequest.failureBlock(cmisError);
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.data = [[NSMutableData alloc] init];
    if ([response isKindOfClass:NSHTTPURLResponse.class]) {
        self.response = (NSHTTPURLResponse*)response;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.data appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (self.failureBlock)
    {
        NSError *cmisError = [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeConnection];
        self.failureBlock(cmisError);
    }

    self.completionBlock = nil;
    self.failureBlock = nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    HTTPResponse *httpResponse = [HTTPResponse responseUsingURLHTTPResponse:self.response andData:self.data];

    NSError *cmisError = nil;
    if (![HttpUtil checkStatusCodeForResponse:httpResponse withHttpRequestMethod:self.requestMethod error:&cmisError]) {
        if (self.failureBlock) {
            self.failureBlock(cmisError);
        }
    } else {
        if (self.completionBlock) {
            self.completionBlock(httpResponse);
        }
    }
    
    self.completionBlock = nil;
    self.failureBlock = nil;
}

@end


#pragma mark HTTPRespons implementation


@implementation HTTPResponse

@synthesize statusCode = _statusCode;
@synthesize data = _data;
@synthesize statusCodeMessage = _statusCodeMessage;

+ (HTTPResponse *)responseUsingURLHTTPResponse:(NSHTTPURLResponse *)httpUrlResponse andData:(NSData *)data
{
    HTTPResponse *httpResponse = [[HTTPResponse alloc] init];
    httpResponse.statusCode = httpUrlResponse.statusCode;
    httpResponse.data = data;
    httpResponse.statusCodeMessage = [NSHTTPURLResponse localizedStringForStatusCode:[httpUrlResponse statusCode]];
    return httpResponse;
}

@end