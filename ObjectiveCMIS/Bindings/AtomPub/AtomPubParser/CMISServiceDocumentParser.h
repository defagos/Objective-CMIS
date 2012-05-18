//
//  ServiceDoc.h
//  ObjectiveCMIS
//
//  Created by Cornwell Gavin on 17/02/2012.
//  Copyright (c) 2012 Alfresco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CMISRepositoryInfoParser.h"

@interface CMISServiceDocumentParser : NSObject <NSXMLParserDelegate, CMISRepositoryInfoParserDelegate>

// Available after parsing the service document
@property (nonatomic, strong, readonly) NSArray *workspaces;

- (id)initWithData:(NSData*)atomData;
- (BOOL)parseAndReturnError:(NSError **)error;

@end
