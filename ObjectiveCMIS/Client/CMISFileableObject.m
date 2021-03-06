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

#import "CMISFileableObject.h"
#import "CMISObjectConverter.h"
#import "CMISOperationContext.h"
#import "CMISSession.h"

@implementation CMISFileableObject


- (void)retrieveParentsWithCompletionBlock:(void (^)(NSArray *parentFolders, NSError *error))completionBlock
{
    return [self retrieveParentsWithOperationContext:[CMISOperationContext defaultOperationContext] completionBlock:completionBlock];
}

- (void)retrieveParentsWithOperationContext:(CMISOperationContext *)operationContext
                            completionBlock:(void (^)(NSArray *parentFolders, NSError *error))completionBlock
{
    [self.binding.navigationService retrieveParentsForObject:self.identifier
                                                  withFilter:operationContext.filterString
                                    withIncludeRelationships:operationContext.includeRelationShips
                                         withRenditionFilter:operationContext.renditionFilterString
                                 withIncludeAllowableActions:operationContext.isIncludeAllowableActions
                              withIncludeRelativePathSegment:operationContext.isIncludePathSegments
                                             completionBlock:^(NSArray *parentObjectDataArray, NSError *error) {
                                                 NSMutableArray *parentFolders = [NSMutableArray array];
                                                 for (CMISObjectData *parentObjectData in parentObjectDataArray)
                                                 {
                                                     [parentFolders addObject:[self.session.objectConverter convertObject:parentObjectData]];
                                                 }
                                                 
                                                 completionBlock(parentFolders, error);
                                                 
                                             }];
}

@end
