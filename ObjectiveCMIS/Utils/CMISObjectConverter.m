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
#import "CMISObjectConverter.h"
#import "CMISDocument.h"
#import "CMISFolder.h"
#import "CMISTypeDefinition.h"
#import "CMISErrors.h"
#import "CMISPropertyDefinition.h"
#import "CMISISO8601DateFormatter.h"
#import "CMISSession.h"
#import "CMISConstants.h"

@interface CMISObjectConverter ()
@property (nonatomic, weak) CMISSession *session;
@end

@implementation CMISObjectConverter

@synthesize session = _session;

- (id)initWithSession:(CMISSession *)session
{
    self = [super init];
    if (self)
    {
        self.session = session;
    }
    
    return self;
}

- (CMISObject *)convertObject:(CMISObjectData *)objectData
{
    CMISObject *object = nil;
    
    if (objectData.baseType == CMISBaseTypeDocument)
    {
        object = [[CMISDocument alloc] initWithObjectData:objectData withSession:self.session];
    }
    else if (objectData.baseType == CMISBaseTypeFolder)
    {
        object = [[CMISFolder alloc] initWithObjectData:objectData withSession:self.session];
    }
    
    return object;
}

- (CMISCollection *)convertObjects:(NSArray *)objects
{
    NSMutableArray *items = [[NSMutableArray alloc] initWithCapacity:[objects count]];
    
    for (CMISObjectData *object in objects) 
    {
        [items addObject:[self convertObject:object]];
    }
    
    // create the collection
    CMISCollection *collection = [[CMISCollection alloc] initWithItems:items];
    
    return collection;
}


- (void)convertProperties:(NSDictionary *)properties 
          forObjectTypeId:(NSString *)objectTypeId 
          completionBlock:(void (^)(CMISProperties *convertedProperties, NSError *error))completionBlock
{
    [self internalNormalConvertProperties:properties objectTypeId:objectTypeId completionBlock:completionBlock];
}


- (void)internalNormalConvertProperties:(NSDictionary *)properties 
                         typeDefinition:(CMISTypeDefinition *)typeDefinition 
                        completionBlock:(void (^)(CMISProperties *convertedProperties, NSError *error))completionBlock
{
    CMISProperties *convertedProperties = [[CMISProperties alloc] init];
    for (NSString *propertyId in properties)
    {
        id propertyValue = [properties objectForKey:propertyId];
        // If the value is already a CMISPropertyData, we don't need to do anything
        if ([propertyValue isKindOfClass:[CMISPropertyData class]])
        {
            [convertedProperties addProperty:(CMISPropertyData *)propertyValue];
        }
        else
        {
            // Convert to CMISPropertyData based on the string
            CMISPropertyDefinition *propertyDefinition = [typeDefinition propertyDefinitionForId:propertyId];
            
            if (propertyDefinition == nil)
            {
                NSError *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                                             withDetailedDescription:[NSString stringWithFormat:@"Invalid property '%@' for this object type", propertyId]];
                completionBlock(nil, error);
                return;
            }
            
            switch (propertyDefinition.propertyType)
            {
                case(CMISPropertyTypeString):
                {
                    if (![propertyValue isKindOfClass:[NSString class]])
                    {
                        NSError *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                                                     withDetailedDescription:[NSString stringWithFormat:@"Property value for %@ should be of type 'NSString'", propertyId]];
                        completionBlock(nil, error);
                        return;
                    }
                    [convertedProperties addProperty:[CMISPropertyData createPropertyForId:propertyId withStringValue:propertyValue]];
                    break;
                }
                case(CMISPropertyTypeBoolean):
                {
                    if (![propertyValue isKindOfClass:[NSNumber class]])
                    {
                        NSError *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                                                     withDetailedDescription:[NSString stringWithFormat:@"Property value for %@ should be of type 'NSNumber'", propertyId]];
                        completionBlock(nil, error);
                        return;
                    }
                    BOOL boolValue = ((NSNumber *) propertyValue).boolValue;
                    [convertedProperties addProperty:[CMISPropertyData createPropertyForId:propertyId withBoolValue:boolValue]];
                    break;
                }
                case(CMISPropertyTypeInteger):
                {
                    if (![propertyValue isKindOfClass:[NSNumber class]])
                    {
                        NSError *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                                                     withDetailedDescription:[NSString stringWithFormat:@"Property value for %@ should be of type 'NSNumber'", propertyId]];
                        completionBlock(nil, error);
                        return;
                    }
                    NSInteger intValue = ((NSNumber *) propertyValue).integerValue;
                    [convertedProperties addProperty:[CMISPropertyData createPropertyForId:propertyId withIntegerValue:intValue]];
                    break;
                }
                case(CMISPropertyTypeId):
                {
                    if (![propertyValue isKindOfClass:[NSString class]])
                    {
                        NSError *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                                                     withDetailedDescription:[NSString stringWithFormat:@"Property value for %@ should be of type 'NSString'", propertyId]];
                        completionBlock(nil, error);
                        return;
                    }
                    [convertedProperties addProperty:[CMISPropertyData createPropertyForId:propertyId withIdValue:propertyValue]];
                    break;
                }
                case(CMISPropertyTypeDateTime):
                {
                    BOOL isDate = [propertyValue isKindOfClass:[NSDate class]];
                    BOOL isString = [propertyValue isKindOfClass:[NSString class]];
                    if (!isDate && !isString)
                    {
                        NSError *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                                                     withDetailedDescription:[NSString stringWithFormat:@"Property value for %@ should be of type 'NSDate' or 'NSString'", propertyId]];
                        completionBlock(nil, error);
                        return;
                    }
                    
                    if (isString)
                    {
                        CMISISO8601DateFormatter *formatter = [[CMISISO8601DateFormatter alloc] init];
                        propertyValue = [formatter dateFromString:propertyValue];
                    }
                    [convertedProperties addProperty:[CMISPropertyData createPropertyForId:propertyId withDateTimeValue:propertyValue]];
                    break;
                }
                default:
                {
                    log(@"Unsupported: cannot convert property type %d", propertyDefinition.propertyType)
                    break;
                }
            }
            
        }
    }
    
    completionBlock(convertedProperties, nil);
}


- (void)internalNormalConvertProperties:(NSDictionary *)properties 
                           objectTypeId:(NSString *)objectTypeId                                    
                        completionBlock:(void (^)(CMISProperties *convertedProperties, NSError *error))completionBlock

{
    // Validate params
    if (!properties)
    {
        completionBlock(nil, nil);
        return;
    }

    // TODO: add support for multi valued properties
    
    BOOL onlyPropertyData = YES;
    for (id propertyValue in properties.objectEnumerator) {
        if (![propertyValue isKindOfClass:[CMISPropertyData class]]) {
            onlyPropertyData = NO;
            break;
        }
    }
    
    // Convert properties
    if (onlyPropertyData) {
        [self internalNormalConvertProperties:properties
                               typeDefinition:nil // not needed because all properties are of type CMISPropertyData
                              completionBlock:completionBlock];
        
    } else {
        [self.session.binding.repositoryService
         retrieveTypeDefinition:objectTypeId
         completionBlock:^(CMISTypeDefinition *typeDefinition, NSError *error) {
             if (error) {
                 completionBlock(nil, [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeRuntime]);
             } else {
                 [self internalNormalConvertProperties:properties
                                        typeDefinition:typeDefinition
                                       completionBlock:completionBlock];
             }
         }];
    }
}

@end
