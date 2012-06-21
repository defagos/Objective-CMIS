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
#import "CMISLinkCache.h"
#import "CMISBindingSession.h"

// Default link cache size is 50 entries
#define DEFAULT_LINK_CACHE_SIZE 50

@interface CMISLinkCache () <NSCacheDelegate>

/**
 * Using an NSCache, as it gives us automatic cache cleanup and thread-safe operations
 * https://developer.apple.com/library/mac/#documentation/Cocoa/Reference/NSCache_Class/Reference/Reference.html
 */
@property (nonatomic, strong) NSCache *linkCache;

@end

@implementation CMISLinkCache

@synthesize linkCache = _linkCache;

- (id)initWithBindingSession:(CMISBindingSession *)bindingSession
{
    self = [super init];
    if (self)
    {
        [self setupLinkCache:bindingSession];

    }
    return self;
}

- (void)setupLinkCache:(CMISBindingSession *)bindingSession
{
    self.linkCache = [[NSCache alloc] init];

    id linkCacheSize = [bindingSession objectForKey:kCMISSessionParameterLinkCacheSize];
    if (linkCacheSize != nil)
    {
        if ([[linkCacheSize class] isEqual:[NSNumber class]])
        {
            self.linkCache.countLimit = [(NSNumber *) linkCacheSize unsignedIntValue];
        }
        else
        {
            log(@"Invalid object set for %@ session parameter. Ignoring and using default instead", kCMISSessionParameterLinkCacheSize);
        }
    }

    if (self.linkCache.countLimit <= 0)
    {
        self.linkCache.countLimit = DEFAULT_LINK_CACHE_SIZE;
    }

    // Uncomment for debugging
//    self.linkCache.delegate = self;
}

- (NSString *)linkForObjectId:(NSString *)objectId andRelation:(NSString *)rel
{
    CMISLinkRelations *linkRelations = [self.linkCache objectForKey:objectId];
    return [linkRelations linkHrefForRel:rel];
}

- (NSString *)linkForObjectId:(NSString *)objectId andRelation:(NSString *)rel andType:(NSString *)type
{
    CMISLinkRelations *linkRelations = [self.linkCache objectForKey:objectId];
    return [linkRelations linkHrefForRel:rel type:type];
}

- (void)addLinks:(CMISLinkRelations *)links forObjectId:(NSString *)objectId
{
    [self.linkCache setObject:links forKey:objectId];
}

- (void)removeLinksForObjectId:(NSString *)objectId
{
    [self.linkCache removeObjectForKey:objectId];
}

// Debugging
//- (void)cache:(NSCache *)cache willEvictObject:(id)obj
//{
//    log(@"Link cache will evict cached links for object '%@'", obj);
//}

@end