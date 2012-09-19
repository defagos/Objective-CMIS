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

#import "CMISAtomPubObjectService.h"
#import "CMISAtomPubBaseService+Protected.h"
#import "CMISHttpUtil.h"
#import "CMISAtomEntryWriter.h"
#import "CMISAtomEntryParser.h"
#import "CMISConstants.h"
#import "CMISErrors.h"
#import "CMISStringInOutParameter.h"
#import "CMISURLUtil.h"
#import "CMISFileDownloadDelegate.h"
#import "CMISFileUploadDelegate.h"

@implementation CMISAtomPubObjectService

- (void)retrieveObject:(NSString *)objectId
            withFilter:(NSString *)filter
andIncludeRelationShips:(CMISIncludeRelationship)includeRelationship
   andIncludePolicyIds:(BOOL)includePolicyIds
    andRenditionFilder:(NSString *)renditionFilter
         andIncludeACL:(BOOL)includeACL
andIncludeAllowableActions:(BOOL)includeAllowableActions
       completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    [self retrieveObjectInternal:objectId
               withReturnVersion:NOT_PROVIDED
                      withFilter:filter
         andIncludeRelationShips:includeRelationship
             andIncludePolicyIds:includePolicyIds
              andRenditionFilder:renditionFilter
                   andIncludeACL:includeACL
      andIncludeAllowableActions:includeAllowableActions
                 completionBlock:^(CMISObjectData *objectData, NSError *error) {
                     if (error) {
                         completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeObjectNotFound]);
                     } else {
                         completionBlock(objectData, nil);
                     }
                 }];
}

- (void)retrieveObjectByPath:(NSString *)path
                  withFilter:(NSString *)filter
     andIncludeRelationShips:(CMISIncludeRelationship)includeRelationship
         andIncludePolicyIds:(BOOL)includePolicyIds
          andRenditionFilder:(NSString *)renditionFilter
               andIncludeACL:(BOOL)includeACL
  andIncludeAllowableActions:(BOOL)includeAllowableActions
             completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    [self retrieveObjectByPathInternal:path
                            withFilter:filter
               andIncludeRelationShips:includeRelationship
                   andIncludePolicyIds:includePolicyIds
                    andRenditionFilder:renditionFilter
                         andIncludeACL:includeACL
            andIncludeAllowableActions:includeAllowableActions
                       completionBlock:completionBlock];
}

- (void)downloadContentOfObject:(NSString *)objectId
                   withStreamId:(NSString *)streamId
                         toFile:(NSString *)filePath
                completionBlock:(CMISVoidCompletionBlock)completionBlock
                   failureBlock:(CMISErrorFailureBlock)failureBlock
                  progressBlock:(CMISProgressBlock)progressBlock;
{
    NSOutputStream *outputStream = [NSOutputStream outputStreamToFileAtPath:filePath append:NO];
    [self downloadContentOfObject:objectId withStreamId:streamId toOutputStream:outputStream
                  completionBlock:completionBlock failureBlock:failureBlock progressBlock:progressBlock];
}

- (void)downloadContentOfObject:(NSString *)objectId
                   withStreamId:(NSString *)streamId
                 toOutputStream:(NSOutputStream *)outputStream
                completionBlock:(CMISVoidCompletionBlock)completionBlock
                   failureBlock:(CMISErrorFailureBlock)failureBlock
                  progressBlock:(CMISProgressBlock)progressBlock;
{
    [self retrieveObjectInternal:objectId completionBlock:^(CMISObjectData *objectData, NSError *error) {
        if (error) {
            log(@"Error while retrieving CMIS object for object id '%@' : %@", objectId, error.description);
            if (failureBlock) {
                failureBlock([CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeObjectNotFound]);
            }
        } else {
            // We create a specific delegate object, as potentially multiple threads can be downloading a file.
            CMISFileDownloadDelegate *dataDelegate = [[CMISFileDownloadDelegate alloc] init];
            dataDelegate.fileStreamForContentRetrieval = outputStream;
            dataDelegate.fileRetrievalCompletionBlock = completionBlock;
            dataDelegate.fileRetrievalFailureBlock = failureBlock;
            dataDelegate.fileRetrievalProgressBlock = progressBlock;
            
            NSURL *contentUrl = objectData.contentUrl;
            
            // This is not spec-compliant!! Took me half a day to find this in opencmis ...
            if (streamId != nil) {
                contentUrl = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterStreamId withValue:streamId toUrl:contentUrl];
            }
            
            [HttpUtil invokeGETAsynchronous:contentUrl withSession:self.bindingSession withDelegate:dataDelegate];
        }
    }];
}

