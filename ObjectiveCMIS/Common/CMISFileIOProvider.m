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

#import "CMISFileIOProvider.h"
#import "AlfrescoFileManagerDelegate.h"
#import "CMISFileUtil.h"
#import "CMISBase64Encoder.h"

@interface CMISFileIOProvider ()
@property (nonatomic, strong, readwrite) Class fileManager;
- (void)standardProvider;
- (BOOL)isCustomProviderWithParameters:(CMISSessionParameters *)parameters;
@end

@implementation CMISFileIOProvider
@synthesize fileManager = _fileManager;

+ (CMISFileIOProvider *)fileIOProviderWithParameters:(CMISSessionParameters *)parameters
{
    CMISFileIOProvider *provider = [[self alloc] init];
    if (provider)
    {
        if (nil == parameters || nil == [parameters objectForKey:kCMISSessionParameterCustomFileIO])
        {
            [provider standardProvider];
        }
        else if(![provider isCustomProviderWithParameters:parameters])
        {
            provider = nil;
        }
    }
    return provider;
}

- (void)standardProvider
{
    self.fileManager = [FileUtil class];
}

- (BOOL)isCustomProviderWithParameters:(CMISSessionParameters *)parameters
{
    id fileIOObj = [parameters objectForKey:kCMISSessionParameterCustomFileIO];
    if (![fileIOObj isKindOfClass:[NSDictionary class]])
    {
        [self standardProvider];
        return YES;
    }
    NSDictionary *fileDict = (NSDictionary *)fileIOObj;
    id mgrObj = [fileDict objectForKey:kCMISSessionParameterCustomFileManager];
    if (nil == mgrObj)
    {
        return NO;
    }
    if (![mgrObj isKindOfClass:[NSString class]])
    {
        return NO;
    }

    Class manager = NSClassFromString((NSString *)mgrObj);
    
    if (![manager conformsToProtocol:@protocol(AlfrescoFileManagerDelegate)])
    {
        return NO;
    }
    
    self.fileManager = manager;
    return YES;
}

@end
