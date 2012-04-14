//
//  CMISAtomPubNavigationService.m
//  ObjectiveCMIS
//
//  Created by Cornwell Gavin on 10/04/2012.
//  Copyright (c) 2012 Alfresco. All rights reserved.
//

#import "CMISAtomPubNavigationService.h"
#import "CMISAtomFeedParser.h"

@implementation CMISAtomPubNavigationService

- (NSArray *)retrieveChildren:(NSString *)objectId error:(NSError **)error
{
    NSArray *children = nil;    
    
    // build URL to get object data
    NSString *urlTemplate = @"%@/s/%@/children?includeAllowableActions=false&includePolicyIds=false&includeRelationships=false&includeACL=false&renditionFilter=cmis:none&includePathSegment=false&maxItems=50";
    //&maxItems=50
    
    // TODO: store links,retrieve children link and build URL for this object!?
    NSString *nodeRef = [[objectId stringByReplacingOccurrencesOfString:@"://" withString:@":"] 
                         stringByReplacingOccurrencesOfString:@"/" withString:@"/i/"];
    
    NSURL *childrenUrl = [NSURL URLWithString:[NSString stringWithFormat:urlTemplate, [self.sessionParameters.atomPubUrl absoluteString], nodeRef]];
    NSLog(@"CMISAtomPubNavigationService GET: %@", [childrenUrl absoluteString]);
    
    // execute the request
    NSData *data = [self executeRequest:childrenUrl error:error];
    if (data != nil)
    {
        CMISAtomFeedParser *parser = [[CMISAtomFeedParser alloc] initWithData:data];
        if ([parser parseAndReturnError:error])
        {
            children = parser.entries;
        }
    }
    
    return children;
}

@end