- (void)deleteContentOfObject:(CMISStringInOutParameter *)objectIdParam
              withChangeToken:(CMISStringInOutParameter *)changeTokenParam
              completionBlock:(void (^)(NSError *error))completionBlock
{
    // Validate object id param
    if (objectIdParam == nil || objectIdParam.inParameter == nil)
    {
        log(@"Object id is nil or inParameter of objectId is nil");
        completionBlock([[NSError alloc] init]); // TODO: properly init error (CmisInvalidArgumentException)
        return;
    }

    // Get edit media link
    [self loadLinkForObjectId:objectIdParam.inParameter andRelation:kCMISLinkEditMedia completionBlock:^(NSString *editMediaLink, NSError *error) {
        if (editMediaLink == nil){
            log(@"Could not retrieve %@ link for object '%@'", kCMISLinkEditMedia, objectIdParam.inParameter);
            completionBlock(error);
            return;
        }
        
        // Append optional change token parameters
        if (changeTokenParam != nil && changeTokenParam.inParameter != nil) {
            editMediaLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterChangeToken
                                                             withValue:changeTokenParam.inParameter toUrlString:editMediaLink];
        }
        
        [HttpUtil invokeDELETE:[NSURL URLWithString:editMediaLink] withSession:self.bindingSession completionBlock:^(HTTPResponse *httpResponse) {
            // Atompub DOES NOT SUPPORT returning the new object id and change token
            // See http://docs.oasis-open.org/cmis/CMIS/v1.0/cs01/cmis-spec-v1.0.html#_Toc243905498
            objectIdParam.outParameter = nil;
            changeTokenParam.outParameter = nil;
            completionBlock(nil);
        } failureBlock:^(NSError *error) {
            completionBlock(error);
        }];
    }];
}

