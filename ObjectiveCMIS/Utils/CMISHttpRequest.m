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

#import "CMISHttpRequest.h"
#import "CMISHttpUtil.h"
#import "CMISHttpResponse.h"
#import "CMISErrors.h"

@implementation CMISHttpRequest

@synthesize requestMethod = _requestMethod;
@synthesize requestBody = _requestBody;
@synthesize responseBody = _responseBody;
@synthesize headers = _headers;
@synthesize response = _response;
@synthesize completionBlock = _completionBlock;
@synthesize connection = _connection;

+ (BOOL)startRequest:(NSMutableURLRequest *)urlRequest
      withHttpMethod:(CMISHttpRequestMethod)httpRequestMethod
         requestBody:(NSData*)requestBody
             headers:(NSDictionary*)additionalHeaders
     completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
{
    CMISHttpRequest *httpRequest = [[self alloc] initWithHttpMethod:httpRequestMethod
                                                    completionBlock:completionBlock];
    httpRequest.requestBody = requestBody;
    httpRequest.headers = additionalHeaders;
    
    return [httpRequest startRequest:urlRequest];
}


- (id)initWithHttpMethod:(CMISHttpRequestMethod)httpRequestMethod
         completionBlock:(void (^)(CMISHttpResponse *httpResponse, NSError *error))completionBlock
{
    self = [super init];
    if (self) {
        _requestMethod = httpRequestMethod;
        _completionBlock = completionBlock;
    }
    return self;
}


- (BOOL)startRequest:(NSMutableURLRequest*)urlRequest
{
    if (self.requestBody) {
        [urlRequest setHTTPBody:self.requestBody];
    }

    [self.headers enumerateKeysAndObjectsUsingBlock:^(NSString *headerName, NSString *header, BOOL *stop) {
        [urlRequest addValue:header forHTTPHeaderField:headerName];
    }];

    self.connection = [NSURLConnection connectionWithRequest:urlRequest delegate:self];
    if (self.connection) {
        return YES;
    } else {
        if (self.completionBlock) {
            NSString *detailedDescription = [NSString stringWithFormat:@"Could not create connection to %@", urlRequest.URL];
            NSError *cmisError = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeConnection withDetailedDescription:detailedDescription];
            self.completionBlock(nil, cmisError);
        }
        return NO;
    }
}


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.responseBody = [[NSMutableData alloc] init];
    if ([response isKindOfClass:NSHTTPURLResponse.class]) {
        self.response = (NSHTTPURLResponse*)response;
    }
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.responseBody appendData:data];
}


- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (self.completionBlock) {
        NSError *cmisError = [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeConnection];
        self.completionBlock(nil, cmisError);
    }
    
    self.completionBlock = nil;
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (self.completionBlock) {
        NSError *cmisError = nil;
        CMISHttpResponse *httpResponse = [CMISHttpResponse responseUsingURLHTTPResponse:self.response andData:self.responseBody];
        if ([self checkStatusCodeForResponse:httpResponse withHttpRequestMethod:self.requestMethod error:&cmisError]) {
            self.completionBlock(httpResponse, nil);
        } else {
            self.completionBlock(nil, cmisError);
        }
    }
    
    self.completionBlock = nil;
}


- (BOOL)checkStatusCodeForResponse:(CMISHttpResponse *)response withHttpRequestMethod:(CMISHttpRequestMethod)httpRequestMethod error:(NSError **)error
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

@end
