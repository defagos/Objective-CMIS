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

#import <Foundation/Foundation.h>
#import "ObjectiveCMISTests.h"
#import "CMISSession.h"
#import "CMISConstants.h"
#import "CMISDocument.h"
#import "CMISFileUtil.h"
#import "CMISAtomLink.h"
#import "CMISAtomPubConstants.h"
#import "CMISObjectList.h"
#import "CMISQueryResult.h"
#import "CMISStringInOutParameter.h"
#import "CMISTypeDefinition.h"
#import "CMISPropertyDefinition.h"
#import "CMISObjectConverter.h"
#import "CMISOperationContext.h"
#import "CMISPagedResult.h"
#import "CMISRenditionData.h"
#import "CMISRendition.h"
#import "CMISAllowableActionsParser.h"
#import "CMISAtomFeedParser.h"
#import "CMISServiceDocumentParser.h"
#import "CMISWorkspace.h"
#import "CMISRequest.h"
#import "CMISErrors.h"
#import "CMISDateUtil.h"

@interface ObjectiveCMISTests ()

@property (nonatomic, strong) CMISRequest *request;

@end


@implementation ObjectiveCMISTests

@synthesize request = _request;

- (void)testRepositories
{
    [self runTest:^
    {
        [CMISSession arrayOfRepositories:self.parameters completionBlock:^(NSArray *repos, NSError *error) {
            STAssertNil(error, @"Error when calling arrayOfRepositories : %@", [error description]);
            STAssertNotNil(repos, @"repos object should not be nil");
            STAssertTrue(repos.count > 0, @"There should be at least one repository");
            
            for (CMISRepositoryInfo *repoInfo in repos)
            {
                NSLog(@"Repo id: %@", repoInfo.identifier);
            }
            self.testCompleted = YES;
        }];
    }];
}

- (void)testAuthenticateWithInvalidCredentials
{
    [self runTest:^
    {
        CMISSessionParameters *bogusParams = [[CMISSessionParameters alloc] initWithBindingType:CMISBindingTypeAtomPub];
        bogusParams.atomPubUrl = self.parameters.atomPubUrl;
        bogusParams.repositoryId = self.parameters.repositoryId;
        bogusParams.username = @"bogus";
        bogusParams.password = @"sugob";

        [CMISSession connectWithSessionParameters:bogusParams completionBlock:^(CMISSession *session, NSError *error){
            STAssertNil(session, @"we should not get back a valid session");
            if (nil == session)
            {
                log(@"*** testAuthenticateWithInvalidCredentials: error domain is %@, error code is %d and error description is %@",[error domain], [error code], [error description]);
                NSError *underlyingError = [[error userInfo] valueForKey:NSUnderlyingErrorKey];
                if (underlyingError) {
                    log(@"There is an underlying error with reason %@ and error code %d",[underlyingError localizedDescription], [underlyingError code]);
                }
            }
            self.testCompleted = YES;
        }];        
    }];
}

- (void)testGetRootFolder
{
    [self runTest:^
    {
        // make sure the repository info is available immediately after authentication
        CMISRepositoryInfo *repoInfo = self.session.repositoryInfo;
        STAssertNotNil(repoInfo, @"repoInfo object should not be nil");

        // check the repository info is what we expect
        STAssertTrue([repoInfo.productVersion rangeOfString:@"4.0.0"].length > 0, @"Product Version should be 4.0.0 (b @build-number@), but was %@", repoInfo.productVersion);
        STAssertTrue([repoInfo.vendorName isEqualToString:@"Alfresco"], @"Vendor name should be Alfresco");

        // retrieve the root folder
        [self.session retrieveRootFolderWithCompletionBlock:^(CMISFolder *rootFolder, NSError *error) {
            STAssertNotNil(rootFolder, @"rootFolder object should not be nil");
            NSString *rootName = rootFolder.name;
            STAssertTrue([rootName isEqualToString:@"Company Home"], @"rootName should be Company Home, but was %@", rootName);

            // check it was modified and created by System and the dates are not nil
            NSString *createdBy = rootFolder.createdBy;
            STAssertTrue([createdBy isEqualToString:@"System"], @"root folder should be created by System");
            
            NSString *modifiedBy = rootFolder.lastModifiedBy;
            STAssertTrue([modifiedBy isEqualToString:@"System"], @"root folder should be modified by System");
            
            NSDate *createdDate = rootFolder.creationDate;
            STAssertNotNil(createdDate, @"created date should not be nil");
            
            NSDate *modifiedDate = rootFolder.lastModificationDate;
            STAssertNotNil(modifiedDate, @"modified date should not be nil");
            
            // retrieve the children of the root folder, there should be more than 10!
            [rootFolder retrieveChildrenWithCompletionBlock:^(CMISPagedResult *pagedResult, NSError *error) {
                STAssertNil(error, @"Got error while retrieving children: %@", [error description]);
                STAssertNotNil(pagedResult, @"Return result should not be nil");
                
                NSArray *children = pagedResult.resultArray;
                STAssertNotNil(children, @"children should not be nil");
                NSLog(@"There are %d children", [children count]);
                STAssertTrue([children count] >= 3, @"There should be at least 3 children");
                
                self.testCompleted = YES;
            }];
        }];
    }];
}

- (void)testRetrieveFolderChildrenUsingPaging
{
    [self runTest:^
    {
        // Fetch 2 children at a time
        CMISOperationContext *operationContext = [CMISOperationContext defaultOperationContext];
        operationContext.skipCount = 0;
        operationContext.maxItemsPerPage = 2;
        [self.session retrieveObjectByPath:@"/ios-test" completionBlock:^(CMISObject *object, NSError *error) {
            CMISFolder *testFolder = (CMISFolder *)object;
            STAssertNil(error, @"Got error while retrieving test folder: %@", [error description]);
            [testFolder retrieveChildrenWithOperationContext:operationContext completionBlock:^(CMISPagedResult *pagedResult, NSError *error) {
                STAssertNil(error, @"Got error while retrieving children: %@", [error description]);
                STAssertTrue(pagedResult.hasMoreItems, @"There should still be more children");
                STAssertTrue(pagedResult.numItems > 6, @"The test repository should have more than 6 objects");
                STAssertTrue(pagedResult.resultArray.count == 2, @"Expected 2 children in the page, but got %d", pagedResult.resultArray.count);
                
                // Save object ids for checking the next pages
                NSMutableArray *objectIds = [NSMutableArray array];
                for (CMISObject *object in pagedResult.resultArray)
                {
                    [objectIds addObject:object.identifier];
                }
                
                // Fetch second page
                [pagedResult fetchNextPageWithCompletionBlock:^(CMISPagedResult *secondPageResult, NSError *error) {
                    STAssertNil(error, @"Got error while retrieving children: %@", [error description]);
                    STAssertTrue(secondPageResult.hasMoreItems, @"There should still be more children");
                    STAssertTrue(secondPageResult.numItems > 6, @"The test repository should have more than 6 objects");
                    STAssertTrue(secondPageResult.resultArray.count == 2, @"Expected 2 children in the page, but got %d", secondPageResult.resultArray.count);
                    
                    // Verify if no double object ids were found
                    for (CMISObject *object in secondPageResult.resultArray)
                    {
                        STAssertTrue(![objectIds containsObject:object.identifier], @"Object was already returned in a previous page. This is a serious impl bug!");
                        [objectIds addObject:object.identifier];
                    }
                    
                    
                    // Bug on Alfresco server. Uncomment when fixed.
                    // Fetch third page, just to be sure
                    //    CMISPagedResult *thirdPageResult = [secondPageResult fetchNextPageAndReturnError:&error];
                    //    STAssertNil(error, @"Got error while retrieving children: %@", [error description]);
                    //    STAssertTrue(thirdPageResult.hasMoreItems, @"There should still be more children");
                    //    STAssertTrue(thirdPageResult.numItems > 6, @"The test repository should have more than 6 objects");
                    //    STAssertTrue(thirdPageResult.resultArray.count == 2, @"Expected 2 children in the page, but got %d", thirdPageResult.resultArray.count);
                    //
                    //    // Verify if no double object ids were found
                    //    for (CMISObject *object in thirdPageResult.resultArray)
                    //    {
                    //        STAssertTrue(![objectIds containsObject:object.identifier], @"Object was already returned in a previous page. This is a serious impl bug!");
                    //        [objectIds addObject:object.identifier];
                    //    }
                    
                    self.testCompleted = YES;
                }];
            }];
        }];
    }];
}

- (void)testDocumentProperties
{
    [self runTest:^
    {

        // Get some random document
        [self retrieveVersionedTestDocumentWithCompletionBlock:^(CMISDocument *document) {
            // Verify properties
            STAssertNotNil(document.name, @"Document name should not be nil");
            STAssertNotNil(document.identifier, @"Document identifier should not be nil");
            STAssertNotNil(document.objectType, @"Document object type should not be nil");
            
            STAssertNotNil(document.createdBy, @"Document created by should not be nil");
            STAssertNotNil(document.creationDate, @"Document creation date should not be nil");
            
            STAssertNotNil(document.lastModificationDate, @"Document last modification date should not be nil");
            STAssertNotNil(document.lastModifiedBy, @"Document last modified by should not be nil");
            
            STAssertNotNil(document.versionLabel, @"Document version label should not be nil");
            STAssertNotNil(document.versionSeriesId, @"Document version series id should not be nil");
            STAssertTrue(document.isLatestVersion, @"Document should be latest version");
            STAssertFalse(document.isLatestMajorVersion, @"Document should be latest major version");
            STAssertFalse(document.isMajorVersion, @"Document should be major version");
            
            STAssertNotNil(document.contentStreamId, @"Document content stream id should not be nil");
            STAssertNotNil(document.contentStreamFileName, @"Document content stream file name should not be nil");
            STAssertNotNil(document.contentStreamMediaType, @"Document content stream media type should not be nil");
            STAssertTrue(document.contentStreamLength > 0, @"Document content stream length should be set");
            
            self.testCompleted = YES;
        }];
    }];
}


- (void)testRetrieveAllowableActions
{
    [self runTest:^
    {
        [self uploadTestFileWithCompletionBlock:^(CMISDocument *document) {
            STAssertNotNil(document.allowableActions, @"Allowable actions should not be nil");
            STAssertTrue(document.allowableActions.allowableActionsSet.count > 0, @"Expected at least one allowable action");
            
            // Cleanup
            [self deleteDocumentAndVerify:document completionBlock:^{
                self.testCompleted = YES;
            }];
        }];
    }];
}