- (void)changeContentOfObject:(CMISStringInOutParameter *)objectIdParam toContentOfFile:(NSString *)filePath
        withOverwriteExisting:(BOOL)overwrite withChangeToken:(CMISStringInOutParameter *)changeTokenParam
              completionBlock:(CMISVoidCompletionBlock)completionBlock
                 failureBlock:(CMISErrorFailureBlock)failureBlock
                progressBlock:(CMISProgressBlock)progressBlock
{
    // Validate object id param
    if (objectIdParam == nil || objectIdParam.inParameter == nil)
    {
        log(@"Object id is nil or inParameter of objectId is nil");
        if (failureBlock) {
            failureBlock([CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:@"Must provide object id"]);
        }
        return;
    }

    // Validate file path param
    if (filePath == nil || ![[NSFileManager defaultManager] isReadableFileAtPath:filePath])
    {
        log(@"Invalid file path: '%@' is not valid", filePath);
        if (failureBlock) {
            failureBlock([CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:@"Invalid file path"]);
        }
        return;
    }

    // Atompub DOES NOT SUPPORT returning the new object id and change token
    // See http://docs.oasis-open.org/cmis/CMIS/v1.0/cs01/cmis-spec-v1.0.html#_Toc243905498
    objectIdParam.outParameter = nil;
    changeTokenParam.outParameter = nil;

    // Get edit media link
    [self loadLinkForObjectId:objectIdParam.inParameter andRelation:kCMISLinkEditMedia completionBlock:^(NSString *editMediaLink, NSError *error) {
        if (editMediaLink == nil){
            log(@"Could not retrieve %@ link for object '%@'", kCMISLinkEditMedia, objectIdParam.inParameter);
            if (failureBlock) {
                failureBlock([CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeObjectNotFound]);
            }
            return;
        }
        
        // Append optional change token parameters
        if (changeTokenParam != nil && changeTokenParam.inParameter != nil) {
            editMediaLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterChangeToken
                                                             withValue:changeTokenParam.inParameter toUrlString:editMediaLink];
        }
        
        // Append overwrite flag
        editMediaLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterOverwriteFlag
                                                         withValue:(overwrite ? @"true" : @"false") toUrlString:editMediaLink];
        
        // Create delegate to handle the async file upload
        CMISFileUploadDelegate *uploadDelegate = [[CMISFileUploadDelegate alloc] init];
        uploadDelegate.fileUploadFailureBlock = failureBlock;
        uploadDelegate.fileUploadProgressBlock = progressBlock;
        uploadDelegate.fileUploadCompletionBlock = ^ (HTTPResponse *httpResponse) {
            
            // Check response status
            if (httpResponse.statusCode != 200 && httpResponse.statusCode != 201 && httpResponse.statusCode != 204)
            {
                log(@"Invalid http response status code when updating content: %d", httpResponse.statusCode);
                if (failureBlock) {
                    failureBlock([CMISErrors createCMISErrorWithCode:kCMISErrorCodeRuntime
                                             withDetailedDescription:[NSString stringWithFormat:@"Could not update content: http status code %d", httpResponse.statusCode]]);
                }
            }
            else {
                if (completionBlock) {
                    completionBlock();
                }
            }
        };
        
        // Execute HTTP call on edit media link, passing the a stream to the file
        NSDictionary *additionalHeader = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"attachment; filename=%@",
                                                                             [filePath lastPathComponent]] forKey:@"Content-Disposition"];
        [HttpUtil invokePUTAsynchronous:[NSURL URLWithString:editMediaLink]
                            withSession:self.bindingSession
                             bodyStream:[NSInputStream inputStreamWithFileAtPath:filePath]
                                headers:additionalHeader
                           withDelegate:uploadDelegate];
        
    }];
}


- (void)createDocumentFromFilePath:(NSString *)filePath withMimeType:(NSString *)mimeType
                          withProperties:(CMISProperties *)properties inFolder:(NSString *)folderObjectId
                         completionBlock:(CMISStringCompletionBlock)completionBlock
                            failureBlock:(CMISErrorFailureBlock)failureBlock
                           progressBlock:(CMISProgressBlock)progressBlock
{
    // Validate properties
    if ([properties propertyValueForId:kCMISPropertyName] == nil || [properties propertyValueForId:kCMISPropertyObjectTypeId] == nil)
    {
        log(@"Must provide %@ and %@ as properties", kCMISPropertyName, kCMISPropertyObjectTypeId);
        if (failureBlock)
        {
            failureBlock([CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:nil]);
        }
        return;
    }

    // Validate mimetype
    if (!mimeType)
    {
        log(@"Must provide a mimetype when creating a cmis document");
        if (failureBlock)
        {
            failureBlock([CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:nil]);
        }
        return;
    }

    // Get Down link
    [self loadLinkForObjectId:folderObjectId andRelation:kCMISLinkRelationDown
                      andType:kCMISMediaTypeChildren completionBlock:^(NSString *downLink, NSError *error) {
                          if (error) {
                              log(@"Could not retrieve down link: %@", error.description);
                              if (failureBlock) {
                                  failureBlock([CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeObjectNotFound]);
                              }
                          } else {
                              
                          }
                          [self asyncSendAtomEntryXmlToLink:downLink withHttpRequestMethod:HTTP_POST
                                             withProperties:properties
                                        withContentFilePath:filePath
                                        withContentMimeType:mimeType
                                              storeInMemory:NO
                                            completionBlock:completionBlock
                                               failureBlock:failureBlock
                                              progressBlock:progressBlock];
                          
                      }];
}

