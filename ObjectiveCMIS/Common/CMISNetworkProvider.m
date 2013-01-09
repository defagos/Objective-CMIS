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
#import "CMISHttpUtil.h"

@interface CMISNetworkProvider ()
@property (nonatomic, strong, readwrite) Class invokerClass;
- (BOOL)customProvider:(CMISSessionParameters *)parameters;
@end

@implementation CMISNetworkProvider
@synthesize invokerClass = _invokerClass;

+ (CMISNetworkProvider *)providerWithParameters:(CMISSessionParameters *)parameters
{
    CMISNetworkProvider *provider = [[self alloc] init];
    
    if (nil == parameters || nil == [parameters objectForKey:kCMISSessionParameterCustomNetworkIO])
    {
        provider.invokerClass = [HttpUtil class];
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
        self.invokerClass = [HttpUtil class];
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
    if (![requestClass conformsToProtocol:@protocol(CMISHttpInvokerDelegate)])
    {
        return NO;
    }
    self.invokerClass = requestClass;
    
    return YES;
}




@end
