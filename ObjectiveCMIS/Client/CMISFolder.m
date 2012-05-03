//
//  CMISFolder.m
//  HybridApp
//
//  Created by Cornwell Gavin on 21/02/2012.
//  Copyright (c) 2012 Alfresco. All rights reserved.
//

#import "CMISFolder.h"
#import "CMISObjectConverter.h"

@interface CMISFolder ()
@property (nonatomic, strong) NSString *downLinkHref;
@property (nonatomic, strong) CMISCollection *children;
@end

@implementation CMISFolder

@synthesize downLinkHref = _downLinkHref;
@synthesize children = _children;

- (id)initWithObjectData:(CMISObjectData *)objectData binding:(id <CMISBinding>)binding
{
    self = [super initWithObjectData:objectData binding:binding];
    if (self)
    {
        self.downLinkHref = [objectData.links objectForKey:@"down"];
    }
    return self;
}


- (CMISCollection *)collectionOfChildrenAndReturnError:(NSError *)error
{
    if (self.children == nil)
    {
        NSArray *children = [self.binding.navigationService retrieveChildren:[self identifier] error:&error];
        
        CMISObjectConverter *objConverter = [[CMISObjectConverter alloc] initWithCMISBinding:self.binding];
        self.children = [objConverter convertObjects:children];
    }
    
    return self.children;
}


@end