- (void)deleteObject:(NSString *)objectId allVersions:(BOOL)allVersions completionBlock:(void (^)(BOOL objectDeleted, NSError *error))completionBlock
{
    [self loadLinkForObjectId:objectId andRelation:kCMISLinkRelationSelf completionBlock:^(NSString *selfLink, NSError *error) {
        if (!selfLink) {
            completionBlock(NO, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:nil]);
        } else {
            NSURL *selfUrl = [NSURL URLWithString:selfLink];
            [HttpUtil invokeDELETE:selfUrl withSession:self.bindingSession completionBlock:^(HTTPResponse *httpResponse) {
                completionBlock(YES, nil);
            } failureBlock:^(NSError *error) {
                completionBlock(NO, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeUpdateConflict]);
            }];
        }
    }];
}

- (void)createFolderInParentFolder:(NSString *)folderObjectId withProperties:(CMISProperties *)properties completionBlock:(void (^)(NSString *, NSError *))completionBlock
{
    if ([properties propertyValueForId:kCMISPropertyName] == nil || [properties propertyValueForId:kCMISPropertyObjectTypeId] == nil)
    {
        log(@"Must provide %@ and %@ as properties", kCMISPropertyName, kCMISPropertyObjectTypeId);
        completionBlock(nil,  [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:nil]);
        return;
    }
    
    // Validate parent folder id
    if (!folderObjectId)
    {
        log(@"Must provide a parent folder object id when creating a new folder");
        completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeObjectNotFound withDetailedDescription:nil]);
        return;
    }
    
    // Get Down link
    [self loadLinkForObjectId:folderObjectId andRelation:kCMISLinkRelationDown
                                           andType:kCMISMediaTypeChildren completionBlock:^(NSString *downLink, NSError *error) {
                                               if (error) {
                                                   log(@"Could not retrieve down link: %@", error.description);
                                                   completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeConnection]);
                                               } else {
                                                   [self sendAtomEntryXmlToLink:downLink
                                                          withHttpRequestMethod:HTTP_POST
                                                                 withProperties:properties
                                                            withContentFilePath:nil
                                                            withContentMimeType:nil
                                                                  storeInMemory:YES
                                                                completionBlock:^(CMISObjectData *objectData, NSError *error) {
                                                                    completionBlock(objectData.identifier, nil);
                                                                }];
                                               }
                                           }];
}

- (void)deleteTree:(NSString *)folderObjectId
        allVersion:(BOOL)allVersions
     unfileObjects:(CMISUnfileObject)unfileObjects
 continueOnFailure:(BOOL)continueOnFailure
   completionBlock:(void (^)(NSArray *failedObjects, NSError *error))completionBlock
{
    // Validate params
    if (!folderObjectId)
    {
        log(@"Must provide a folder object id when deleting a folder tree");
        completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeObjectNotFound withDetailedDescription:nil]);
        return;
    }

    [self loadLinkForObjectId:folderObjectId andRelation:kCMISLinkRelationDown andType:kCMISMediaTypeDescendants completionBlock:^(NSString *link, NSError *error) {
        if (error) {
            log(@"Error while fetching %@ link : %@", kCMISLinkRelationDown, error.description);
            completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
            return;
        }
        
        void (^continueWithLink)(NSString *) = ^(NSString *link) {
            link = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterAllVersions withValue:(allVersions ? @"true" : @"false") toUrlString:link];
            link = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterUnfileObjects withValue:[CMISEnums stringForUnfileObject:unfileObjects] toUrlString:link];
            link = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterContinueOnFailure withValue:(continueOnFailure ? @"true" : @"false") toUrlString:link];
            
            [HttpUtil invokeDELETE:[NSURL URLWithString:link] withSession:self.bindingSession completionBlock:^(HTTPResponse *httpResponse) {
                // TODO: retrieve failed folders and files and return
                completionBlock([NSArray array], nil);
            } failureBlock:^(NSError *error) {
                completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeConnection]);
            }];
        };
        
        if (link == nil) {
            [self loadLinkForObjectId:folderObjectId andRelation:kCMISLinkRelationFolderTree completionBlock:^(NSString *link, NSError *error) {
                if (error) {
                    log(@"Error while fetching %@ link : %@", kCMISLinkRelationFolderTree, error.description);
                    completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
                } else if (link == nil) {
                    log(@"Could not retrieve %@ nor %@ link", kCMISLinkRelationDown, kCMISLinkRelationFolderTree);
                    completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
                } else {
                    continueWithLink(link);
                }
            }];
        } else {
            continueWithLink(link);
        }
    }];
}

