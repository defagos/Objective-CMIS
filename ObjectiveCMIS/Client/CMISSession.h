//
//  CMISSession.h
//  ObjectiveCMIS
//
//  Created by Cornwell Gavin on 10/02/2012.
//  Copyright (c) 2012 Alfresco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CMISSessionParameters.h"
#import "CMISRepositoryInfo.h"
#import "CMISBinding.h"
#import "CMISFolder.h"

@class CMISOperationContext;
@class CMISPagedResult;
@class CMISTypeDefinition;

@interface CMISSession : NSObject

// Flag to indicate whether the session has been authenticated.
@property (nonatomic, assign, readonly) BOOL isAuthenticated;

// The binding object being used for the session.
@property (nonatomic, strong, readonly) id<CMISBinding> binding;

// Information about the repository the session is connected to, will be nil until the session is authenticated.
@property (nonatomic, strong, readonly) CMISRepositoryInfo *repositoryInfo;

// *** setup ***

// returns an array of CMISRepositoryInfo objects representing the repositories available at the endpoint.
+ (NSArray *)arrayOfRepositories:(CMISSessionParameters *)sessionParameters
                           error:(NSError **)error;

// Returns a CMISSession using the given session parameters.
- (id)initWithSessionParameters:(CMISSessionParameters *)sessionParameters;

// Authenticates using the CMISSessionParameters and returns if the authentication was succesful
- (BOOL)authenticateAndReturnError:(NSError **)error;

// *** CMIS operations ***

/**
 * Retrieves the root folder for the repository.
 */
- (CMISFolder *)retrieveRootFolderAndReturnError:(NSError **)error;

/**
 * Retrieves the root folder for the repository using the provided operation context.
 */
- (CMISFolder *)retrieveFolderWithOperationContext:(CMISOperationContext *)operationContext
                                         withError:(NSError **)error;

/**
  * Retrieves the object with the given identifier.
  */
- (CMISObject *)retrieveObject:(NSString *)objectId error:(NSError **)error;

/**
  * Retrieves the object with the given identifier, using the provided operation context.
  */
- (CMISObject *)retrieveObject:(NSString *)objectId
          withOperationContext:(CMISOperationContext *)operationContext
                         error:(NSError **)error;

/**
  * Retrieves the object for the given path.
  */
- (CMISObject *)retrieveObjectByPath:(NSString *)path
                               error:(NSError **)error;

/**
 * Retrieves the object for the given path, using the provided operation context.
 */
- (CMISObject *)retrieveObjectByPath:(NSString *)path
                withOperationContext:(CMISOperationContext *)operationContext
                               error:(NSError **)error;

/**
 * Retrieves the definition for the given type.
 */
- (CMISTypeDefinition *)retrieveTypeDefinitions:(NSString *)typeId
                                          error:(NSError **)error;

/**
 * Retrieves all objects matching the given cmis query.
 *
 * @return An array of CMISQueryResult objects.
 */
- (CMISPagedResult *)query:(NSString *)statement
         searchAllVersions:(BOOL)searchAllVersion
                     error:(NSError **)error;

/**
 * Retrieves all objects matching the given cmis query, as CMISQueryResult objects.
 * and using the parameters provided in the operation context.
 *
 * @return An array of CMISQueryResult objects.
 */
- (CMISPagedResult *)query:(NSString *)statement
         searchAllVersions:(BOOL)searchAllVersion
          operationContext:(CMISOperationContext *)operationContext
                     error:(NSError **)error;

/**
 * Creates a folder in the provided folder.
 */
- (NSString *)createFolder:(NSDictionary *)properties
                  inFolder:(NSString *)folderObjectId
                     error:(NSError **)error;

/**
 * Downloads the content of object with the provided object id to the given path.
 */
- (void)downloadContentOfCMISObject:(NSString *)objectId
                             toFile:(NSString *)filePath
                    completionBlock:(CMISVoidCompletionBlock)completionBlock
                       failureBlock:(CMISErrorFailureBlock)failureBlock
                      progressBlock:(CMISProgressBlock)progressBlock;

/**
 * Creates a cmis document using the content from the file path.
 */
- (void)createDocumentFromFilePath:(NSString *)filePath
                      withMimeType:(NSString *)mimeType
                    withProperties:(NSDictionary *)properties
                          inFolder:(NSString *)folderObjectId
                   completionBlock:(CMISStringCompletionBlock)completionBlock  // The returned id is the object id of the newly created document
                      failureBlock:(CMISErrorFailureBlock)failureBlock
                     progressBlock:(CMISProgressBlock)progressBlock;
@end
