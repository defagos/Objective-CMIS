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

#import "CMISPagedResult.h"
#import "CMISErrors.h"

/**
 * Implementation of the wrapper class for the returned results
 */
@implementation CMISFetchNextPageBlockResult

@synthesize resultArray = _resultArray;
@synthesize hasMoreItems = _hasMoreItems;
@synthesize numItems = _numItems;

@end

/**
 * Private interface for CMISPagedResult
 */
@interface CMISPagedResult ()

@property (nonatomic, strong, readwrite) NSArray *resultArray;
@property (readwrite) BOOL hasMoreItems;
@property (readwrite) NSInteger numItems;
@property (readwrite) NSInteger maxItems;
@property (readwrite) NSInteger skipCount;

@property (nonatomic, copy) CMISFetchNextPageBlock fetchNextPageBlock;

@end

/**
 * The implementation of the result when fetching a new page.
 */
@implementation CMISPagedResult

@synthesize resultArray = _resultArray;
@synthesize hasMoreItems = _hasMoreItems;
@synthesize numItems = _numItems;
@synthesize fetchNextPageBlock = _fetchNextPageBlock;
@synthesize maxItems = _maxItems;
@synthesize skipCount = _skipCount;


/** Internal init */
- (id)initWithResultArray:(NSArray *)resultArray
 retrievedUsingFetchBlock:(CMISFetchNextPageBlock)fetchNextPageBlock
              andNumItems:(NSInteger)numItems andHasMoreItems:(BOOL)hasMoreItems
              andMaxItems:(NSInteger)maxItems andSkipCount:(NSInteger)skipCount;
{
    self = [super init];
    if (self)
    {
        self.resultArray = resultArray;
        self.fetchNextPageBlock = fetchNextPageBlock;
        self.hasMoreItems = hasMoreItems;
        self.numItems = numItems;
        self.maxItems = maxItems;
        self.skipCount = skipCount;
    }
    return self;
}

+ (void)pagedResultUsingFetchBlock:(CMISFetchNextPageBlock)fetchNextPageBlock
                andLimitToMaxItems:(NSInteger)maxItems andStartFromSkipCount:(NSInteger)skipCount
                   completionBlock:(void (^)(CMISPagedResult *result, NSError *error))completionBlock
{
    // Fetch the first requested page
    fetchNextPageBlock(skipCount, maxItems, ^(CMISFetchNextPageBlockResult *result, NSError *error) {
        if (error) {
            completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
        } else {
            completionBlock([[CMISPagedResult alloc] initWithResultArray:result.resultArray
                                                retrievedUsingFetchBlock:fetchNextPageBlock
                                                             andNumItems:result.numItems
                                                         andHasMoreItems:result.hasMoreItems
                                                             andMaxItems:maxItems
                                                            andSkipCount:skipCount],
                            nil);
        }
    });
}

- (void)fetchNextPageWithCompletionBlock:(void (^)(CMISPagedResult *result, NSError *error))completionBlock
{
    [CMISPagedResult pagedResultUsingFetchBlock:self.fetchNextPageBlock
                             andLimitToMaxItems:self.maxItems
                          andStartFromSkipCount:(self.skipCount + self.resultArray.count)
                                completionBlock:completionBlock];
}

- (void)enumerateItemsUsingBlock:(void (^)(CMISObject *object, BOOL *stop))enumerationBlock completionBlock:(void (^)(NSError *error))completionBlock
{
    BOOL stop = NO;
    for (CMISObject *object in self.resultArray) {
        enumerationBlock(object, &stop);
        if (stop) {
            NSError *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeCancelled withDetailedDescription:@"Item enumeration was stopped"];
            completionBlock(error);
            return;
        }
    }
    if (self.hasMoreItems) {
        [self fetchNextPageWithCompletionBlock:^(CMISPagedResult *result, NSError *error) {
            if (error) {
                completionBlock(error);
            } else {
                [result enumerateItemsUsingBlock:enumerationBlock completionBlock:completionBlock];
            }
        }];
    } else {
        completionBlock(nil);
    }
}

@end