- (void)updatePropertiesForObject:(CMISStringInOutParameter *)objectIdParam
                   withProperties:(CMISProperties *)properties
                  withChangeToken:(CMISStringInOutParameter *)changeTokenParam
                  completionBlock:(void (^)(NSError *error))completionBlock
{
    // Validate params
    if (objectIdParam == nil || objectIdParam.inParameter == nil)
    {
        log(@"Object id is nil or inParameter of objectId is nil");
        completionBlock([[NSError alloc] init]); // TODO: properly init error (CmisInvalidArgumentException)
        return;
    }

    // Get self link
    [self loadLinkForObjectId:objectIdParam.inParameter andRelation:kCMISLinkRelationSelf completionBlock:^(NSString *selfLink, NSError *error) {
        if (selfLink == nil)
        {
            log(@"Could not retrieve %@ link", kCMISLinkRelationSelf);
            completionBlock([CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeConnection]);
            return;
        }
        
        // Append optional params
        if (changeTokenParam != nil && changeTokenParam.inParameter != nil)
        {
            selfLink = [CMISURLUtil urlStringByAppendingParameter:kCMISParameterChangeToken
                                                        withValue:changeTokenParam.inParameter toUrlString:selfLink];
        }
        
        // Execute request
        [self sendAtomEntryXmlToLink:selfLink
               withHttpRequestMethod:HTTP_PUT
                      withProperties:properties
                 withContentFilePath:nil
                 withContentMimeType:nil
                       storeInMemory:YES
                    completionBlock:^(CMISObjectData *objectData, NSError *error) {
                        // Create XML needed as body of html
                        
                        CMISAtomEntryWriter *xmlWriter = [[CMISAtomEntryWriter alloc] init];
                        xmlWriter.cmisProperties = properties;
                        xmlWriter.generateXmlInMemory = YES;
                        
                        [HttpUtil invokePUT:[NSURL URLWithString:selfLink]
                                withSession:self.bindingSession
                                       body:[xmlWriter.generateAtomEntryXml dataUsingEncoding:NSUTF8StringEncoding]
                                    headers:[NSDictionary dictionaryWithObject:kCMISMediaTypeEntry forKey:@"Content-type"]
                            completionBlock:^(HTTPResponse *httpResponse) {
                                // Object id and changeToken might have changed because of this operation
                                CMISAtomEntryParser *atomEntryParser = [[CMISAtomEntryParser alloc] initWithData:httpResponse.data];
                                NSError *error = nil;
                                if ([atomEntryParser parseAndReturnError:&error])
                                {
                                    objectIdParam.outParameter = [[atomEntryParser.objectData.properties propertyForId:kCMISPropertyObjectId] firstValue];
                                    
                                    if (changeTokenParam != nil)
                                    {
                                        changeTokenParam.outParameter = [[atomEntryParser.objectData.properties propertyForId:kCMISPropertyChangeToken] firstValue];
                                    }
                                }
                                completionBlock(nil);
                            } failureBlock:^(NSError *error) {
                                completionBlock([CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeConnection]);
                            }];
                    }];
    }];
}


