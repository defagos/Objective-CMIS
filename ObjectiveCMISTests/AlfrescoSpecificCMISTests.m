//
//  Created by Joram Barrez
//  Copyright (c) 2012 Alfresco. All rights reserved.
//

#import "AlfrescoSpecificCMISTests.h"
#import "CMISConstants.h"
#import "CMISDocument.h"
#import "CMISFolder.h"
#import "CMISSession.h"

@implementation AlfrescoSpecificCMISTests

- (void)testCreateDocumentWithDescription
{
    // Adding extra param to enable alfresco mode
    NSDictionary *extraParams = [NSDictionary dictionaryWithObject:@"alfresco" forKey:kCMISSessionParameterMode];

    [self runTest:^
    {
        NSString *documentName = [NSString stringWithFormat:@"temp_test_file_alfresco_%@.txt", [self stringFromCurrentDate]];
        NSString *documentDescription = @"This is a test description";
        NSMutableDictionary *documentProperties = [NSMutableDictionary dictionary];
        [documentProperties setObject:documentName forKey:kCMISPropertyName];
        [documentProperties setObject:@"cmis:document,P:cm:titled" forKey:kCMISPropertyObjectTypeId];
        [documentProperties setObject:documentDescription forKey:@"cm:description"];

        // Create document with description
        __block NSInteger previousBytesUploaded = -1;
        NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test_file.txt" ofType:nil];
        [self.rootFolder createDocumentFromFilePath:filePath withMimeType:@"text/plain"
                withProperties:documentProperties
                completionBlock:^ (NSString *objectId)
                {
                    STAssertNotNil(objectId, @"Object id received should be non-nil");

                    // Verify creation
                    NSError *retrievalError = nil;
                    CMISDocument *document = (CMISDocument *) [self.session retrieveObject:objectId error:&retrievalError];
                    STAssertTrue([documentName isEqualToString:document.name],
                        @"Document name of created document is wrong: should be %@, but was %@", documentName, document.name);

                    // Let's do some extension juggling
                    STAssertNotNil(document.properties.extensions, @"description should be returned as an extension, but none was found");
                    STAssertTrue(document.properties.extensions.count > 0, @"Expected at least one property extension");

                    // Verify root extension element
                    CMISExtensionElement *rootExtensionElement = (CMISExtensionElement *)[document.properties.extensions objectAtIndex:0];
                    STAssertTrue([rootExtensionElement.name isEqualToString:@"aspects"], @"root element of extensions should be 'aspects'");

                    // Find properties extension element
                    CMISExtensionElement *propertiesExtensionElement = nil;
                    for (CMISExtensionElement *childExtensionElement in rootExtensionElement.children)
                    {
                        if ([childExtensionElement.name isEqualToString:@"properties"])
                        {
                            propertiesExtensionElement = childExtensionElement;
                        }
                    }
                    STAssertNotNil(propertiesExtensionElement, @"No properties extension element found");

                    // Find description property
                    CMISExtensionElement *descriptionElement = nil;
                    for (CMISExtensionElement *childExtensionElement in propertiesExtensionElement.children)
                    {
                        if (childExtensionElement.attributes != nil &&
                             ([[childExtensionElement.attributes objectForKey:@"propertyDefinitionId"] isEqualToString:@"cm:description"]) )
                        {
                            descriptionElement = childExtensionElement;
                        }
                    }
                    STAssertNotNil(descriptionElement, @"No description element was found");

                    // Finally, verify the description
                    CMISExtensionElement *valueElement = [descriptionElement.children objectAtIndex:0];
                    STAssertNotNil(valueElement, @"There is no value element for the description property");
                    STAssertTrue([valueElement.value isEqualToString:documentDescription],
                        @"Document description does not match: was %@ but expected %@", valueElement.value, documentDescription);

                    // Cleanup after ourselves
                    NSError *deleteError = nil;
                    BOOL documentDeleted = [document deleteAllVersionsAndReturnError:&deleteError];
                    STAssertNil(deleteError, @"Error while deleting created document: %@", [deleteError description]);
                    STAssertTrue(documentDeleted, @"Document was not deleted");

                    self.callbackCompleted = YES;
                }
                failureBlock: ^ (NSError *uploadError)
                {
                   STAssertNil(uploadError, @"Got error while creating document: %@", [uploadError description]);
                }
                progressBlock: ^ (NSInteger bytesUploaded, NSInteger bytesTotal)
                {
                    STAssertTrue(bytesUploaded > previousBytesUploaded, @"No progress was made");
                    previousBytesUploaded = bytesUploaded;
                }
        ];
        [self waitForCompletion:20];

        } withExtraSessionParameters:extraParams];




   }


@end