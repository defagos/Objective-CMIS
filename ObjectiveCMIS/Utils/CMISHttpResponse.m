//
//  CMISHttpResponse.m
//  ObjectiveCMIS
//
//  Created by Eberlein, Peter on 15.10.12.
//  Copyright (c) 2012 Alfresco. All rights reserved.
//

#import "CMISHttpResponse.h"

@implementation CMISHttpResponse

@synthesize statusCode = _statusCode;
@synthesize data = _data;
@synthesize statusCodeMessage = _statusCodeMessage;

+ (CMISHttpResponse *)responseUsingURLHTTPResponse:(NSHTTPURLResponse *)httpUrlResponse andData:(NSData *)data
{
    CMISHttpResponse *httpResponse = [[CMISHttpResponse alloc] init];
    httpResponse.statusCode = httpUrlResponse.statusCode;
    httpResponse.data = data;
    httpResponse.statusCodeMessage = [NSHTTPURLResponse localizedStringForStatusCode:[httpUrlResponse statusCode]];
    return httpResponse;
}

@end