- (void)testFileDownload
{
    [self runTest:^
    {
        [self.session retrieveObjectByPath:@"/ios-test" completionBlock:^(CMISObject *object, NSError *error) {
            CMISFolder *testFolder = (CMISFolder *)object;
            STAssertNil(error, @"Error while retrieving folder: %@", [error description]);
            STAssertNotNil(testFolder, @"folder object should not be nil");
            
            CMISOperationContext *operationContext = [CMISOperationContext defaultOperationContext];
            operationContext.maxItemsPerPage = 100;
            [testFolder retrieveChildrenWithOperationContext:operationContext completionBlock:^(CMISPagedResult *childrenResult, NSError *error) {
                STAssertNil(error, @"Got error while retrieving children: %@", [error description]);
                STAssertNotNil(childrenResult, @"childrenCollection should not be nil");
                
                NSArray *children = childrenResult.resultArray;
                STAssertNotNil(children, @"children should not be nil");
                STAssertTrue([children count] >= 3, @"There should be at least 3 children");
                
                CMISDocument *randomDoc = nil;
                for (CMISObject *object in children)
                {
                    if ([object class] == [CMISDocument class])
                    {
                        randomDoc = (CMISDocument *)object;
                    }
                }
                
                STAssertNotNil(randomDoc, @"Can only continue test if test folder contains at least one document");
                NSLog(@"Fetching content stream for document %@", randomDoc.name);
                
                // Writing content of CMIS document to local file
                NSString *filePath = [NSString stringWithFormat:@"%@/testfile", NSTemporaryDirectory()];
//                NSString *filePath = @"testfile";
                [randomDoc downloadContentToFile:filePath
                                 completionBlock:^(NSError *error) {
                    if (error == nil) {
                        // Assert File exists and check file length
                        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:filePath], @"File does not exist");
                        NSError *fileError = nil;
                        NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&fileError];
                        STAssertNil(fileError, @"Could not verify attributes of file %@: %@", filePath, [fileError description]);
                        STAssertTrue([fileAttributes fileSize] > 10, @"Expected a file of at least 10 bytes, but found one of %d bytes", [fileAttributes fileSize]);
                        
                        // Nice boys clean up after themselves
                        [[NSFileManager defaultManager] removeItemAtPath:filePath error:&fileError];
                        STAssertNil(fileError, @"Could not remove file %@: %@", filePath, [fileError description]);
                    } else {
                        STAssertNil(error, @"Error while writing content: %@", [error description]);
                    }
                    self.testCompleted = YES;
                } progressBlock:nil];
            }];
        }];
    }];
}

- (void)testCancelDownload
{
    [self runTest:^
     {
         [self.session retrieveObjectByPath:@"/ios-test/activiti-modeler.png" completionBlock:^(CMISObject *object, NSError *error) {
             CMISDocument *document = (CMISDocument *)object;
             STAssertNil(error, @"Error while retrieving object: %@", [error description]);

             // Writing content of CMIS document to local file
             NSString *filePath = [NSString stringWithFormat:@"%@/testfile", NSTemporaryDirectory()];
             self.request = [document downloadContentToFile:filePath
                                            completionBlock:^(NSError *error)
             {
                 STAssertNotNil(error, @"Could not cancel download");
                 STAssertTrue(error.code == kCMISErrorCodeCancelled, @"Unexpected error: %@", [error description]);
                 // Assert File exists and check file length
                 STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:filePath], @"File does not exist");
                 NSError *fileError = nil;
                 NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&fileError];
                 STAssertNil(fileError, @"Could not verify attributes of file %@: %@", filePath, [fileError description]);
                 STAssertTrue([fileAttributes fileSize] > 0, @"Expected at least some bytes but found an empty file");
                 STAssertTrue([fileAttributes fileSize] < document.contentStreamLength, @"Could not cancel download before the complete file was downloaded");
                                          
                 // Nice boys clean up after themselves
                 [[NSFileManager defaultManager] removeItemAtPath:filePath error:&fileError];
                 STAssertNil(fileError, @"Could not remove file %@: %@", filePath, [fileError description]);

                 self.testCompleted = YES;
             } progressBlock:^(unsigned long long bytesDownloaded, unsigned long long bytesTotal) {
                 if (bytesDownloaded > 0) { // as soon as some data was downloaded cancel the request
                     [self.request cancel];
                     self.request = nil;
                 }
             }];
         }];
     }];
}

- (void)testCreateAndDeleteDocument
{
    [self runTest:^
    {
        // Check if test file exists
        NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test_file.txt" ofType:nil];
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:filePath],
            @"Test file 'test_file.txt' cannot be found as resource for the test");

        // Upload test file
        NSString *documentName = [NSString stringWithFormat:@"test_file_%@.txt", [self stringFromCurrentDate]];
        NSMutableDictionary *documentProperties = [NSMutableDictionary dictionary];
        [documentProperties setObject:documentName forKey:kCMISPropertyName];
        [documentProperties setObject:kCMISPropertyObjectTypeIdValueDocument forKey:kCMISPropertyObjectTypeId];

        __block long long previousBytesUploaded = -1;
        [self.rootFolder createDocumentFromFilePath:filePath
                                       withMimeType:@"text/plain"
                                     withProperties:documentProperties
                                    completionBlock:^ (NSString *objectId, NSError *error)
             {
                 if (objectId) {
                     STAssertNotNil(objectId, @"Object id received should be non-nil");

                     // Verify creation
                     [self.session retrieveObject:objectId completionBlock:^(CMISObject *object, NSError *error) {
                         CMISDocument *document = (CMISDocument *)object;
                         STAssertTrue([documentName isEqualToString:document.name],
                                      @"Document name of created document is wrong: should be %@, but was %@", documentName, document.name);
                         
                         // Cleanup after ourselves
                         [document deleteAllVersionsWithCompletionBlock:^(BOOL documentDeleted, NSError *deleteError) {
                             STAssertNil(deleteError, @"Error while deleting created document: %@", [error description]);
                             STAssertTrue(documentDeleted, @"Document was not deleted");
                             
                             self.testCompleted = YES;
                         }];
                     }];
                 } else {
                     STAssertNil(error, @"Got error while creating document: %@", [error description]);
                     
                     self.testCompleted = YES;
                 }
             }
             progressBlock: ^ (unsigned long long bytesUploaded, unsigned long long bytesTotal)
             {
                 STAssertTrue((long long)bytesUploaded > previousBytesUploaded, @"No progress was made");
                 previousBytesUploaded = bytesUploaded;
             }];
    }];
}

- (void)testUploadFileThroughSession
{
    [self runTest:^
    {

        // Set properties on test file
        NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test_file.txt" ofType:nil];
        NSString *documentName = [NSString stringWithFormat:@"test_file_%@.txt", [self stringFromCurrentDate]];
        NSMutableDictionary *documentProperties = [NSMutableDictionary dictionary];
        [documentProperties setObject:documentName forKey:kCMISPropertyName];
        [documentProperties setObject:kCMISPropertyObjectTypeIdValueDocument forKey:kCMISPropertyObjectTypeId];

        // Upload test file
        __block long long previousUploadedBytes = -1;
        __block NSString *objectId = nil;
        [self.session createDocumentFromFilePath:filePath
                withMimeType:@"text/plain"
                withProperties:documentProperties
                inFolder:self.rootFolder.identifier
                completionBlock: ^ (NSString *newObjectId, NSError *error)
                {
                    if (newObjectId) {
                        objectId = newObjectId;
                   
                        [self.session retrieveObject:objectId completionBlock:^(CMISObject *object, NSError *error) {
                            CMISDocument *document = (CMISDocument *)object;
                            STAssertNil(error, @"Got error while creating document: %@", [error description]);
                            STAssertNotNil(objectId, @"Object id received should be non-nil");
                            STAssertNotNil(document, @"Retrieved document should not be nil");
                            STAssertTrue(document.contentStreamLength > 0, @"No content found for document");
                            
                            // Cleanup
                            [self deleteDocumentAndVerify:document completionBlock:^{
                                self.testCompleted = YES;
                            }];
                        }];
                    } else {
                        STAssertNotNil(error, @"Object id should not be nil");
                        STAssertNil(error, @"Got error while uploading document: %@", [error description]);
                        self.testCompleted = YES;
                    }
                }
                progressBlock: ^ (unsigned long long uploadedBytes, unsigned long long totalBytes)
                {
                    STAssertTrue((long long)uploadedBytes > previousUploadedBytes, @"no progress");
                    previousUploadedBytes = uploadedBytes;
                }];
    }];
}

- (void)testCreateBigDocument
{
    [self runTest:^
    {
        // Check if test file exists
        NSString *fileToUploadPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"cmis-spec-v1.0.pdf" ofType:nil];
        STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:fileToUploadPath],
            @"Test file 'cmis-spec-v1.0.pdf' cannot be found as resource for the test");

        // Upload test file
        NSString *documentName = [NSString stringWithFormat:@"cmis-spec-v1.0_%@.pdf", [self stringFromCurrentDate]];
        NSMutableDictionary *documentProperties = [NSMutableDictionary dictionary];
        [documentProperties setObject:documentName forKey:kCMISPropertyName];
        [documentProperties setObject:kCMISPropertyObjectTypeIdValueDocument forKey:kCMISPropertyObjectTypeId];

        __block long long previousBytesUploaded = -1;
        __block NSString *objectId;
        [self.rootFolder createDocumentFromFilePath:fileToUploadPath
                                       withMimeType:@"application/pdf"
                                     withProperties:documentProperties
                                    completionBlock:^(NSString *newObjectId, NSError *error)
               {
                   if (newObjectId) {
                       NSLog(@"File upload completed");
                       
                       objectId = newObjectId;
                       STAssertNotNil(objectId, @"Object id received should be non-nil");
                       
                       // Verify created file by downloading it again
                       [self.session retrieveObject:objectId completionBlock:^(CMISObject *object, NSError *error) {
                           CMISDocument *document = (CMISDocument *)object;
                           STAssertTrue([documentName isEqualToString:document.name],
                                        @"Document name of created document is wrong: should be %@, but was %@", documentName, document.name);
                           
                           __block long long previousBytesDownloaded = -1;
                           NSString *downloadedFilePath = [NSString stringWithFormat:@"%@/testfile.pdf", NSTemporaryDirectory()];
//                           NSString *downloadedFilePath = @"testfile.pdf";
                           [document downloadContentToFile:downloadedFilePath completionBlock:^(NSError *error) {
                               if (error == nil) {
                                   NSLog(@"File download completed");
                                   
                                   // Compare file sizes
                                   NSError *fileError;
                                   unsigned long long originalFileSize = [FileUtil fileSizeForFileAtPath:fileToUploadPath error:&fileError];
                                   STAssertNil(fileError, @"Got error while getting file size for %@: %@", fileToUploadPath, [fileError description]);
                                   unsigned long long downloadedFileSize = [FileUtil fileSizeForFileAtPath:downloadedFilePath error:&fileError];
                                   STAssertNil(fileError, @"Got error while getting file size for %@: %@", downloadedFilePath, [fileError description]);
                                   STAssertTrue(originalFileSize == downloadedFileSize, @"Original file size (%llu) is not equal to downloaded file size (%llu)", originalFileSize, downloadedFileSize);
                                   
                                   // Cleanup after ourselves
                                   [document deleteAllVersionsWithCompletionBlock:^(BOOL documentDeleted, NSError *error) {
                                       STAssertNil(error, @"Error while deleting created document: %@", [error description]);
                                       STAssertTrue(documentDeleted, @"Document was not deleted");
                                       
                                       NSError *internalError;
                                       [[NSFileManager defaultManager] removeItemAtPath:downloadedFilePath error:&internalError];
                                       STAssertNil(error, @"Could not remove file %@: %@", downloadedFilePath, [error description]);
                                       
                                       self.testCompleted = YES;
                                   }];
                               } else {
                                   STAssertNil(error, @"Error while writing content: %@", [error description]);
                                   
                                   self.testCompleted = YES;
                               }
                           } progressBlock:^(unsigned long long bytesDownloaded, unsigned long long bytesTotal) {
                               STAssertTrue((long long)bytesDownloaded > previousBytesDownloaded, @"No progress in downloading file");
                               previousBytesDownloaded = bytesDownloaded;
                           }];
                       }];
                   } else {
                       STAssertNil(error, @"Got error while creating document: %@", [error description]);
                       
                       self.testCompleted = YES;
                   }
               }
               progressBlock:^(unsigned long long bytesUploaded, unsigned long long bytesTotal)
               {
                   STAssertTrue((long long)bytesUploaded > previousBytesUploaded, @"No progress was made");
                   previousBytesUploaded = bytesUploaded;
               }];
    }];
}

