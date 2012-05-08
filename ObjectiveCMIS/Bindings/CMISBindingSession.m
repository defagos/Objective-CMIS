//
//  CMISBindingSession.m
//  ObjectiveCMIS
//
//  Created by Cornwell Gavin on 04/05/2012.
//  Copyright (c) 2012 Alfresco. All rights reserved.
//

#import "CMISBindingSession.h"

NSString * const kCMISBindingSessionKeyAtomPubUrl = @"cmis_session_key_atompub_url";
NSString * const kCMISBindingSessionKeyObjectByIdUriBuilder = @"cmis_session_key_objectbyid_uri_builder";

@interface CMISBindingSession ()
@property (nonatomic, strong, readwrite) NSString *username;
@property (nonatomic, strong, readwrite) NSString *repositoryId;
@property (nonatomic, strong, readwrite) id<CMISAuthenticationProvider> authenticationProvider;
@property (nonatomic, strong, readwrite) NSMutableDictionary *sessionData;
@end

@implementation CMISBindingSession

@synthesize username = _username;
@synthesize repositoryId = _repositoryId;
@synthesize authenticationProvider = _authenticationProvider;
@synthesize sessionData = _sessionData;

- (id)initWithSessionParameters:(CMISSessionParameters *)sessionParameters
{
    if (self = [super init])
    {
        self.sessionData = [[NSMutableDictionary alloc] init];
        
        // grab common data from session parameters
        self.username = sessionParameters.username;
        self.repositoryId = sessionParameters.repositoryId;
        self.authenticationProvider = sessionParameters.authenticationProvider;
        
        // store all other data in the dictionary
        [self.sessionData setObject:sessionParameters.atomPubUrl forKey:kCMISBindingSessionKeyAtomPubUrl];
        
        for (id key in sessionParameters.allKeys) 
        {
            [self.sessionData setObject:[sessionParameters objectForKey:key] forKey:key];
        }
    }
    
    return self;
}

- (NSArray *)allKeys
{
    return [self.sessionData allKeys];
}

- (id)objectForKey:(id)key
{
    return [self.sessionData objectForKey:key];
}

- (id)objectForKey:(id)key withDefaultValue:(id)defaultValue
{
    NSObject *value = [self.sessionData objectForKey:key];
    return value != nil ? value : defaultValue;
}

- (void)setObject:(id)object forKey:(id)key
{
    [self.sessionData setObject:object forKey:key];
}

- (void)removeKey:(id)key
{
    [self.sessionData removeObjectForKey:key];
}

@end