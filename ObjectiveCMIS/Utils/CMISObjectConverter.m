//
//  CMISObjectConverter.m
//  ObjectiveCMIS
//
//  Created by Cornwell Gavin on 22/02/2012.
//  Copyright (c) 2012 Alfresco. All rights reserved.
//

#import "CMISObjectConverter.h"
#import "CMISDocument.h"
#import "CMISFolder.h"
#import "CMISTypeDefinition.h"
#import "CMISErrors.h"
#import "CMISPropertyDefinition.h"
#import "ISO8601DateFormatter.h"

@interface CMISObjectConverter ()
@property (nonatomic, strong) id<CMISBinding> binding;
@end

@implementation CMISObjectConverter

@synthesize binding = _binding;

- (id)initWithCMISBinding:(id<CMISBinding>)binding
{
    if (self = [super init])
    {
        self.binding = binding;
    }
    
    return self;
}

- (CMISObject *)convertObject:(CMISObjectData *)objectData
{
    CMISObject *object = nil;
    
    if (objectData.baseType == CMISBaseTypeDocument)
    {
        object = [[CMISDocument alloc] initWithObjectData:objectData binding:self.binding];
    }
    else if (objectData.baseType == CMISBaseTypeFolder)
    {
        object = [[CMISFolder alloc] initWithObjectData:objectData binding:self.binding];
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

- (CMISProperties *)convertProperties:(NSDictionary *)properties forObjectTypeId:(NSString *)objectTypeId error:(NSError **)error
{
    // Validate params
    if (!properties)
    {
        return nil;
    }

    // TODO: add support for multi valued properties

    // Convert properties
    CMISTypeDefinition *typeDefinition = nil;
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
            // Fetch type definition if not yet fetched
            if (typeDefinition == nil)
            {
                NSError *internalError = nil;
                typeDefinition = [self.binding.repositoryService retrieveTypeDefinition:objectTypeId error:&internalError];

                if (internalError != nil)
                {
                    *error = [CMISErrors cmisError:&internalError withCMISErrorCode:kCMISErrorCodeRuntime];
                    return nil;
                }
            }

            // Convert to CMISPropertyData based on the string
            CMISPropertyDefinition *propertyDefinition = [typeDefinition propertyDefinitionForId:propertyId];
            switch (propertyDefinition.propertyType)
            {
                case(CMISPropertyTypeString):
                {
                    if (![propertyValue isKindOfClass:[NSString class]])
                    {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                            withDetailedDescription:[NSString stringWithFormat:@"Property value for %@ should be of type 'NSString'", propertyId]];
                        return nil;
                    }
                    [convertedProperties addProperty:[CMISPropertyData createPropertyForId:propertyId withStringValue:propertyValue]];
                    break;
                }
                case(CMISPropertyTypeBoolean):
                {
                    if (![propertyValue isKindOfClass:[NSNumber class]])
                    {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                                    withDetailedDescription:[NSString stringWithFormat:@"Property value for %@ should be of type 'NSNumber'", propertyId]];
                        return nil;
                    }
                    BOOL boolValue = ((NSNumber *) propertyValue).boolValue;
                    [convertedProperties addProperty:[CMISPropertyData createPropertyForId:propertyId withBoolValue:boolValue]];
                    break;
                }
                case(CMISPropertyTypeInteger):
                {
                    if (![propertyValue isKindOfClass:[NSNumber class]])
                    {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                                    withDetailedDescription:[NSString stringWithFormat:@"Property value for %@ should be of type 'NSNumber'", propertyId]];
                        return nil;
                    }
                    NSInteger intValue = ((NSNumber *) propertyValue).integerValue;
                    [convertedProperties addProperty:[CMISPropertyData createPropertyForId:propertyId withIntegerValue:intValue]];
                    break;
                }
                case(CMISPropertyTypeId):
                {
                    if (![propertyValue isKindOfClass:[NSString class]])
                    {
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                                    withDetailedDescription:[NSString stringWithFormat:@"Property value for %@ should be of type 'NSString'", propertyId]];
                        return nil;
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
                        *error = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeInvalidArgument
                                    withDetailedDescription:[NSString stringWithFormat:@"Property value for %@ should be of type 'NSDate' or 'NSString'", propertyId]];
                        return nil;
                    }

                    if (isString)
                    {
                        ISO8601DateFormatter *formatter = [[ISO8601DateFormatter alloc] init];
                        propertyValue = [formatter dateFromString:propertyValue];
                    }
                    [convertedProperties addProperty:[CMISPropertyData createPropertyForId:propertyId withDateTimeValue:propertyValue]];
                    break;
                }
            }

        }
    }

    return convertedProperties;
}


@end