- (void)testCreateAndDeleteFolder
{
    [self runTest:^
    {
        // Create a test folder
        NSMutableDictionary *properties = [NSMutableDictionary dictionary];
        NSString *folderName = [NSString stringWithFormat:@"test-folder-%@", [self stringFromCurrentDate]];
        [properties setObject:folderName forKey:kCMISPropertyName];
        [properties setObject:kCMISPropertyObjectTypeIdValueFolder forKey:kCMISPropertyObjectTypeId];

        [self.rootFolder createFolder:properties completionBlock:^(NSString *newFolderObjectId, NSError *error) {
            STAssertNil(error, @"Error while creating folder in root folder: %@", [error description]);
            
            // Delete the test folder again
            [self.session retrieveObject:newFolderObjectId completionBlock:^(CMISObject *object, NSError *error) {
                CMISFolder *newFolder = (CMISFolder *)object;
                STAssertNil(error, @"Error while retrieving newly created folder: %@", [error description]);
                STAssertNotNil(newFolder, @"New folder should not be nil");
                [newFolder deleteTreeWithDeleteAllVersions:YES withUnfileObjects:CMISDelete withContinueOnFailure:YES completionBlock:^(NSArray *failedObjects, NSError *error) {
                    STAssertNil(error, @"Error while deleting newly created folder: %@", [error description]);

                    self.testCompleted = YES;
                }];
            }];
        }];
    }];
}

- (void)testRetrieveAllVersionsOfDocument
{
    [self runTest:^
    {
        // First find the document which we know that has some versions
        [self retrieveVersionedTestDocumentWithCompletionBlock:^(CMISDocument *document) {
            // Get all the versions of the document
            [document retrieveAllVersionsWithCompletionBlock:^(CMISCollection *allVersionsOfDocument, NSError *error) {
                STAssertNil(error, @"Error while retrieving all versions of document : %@", [error description]);
                STAssertTrue(allVersionsOfDocument.items.count == 6, @"Expected 6 versions of document, but was %d", allVersionsOfDocument.items.count);
                
                // Print out the version labels and verify them, while also verifying that they are ordered by creation date, descending
                NSDate *previousModifiedDate = document.lastModificationDate;
                for (CMISDocument *versionOfDocument in allVersionsOfDocument.items)
                {
                    NSLog(@"%@ - version %@", versionOfDocument.name, versionOfDocument.versionLabel);
                    
                    if (!versionOfDocument.isLatestVersion) // latest version is the one we got originally
                    {
                        STAssertTrue([document.name isEqualToString:versionOfDocument.name], @"Other version of same document does not have the same name");
                        STAssertFalse([document.versionLabel isEqualToString:versionOfDocument.versionLabel], @"Other version of same document should have different version label");
                        STAssertTrue([previousModifiedDate compare:versionOfDocument.lastModificationDate] == NSOrderedDescending,
                                     @"Versions of document should be ordered descending by creation date");
                        previousModifiedDate = versionOfDocument.lastModificationDate;
                    }
                }
                
                // Take an older version, and verify its version properties
                CMISDocument *olderVersionOfDocument = [allVersionsOfDocument.items objectAtIndex:3]; // In the test data, this should be version 1.0 of doc.
                STAssertFalse(olderVersionOfDocument.isLatestVersion, @"Older version of document should have 'false' for the property 'isLatestVersion");
                STAssertFalse(olderVersionOfDocument.isLatestMajorVersion, @"Older version of document should have 'false' for the property 'isLatestMajorVersion");

                self.testCompleted = YES;
            }];
        }];
    }];
}

-(void)testRetrieveLatestVersionOfDocument
{
    [self runTest:^
    {
         // First find the document which we know that has some versions
        [self retrieveVersionedTestDocumentWithCompletionBlock:^(CMISDocument *document) {
            // Check if the document retrieved is the latest version
            [document retrieveObjectOfLatestVersionWithMajorVersion:NO completionBlock:^(CMISDocument *latestVersionOfDocument, NSError *error) {
                STAssertNil(error, @"Error while retrieving latest version of document");
                STAssertTrue([document.versionLabel isEqualToString:latestVersionOfDocument.versionLabel], @"Version label should match");
                STAssertTrue([document.creationDate isEqual:latestVersionOfDocument.creationDate], @"Creation dates should be equal");
                
                // Retrieve an older version, and check if we get the right one back if we call the 'retrieveLatest' on it
                [document retrieveAllVersionsWithCompletionBlock:^(CMISCollection *allVersionsOfDocument, NSError *error) {
                    STAssertNil(error, @"Error while retrieving all versions: %@", [error description]);
                    
                    CMISDocument *olderVersionOfDocument = [allVersionsOfDocument.items objectAtIndex:1];
                    STAssertFalse([document.versionLabel isEqualToString:olderVersionOfDocument.versionLabel], @"Version label should NOT match");
                    
                    // Commented out due to different behaviour when using 'cmisatom' url
                    //    STAssertTrue([document.creationDate isEqualToDate:olderVersionOfDocument.creationDate], @"Creation dates should match: %@ vs %@", document.creationDate, olderVersionOfDocument.creationDate);
                    
                    STAssertFalse([document.lastModificationDate isEqual:olderVersionOfDocument.lastModificationDate], @"Creation dates should NOT match");
                    
                    
                    [olderVersionOfDocument retrieveObjectOfLatestVersionWithMajorVersion:NO completionBlock:^(CMISDocument *latestVersionOfDocument, NSError *error) {
                        STAssertNil(error, @"Error while retrieving latest version of document");
                        STAssertNotNil(latestVersionOfDocument, @"Latest version should not be nil");
                        STAssertTrue([document.name isEqualToString:latestVersionOfDocument.name], @"Name should match: expected %@ but was %@", document.name, latestVersionOfDocument.name);
                        STAssertTrue([document.versionLabel isEqualToString:latestVersionOfDocument.versionLabel], @"Version label should match");
                        STAssertTrue([document.lastModificationDate isEqual:latestVersionOfDocument.lastModificationDate], @"Creation dates should be equal");

                        self.testCompleted = YES;
                    }];
                }];
            }];
        }];
    }];
}

- (void)testLinkRelations
{
    NSMutableSet *setup = [NSMutableSet set];
    [setup addObject:[[CMISAtomLink alloc] initWithRelation:@"down" type:kCMISMediaTypeChildren href:@"http://down/children"]];
    [setup addObject:[[CMISAtomLink alloc] initWithRelation:@"down" type:kCMISMediaTypeDescendants href:@"http://down/descendants"]];
    [setup addObject:[[CMISAtomLink alloc] initWithRelation:@"up" type:kCMISMediaTypeChildren href:@"http://up/children"]];
    [setup addObject:[[CMISAtomLink alloc] initWithRelation:@"up" type:kCMISMediaTypeEntry href:@"http://up/entry"]];
    [setup addObject:[[CMISAtomLink alloc] initWithRelation:@"service" type:nil href:@"http://service"]];
    CMISLinkRelations *linkRelations = [[CMISLinkRelations alloc] initWithLinkRelationSet:setup];
    
    STAssertNil([linkRelations linkHrefForRel:@"down"], @"Expected nil since there are more link relations with the down relations");
    STAssertEquals([linkRelations linkHrefForRel:@"service"], @"http://service", @"The Service link should have been returned");
    STAssertEquals([linkRelations linkHrefForRel:@"down" type:kCMISMediaTypeChildren], @"http://down/children", @"The down relation for the children media type should have been returned");
    STAssertEquals([linkRelations linkHrefForRel:@"down" type:kCMISMediaTypeDescendants], @"http://down/descendants", @"The down relation for the descendants media type should have been returned");
}

- (void)testQueryThroughDiscoveryService
{
    [self runTest:^
    {
        id<CMISDiscoveryService> discoveryService = self.session.binding.discoveryService;
        STAssertNotNil(discoveryService, @"Discovery service should not be nil");

        // Basic check if the service returns results that are usable
        [discoveryService
         query:@"SELECT * FROM cmis:document" searchAllVersions:NO
         includeRelationShips:CMISIncludeRelationshipNone
         renditionFilter:nil
         includeAllowableActions:YES
         maxItems:[NSNumber numberWithInt:3]
         skipCount:[NSNumber numberWithInt:0]
         completionBlock:^(CMISObjectList *objectList, NSError *error) {
             STAssertNil(error, @"Got an error while executing query: %@", [error description]);
             STAssertNotNil(objectList, @"Object list after query should not be nil");
             
             // numitems not supported by cmisatom url
             //    STAssertTrue(objectList.numItems > 100, @"Expecting at least 100 items when querying for all documents, but got %d", objectList.numItems);
             
             STAssertTrue(objectList.objects.count == 3, @"Expected 3 items to be returned, but was %d", objectList.objects.count);
             
             for (CMISObjectData *objectData in objectList.objects)
             {
                 STAssertTrue(objectData.properties.propertiesDictionary.count > 10, @"Expecting properties to be passed when querying");
             }
             
             // Doing a query without any maxItems or skipCount, and also only requesting one property 'column'
             [discoveryService
              query:@"SELECT cmis:name FROM cmis:document WHERE cmis:name LIKE '%quote%'"
              searchAllVersions:NO
              includeRelationShips:CMISIncludeRelationshipNone
              renditionFilter:nil
              includeAllowableActions:YES
              maxItems:nil skipCount:nil completionBlock:^(CMISObjectList *objectList, NSError *error) {
                  STAssertNil(error, @"Got an error while executing query: %@", [error description]);
                  STAssertNotNil(objectList, @"Object list after query should not be nil");
                  STAssertTrue(objectList.objects.count > 0, @"Returned # objects is repo specific, but should be at least 1");
                  
                  CMISObjectData *firstResult = [objectList.objects objectAtIndex:0];
                  STAssertTrue(firstResult.properties.propertiesDictionary.count == 1, @"Only querying for 1 property, but got %d properties back", firstResult.properties.propertiesDictionary.count);
                  
                  self.testCompleted = YES;
              }];
         }];
    }];
}

