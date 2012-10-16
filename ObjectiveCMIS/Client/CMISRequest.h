//
//  CMISRequest.h
//  ObjectiveCMIS
//
//  Created by Eberlein, Peter on 16.10.12.
//  Copyright (c) 2012 Alfresco. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CMISHttpRequest;

@interface CMISRequest : NSObject

@property (nonatomic, weak) CMISHttpRequest *httpRequest;
@property (nonatomic, readonly, getter = isCancelled) BOOL cancelled;

- (void)cancel;

@end
