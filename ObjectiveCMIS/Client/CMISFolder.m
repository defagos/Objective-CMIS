//
//  CMISFolder.m
//  ObjectiveCMIS
//
//  Created by Cornwell Gavin on 21/02/2012.
//  Copyright (c) 2012 Alfresco. All rights reserved.
//

#import "CMISFolder.h"
#import "CMISObjectConverter.h"
#import "CMISConstants.h"
#import "CMISErrors.h"
#import "CMISPagedResult.h"
#import "CMISOperationContext.h"
#import "CMISObjectList.h"
#import "CMISSession.h"

@interface CMISFolder ()

@property (nonatomic, strong, readwrite) NSString *path;
@property (nonatomic, strong, readwrite) CMISCollection *children;
@end

@implementation CMISFolder

@synthesize path = _path;
@synthesize children = _children;

- (id)initWithObjectData:(CMISObjectData *)objectData withSession:(CMISSession *)session
{
    self = [super initWithObjectData:objectData withSession:session];
    if (self)
    {
        self.path = [[objectData.properties propertyForId:kCMISPropertyPath] firstValue];
    }
    return self;
}

- (CMISPagedResult *)retrieveChildrenAndReturnError:(NSError **)error
{
    return [self retrieveChildrenWithOperationContext:[CMISOperationContext defaultOperationContext] andReturnError:error];
}

- (BOOL)isRootFolder
{
    return [self.identifier isEqualToString:self.session.repositoryInfo.rootFolderId];
}

- (CMISFolder *)retrieveFolderParentAndReturnError:(NSError **)error;
{
   if ([self isRootFolder])
   {
       return nil;
   }

   NSArray *parents = [self retrieveParentsAndReturnError:error];
   if (parents == nil || parents.count == 0)
   {
       return nil;
   }

    return [parents objectAtIndex:0];
}

- (CMISPagedResult *)retrieveChildrenWithOperationContext:(CMISOperationContext *)operationContext andReturnError:(NSError **)error
{
    CMISFetchNextPageBlock fetchNextPageBlock = ^CMISFetchNextPageBlockResult *(int skipCount, int maxItems, NSError **fetchError)
    {
        // Fetch results through navigationService
        CMISObjectList *objectList = [self.binding.navigationService retrieveChildren:self.identifier
                                                   orderBy:operationContext.orderBy
                                                   filter:operationContext.filterString
                                                   includeRelationShips:operationContext.includeRelationShips
                                                   renditionFilter:operationContext.renditionFilterString
                                                   includeAllowableActions:operationContext.isIncludeAllowableActions
                                                   includePathSegment:operationContext.isIncludePathSegments
                                                   skipCount:[NSNumber numberWithInt:skipCount]
                                                   maxItems:[NSNumber numberWithInt:maxItems]
                                                   error:fetchError];



        // Fill up return result
        CMISFetchNextPageBlockResult *result = [[CMISFetchNextPageBlockResult alloc] init];
        result.hasMoreItems = objectList.hasMoreItems;
        result.numItems = objectList.numItems;

        CMISObjectConverter *converter = [[CMISObjectConverter alloc] initWithSession:self.session];
        result.resultArray = [converter convertObjects:objectList.objects].items;

        return result;
    };

    NSError *internalError = nil;
    CMISPagedResult *result = [CMISPagedResult pagedResultUsingFetchBlock:fetchNextPageBlock
                                                       andLimitToMaxItems:operationContext.maxItemsPerPage
                                                    andStartFromSkipCount:operationContext.skipCount
                                                                    error:&internalError];

    // Return nil and populate error in case something went wrong
    if (internalError != nil)
    {
        *error = [CMISErrors cmisError:&internalError withCMISErrorCode:kCMISErrorCodeRuntime];
        return nil;
    }

    return result;
}

- (NSString *)createFolder:(NSDictionary *)properties error:(NSError **)error;
{
    NSError *internalError = nil;
    CMISObjectConverter *converter = [[CMISObjectConverter alloc] initWithSession:self.session];
    CMISProperties *convertedProperties = [converter convertProperties:properties forObjectTypeId:kCMISPropertyObjectTypeIdValueFolder error:&internalError];
    if (internalError != nil)
    {
        *error = [CMISErrors cmisError:&internalError withCMISErrorCode:kCMISErrorCodeRuntime];
        return nil;
    }

    return [self.binding.objectService createFolderInParentFolder:self.identifier withProperties:convertedProperties error:error];
}

- (void)createDocumentFromFilePath:(NSString *)filePath withMimeType:(NSString *)mimeType
                          withProperties:(NSDictionary *)properties completionBlock:(CMISStringCompletionBlock)completionBlock
                          failureBlock:(CMISErrorFailureBlock)failureBlock progressBlock:(CMISProgressBlock)progressBlock
{
    NSError *internalError = nil;
    CMISObjectConverter *converter = [[CMISObjectConverter alloc] initWithSession:self.session];
    CMISProperties *convertedProperties = [converter convertProperties:properties forObjectTypeId:kCMISPropertyObjectTypeIdValueDocument error:&internalError];
    if (internalError != nil)
    {
        log(@"Could not convert properties: %@", [internalError description]);
        if (failureBlock)
        {
            failureBlock([CMISErrors cmisError:&internalError withCMISErrorCode:kCMISErrorCodeRuntime]);
        }
        return;
    }

    [self.binding.objectService createDocumentFromFilePath:filePath withMimeType:mimeType withProperties:convertedProperties inFolder:self.identifier
                                           completionBlock:completionBlock failureBlock:failureBlock progressBlock:progressBlock];
}

- (NSArray *)deleteTreeWithDeleteAllVersions:(BOOL)deleteAllversions
                           withUnfileObjects:(CMISUnfileObject)unfileObjects
                       withContinueOnFailure:(BOOL)continueOnFailure
                              andReturnError:(NSError **)error;
{
    return [self.binding.objectService deleteTree:self.identifier allVersion:deleteAllversions
                                    unfileObjects:unfileObjects continueOnFailure:continueOnFailure error:error];
}


@end