- (void)testQueryThroughSession
{
    [self runTest:^
     {
         // Query all properties
         [self.session query:@"SELECT * FROM cmis:document WHERE cmis:name LIKE '%quote%'" searchAllVersions:NO completionBlock:^(CMISPagedResult *result, NSError *error) {
             STAssertNil(error, @"Got an error while executing query: %@", [error description]);
             STAssertTrue(result.resultArray.count > 0, @"Expected at least one result for query");
             
             CMISQueryResult *firstResult = [result.resultArray objectAtIndex:0];
             STAssertNotNil([firstResult.properties propertyForId:kCMISPropertyName], @"Name property should not be nil");
             STAssertNotNil([firstResult.properties propertyForId:kCMISPropertyVersionLabel], @"Version label property should not be nil");
             STAssertNotNil([firstResult.properties propertyForId:kCMISPropertyCreationDate], @"Creation date property should not be nil");
             STAssertNotNil([firstResult.properties propertyForId:kCMISPropertyContentStreamLength], @"Content stream length property should not be nil");
             
             STAssertNotNil([firstResult.properties propertyForQueryName:kCMISPropertyName], @"Name property should not be nil");
             STAssertNotNil([firstResult.properties propertyForQueryName:kCMISPropertyVersionLabel], @"Version label property should not be nil");
             STAssertNotNil([firstResult.properties propertyForQueryName:kCMISPropertyCreationDate], @"Creation date property should not be nil");
             STAssertNotNil([firstResult.properties propertyForQueryName:kCMISPropertyContentStreamLength], @"Content stream length property should not be nil");
             
             // Query a limited set of properties
             [self.session query:@"SELECT cmis:name, cmis:creationDate FROM cmis:document WHERE cmis:name LIKE '%activiti%'" searchAllVersions:NO completionBlock:^(CMISPagedResult *result, NSError *error) {
                 STAssertNil(error, @"Got an error while executing query: %@", [error description]);
                 STAssertTrue(result.resultArray.count > 0, @"Expected at least one result for query");
                 
                 CMISQueryResult *firstResult = [result.resultArray objectAtIndex:0];
                 STAssertNotNil([firstResult.properties propertyForId:kCMISPropertyName], @"Name property should not be nil");
                 STAssertNotNil([firstResult.properties propertyForId:kCMISPropertyCreationDate], @"Creation date property should not be nil");
                 STAssertNil([firstResult.properties propertyForId:kCMISPropertyVersionLabel], @"Version label property should be nil");
                 STAssertNil([firstResult.properties propertyForId:kCMISPropertyContentStreamLength], @"Content stream length property should be nil");
                 STAssertNotNil(firstResult.allowableActions, @"By default, allowable actions whould be included");
                 STAssertTrue(firstResult.allowableActions.allowableActionsSet.count > 0, @"Expected at least one allowable action");
                 // With operationContext
                 CMISOperationContext *context = [CMISOperationContext defaultOperationContext];
                 context.isIncludeAllowableActions = NO;
                 [self.session query:@"SELECT * FROM cmis:document WHERE cmis:name LIKE '%quote%'"
                   searchAllVersions:NO operationContext:context completionBlock:^(CMISPagedResult *result, NSError *error) {
                       STAssertNil(error, @"Got an error while executing query: %@", [error description]);
                       STAssertTrue(result.resultArray.count > 0, @"Expected at least one result for query");
                       CMISQueryResult *firstResult = [result.resultArray objectAtIndex:0];
                       STAssertTrue(firstResult.allowableActions.allowableActionsSet.count == 0,
                                    @"Expected allowable actions, as the operation ctx excluded them, but found %d allowable actions", firstResult.allowableActions.allowableActionsSet.count);

                       self.testCompleted = YES;
                   }];
             }];
         }];
     }];
}

- (void)testQueryWithPaging
{
    [self runTest:^
     {
         // Fetch first page
         CMISOperationContext *context = [[CMISOperationContext alloc] init];
         context.maxItemsPerPage = 5;
         context.skipCount = 0;
         [self.session query:@"SELECT * FROM cmis:document" searchAllVersions:NO operationContext:context completionBlock:^(CMISPagedResult *firstPageResult, NSError *error) {
             STAssertNil(error, @"Got an error while executing query: %@", [error description]);
             STAssertTrue(firstPageResult.resultArray.count == 5, @"Expected 5 results, but got %d back", firstPageResult.resultArray.count);
             
             // Save all the ids to check them later
             NSMutableArray *idsOfFirstPage = [NSMutableArray array];
             for (CMISQueryResult *queryresult in firstPageResult.resultArray)
             {
                 [idsOfFirstPage addObject:[queryresult propertyForId:kCMISPropertyObjectId]];
             }
             
             // Fetch second page
             [firstPageResult fetchNextPageWithCompletionBlock:^(CMISPagedResult *secondPageResults, NSError *error) {
                 STAssertNil(error, @"Got an error while executing query: %@", [error description]);
                 STAssertTrue(secondPageResults.resultArray.count == 5, @"Expected 5 results, but got %d back", secondPageResults.resultArray.count);
                 
                 for (CMISQueryResult *queryResult in secondPageResults.resultArray)
                 {
                     STAssertFalse([idsOfFirstPage containsObject:[queryResult propertyForId:kCMISPropertyObjectId]], @"Found same object in first and second page");
                 }
                 
                 // Fetch last element by specifying a page which is just lastelement-1
                 
                 // Commented due to 'cmisatom' not supporting numItems
                 //    context.skipCount = secondPageResults.numItems - 1;
                 //    CMISPagedResult *thirdPageResults = [self.session query:@"SELECT * FROM cmis:document"
                 //                                            searchAllVersions:NO operationContext:context error:&error];
                 //    STAssertNil(error, @"Got an error while executing query: %@", [error description]);
                 //    STAssertTrue(thirdPageResults.resultArray.count == 1, @"Expected 1 result, but got %d back", thirdPageResults.resultArray.count);
                 
                 self.testCompleted = YES;
             }];
         }];
     }];
}

- (void)testQueryObjects
{
    [self runTest:^
     {
         // Fetch first page
         CMISOperationContext *context = [[CMISOperationContext alloc] init];
         context.maxItemsPerPage = 2;
         context.skipCount = 0;
         [self.session
          queryObjectsWithTypeid:@"cmis:document"
          withWhereClause:nil
          searchAllVersions:NO operationContext:context completionBlock:^(CMISPagedResult *firstPageResult, NSError *error) {
              STAssertNil(error, @"Got an error while executing query: %@", [error description]);
              STAssertTrue(firstPageResult.resultArray.count == 2, @"Expected 2 results, but got %d back", firstPageResult.resultArray.count);
              
              // Save all the ids to check them later
              NSMutableArray *idsOfFirstPage = [NSMutableArray array];
              for (CMISDocument *document in firstPageResult.resultArray)
              {
                  [idsOfFirstPage addObject:document.identifier];
              }
              
              // Fetch second page
              [firstPageResult fetchNextPageWithCompletionBlock:^(CMISPagedResult *secondPageResults, NSError *error) {
                  STAssertNil(error, @"Got an error while executing query: %@", [error description]);
                  STAssertTrue(secondPageResults.resultArray.count == 2, @"Expected 2 results, but got %d back", secondPageResults.resultArray.count);
                  
                  for (CMISDocument *document in secondPageResults.resultArray)
                  {
                      STAssertFalse([idsOfFirstPage containsObject:document.identifier], @"Found same object in first and second page");
                  }
                  
                  self.testCompleted = YES;
              }];
          }];
     }];
}

- (void)testRetrieveParents
{
    [self runTest:^
     {
         // First, do a query for our test document
         NSString *queryStmt = @"SELECT * FROM cmis:document WHERE cmis:name = 'thumbsup-ios-test-retrieve-parents.gif'";
         [self.session query:queryStmt searchAllVersions:NO completionBlock:^(CMISPagedResult *results, NSError *error) {
             STAssertNil(error, @"Got an error while executing query: %@", [error description]);
             STAssertTrue(results.resultArray.count == 1, @"Expected one result for query");
             CMISQueryResult *result = [results.resultArray objectAtIndex:0];
             
             // Retrieve the document as CMISDocument
             NSString *objectId = [[result propertyForId:kCMISPropertyObjectId] firstValue];
             [self.session retrieveObject:objectId completionBlock:^(CMISObject *object, NSError *error) {
                 CMISDocument *document = (CMISDocument *)object;
                 STAssertNil(error, @"Got an error while retrieving test document: %@", [error description]);
                 STAssertNotNil(document, @"Test document should not be nil");
                 
                 // Verify the parents of this document
                 CMISFileableObject *currentObject = document;
                 
                 [currentObject retrieveParentsWithCompletionBlock:^(NSArray *parentFolders, NSError *error) {
                     STAssertNil(error, @"Got an error while retrieving parent folders: %@", [error description]);
                     STAssertTrue(parentFolders.count == 1, @"Expecting only 1 parent, but found %d parents", parentFolders.count);
                     CMISFileableObject *currentObject = [parentFolders objectAtIndex:0];
                     STAssertEqualObjects(@"ios-subsubfolder", currentObject.name, @"Wrong parent folder");
                     [currentObject retrieveParentsWithCompletionBlock:^(NSArray *parentFolders, NSError *error) {
                         STAssertNil(error, @"Got an error while retrieving parent folders: %@", [error description]);
                         STAssertTrue(parentFolders.count == 1, @"Expecting only 1 parent, but found %d parents", parentFolders.count);
                         CMISFileableObject *currentObject = [parentFolders objectAtIndex:0];
                         STAssertEqualObjects(@"ios-subfolder", currentObject.name, @"Wrong parent folder");
                         [currentObject retrieveParentsWithCompletionBlock:^(NSArray *parentFolders, NSError *error) {
                             STAssertNil(error, @"Got an error while retrieving parent folders: %@", [error description]);
                             STAssertTrue(parentFolders.count == 1, @"Expecting only 1 parent, but found %d parents", parentFolders.count);
                             CMISFileableObject *currentObject = [parentFolders objectAtIndex:0];
                             STAssertEqualObjects(@"ios-test", currentObject.name, @"Wrong parent folder");
                             [currentObject retrieveParentsWithCompletionBlock:^(NSArray *parentFolders, NSError *error) {
                                 STAssertNil(error, @"Got an error while retrieving parent folders: %@", [error description]);
                                 STAssertTrue(parentFolders.count == 1, @"Expecting only 1 parent, but found %d parents", parentFolders.count);
                                 CMISFileableObject *currentObject = [parentFolders objectAtIndex:0];
                                 STAssertEqualObjects(@"Company Home", currentObject.name, @"Wrong parent folder");
                                 // Check if the root folder parent is empty
                                 [currentObject retrieveParentsWithCompletionBlock:^(NSArray *parentFolders, NSError *error) {
                                     STAssertNil(error, @"Got an error while retrieving parent folders: %@", [error description]);
                                     STAssertTrue(parentFolders.count == 0, @"Root folder should not have any parents");

                                     self.testCompleted = YES;
                                 }];
                             }];
                         }];
                     }];
                 }];
             }];
         }];
     }];
}

