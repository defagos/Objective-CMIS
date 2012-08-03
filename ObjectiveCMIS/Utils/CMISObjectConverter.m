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
@property (nonatomic, strong) CMISSession *session;
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
    // TODO: Temporary. Must be extracted into separate project.
    // I decided to keep all logic in one method: so keep in mind when ripping it out that you will need to do
    // some SERIOUS refactoring, by splitting into several methods and util classes (eg to create the extension elements)

// TODO: reactivate this code if needed
//    NSString *mode = [self.session.sessionParameters objectForKey:kCMISSessionParameterMode];
//    if (mode != nil && [mode isEqualToString:@"alfresco"])
//    {
//        [self internalAlfrescoConvertProperties:properties objectTypeId:objectTypeId completionBlock:completionBlock];
//    }
//    else {
        [self internalNormalConvertProperties:properties objectTypeId:objectTypeId completionBlock:completionBlock];
//    }
}

/* TODO: reactivate and finish implementation if needed
- (void)internalAlfrescoConvertProperties:(NSDictionary *)properties 
                             objectTypeId:(NSString *)objectTypeId           
                          completionBlock:(void (^)(CMISProperties *properties, NSError *error))completionBlock

{
    // A direct port of the Alfresco extensions code ... definitely not going to win a beauty contest ...

    // Check input
    if (properties == nil)
    {
        completionBlock(nil, nil);
        return;
    }

    // Get object and aspect types
    NSObject *objectTypeIdValue = [properties objectForKey:kCMISPropertyObjectTypeId];
    NSString *objectTypeIdString = nil;

    if ([objectTypeIdValue isKindOfClass:[NSString class]])
    {
        objectTypeIdString = (NSString *)objectTypeIdValue;
    }
    else if ([objectTypeIdValue isKindOfClass:[CMISPropertyData class]])
    {
        objectTypeIdString = [(CMISPropertyData *)objectTypeIdValue firstValue];
    }

    if (objectTypeIdString == nil)
    {
        NSError *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument withDetailedDescription:@"Type property must be set"];
        completionBlock(nil, error);
        return;
    }

    NSArray *typeIds = nil;
    NSString *typeDefinitionString = nil;
    // Check if there are actually aspects/
    // If so, split them and fetch the type definition for each of them
    if ([objectTypeIdString rangeOfString:@","].location == NSNotFound)
    {
        typeDefinitionString = objectTypeId;
    }
    else
    {
        typeIds = [objectTypeIdString componentsSeparatedByString:@","];
        typeDefinitionString = [[typeIds objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
    }

    // Get type definitions
    CMISTypeDefinition *typeDefinition = nil;
    NSMutableArray *aspectTypes = [[NSMutableArray alloc] init];

    // Main type
    [self.session.binding.repositoryService retrieveTypeDefinition:typeDefinitionString  
                                                   completionBlock:^(CMISTypeDefinition *typeDefinition, NSError *internalError) {
                                                       if (internalError) {
                                                           NSError *error = [CMISErrors cmisError:internalError withCMISErrorCode:kCMISErrorCodeInvalidArgument];
                                                           completionBlock(nil, error);
                                                           return;
                                                       }
    }];
    
    // from here on the implementation has not been changed yet; it would need to be switched to recursive calls to get all aspect type definitions
 
    // Aspects
    for (int i=1; i < typeIds.count; i++)
    {
        NSString *aspectTypeDefinitionString = [typeIds objectAtIndex:i];
        CMISTypeDefinition *aspectTypeDefinition = [self.session.binding.repositoryService retrieveTypeDefinition:
                                                    [aspectTypeDefinitionString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] error:&internalError];
        
        if (internalError != nil)
        {
            *error = [CMISErrors cmisError:internalError withCMISErrorCode:kCMISErrorCodeInvalidArgument];
            return nil;
        }
        
        [aspectTypes addObject:aspectTypeDefinition];
    }

    // Split type properties from aspect properties
    NSMutableDictionary *typeProperties = [NSMutableDictionary dictionary];
    NSMutableDictionary *aspectProperties = [NSMutableDictionary dictionary];
    NSMutableDictionary *aspectPropertyDefinitions = [NSMutableDictionary dictionary];

    // Loop over all provided properties and put them in the right dictionary
    for (NSString *propertyId in properties)
    {
        id propertyValue = [properties objectForKey:propertyId];

        if ([propertyId isEqualToString:kCMISPropertyObjectTypeId])
        {
            if (objectTypeId == nil) // do not merge this if with the parent if. In case it's not nil, we don't do anything!
            {
                [typeProperties setObject:typeDefinition.id forKey:propertyId];
            }
            else
            {
                [typeProperties setObject:objectTypeId forKey:propertyId];
            }
        }
        else if ([typeDefinition propertyDefinitionForId:propertyId])
        {
            [typeProperties setObject:propertyValue forKey:propertyId];
        }
        else
        {
            [aspectProperties setObject:propertyValue forKey:propertyId];

            // Find matching property definition
            BOOL matchingPropertyDefinitionFound = NO;
            uint index = 0;
            while (!matchingPropertyDefinitionFound && index < aspectTypes.count)
            {
                CMISTypeDefinition *aspectType = [aspectTypes objectAtIndex:index];
                if (aspectType.propertyDefinitions != nil)
                {
                    CMISPropertyDefinition *aspectPropertyDefinition = [aspectType propertyDefinitionForId:propertyId];
                    if (aspectPropertyDefinition != nil)
                    {
                        [aspectPropertyDefinitions setObject:aspectPropertyDefinition forKey:propertyId];
                       matchingPropertyDefinitionFound = YES;
                    }
                }
                index++;
            }

            // If no match was found, throw an exception
            if (!matchingPropertyDefinitionFound)
            {
                *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                    withDetailedDescription:[NSString stringWithFormat:@"Property '%@' is neither an object type property nor an aspect property", propertyId]];
                return nil;
            }
        }
    }

    // Create an array to hold all converted stuff
    NSMutableArray *alfrescoExtensions = [NSMutableArray array];

    // Convert the aspect types stuff to CMIS extensions
    for (CMISTypeDefinition *aspectType in aspectTypes)
    {
        CMISExtensionElement *extensionElement = [[CMISExtensionElement alloc] initLeafWithName:@"aspectsToAdd"
            namespaceUri:@"http://www.alfresco.org" attributes:nil value:aspectType.id];
        [alfrescoExtensions addObject:extensionElement];
    }

    // Convert the aspect properties
    if (aspectProperties.count > 0)
    {
        NSMutableArray *propertyExtensions = [NSMutableArray array];

        for (NSString *propertyId in aspectProperties)
        {
            CMISPropertyDefinition *aspectPropertyDefinition = [aspectPropertyDefinitions objectForKey:propertyId];
            if (aspectPropertyDefinition == nil)
            {
                *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                                   withDetailedDescription:[NSString stringWithFormat:@"Unknown aspect property: %@",propertyId]];
                return nil;
            }


            NSString *name = nil;
            switch (aspectPropertyDefinition.propertyType)
            {
                case CMISPropertyTypeBoolean:
                    name = @"propertyBoolean";
                    break;
                case CMISPropertyTypeDateTime:
                    name = @"propertyDateTime";
                    break;
                case CMISPropertyTypeInteger:
                    name = @"propertyInteger";
                    break;
                case CMISPropertyTypeDecimal:
                    name = @"propertyDecimal";
                    break;
                case CMISPropertyTypeId:
                    name = @"propertyId";
                    break;
                case CMISPropertyTypeHtml:
                    name = @"propertyHtml";
                    break;
                case CMISPropertyTypeUri:
                    name = @"propertyUri";
                    break;
                default:
                    name = @"propertyString";
            }

            NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
            [attributes setObject:aspectPropertyDefinition.id forKey:@"propertyDefinitionId"];

            NSMutableArray *propertyValues = [NSMutableArray array];
            id value = [aspectProperties objectForKey:propertyId];
            if (value != nil)
            {
                NSString *stringValue = nil;
                if ([value isKindOfClass:[NSString class]])
                {
                    stringValue = value;
                }
                else if ([value isKindOfClass:[CMISPropertyData class]])
                {
                    stringValue = ((CMISPropertyData *) value).firstValue;
                }

                CMISExtensionElement *valueExtensionElement = [[CMISExtensionElement alloc] initLeafWithName:@"value"
                    namespaceUri:@"http://docs.oasis-open.org/ns/cmis/core/200908/" attributes:nil value:stringValue];
                [propertyValues addObject:valueExtensionElement];
            }


            CMISExtensionElement *aspectPropertyExtensionElement = [[CMISExtensionElement alloc] initNodeWithName:name
                           namespaceUri:@"http://docs.oasis-open.org/ns/cmis/core/200908/" attributes:attributes children:propertyValues];
            [propertyExtensions addObject:aspectPropertyExtensionElement];
        }

        [alfrescoExtensions addObject: [[CMISExtensionElement alloc] initNodeWithName:@"properties"
                                          namespaceUri:@"http://www.alfresco.org" attributes:nil children:propertyExtensions]];
    }

    // Convert regular type properties
    CMISProperties *result = [self internalNormalConvertProperties:typeProperties objectTypeId:objectTypeId error:error];
    if (alfrescoExtensions.count > 0)
    {
        result.extensions = [NSArray arrayWithObject:[[CMISExtensionElement alloc] initNodeWithName:@"setAspects"
                                 namespaceUri:@"http://www.alfresco.org" attributes:nil children:alfrescoExtensions]];
    }

    return result;
}
*/
 
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
