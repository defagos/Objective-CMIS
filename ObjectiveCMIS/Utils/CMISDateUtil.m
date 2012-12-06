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

//
// CMISDateUtil
//
#import "CMISDateUtil.h"
#import "CMISISO8601DateFormatter.h"


@implementation CMISDateUtil

+ (CMISISO8601DateFormatter *)defaultDateFormatter
{
    static dispatch_once_t predicate = 0;
      __strong static CMISISO8601DateFormatter *defaultFormatter = nil;
      dispatch_once(&predicate, ^
      {
        defaultFormatter = [[CMISISO8601DateFormatter alloc] init];
        defaultFormatter.includeTime = YES;
        defaultFormatter.defaultTimeZone = [NSTimeZone timeZoneWithName:@"UTC"];
      });
      return defaultFormatter;
}

@end