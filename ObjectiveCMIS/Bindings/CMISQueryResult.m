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

#import "CMISQueryResult.h"
#import "CMISPropertyData.h"
#import "CMISAllowableActions.h"
#import "CMISObjectData.h"
#import "CMISRendition.h"
#import "CMISSession.h"

@interface CMISQueryResult()

@property(nonatomic, strong, readwrite) CMISProperties *properties;
@property(nonatomic, strong, readwrite) CMISAllowableActions *allowableActions;
@property(nonatomic, strong, readwrite) NSArray *renditions;

@end


@implementation CMISQueryResult

@synthesize properties = _properties;
@synthesize allowableActions = _allowableActions;
@synthesize renditions = _renditions;


- (id)initWithCmisObjectData:(CMISObjectData *)cmisObjectData andWithSession:(CMISSession *)session
{
    self = [super init];
    if (self)
    {
        self.properties = cmisObjectData.properties;
        self.allowableActions = cmisObjectData.allowableActions;

        if (cmisObjectData.renditions != nil)
        {
            NSMutableArray *renditions = [NSMutableArray array];
            for (CMISRenditionData *renditionData in cmisObjectData.renditions)
            {
                [renditions addObject:[[CMISRendition alloc] initWithRenditionData:renditionData andObjectId:cmisObjectData.identifier andSession:session]];
            }
            self.renditions = renditions;
        }
    }
    return self;
}

+ (CMISQueryResult *)queryResultUsingCmisObjectData:(CMISObjectData *)cmisObjectData andWithSession:(CMISSession *)session
{
    CMISQueryResult *queryResult = [[CMISQueryResult alloc] initWithCmisObjectData:cmisObjectData andWithSession:session];
    return queryResult;
}

- (CMISPropertyData *)propertyForId:(NSString *)id
{
    return [self.properties propertyForId:id];
}

- (CMISPropertyData *)properyForQueryName:(NSString *)queryName
{
    return [self.properties propertyForQueryName:queryName];
}

- (id)properyValueForId:(NSString *)propertyId
{
    return [self.properties propertyValueForId:propertyId];
}

- (id)propertyValueForQueryName:(NSString *)queryName
{
    return [self.properties propertyValueForQueryName:queryName];
}

- (NSArray *)propertyMultiValueById:(NSString *)id
{
    return [self.properties propertyMultiValueById:id];
}

- (NSArray *)propertyMultiValueByQueryName:(NSString *)queryName
{
    return [self.properties propertyMultiValueByQueryName:queryName];
}


@end