- (void)retrieveRenditions:(NSString *)objectId withRenditionFilter:(NSString *)renditionFilter
              withMaxItems:(NSNumber *)maxItems withSkipCount:(NSNumber *)skipCount
           completionBlock:(void (^)(NSArray *renditions, NSError *error))completionBlock
{
    // Only fetching the bare minimum
    [self retrieveObjectInternal:objectId withReturnVersion:LATEST withFilter:kCMISPropertyObjectId
         andIncludeRelationShips:CMISIncludeRelationshipNone andIncludePolicyIds:NO
              andRenditionFilder:renditionFilter andIncludeACL:NO andIncludeAllowableActions:NO
                 completionBlock:^(CMISObjectData *objectData, NSError *error) {
                     if (error) {
                         completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeObjectNotFound]);
                     } else {
                         completionBlock(objectData.renditions, nil);
                     }
                 }];
}

#pragma mark Helper methods

- (void)sendAtomEntryXmlToLink:(NSString *)link
         withHttpRequestMethod:(CMISHttpRequestMethod)httpRequestMethod
                withProperties:(CMISProperties *)properties
           withContentFilePath:(NSString *)contentFilePath
           withContentMimeType:(NSString *)contentMimeType
                 storeInMemory:(BOOL)isXmlStoredInMemory
               completionBlock:(void (^)(CMISObjectData *objectData, NSError *error))completionBlock
{
    // Validate params
    if (link == nil) {
        completionBlock(nil, [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:nil]);
        log(@"Could not retrieve link from object to do creation or update");
        return;
    }
    
    // Generate XML
    NSString *writeResult = [self createAtomEntryWriter:properties contentFilePath:contentFilePath
                                        contentMimeType:contentMimeType isXmlStoredInMemory:isXmlStoredInMemory];
    
    // Execute call
    NSURL *url = [NSURL URLWithString:link];
    if (isXmlStoredInMemory) {
        [HttpUtil invoke:url
          withHttpMethod:httpRequestMethod
             withSession:self.bindingSession
                    body:[writeResult dataUsingEncoding:NSUTF8StringEncoding]
                 headers:[NSDictionary dictionaryWithObject:kCMISMediaTypeEntry forKey:@"Content-type"]
         completionBlock:^(HTTPResponse *httpResponse) {
             CMISAtomEntryParser *atomEntryParser = [[CMISAtomEntryParser alloc] initWithData:httpResponse.data];
             NSError *error = nil;
             [atomEntryParser parseAndReturnError:&error];
             if (error) {
                 completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeUpdateConflict]);
             } else {
                 completionBlock(atomEntryParser.objectData, nil);
             }
         } failureBlock:^(NSError *error) {
             completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeConnection]);
         }];
    }
    else
    {
        NSInputStream *bodyStream = [NSInputStream inputStreamWithFileAtPath:writeResult];
        [HttpUtil invoke:url
          withHttpMethod:httpRequestMethod
             withSession:self.bindingSession
              bodyStream:bodyStream
                 headers:[NSDictionary dictionaryWithObject:kCMISMediaTypeEntry forKey:@"Content-type"]
         completionBlock:^(HTTPResponse *httpResponse) {
             // Close stream and delete temporary file
             [bodyStream close];
             
             NSError *fileError = nil;
             [[NSFileManager defaultManager] removeItemAtPath:writeResult error:&fileError];

             CMISAtomEntryParser *atomEntryParser = [[CMISAtomEntryParser alloc] initWithData:httpResponse.data];
             NSError *parserError = nil;
             [atomEntryParser parseAndReturnError:&parserError];

             if (parserError) {
                 completionBlock(nil, [CMISErrors cmisError:parserError withCMISErrorCode:kCMISErrorCodeUpdateConflict]);
             } else if (fileError) {
                 completionBlock(nil, [CMISErrors cmisError:fileError withCMISErrorCode:kCMISErrorCodeStorage]);
             } else {
                 completionBlock(atomEntryParser.objectData, nil);
             }
         } failureBlock:^(NSError *error) {
             // Close stream and delete temporary file
             [bodyStream close];
             [[NSFileManager defaultManager] removeItemAtPath:writeResult error:nil]; // TODO: should the temp file be deleted if an error occured?
             completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeConnection]);
         }];
    }
}