- (void)testRetrieveNonExistingObject
{
    [self runTest:^
     {
         // test with non existing object id
         [self.session retrieveObject:@"bogus" completionBlock:^(CMISObject *object, NSError *error) {
             CMISDocument *document = (CMISDocument *)object;
             STAssertNotNil(error, @"Expecting error when retrieving object with wrong id");
             STAssertNil(document, @"Document should be nil");
             
             // Test with a non existing path
             NSString *path = @"/bogus/i_do_not_exist.pdf";
             [self.session retrieveObjectByPath:path completionBlock:^(CMISObject *object, NSError *error) {
                 CMISDocument *document = (CMISDocument *)object;
                 STAssertNotNil(error, @"Expecting error when retrieving object with wrong path");
                 STAssertNil(document, @"Document should be nil");

                 self.testCompleted = YES;
             }];
         }];
     }];
}

- (void)testRetrieveObjectByPath
{
    [self runTest:^
     {
         // Use a document that has spaces in them (should be correctly encoded)
         NSString *path = [NSString stringWithFormat:@"%@ios-test/activiti logo big.png", self.rootFolder.path];
         [self.session retrieveObjectByPath:path completionBlock:^(CMISObject *object, NSError *error) {
             CMISDocument *document = (CMISDocument *)object;
             STAssertNil(error, @"Error while retrieving object with path %@", path);
             STAssertNotNil(document, @"Document should not be nil");
             STAssertEqualObjects(@"activiti logo big.png", document.name, @"When retrieving document by path, name does not match");
             
             // Test with a few folders
             NSString *path = @"/ios-test/ios-subfolder/ios-subsubfolder/activiti-logo.png";
             [self.session retrieveObjectByPath:path completionBlock:^(CMISObject *object, NSError *error) {
                 CMISDocument *document = (CMISDocument *) object;
                 STAssertNil(error, @"Error while retrieving object with path %@", path);
                 STAssertNotNil(document, @"Document should not be nil");

                 self.testCompleted = YES;
             }];
         }];
     }];
}

// In this test, we'll upload a test file
// Change the content of that test file
// And verify of the content is correct
- (void)testChangeContentOfDocument
{
    [self runTest:^
     {
         // Upload test file
         [self uploadTestFileWithCompletionBlock:^(CMISDocument *originalDocument) {
             // Change content of test file using overwrite
             __block long long previousUploadedBytes = -1;
             NSString *newContentFilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test_file_2.txt" ofType:nil];
             [self.session.binding.objectService
              changeContentOfObject:[CMISStringInOutParameter inOutParameterUsingInParameter:originalDocument.identifier]
              toContentOfFile:newContentFilePath
              withOverwriteExisting:YES
              withChangeToken:nil
              completionBlock: ^(NSError *error) {
                  if (error == nil) {
                      NSLog(@"Content has been successfully changed");
                      
                      // Verify content of document
                      NSString *tempDownloadFilePath = [NSString stringWithFormat:@"%@/temp_download_file.txt", NSTemporaryDirectory()];
//                      NSString *tempDownloadFilePath = @"temp_download_file.txt";
                      // some repos will up the version when uploading new content
                      [originalDocument retrieveObjectOfLatestVersionWithMajorVersion:NO completionBlock:^(CMISDocument *latestVersionOfDocument , NSError *error) {
                          [latestVersionOfDocument downloadContentToFile:tempDownloadFilePath completionBlock:^(NSError *error) {
                              if (error == nil) {
                                  NSString *contentOfDownloadedFile = [NSString stringWithContentsOfFile:tempDownloadFilePath encoding:NSUTF8StringEncoding error:nil];
                                  STAssertEqualObjects(@"In theory, there is no difference between theory and practice. But in practice, there is.",
                                                       contentOfDownloadedFile, @"Downloaded file content does not match: '%@'", contentOfDownloadedFile);
                                  
                                  // Delete downloaded file
                                  NSError *fileError;
                                  [[NSFileManager defaultManager] removeItemAtPath:tempDownloadFilePath error:&fileError];
                                  STAssertNil(fileError, @"Error when deleting temporary downloaded file: %@", [fileError description]);
                                  
                                  // Delete test document from server
                                  [self deleteDocumentAndVerify:originalDocument completionBlock:^{
                                      self.testCompleted = YES;
                                  }];
                              } else {
                                  STAssertNil(error, @"Error while writing content: %@", [error description]);
                                  
                                  self.testCompleted = YES;
                              }
                          } progressBlock:nil];
                      }];
                  } else {
                      STAssertNil(error, @"Got error while changing content of document: %@", [error description]);
                  
                      self.testCompleted = YES;
                  }
              } progressBlock: ^ (unsigned long long bytesUploaded, unsigned long long bytesTotal) {
                  STAssertTrue((long long)bytesUploaded > previousUploadedBytes, @"No progress");
                  previousUploadedBytes = bytesUploaded;
              }];
         }];
     }];
}

- (void)testDeleteContentOfDocument
{
    [self runTest:^
     {
         // Upload test file
         [self uploadTestFileWithCompletionBlock:^(CMISDocument *originalDocument) {
             // Delete its content
             [originalDocument deleteContentWithCompletionBlock:^(NSError *error) {
                 STAssertNil(error, @"Got error while deleting content of document: %@", [error description]);
                 
                 // Get latest version and verify content length
                 [originalDocument retrieveObjectOfLatestVersionWithMajorVersion:NO completionBlock:^(CMISDocument *latestVersion, NSError *error) {
                     STAssertNil(error, @"Got error while getting latest version of documet: %@", [error description]);
                     STAssertTrue(latestVersion.contentStreamLength == 0, @"Expected zero content length for document with no content, but was %d", latestVersion.contentStreamLength);
                     
                     // Delete test document from server
                     [self deleteDocumentAndVerify:originalDocument completionBlock:^{
                         self.testCompleted = YES;
                     }];
                 }];
             }];
         }];
     }];
}

- (void)testRetrieveTypeDefinition
{
    [self runTest:^
     {
         [self.session.binding.repositoryService retrieveTypeDefinition:@"cmis:document" completionBlock:^(CMISTypeDefinition *typeDefinition, NSError *error) {
             STAssertNil(error, @"Got error while retrieving type definition: %@", [error description]);
             
             // Check type definition properties
             STAssertNotNil(typeDefinition, @"Type definition should not be nil");
             STAssertTrue(typeDefinition.baseTypeId == CMISBaseTypeDocument, @"Unexpected base type id");
             STAssertNotNil(typeDefinition.description, @"Type description should not be nil");
             STAssertNotNil(typeDefinition.displayName, @"Type displayName should not be nil");
             STAssertNotNil(typeDefinition.id, @"Type id should not be nil");
             STAssertTrue([typeDefinition.id isEqualToString:@"cmis:document"], @"Wrong id for type");
             STAssertNotNil(typeDefinition.localName, @"Type local name should not be nil");
             STAssertNotNil(typeDefinition.localNameSpace, @"Type local namespace should not be nil");
             STAssertNotNil(typeDefinition.queryName, @"Type query name should not be nil");
             
             // Check property definitions
             STAssertTrue(typeDefinition.propertyDefinitions.count > 0, @"Expected at least one propery definition, but got %d", typeDefinition.propertyDefinitions.count);
             for (id key in typeDefinition.propertyDefinitions)
             {
                 CMISPropertyDefinition *propertyDefinition = [typeDefinition.propertyDefinitions objectForKey:key];
                 STAssertNotNil(propertyDefinition.description, @"Property definition description should not be nil");
                 STAssertNotNil(propertyDefinition.displayName, @"Property definition display name should not be nil");
                 STAssertNotNil(propertyDefinition.id, @"Property definition id should not be nil");
                 STAssertNotNil(propertyDefinition.localName, @"Property definition local name should not be nil");
                 STAssertNotNil(propertyDefinition.localNamespace, @"Property definition local namespace should not be nil");
                 STAssertNotNil(propertyDefinition.queryName, @"Property definition query name should not be nil");
             }
             
             self.testCompleted = YES;
         }];
     }];
}

- (void)testUpdateDocumentPropertiesThroughObjectService
{
    [self runTest:^
     {
         id<CMISObjectService> objectService = self.session.binding.objectService;
         
         // Create test document
         [self uploadTestFileWithCompletionBlock:^(CMISDocument *document) {
             // Prepare params
             CMISStringInOutParameter *objectIdInOutParam = [CMISStringInOutParameter inOutParameterUsingInParameter:document.identifier];
             CMISProperties *properties = [[CMISProperties alloc] init];
             [properties addProperty:[CMISPropertyData createPropertyForId:kCMISPropertyName withStringValue:@"name_has_changed"]];
             
             // Update properties and verify
             [objectService updatePropertiesForObject:objectIdInOutParam withProperties:properties withChangeToken:nil completionBlock:^(NSError *error) {
                 STAssertNil(error, @"Got error while updating properties: %@", [error description]);
                 STAssertNotNil(objectIdInOutParam.outParameter, @"When updating properties, the object id should be returned");
                 
                 NSString *newObjectId = objectIdInOutParam.outParameter;
                 [self.session retrieveObject:newObjectId completionBlock:^(CMISObject *object, NSError *error) {
                     CMISDocument *document = (CMISDocument *)object;
                     STAssertNil(error, @"Got error while retrieving test document: %@", [error description]);
                     STAssertEqualObjects(document.name, @"name_has_changed", @"Name was not updated");
                     
                     // Cleanup
                     [self deleteDocumentAndVerify:document completionBlock:^{
                         self.testCompleted = YES;
                     }];
                 }];
             }];
         }];
     }];
}

