//
//  CMISRequest.m
//  ObjectiveCMIS
//
//  Created by Eberlein, Peter on 16.10.12.
//  Copyright (c) 2012 Alfresco. All rights reserved.
//

#import "CMISRequest.h"
#import "CMISHttpRequest.h"

@interface CMISRequest ()

@property (nonatomic, getter = isCancelled) BOOL cancelled;

@end


@implementation CMISRequest

@synthesize httpRequest = _httpRequest;
@synthesize cancelled = _cancelled;

- (void)cancel
{
    self.cancelled = YES;
    
    [self.httpRequest cancel];
}

- (void)setHttpRequest:(CMISHttpRequest *)httpRequest
{
    _httpRequest = httpRequest;
    
    if (self.isCancelled) {
        [httpRequest cancel];
    }
}

@end
