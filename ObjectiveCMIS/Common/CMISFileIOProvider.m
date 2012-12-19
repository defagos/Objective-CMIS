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
#import "CMISFileIODelegate.h"
#import "CMISBase64EncoderDelegate.h"
#import "CMISFileUtil.h"
#import "CMISBase64Encoder.h"

@interface CMISFileIOProvider ()
@property (nonatomic, strong, readwrite) Class inputStreamClass;
@property (nonatomic, strong, readwrite) Class outputStreamClass;
@property (nonatomic, strong, readwrite) Class fileManager;
@property (nonatomic, strong, readwrite) Class baseEncoder;
- (void)standardProvider;
- (BOOL)isCustomProviderWithParameters:(CMISSessionParameters *)parameters;
@end

@implementation CMISFileIOProvider
@synthesize inputStreamClass = _inputStreamClass;
@synthesize outputStreamClass = _outputStreamClass;
@synthesize fileManager = _fileManager;
@synthesize baseEncoder = _baseEncoder;

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
    self.inputStreamClass = [NSInputStream class];
    self.outputStreamClass = [NSOutputStream class];
    self.fileManager = [FileUtil class];
    self.baseEncoder = [CMISBase64Encoder class];    
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
    id inObj = [fileDict objectForKey:kCMISSessionParameterCustomFileInputStream];
    id outObj = [fileDict objectForKey:kCMISSessionParameterCustomFileOutputStream];
    id mgrObj = [fileDict objectForKey:kCMISSessionParameterCustomFileManager];
    id encObj = [fileDict objectForKey:kCMISSessionParameterCustomBaseEncoder];
    if (nil == inObj || nil == outObj || nil == mgrObj || nil == encObj)
    {
        return NO;
    }
    if (![inObj isKindOfClass:[NSString class]] || ![outObj isKindOfClass:[NSString class]]
        || ![mgrObj isKindOfClass:[NSString class]] || ![encObj isKindOfClass:[NSString class]])
    {
        return NO;
    }

    Class input = NSClassFromString((NSString *)inObj);
    Class output = NSClassFromString((NSString *)outObj);
    Class manager = NSClassFromString((NSString *)mgrObj);
    Class encoder = NSClassFromString((NSString *)encObj);
    
    if (![input isSubclassOfClass:[NSInputStream class]] || ![output isSubclassOfClass:[NSOutputStream class]])
    {
        return NO;
    }
    if (![manager conformsToProtocol:@protocol(AlfrescoFileManagerDelegate)])
    {
        return NO;
    }
    if (![encoder conformsToProtocol:@protocol(CMISBase64EncoderDelegate)])
    {
        return NO;
    }
    
    self.inputStreamClass = input;
    self.outputStreamClass = output;
    self.fileManager = manager;
    self.baseEncoder = encoder;
    return YES;
}

@end