- (void)testUpdateFolderPropertiesThroughObjectService
{
    [self runTest:^
     {
         // Create a temporary test folder
         NSMutableDictionary *properties = [NSMutableDictionary dictionary];
         NSString *folderName = [NSString stringWithFormat:@"temp_test_folder_%@", [self stringFromCurrentDate]];
         [properties setObject:folderName forKey:kCMISPropertyName];
         [properties setObject:kCMISPropertyObjectTypeIdValueFolder forKey:kCMISPropertyObjectTypeId];
         
         [self.rootFolder createFolder:properties completionBlock:^(NSString *folderId, NSError *error) {
             STAssertNil(error, @"Got error while creating folder: %@", [error description]);
             
             // Update name of test folder through object service
             id<CMISObjectService> objectService = self.session.binding.objectService;
             CMISStringInOutParameter *objectIdParam = [CMISStringInOutParameter inOutParameterUsingInParameter:folderId];
             CMISProperties *updateProperties = [[CMISProperties alloc] init];
             NSString *renamedFolderName = [NSString stringWithFormat:@"temp_test_folder_renamed_%@", [self stringFromCurrentDate]];
             [updateProperties addProperty:[CMISPropertyData createPropertyForId:kCMISPropertyName withStringValue:renamedFolderName]];
             [objectService updatePropertiesForObject:objectIdParam withProperties:updateProperties withChangeToken:nil completionBlock:^(NSError *error) {
                 STAssertNil(error, @"Got error while updating folder properties: %@", [error description]);
                 STAssertNotNil(objectIdParam.outParameter, @"Returned object id should not be nil");
                 
                 // Retrieve folder again and check if name has actually changed
                 [self.session retrieveObject:folderId completionBlock:^(CMISObject *object, NSError *error) {
                     CMISFolder *renamedFolder = (CMISFolder *)object;
                     STAssertNil(error, @"Got error while retrieving renamed folder: %@", [error description]);
                     STAssertEqualObjects(renamedFolder.name, renamedFolderName, @"Folder was not renamed, name is %@", renamedFolder.name);
                     
                     // Delete test folder
                     [renamedFolder deleteTreeWithDeleteAllVersions:YES withUnfileObjects:CMISDelete withContinueOnFailure:YES completionBlock:^(NSArray *failedObjects, NSError *error) {
                         STAssertNil(error, @"Error while deleting newly created folder: %@", [error description]);

                         self.testCompleted = YES;
                     }];
                 }];
             }];
         }];
     }];
}

- (void)testUpdatePropertiesThroughCmisObject
{
    [self runTest:^
     {
         // Create test document
         [self uploadTestFileWithCompletionBlock:^(CMISDocument *document) {
             // Prepare properties
             NSMutableDictionary *properties = [NSMutableDictionary dictionary];
             NSString *newName = @"testUpdatePropertiesThroughCmisObject";
             [properties setObject:newName forKey:kCMISPropertyName];
             [document updateProperties:properties completionBlock:^(CMISObject *object, NSError *error) {
                 CMISDocument *document = (CMISDocument *)object;
                 STAssertNil(error, @"Got error while retrieving renamed folder: %@", [error description]);
                 STAssertEqualObjects(newName, document.name, @"Name was not updated");
                 STAssertEqualObjects(newName, [document.properties propertyValueForId:kCMISPropertyName], @"Name property was not updated");
                 
                 // Cleanup
                 [self deleteDocumentAndVerify:document completionBlock:^{
                     self.testCompleted = YES;
                 }];
             }];
         }];
     }];
}


// Helper method used by the extension element parse tests
- (void)checkExtensionElement:(CMISExtensionElement *)extElement withName:(NSString *)expectedName namespaceUri:(NSString *)expectedNamespaceUri
               attributeCount:(NSUInteger)expectedAttrCount childrenCount:(NSUInteger)expectedChildCount hasValue:(BOOL)hasValue
{
    NSLog(@"Checking Extension Element: %@", extElement);
    STAssertTrue([extElement.name isEqualToString:expectedName], @"Expected extension element name '%@', but name is '%@'", expectedName, extElement.name);
    STAssertTrue([extElement.namespaceUri isEqualToString:expectedNamespaceUri], @"Expected namespaceUri=%@, but actual namespaceUri=%@", expectedNamespaceUri, extElement.namespaceUri);
    STAssertTrue(extElement.attributes.count == expectedAttrCount, @"Expected %d attributes, but found %d", expectedAttrCount, extElement.attributes.count);
    STAssertTrue(extElement.children.count == expectedChildCount, @"Expected %d children elements but found %d", expectedChildCount, extElement.children.count);
    
    if (extElement.children.count > 0)
    {
        STAssertNil(extElement.value, @"Extension Element value must by nil but value contained '%@'", extElement.value);
    }
    else if (hasValue)
    {
        STAssertTrue(extElement.value.length > 0, @"Expected extension element value to be non-empty");
    }
}

// Test Extension Elements using generated FolderChildren XML
- (void)testParsedExtensionElementsFromFolderChildrenXml
{
    // Testing FolderChildren, executed at end
    
    void (^testFolderChildrenXml)(NSString *, BOOL) = ^(NSString * filename, BOOL isOpenCmisImpl)
    {
        NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:filename ofType:@"xml"];
        NSData *atomData = [[NSData alloc] initWithContentsOfFile:filePath];
        STAssertNotNil(atomData, @"FolderChildren.xml is missing from the test target!");
        
        NSError *error = nil;
        CMISAtomFeedParser *feedParser = [[CMISAtomFeedParser alloc] initWithData:atomData];
        STAssertTrue([feedParser parseAndReturnError:&error], @"Failed to parse FolderChildren.xml");
        
        NSArray *entries = feedParser.entries;
        STAssertTrue(entries.count == 2, @"Expected 2 parsed entry objects, but found %d", entries.count);
        
        for (CMISObjectData *objectData  in entries)
        {
            // Check that there are no extension elements on the Object and allowable actions objects
            STAssertTrue(objectData.extensions.count == 0, @"Expected 0 extension elements, but found %d", objectData.extensions.count);
            STAssertTrue(objectData.allowableActions.extensions.count == 0, @"Expected 0 extension elements, but found %d", objectData.allowableActions.extensions.count);
            
            // Check that we have the expected Alfresco Aspect Extension elements on the Properties object
            NSArray *extensions = objectData.properties.extensions;
            STAssertTrue(extensions.count == 1, @"Expected only one extension element but encountered %d", extensions.count);
            
            // Traverse the extension element tree
            int expectedAspectsExtChildrenCt = (isOpenCmisImpl ? 4 : 5);
            CMISExtensionElement *extElement = [extensions lastObject];
            [self checkExtensionElement:extElement withName:@"aspects" namespaceUri:@"http://www.alfresco.org" attributeCount:0
                          childrenCount:expectedAspectsExtChildrenCt hasValue:NO];
            
            int aspectChildCt = 0;
            for (CMISExtensionElement *aspectChild in extElement.children)
            {
                switch (aspectChildCt ++)
                {
                    case 0:
                    case 1:
                    case 2:
                    case 3:
                    {
                        // appliedAspects
                        [self checkExtensionElement:aspectChild withName:@"appliedAspects" namespaceUri:@"http://www.alfresco.org" attributeCount:0 childrenCount:0 hasValue:YES];
                        break;
                    }
                    case 4:
                    {
                        STAssertFalse(isOpenCmisImpl, @"Unexpected extension element encountered!");
                        // alf:properties
                        [self checkExtensionElement:aspectChild withName:@"properties" namespaceUri:@"http://www.alfresco.org" attributeCount:0 childrenCount:3 hasValue:NO];
                        
                        for (CMISExtensionElement *aspectPropExt in aspectChild.children)
                        {
                            if (aspectPropExt.children)
                            {
                                [self checkExtensionElement:aspectPropExt withName:@"propertyString" namespaceUri:kCMISNamespaceCmis attributeCount:3 childrenCount:1 hasValue:NO];
                                
                                CMISExtensionElement *valueExt = aspectPropExt.children.lastObject;
                                [self checkExtensionElement:valueExt withName:@"value" namespaceUri:kCMISNamespaceCmis attributeCount:0 childrenCount:0 hasValue:YES];
                            }
                            else
                            {
                                [self checkExtensionElement:aspectPropExt withName:@"propertyString" namespaceUri:kCMISNamespaceCmis attributeCount:3 childrenCount:0 hasValue:NO];
                            }
                            
                            
                            // Test the attributes on each of the cmis property objects
                            NSArray *expectedAttributeNames = [NSArray arrayWithObjects:kCMISCoreQueryName, kCMISCoreDisplayName, kCMISAtomEntryPropertyDefId, nil];
                            NSMutableArray *attrNames = [[aspectPropExt.attributes allKeys] mutableCopy];
                            [attrNames removeObjectsInArray:expectedAttributeNames];
                            STAssertTrue(0 == attrNames.count, @"Unexpected Attribute(s) found %@", attrNames);
                            
                            break;
                        }
                    }
                }
            }
        }
    };
    
    // Test the FolderChildren XML generated from Alfresco's Web Script Impl
    testFolderChildrenXml(@"FolderChildren-webscripts", NO);
    
    // Test the FolderChildren XML generated from OpenCmis Impl
    testFolderChildrenXml(@"FolderChildren-opencmis", YES);
}

// This test test the extension levels Allowable Actions, Object, and Properties, with simplicity
// the same extension elements are used at each of the different levels
- (void)testParsedExtensionElementsFromAtomFeedXml
{
    static NSString *exampleUri = @"http://www.example.com";
    
    // Local Blocks
    void (^testSimpleRootExtensionElement)(CMISExtensionElement *) = ^(CMISExtensionElement *rootExtElement)
    {
        [self checkExtensionElement:rootExtElement withName:@"testExtSimpleRoot" namespaceUri:exampleUri attributeCount:0 childrenCount:1 hasValue:NO];
        
        CMISExtensionElement *simpleChildExtElement = rootExtElement.children.lastObject;
        [self checkExtensionElement:simpleChildExtElement withName:@"simpleChild" namespaceUri:@"http://www.example.com" attributeCount:0 childrenCount:0 hasValue:YES];
        STAssertTrue([simpleChildExtElement.value isEqualToString:@"simpleChildValue"], @"Expected value 'simpleChildValue' but was '%@'", simpleChildExtElement.value);
    };
    
    void (^testComplexRootExtensionElement)(CMISExtensionElement *) = ^(CMISExtensionElement *rootExtElement)
    {
        [self checkExtensionElement:rootExtElement withName:@"testExtRoot" namespaceUri:exampleUri attributeCount:0 childrenCount:5 hasValue:NO];
        // Children Depth=1
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:0] withName:@"testExtChildLevel1A" namespaceUri:exampleUri attributeCount:0 childrenCount:0 hasValue:YES];
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:1] withName:@"testExtChildLevel1A" namespaceUri:exampleUri attributeCount:0 childrenCount:0 hasValue:YES];
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:2] withName:@"testExtChildLevel1B" namespaceUri:exampleUri attributeCount:1 childrenCount:1 hasValue:NO];
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:3] withName:@"testExtChildLevel1B" namespaceUri:exampleUri attributeCount:1 childrenCount:0 hasValue:NO];
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:4] withName:@"testExtChildLevel1B" namespaceUri:exampleUri attributeCount:1 childrenCount:0 hasValue:YES];
        
        CMISExtensionElement *level1ExtElement = [rootExtElement.children objectAtIndex:2];
        
        CMISExtensionElement *level2ExtElement = level1ExtElement.children.lastObject;
        [self checkExtensionElement:level2ExtElement withName:@"testExtChildLevel2" namespaceUri:exampleUri attributeCount:1 childrenCount:1 hasValue:NO];
        
        CMISExtensionElement *level3ExtElement = level2ExtElement.children.lastObject;
        [self checkExtensionElement:level3ExtElement withName:@"testExtChildLevel3" namespaceUri:exampleUri attributeCount:1 childrenCount:0 hasValue:YES];
    };
    
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AtomFeedWithExtensions" ofType:@"xml"];
    NSData *atomData = [[NSData alloc] initWithContentsOfFile:filePath];
    STAssertNotNil(atomData, @"AtomFeedWithExtensions.xml is missing from the test target!");
    
    NSError *error = nil;
    CMISAtomFeedParser *feedParser = [[CMISAtomFeedParser alloc] initWithData:atomData];
    STAssertTrue([feedParser parseAndReturnError:&error], @"Failed to parse AtomFeedWithExtensions.xml");
    
    NSArray *entries = feedParser.entries;
    STAssertTrue(entries.count == 2, @"Expected 2 parsed entry objects, but found %d", entries.count);
    
    for (CMISObjectData *objectData  in entries)
    {
        STAssertTrue(objectData.extensions.count == 2, @"Expected 2 extension elements, but found %d", objectData.extensions.count);
        testSimpleRootExtensionElement([objectData.extensions objectAtIndex:0]);
        testComplexRootExtensionElement([objectData.extensions objectAtIndex:1]);
        
        STAssertTrue(objectData.allowableActions.extensions.count == 2, @"Expected 2 extension elements, but found %d", objectData.allowableActions.extensions.count);
        testSimpleRootExtensionElement([objectData.allowableActions.extensions objectAtIndex:0]);
        testComplexRootExtensionElement([objectData.allowableActions.extensions objectAtIndex:1]);
        
        NSArray *extensions = objectData.properties.extensions;
        STAssertTrue(extensions.count == 2, @"Expected only one extension element but encountered %d", extensions.count);
        testSimpleRootExtensionElement([objectData.properties.extensions objectAtIndex:0]);
        testComplexRootExtensionElement([objectData.properties.extensions objectAtIndex:1]);
    }
}