- (void)asyncSendAtomEntryXmlToLink:(NSString *)link
                    withHttpRequestMethod:(CMISHttpRequestMethod)httpRequestMethod
                    withProperties:(CMISProperties *)properties
                    withContentFilePath:(NSString *)contentFilePath
                    withContentMimeType:(NSString *)contentMimeType
                    storeInMemory:(BOOL)isXmlStoredInMemory
                    completionBlock:(CMISStringCompletionBlock)completionBlock
                    failureBlock:(CMISErrorFailureBlock)failureBlock
                    progressBlock:(CMISProgressBlock)progressBlock;
{
    // Validate param
    if (link == nil) {
        log(@"Could not retrieve link from object to do creation or update");
        if (failureBlock)
        {
            failureBlock([CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:nil]);
        }
        return;
    }

    // Generate XML
    NSString *writeResult = [self createAtomEntryWriter:properties contentFilePath:contentFilePath
            contentMimeType:contentMimeType isXmlStoredInMemory:isXmlStoredInMemory];

    // Create delegate object for the asynchronous POST HTTP call
    CMISFileUploadDelegate *uploadDelegate = [self createFileUploadDelegateForFilePath:contentFilePath
                     withCompletionBlock:completionBlock withFailureBlock:failureBlock withProgressBlock:progressBlock];

    // Start the asynchronous POST http call
    NSURL *url = [NSURL URLWithString:link];
    if (isXmlStoredInMemory)
    {
        [self asyncSendXMLInMemory:url body:writeResult uploadDelegate:uploadDelegate];
    }
    else
    {
        [self asyncSendXMLUsingTempFile:url tempFilePath:writeResult failureBlock:failureBlock uploadDelegate:uploadDelegate];
    }
}

/**
 * Helper method: creates a writer for the xml needed to upload a file.
 * The atom entry XML can become huge, as the whole file is stored as base64 in the XML itself
 * Hence, we're allowing to store the atom entry xml in a temporary file and stream the body of the http post
 */
- (NSString *)createAtomEntryWriter:(CMISProperties *)properties contentFilePath:(NSString *)contentFilePath contentMimeType:(NSString *)contentMimeType isXmlStoredInMemory:(BOOL)isXmlStoredInMemory
{

    CMISAtomEntryWriter *atomEntryWriter = [[CMISAtomEntryWriter alloc] init];
    atomEntryWriter.contentFilePath = contentFilePath;
    atomEntryWriter.mimeType = contentMimeType;
    atomEntryWriter.cmisProperties = properties;
    atomEntryWriter.generateXmlInMemory = isXmlStoredInMemory;
    NSString *writeResult = [atomEntryWriter generateAtomEntryXml];
    return writeResult;
}

/**
 * Helper method: creates a CMISFileUploadDelegate object to handle the asynchronous upload
 */
