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

#import "CMISAllowableActionsParser.h"
#import "CMISAtomPubConstants.h"

@interface CMISAllowableActionsParser ()

@property (nonatomic, strong) NSMutableDictionary *internalAllowableActionsDict;
@property (nonatomic, weak) id<NSXMLParserDelegate, CMISAllowableActionsParserDelegate> parentDelegate;
@property (nonatomic, strong) NSMutableString *string;
@property (nonatomic, strong) NSString *elementBeingParsed;
@property (nonatomic, strong) NSData *atomData;

// Private init Used for child delegate parser
- (id)initWithParentDelegate:(id<NSXMLParserDelegate, CMISAllowableActionsParserDelegate>)parentDelegate parser:(NSXMLParser *)parser;
@end


@implementation CMISAllowableActionsParser

@synthesize internalAllowableActionsDict = _internalAllowableActionsDict;
@synthesize parentDelegate = _parentDelegate;
@synthesize string = _string;
@synthesize elementBeingParsed = _elementBeingParsed;
@synthesize atomData = _atomData;
@synthesize allowableActions;

#pragma mark - 
#pragma mark Init/Create methods

- (id)initWithParentDelegate:(id<NSXMLParserDelegate, CMISAllowableActionsParserDelegate>)parentDelegate parser:(NSXMLParser *)parser 
{
    self = [self initWithData:nil];
    if (self) 
    {
        self.parentDelegate = parentDelegate;
        self.internalAllowableActionsDict = [[NSMutableDictionary alloc] init];
        
        self.allowableActions = [[CMISAllowableActions alloc] init];
        [self pushNewCurrentExtensionData:self.allowableActions];
        
        // Setting Child Parser Delegate
        [parser setDelegate:self];
    }
    return self;
}

+ (id)allowableActionsParserWithParentDelegate:(id<NSXMLParserDelegate, CMISAllowableActionsParserDelegate>)parentDelegate parser:(NSXMLParser *)parser
{
    return [[[self class] alloc] initWithParentDelegate:parentDelegate parser:parser];
}

// Designated Initializer
- (id)initWithData:(NSData*)atomData
{
    self = [super init];
    if (self)
    {
        self.atomData = atomData;
    }
    
    return self;
}

- (BOOL)parseAndReturnError:(NSError **)error;
{
    BOOL parseSuccessful = YES;
    
    // parse the AtomPub data
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:self.atomData];
    [parser setShouldProcessNamespaces:YES];
    [parser setDelegate:self];
    
    parseSuccessful = [parser parse];
    
    if (!parseSuccessful)
    {
        if (error)
        {
            *error = [parser parserError];
        }
    }
    
    return parseSuccessful;
}

#pragma mark - 
#pragma mark NSXMLParserDelegate Methods

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName
    attributes:(NSDictionary *)attributeDict 
{
    self.elementBeingParsed = elementName;
    
    if ([namespaceURI isEqualToString:kCMISNamespaceCmis])
    {
        
        if ([elementName isEqualToString:kCMISAtomEntryAllowableActions]) 
        {
            [self setInternalAllowableActionsDict:[NSMutableDictionary dictionary]];
            
            self.allowableActions = [[CMISAllowableActions alloc] init];
            [self pushNewCurrentExtensionData:self.allowableActions];
        }
        else
        {
            self.string = [NSMutableString string];
        }
    }
    else 
    {
        self.childParserDelegate = [CMISAtomPubExtensionElementParser extensionElementParserWithElementName:elementName namespaceUri:namespaceURI 
                                                                                                 attributes:attributeDict parentDelegate:self parser:parser];
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string 
{
    if (self.string)
    {
        [self.string appendString:string];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName 
{
    if ([namespaceURI isEqualToString:kCMISNamespaceCmis])
    {
        if ([elementName isEqualToString:kCMISAtomEntryAllowableActions])
        {
            // Set the parsed dictionary of allowable actions
            [self.allowableActions setAllowableActionsWithDictionary:[self.internalAllowableActionsDict copy]];
            // Save the extension data
            [self saveCurrentExtensionsAndPushPreviousExtensionData];
            
            if (self.parentDelegate)
            {
                if ([self.parentDelegate respondsToSelector:@selector(allowableActionsParser:didFinishParsingAllowableActions:)])
                {
                    [self.parentDelegate performSelector:@selector(allowableActionsParser:didFinishParsingAllowableActions:) withObject:self withObject:self.allowableActions];
                }
                
                // Reset Delegate to parent
                [parser setDelegate:self.parentDelegate];
                self.parentDelegate = nil;
            }
        }
        else
        {
            [self.internalAllowableActionsDict setObject:self.string forKey:elementName];
        }
    }
    
    self.elementBeingParsed = nil;
    self.string = nil;
}

@end