- (void)testParsedExtensionElementsFromAtomPubService
{
    static NSString *exampleUri = @"http://www.example.com";
    
    // Local Blocks
    void (^testSimpleRootExtensionElement)(CMISExtensionElement *) = ^(CMISExtensionElement *rootExtElement)
    {
        [self checkExtensionElement:rootExtElement withName:@"testExtSimpleRoot" namespaceUri:exampleUri attributeCount:0 childrenCount:1 hasValue:NO];
        
        CMISExtensionElement *simpleChildExtElement = rootExtElement.children.lastObject;
        [self checkExtensionElement:simpleChildExtElement withName:@"simpleChild" namespaceUri:@"http://www.example.com" attributeCount:0 childrenCount:0 hasValue:YES];
        STAssertTrue([simpleChildExtElement.value isEqualToString:@"simpleChildValue"], @"Expected value 'simpleChildValue' but was '%@'", simpleChildExtElement.value);
    };
    
    void (^testComplexRootExtensionElement)(CMISExtensionElement *) = ^(CMISExtensionElement *rootExtElement)
    {
        [self checkExtensionElement:rootExtElement withName:@"testExtRoot" namespaceUri:exampleUri attributeCount:0 childrenCount:5 hasValue:NO];
        // Children Depth=1
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:0] withName:@"testExtChildLevel1A" namespaceUri:exampleUri attributeCount:0 childrenCount:0 hasValue:YES];
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:1] withName:@"testExtChildLevel1A" namespaceUri:exampleUri attributeCount:0 childrenCount:0 hasValue:YES];
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:2] withName:@"testExtChildLevel1B" namespaceUri:exampleUri attributeCount:1 childrenCount:1 hasValue:NO];
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:3] withName:@"testExtChildLevel1B" namespaceUri:exampleUri attributeCount:1 childrenCount:0 hasValue:NO];
        [self checkExtensionElement:[rootExtElement.children objectAtIndex:4] withName:@"testExtChildLevel1B" namespaceUri:exampleUri attributeCount:1 childrenCount:0 hasValue:YES];
        
        CMISExtensionElement *level1ExtElement = [rootExtElement.children objectAtIndex:2];
        
        CMISExtensionElement *level2ExtElement = level1ExtElement.children.lastObject;
        [self checkExtensionElement:level2ExtElement withName:@"testExtChildLevel2" namespaceUri:exampleUri attributeCount:1 childrenCount:1 hasValue:NO];
        
        CMISExtensionElement *level3ExtElement = level2ExtElement.children.lastObject;
        [self checkExtensionElement:level3ExtElement withName:@"testExtChildLevel3" namespaceUri:exampleUri attributeCount:1 childrenCount:0 hasValue:YES];
    };
    
    // Testing AllowableActions Extensions using the - initWithData: entry point
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"AtomPubServiceDocument" ofType:@"xml"];
    NSData *atomData = [[NSData alloc] initWithContentsOfFile:filePath];
    STAssertNotNil(atomData, @"AtomPubServiceDocument.xml is missing from the test target!");
    
    NSError *error = nil;
    CMISServiceDocumentParser *serviceDocParser = [[CMISServiceDocumentParser alloc] initWithData:atomData];
    STAssertTrue([serviceDocParser parseAndReturnError:&error], @"Failed to parse AtomPubServiceDocument.xml");
    
    NSArray *workspaces = [serviceDocParser workspaces];
    CMISWorkspace *workspace = [workspaces objectAtIndex:0];
    CMISRepositoryInfo *repoInfo = workspace.repositoryInfo;
    
    STAssertTrue(repoInfo.extensions.count == 2, @"Expected 2 extension elements, but found %d", repoInfo.extensions.count);
    testSimpleRootExtensionElement([repoInfo.extensions objectAtIndex:0]);
    testComplexRootExtensionElement([repoInfo.extensions objectAtIndex:1]);
}

// Commented out due to the fact of no extension data returned by the 'cmisatom' url (the old url did)
//
//- (void)testExtensionData
//{
//    [self setupCmisSession];
//    NSError *error = nil;
//
//    // Test RepositoryInfo Extensions
//    CMISRepositoryInfo *repoInfo = self.session.repositoryInfo;
//    NSArray *repoExtensions = repoInfo.extensions;
//    STAssertTrue(1 == repoExtensions.count, @"Expected 1 RepositoryInfo extension, but %d extension(s) returned", repoExtensions.count);
//    CMISExtensionElement *element = [repoExtensions objectAtIndex:0];
//    STAssertTrue([@"Version 1.0 OASIS Standard" isEqualToString:element.value], @"Expected value='Version 1.0 OASIS Standard', actual='%@'", element.value);
//    STAssertTrue([@"http://www.alfresco.org" isEqualToString:element.namespaceUri], @"Expected namespaceUri='http://www.alfresco.org', actual='%@'", element.namespaceUri);
//    STAssertTrue([@"cmisSpecificationTitle" isEqualToString:element.name], @"Expected name='cmisSpecificationTitle', actual='%@'", element.name);
//    STAssertTrue([element.children count] == 0, @"Expected 0 children, but %d were found", [element.children count]);
//    STAssertTrue([element.attributes count] == 0, @"Expected 0 attributes, but %d were found", [element.attributes count]);
//
//
//    // Get an existing Document
//    CMISDocument *testDocument = [self retrieveVersionedTestDocument];
//
//    // Get testDocument but with AllowableActions
//    CMISOperationContext *ctx = [[CMISOperationContext alloc] init];
//    ctx.isIncludeAllowableActions = YES;
//    CMISDocument *document = (CMISDocument *) [self.session retrieveObject:testDocument.identifier withOperationContext:ctx error:&error];
//
//    NSArray *extensions = [document extensionsForExtensionLevel:CMISExtensionLevelObject];
//    STAssertTrue([extensions count] == 0, @"Expected no extensions, but found %d", [extensions count]);
//
//    extensions = [document extensionsForExtensionLevel:CMISExtensionLevelProperties];
//    STAssertTrue([extensions count] > 0, @"Expected extension data for properties, but none were found");
//
//    STAssertTrue([document.allowableActions.allowableActionsSet count] > 0, @"Expected at least one allowable action but found none");
//    extensions = [document extensionsForExtensionLevel:CMISExtensionLevelAllowableActions];
//    STAssertTrue([extensions count] == 0, @"Expected no extension data for allowable actions, but found %d", [extensions count]);
//}