- (CMISFileUploadDelegate *)createFileUploadDelegateForFilePath:(NSString *)filePath
                                            withCompletionBlock:(CMISStringCompletionBlock)completionBlock
                                               withFailureBlock:(CMISErrorFailureBlock)failureBlock
                                              withProgressBlock:(CMISProgressBlock)progressBlock
{
    CMISFileUploadDelegate *uploadDelegate = [[CMISFileUploadDelegate alloc] init];
    uploadDelegate.fileUploadFailureBlock = failureBlock;
    uploadDelegate.fileUploadProgressBlock = progressBlock;
    uploadDelegate.fileUploadCompletionBlock = ^(HTTPResponse *response)
    {
        if (response.statusCode != 200 && response.statusCode != 201 && response.statusCode != 204)
        {
            log(@"Invalid http response status code when creating/uploading content: %d", response.statusCode);
            NSString *errorContent = [[NSString alloc] initWithData:response.data encoding:NSUTF8StringEncoding];
            log(@"Error content: %@", errorContent);
            if (failureBlock)
            {
                failureBlock([CMISErrors createCMISErrorWithCode:kCMISErrorCodeRuntime
                                         withDetailedDescription:[NSString stringWithFormat:@"Could not create content: http status code %d", response.statusCode]]);
            }
        }
        else {
            if (completionBlock)
            {
                NSError *parseError = nil;
                CMISAtomEntryParser *atomEntryParser = [[CMISAtomEntryParser alloc] initWithData:response.data];
                [atomEntryParser parseAndReturnError:&parseError];
                if (parseError)
                {
                    log(@"Error while parsing response: %@", [parseError description]);
                    if (failureBlock)
                    {
                        failureBlock([CMISErrors cmisError:parseError withCMISErrorCode:kCMISErrorCodeUpdateConflict]);
                    }
                }
                
                if (completionBlock)
                {
                    completionBlock(atomEntryParser.objectData.identifier);
                }
            }
        }
    };

    // We set the expected bytes Explicitely. In case the call is done using an Inputstream, NSURLConnection
    // would not be able to determine the file size.
    NSError *fileSizeError = nil;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&fileSizeError];

    if (fileSizeError == nil)
    {
        uploadDelegate.bytesExpected = [fileAttributes objectForKey:NSFileSize];
    }
    else
    {
        log(@"Could not determine file size of %@ : %@", filePath, [fileSizeError description]);
        if (failureBlock)
        {
            failureBlock(fileSizeError);
            return nil;
        }
    }

    return uploadDelegate;
}

/**
 * Helper method to send the xml (in memory) to the given url.
 */
- (void)asyncSendXMLInMemory:(NSURL *)url body:(NSString *)writeResult uploadDelegate:(CMISFileUploadDelegate *)uploadDelegate
{
    [HttpUtil invokePOSTAsynchronous:url
                      withSession:self.bindingSession
                      body:[writeResult dataUsingEncoding:NSUTF8StringEncoding]
                      headers:[NSDictionary dictionaryWithObject:kCMISMediaTypeEntry forKey:@"Content-type"]
                      withDelegate:uploadDelegate];
}

/**
 * Helper method to send the xml using a temporary file to the given url.
 */
- (void)asyncSendXMLUsingTempFile:(NSURL *)url tempFilePath:(NSString *)tempFilePath
                failureBlock:(CMISErrorFailureBlock)failureBlock uploadDelegate:(CMISFileUploadDelegate *)uploadDelegate
{
    NSInputStream *bodyStream = [NSInputStream inputStreamWithFileAtPath:tempFilePath];

    // Add cleanup block to close stream to input file and delete temporary file (after upload completion)
    uploadDelegate.fileUploadCleanupBlock = ^
    {
        // Close stream
        [bodyStream close];

        // Remove temp file
        NSError *internalError = nil;
        [[NSFileManager defaultManager] removeItemAtPath:tempFilePath error:&internalError];
        if (internalError)
        {
            if (failureBlock)
            {
                failureBlock([CMISErrors cmisError:internalError withCMISErrorCode:kCMISErrorCodeStorage]);
            }
            return;
        }
    };

    [HttpUtil invokePOSTAsynchronous:url withSession:self.bindingSession
                          bodyStream:bodyStream
                          headers:[NSDictionary dictionaryWithObject:kCMISMediaTypeEntry forKey:@"Content-type"]
                          withDelegate:uploadDelegate];
}


@end
