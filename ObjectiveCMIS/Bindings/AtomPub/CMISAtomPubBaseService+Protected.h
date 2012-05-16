//
//  CMISAtomPubBaseService+Protected.h
//  ObjectiveCMIS
//
//  Created by Cornwell Gavin on 04/05/2012.
//  Copyright (c) 2012 Alfresco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CMISAtomPubBaseService.h"
#import "CMISObjectByIdUriBuilder.h"

@class CMISObjectData;

@interface CMISAtomPubBaseService (Protected)

- (void)fetchRepositoryInfoAndReturnError:(NSError * *)error;

- (NSArray *)retrieveCMISWorkspacesAndReturnError:(NSError * *)error;

- (CMISObjectData *)retrieveObjectInternal:(NSString *)objectId error:(NSError **)error;

- (CMISObjectData *)retrieveObjectByPathInternal:(NSString *)path error:(NSError **)error;

- (id) retrieveFromCache:(NSString *)cacheKey error:(NSError * *)error;

@end
