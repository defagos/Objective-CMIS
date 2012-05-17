//
//  Created by Joram Barrez
//  Copyright (c) 2012 Alfresco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "URLUtil.h"


@implementation URLUtil

+ (NSString *)urlStringByAppendingParameter:(NSString *)parameterName withValue:(NSString *)parameterValue toUrlString:(NSString *)urlString
{
    NSMutableString *result = [NSMutableString stringWithString:urlString];

    // Append '?' if not yet in url, else append ampersand
    if ([result rangeOfString:@"?"].location == NSNotFound)
    {
        [result appendString:@"?"];
    }
    else
    {
        [result appendString:@"&"];
    }

    // Append param
    [result appendString:parameterName];
    [result appendString:@"="];
    [result appendString:[parameterValue stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];

    return result;
}

@end