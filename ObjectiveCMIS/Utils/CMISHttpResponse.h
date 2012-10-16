//
//  CMISHttpResponse.h
//  ObjectiveCMIS
//
//  Created by Eberlein, Peter on 15.10.12.
//  Copyright (c) 2012 Alfresco. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CMISHttpResponse : NSObject

@property NSInteger statusCode;
@property (nonatomic, strong) NSString *statusCodeMessage;
@property (nonatomic, strong) NSData *data;

+ (CMISHttpResponse *)responseUsingURLHTTPResponse:(NSHTTPURLResponse *)HTTPURLResponse andData:(NSData *)data;

@end
