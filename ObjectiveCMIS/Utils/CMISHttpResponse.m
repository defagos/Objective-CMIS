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