- (void)testPropertiesConversion
{
    [self runTest:^
     {
         NSDate *testDate = [NSDate date];
         NSCalendar *calendar = [NSCalendar currentCalendar];
         NSUInteger unitflags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
         NSDateComponents *origComponents = [calendar components:unitflags fromDate:testDate];
         
         // Create converter
         
         // Try to convert with already CMISPropertyData. This should work just fine.
         NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
         [properties setObject:[CMISPropertyData createPropertyForId:kCMISPropertyName withStringValue:@"testName"] forKey:kCMISPropertyName];
         [properties setObject:[CMISPropertyData createPropertyForId:kCMISPropertyObjectTypeId withIdValue:@"cmis:document"] forKey:kCMISPropertyObjectTypeId];
         [properties setObject:[CMISPropertyData createPropertyForId:kCMISPropertyCreationDate withDateTimeValue:testDate] forKey:kCMISPropertyCreationDate];
         [properties setObject:[CMISPropertyData createPropertyForId:kCMISPropertyIsLatestVersion withBoolValue:YES] forKey:kCMISPropertyIsLatestVersion];
         [properties setObject:[CMISPropertyData createPropertyForId:kCMISPropertyContentStreamLength withIntegerValue:5] forKey:kCMISPropertyContentStreamLength];
         
         [self.session.objectConverter convertProperties:properties forObjectTypeId:@"cmis:document" completionBlock:^(CMISProperties *convertedProperties, NSError *error) {
             STAssertNil(error, @"Error while converting properties: %@", [error description]);
             STAssertNotNil(convertedProperties, @"Conversion failed, nil was returned");
             STAssertTrue(convertedProperties.propertyList.count == 5, @"Expected 5 converted properties, but was %d", convertedProperties.propertyList.count);
             STAssertEqualObjects(@"testName", [[convertedProperties propertyForId:kCMISPropertyName]propertyStringValue], @"Converted property value did not match");
             STAssertEqualObjects(@"cmis:document", [[convertedProperties propertyForId:kCMISPropertyObjectTypeId] propertyIdValue], @"Converted property value did not match");
             STAssertEqualObjects(testDate, [[convertedProperties propertyForId:kCMISPropertyCreationDate] propertyDateTimeValue], @"Converted property value did not match");
             STAssertEqualObjects([NSNumber numberWithBool:YES], [[convertedProperties propertyForId:kCMISPropertyIsLatestVersion] propertyBooleanValue], @"Converted property value did not match");
             STAssertEqualObjects([NSNumber numberWithInteger:5], [[convertedProperties propertyForId:kCMISPropertyContentStreamLength] propertyIntegerValue], @"Converted property value did not match");
             
             // Test with non-CMISPropertyData values
             NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
             [properties setObject:@"test" forKey:kCMISPropertyName];
             [properties setObject:@"cmis:document" forKey:kCMISPropertyObjectTypeId];
             [properties setObject:[CMISDateUtil stringFromDate:testDate] forKey:kCMISPropertyCreationDate];
             [properties setObject:[NSNumber numberWithBool:NO] forKey:kCMISPropertyIsLatestVersion];
             [properties setObject:[NSNumber numberWithInt:4] forKey:kCMISPropertyContentStreamLength];
             
             [self.session.objectConverter convertProperties:properties forObjectTypeId:@"cmis:document" completionBlock:^(CMISProperties *convertedProperties, NSError *error) {
                 STAssertNil(error, @"Error while converting properties: %@", [error description]);
                 STAssertNotNil(convertedProperties, @"Conversion failed, nil was returned");
                 STAssertTrue(convertedProperties.propertyList.count == 5, @"Expected 5 converted properties, but was %d", convertedProperties.propertyList.count);
                 STAssertEqualObjects(@"test", [[convertedProperties propertyForId:kCMISPropertyName] propertyStringValue], @"Converted property value did not match");
                 STAssertEqualObjects(@"cmis:document", [[convertedProperties propertyForId:kCMISPropertyObjectTypeId] propertyIdValue], @"Converted property value did not match");
                 
                 // NSDate is using sub-second precision ... and the formatter is not.
                 // ... sigh ... hence we test if the dates are 'relatively' (ie 1 second) close
                 NSDate *convertedDate = [[convertedProperties propertyForId:kCMISPropertyCreationDate] propertyDateTimeValue];
                 NSDateComponents *convertedComps = [calendar components:unitflags fromDate:convertedDate];
                 BOOL isOnSameDate = (origComponents.year == convertedComps.year) && (origComponents.month == convertedComps.month) && (origComponents.day == convertedComps.day);
                 STAssertTrue(isOnSameDate, @"We expected the reconverted date to be on the same date as the original one");
                 
                 BOOL isOnSameTime = (origComponents.hour == convertedComps.hour) && (origComponents.minute == convertedComps.minute) && (origComponents.second == convertedComps.second);
                 STAssertTrue(isOnSameTime, @"We expected the reconverted time to be at the same time as the original one");
                 
//                 NSDate *convertedDate = [[convertedProperties propertyForId:kCMISPropertyCreationDate] propertyDateTimeValue];
//                 STAssertTrue(testDate.timeIntervalSince1970 - 1000 <= convertedDate.timeIntervalSince1970
//                              && convertedDate.timeIntervalSince1970 <= testDate.timeIntervalSince1970 + 1000, @"Converted property value did not match");
                 STAssertEqualObjects([NSNumber numberWithBool:NO], [[convertedProperties propertyForId:kCMISPropertyIsLatestVersion] propertyBooleanValue], @"Converted property value did not match");
                 STAssertEqualObjects([NSNumber numberWithInteger:4], [[convertedProperties propertyForId:kCMISPropertyContentStreamLength] propertyIntegerValue], @"Converted property value did not match");
                 
                 // Test error return
                 [self.session.objectConverter convertProperties:nil forObjectTypeId:@"doesntmatter" completionBlock:^(CMISProperties *convertedProperties, NSError *error) {
                     STAssertNil(convertedProperties, @"Should be nil");

                     NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
                     [properties setObject:@"test" forKey:kCMISPropertyContentStreamLength];
                     [self.session.objectConverter convertProperties:properties forObjectTypeId:@"cmis:document" completionBlock:^(CMISProperties *convertedProperties, NSError *error) {
                         STAssertNotNil(error, @"Expecting an error when converting");
                         STAssertNil(convertedProperties, @"When conversion goes wrong, should return nil");
                         
                         NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
                         [properties setObject:[NSNumber numberWithBool:YES] forKey:kCMISPropertyName];
                         [self.session.objectConverter convertProperties:properties forObjectTypeId:@"cmis:document" completionBlock:^(CMISProperties *convertedProperties, NSError *error) {
                             STAssertNotNil(error, @"Expecting an error when converting");
                             STAssertNil(convertedProperties, @"When conversion goes wrong, should return nil");
                             
                             self.testCompleted = YES;
                         }];
                     }];
                 }];
             }];
         }];
     }];
}

- (void)testOperationContextForRetrievingObject
{
    [self runTest:^
     {
         // Create some test document
         [self uploadTestFileWithCompletionBlock:^(CMISDocument *testDocument) {
             // Use YES for retrieving the allowable actions
             CMISOperationContext *ctx = [[CMISOperationContext alloc] init];
             ctx.isIncludeAllowableActions = YES;
             [self.session retrieveObject:testDocument.identifier withOperationContext:ctx completionBlock:^(CMISObject *object, NSError *error) {
                 CMISDocument *document = (CMISDocument *)object;
                 STAssertNil(error, @"Got error while retrieving object : %@", [error description]);
                 STAssertNotNil(document.allowableActions, @"Allowable actions should not be nil");
                 STAssertTrue(document.allowableActions.allowableActionsSet.count > 0, @"Expected at least one allowable action");
                 
                 //Use NO for allowable actions
                 CMISOperationContext *ctx = [[CMISOperationContext alloc] init];
                 ctx.isIncludeAllowableActions = NO;
                 [self.session retrieveObject:testDocument.identifier withOperationContext:ctx completionBlock:^(CMISObject *object, NSError *error) {
                     CMISDocument *document = (CMISDocument *)object;
                     STAssertNil(error, @"Got error while retrieving object : %@", [error description]);
                     STAssertNil(document.allowableActions, @"Allowable actions should be nil");
                     STAssertTrue(document.allowableActions.allowableActionsSet.count == 0, @"Expected zero allowable actions");
                     
                     // Cleanup
                     [self deleteDocumentAndVerify:testDocument completionBlock:^{
                         self.testCompleted = YES;
                     }];
                 }];
             }];
         }];
     }];
}

- (void)testGetRenditionsThroughCmisObject
{
    [self runTest:^
     {
         // Fetch test document
         NSString *path = [NSString stringWithFormat:@"%@ios-test/test-word-doc.docx", self.rootFolder.path];
         CMISOperationContext *operationContext = [CMISOperationContext defaultOperationContext];
         operationContext.renditionFilterString = @"*";
         [self.session retrieveObjectByPath:path withOperationContext:operationContext completionBlock:^(CMISObject *object, NSError *error) {
             CMISDocument *document = (CMISDocument *)object;
             STAssertNil(error, @"Error while retrieving document: %@", [error description]);
             
             // Get and verify Renditions
             NSArray *renditions = document.renditions;
             STAssertTrue(renditions.count > 0, @"Expected at least one rendition");
             CMISRendition *thumbnailRendition = nil;
             for (CMISRendition *rendition in renditions)
             {
                 if ([rendition.kind isEqualToString:@"cmis:thumbnail"])
                 {
                     thumbnailRendition = rendition;
                 }
             }
             STAssertNotNil(thumbnailRendition, @"Thumbnail rendition should be availabile");
             STAssertTrue(thumbnailRendition.length > 0, @"Rendition length should be greater than 0");
             
             // Get content
             NSString *filePath = [NSString stringWithFormat:@"%@/testfile.pdf" , NSTemporaryDirectory()];
//             NSString *filePath = @"testfile.pdf";
             [thumbnailRendition downloadRenditionContentToFile:filePath completionBlock:^(NSError *error) {
                 if (error == nil) {
                     // Assert File exists and check file length
                     STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:filePath], @"File does not exist");
                     NSError *fileError;
                     NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&fileError];
                     STAssertNil(fileError, @"Could not verify attributes of file %@: %@", filePath, [fileError description]);
                     STAssertTrue([fileAttributes fileSize] > 10, @"Expected a file of at least 10 bytes, but found one of %d bytes", [fileAttributes fileSize]);
                     
                     // Nice boys clean up after themselves
                     [[NSFileManager defaultManager] removeItemAtPath:filePath error:&fileError];
                     STAssertNil(fileError, @"Could not remove file %@: %@", filePath, [fileError description]);
                     
                     self.testCompleted = YES;
                 } else {
                     STAssertNil(error, @"Error while writing content: %@", [error description]);
                 
                     self.testCompleted = YES;
                 }
             } progressBlock:nil];
         }];
     }];
}

- (void)testGetRenditionsThroughObjectService
{
    [self runTest:^
     {
         // Fetch test document
         NSString *path = [NSString stringWithFormat:@"%@ios-test/test-word-doc.docx", self.rootFolder.path];
         CMISOperationContext *operationContext = [CMISOperationContext defaultOperationContext];
         operationContext.renditionFilterString = @"*";
         [self.session retrieveObjectByPath:path withOperationContext:operationContext completionBlock:^(CMISObject *object, NSError *error) {
             CMISDocument *document = (CMISDocument *)object;
             STAssertNil(error, @"Error while retrieving document: %@", [error description]);
             
             // Get renditions through service
             [self.session.binding.objectService
              retrieveRenditions:document.identifier
              withRenditionFilter:@"*"
              withMaxItems:nil
              withSkipCount:nil
              completionBlock:^(NSArray *renditions, NSError *error) {
                  STAssertNil(error, @"Error while retrieving renditions: %@", [error description]);
                  STAssertTrue(renditions.count > 0, @"Expected at least one rendition");
                  CMISRenditionData *thumbnailRendition = nil;
                  for (CMISRenditionData *rendition in renditions)
                  {
                      if ([rendition.kind isEqualToString:@"cmis:thumbnail"])
                      {
                          thumbnailRendition = rendition;
                      }
                  }
                  STAssertNotNil(thumbnailRendition, @"Thumbnail rendition should be availabile");
                  STAssertTrue(thumbnailRendition.length > 0, @"Rendition length should be greater than 0");
                  
                  // Download content through objectService
                  NSString *filePath = [NSString stringWithFormat:@"%@/testfile-rendition-through-objectservice.pdf", NSTemporaryDirectory()];
//                  NSString *filePath = @"testfile-rendition-through-objectservice.pdf";
                  [self.session.binding.objectService
                   downloadContentOfObject:document.identifier
                   withStreamId:thumbnailRendition.streamId
                   toFile:filePath
                   completionBlock: ^(NSError *error) {
                       if (error == nil) {
                           // Assert File exists and check file length
                           STAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:filePath], @"File does not exist");
                           NSError *fileError;
                           NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&fileError];
                           STAssertNil(error, @"Could not verify attributes of file %@: %@", filePath, [error description]);
                           STAssertTrue([fileAttributes fileSize] > 10, @"Expected a file of at least 10 bytes, but found one of %d bytes", [fileAttributes fileSize]);

                           // Nice boys clean up after themselves
                           [[NSFileManager defaultManager] removeItemAtPath:filePath error:&fileError];
                           STAssertNil(fileError, @"Could not remove file %@: %@", filePath, [fileError description]);
                       } else {
                           STAssertNil(error, @"Error while downloading content: %@", [error description]);
                       }
                       
                       self.testCompleted = YES;
                   } progressBlock:nil];
              }];
         }];
     }];
}

@end
