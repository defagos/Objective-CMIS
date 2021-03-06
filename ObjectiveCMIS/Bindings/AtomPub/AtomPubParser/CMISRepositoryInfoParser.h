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

#import <Foundation/Foundation.h>
#import "CMISRepositoryInfo.h"
#import "CMISAtomPubExtensionDataParserBase.h"

@class CMISRepositoryInfoParser;

@protocol CMISRepositoryInfoParserDelegate <NSObject>
@required
- (void)repositoryInfoParser:(CMISRepositoryInfoParser *)epositoryInfoParser didFinishParsingRepositoryInfo:(CMISRepositoryInfo *)repositoryInfo;
@end


@interface CMISRepositoryInfoParser : CMISAtomPubExtensionDataParserBase <NSXMLParserDelegate>

@property (nonatomic, strong, readonly) CMISRepositoryInfo *currentRepositoryInfo;

- (id)initRepositoryInfoParserWithParentDelegate:(id<NSXMLParserDelegate, CMISRepositoryInfoParserDelegate>)parentDelegate parser:(NSXMLParser *)parser;
+ (id)repositoryInfoParserWithParentDelegate:(id<NSXMLParserDelegate, CMISRepositoryInfoParserDelegate>)parentDelegate parser:(NSXMLParser *)parser;

@end
