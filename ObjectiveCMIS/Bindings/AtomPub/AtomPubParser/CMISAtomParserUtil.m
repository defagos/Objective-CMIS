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
// CMISAtomParserUtil
//
#import "CMISAtomParserUtil.h"
#import "CMISAtomPubConstants.h"
#import "CMISISO8601DateFormatter.h"
#import "CMISDateUtil.h"


@implementation CMISAtomParserUtil

+ (CMISPropertyType)atomPubTypeToInternalType:(NSString *)atomPubType
{
    if([atomPubType isEqualToString:kCMISAtomEntryPropertyId])
    {
        return CMISPropertyTypeId;
    }
    else if ([atomPubType isEqualToString:kCMISAtomEntryPropertyString])
       {
           return CMISPropertyTypeString;
       }
    else if ([atomPubType isEqualToString:kCMISAtomEntryPropertyInteger])
    {
        return CMISPropertyTypeInteger;
    }
    else if ([atomPubType isEqualToString:kCMISAtomEntryPropertyBoolean])
    {
        return CMISPropertyTypeBoolean;
    }
    else if ([atomPubType isEqualToString:kCMISAtomEntryPropertyDateTime])
    {
        return CMISPropertyTypeDateTime;
    }
    else if ([atomPubType isEqualToString:kCMISAtomEntryPropertyDecimal])
    {
        return CMISPropertyTypeDecimal;
    }
    else
    {
        log(@"Unknow property type %@. Go tell a developer to fix this.", atomPubType);
        return CMISPropertyTypeString;
    }
}

+ (NSArray *)parsePropertyValue:(NSString *)stringValue withPropertyType:(NSString *)propertyType
{
    if ([propertyType isEqualToString:kCMISAtomEntryPropertyString] ||
            [propertyType isEqualToString:kCMISAtomEntryPropertyId])
    {
        return [NSArray arrayWithObject:stringValue];
    }
    else if ([propertyType isEqualToString:kCMISAtomEntryPropertyInteger])
    {
        return [NSArray arrayWithObject:[NSNumber numberWithInt:[stringValue intValue]]];
    }
    else if ([propertyType isEqualToString:kCMISAtomEntryPropertyBoolean])
    {
        return [NSArray arrayWithObject:[NSNumber numberWithBool:[stringValue isEqualToString:kCMISAtomEntryValueTrue]]];
    }
    else if ([propertyType isEqualToString:kCMISAtomEntryPropertyDateTime])
    {
        return [NSArray arrayWithObject:[[CMISDateUtil defaultDateFormatter] dateFromString:stringValue]];
    }
    else if ([propertyType isEqualToString:kCMISAtomEntryPropertyDecimal])
    {
        return [NSArray arrayWithObject:[NSNumber numberWithFloat:[stringValue floatValue]]];
    }
    else
    {
        log(@"Unknow property type %@. Go tell a developer to fix this.", propertyType);
         return [NSArray array];
    }
}


@end