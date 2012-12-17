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

#import "CMISNetworkProvider.h"
#import "CMISHttpDownloadRequest.h"
#import "CMISHttpUploadRequest.h"
#import "CMISHttpRequestDelegate.h"

@interface CMISNetworkProvider ()
@property (nonatomic, strong, readwrite) Class requestClass;
@property (nonatomic, strong, readwrite) Class downloadRequestClass;
@property (nonatomic, strong, readwrite) Class uploadRequestClass;
- (void)standardProvider;
- (BOOL)customProvider:(CMISSessionParameters *)parameters;
@end

@implementation CMISNetworkProvider
@synthesize requestClass = _requestClass;
@synthesize downloadRequestClass = _downloadRequestClass;
@synthesize uploadRequestClass = _uploadRequestClass;

+ (CMISNetworkProvider *)providerWithParameters:(CMISSessionParameters *)parameters
{
    CMISNetworkProvider *provider = [[self alloc] init];
    
    if (nil == parameters || nil == [parameters objectForKey:kCMISSessionParameterCustomNetworkIO])
    {
        [provider standardProvider];
    }
    else if (![provider customProvider:parameters])
    {
        provider = nil;
    }
    
    return provider;
}

- (BOOL)customProvider:(CMISSessionParameters *)parameters
{
    id networkObj = [parameters objectForKey:kCMISSessionParameterCustomNetworkIO];
    if (![networkObj isKindOfClass:[NSDictionary class]])
    {
        [self standardProvider];
        return YES;
    }
    
    NSDictionary *networkDict = (NSDictionary *)networkObj;
    id requestObj = [networkDict objectForKey:kCMISSessionParameterCustomRequest];
    if (nil == requestObj || ![requestObj isKindOfClass:[NSString class]])
    {
        return NO;
    }
    NSString *requestClassName = (NSString *)requestObj;
    Class requestClass = NSClassFromString(requestClassName);
    if (![requestClass conformsToProtocol:@protocol(CMISHttpRequestDelegate)])
    {
        return NO;
    }
    self.requestClass = requestClass;
    self.downloadRequestClass = requestClass;
    self.uploadRequestClass = requestClass;
    
    id downloadObj = [networkDict objectForKey:kCMISSessionParameterCustomDownloadRequest];
    if (nil != downloadObj && [downloadObj isKindOfClass:[NSString class]])
    {
        NSString *name = (NSString *)downloadObj;
        Class downloadClass = NSClassFromString(name);
        if ([downloadClass conformsToProtocol:@protocol(CMISHttpRequestDelegate)])
        {
            self.downloadRequestClass = downloadClass;
        }
        else
        {
            self.downloadRequestClass = nil;
            return NO;
        }
    }
    
    id uploadObj = [networkDict objectForKey:kCMISSessionParameterCustomUploadRequest];
    if (nil != uploadObj && [uploadObj isKindOfClass:[NSString class]])
    {
        NSString *name = (NSString *)uploadObj;
        Class uploadClass = NSClassFromString(name);
        if ([uploadClass conformsToProtocol:@protocol(CMISHttpRequestDelegate)])
        {
            self.uploadRequestClass = uploadClass;
        }
        else
        {
            self.uploadRequestClass = nil;
            return NO;
        }
    }
    
    return YES;
}


- (void)standardProvider
{
    self.requestClass = [CMISHttpRequest class];
    self.downloadRequestClass = [CMISHttpDownloadRequest class];
    self.uploadRequestClass = [CMISHttpUploadRequest class];
}


@end
