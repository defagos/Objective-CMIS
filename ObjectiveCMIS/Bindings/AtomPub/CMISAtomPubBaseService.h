//
//  CMISAtomPubBaseService.h
//  ObjectiveCMIS
//
//  Created by Cornwell Gavin on 10/04/2012.
//  Copyright (c) 2012 Alfresco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CMISSessionParameters.h"

@class CMISWorkspace;

@interface CMISAtomPubBaseService : NSObject

@property (nonatomic, strong, readonly) CMISSessionParameters *sessionParameters;
@property (nonatomic, strong, readonly) NSArray *cmisWorkspaces;

// TODO: discuss:too much passing of params ... all this info should be bundled? Or am I doing something wrong?
- (id)initWithSessionParameters:(CMISSessionParameters *)sessionParameters andWithCMISWorkspaces:(NSArray *)cmisWorkspaces;

- (NSData *)executeRequest:(NSURL *)url error:(NSError **)outError;
- (CMISObjectData *)retrieveObject:(NSString *)objectId error:(NSError **)error;

@end
