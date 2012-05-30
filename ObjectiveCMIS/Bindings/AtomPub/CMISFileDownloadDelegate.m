//
//  Created by Joram Barrez
//  Copyright (c) 2012 Alfresco. All rights reserved.
//

#import "CMISFileDownloadDelegate.h"
#import "CMISErrors.h"
#import "CMISFileUtil.h"

@interface CMISFileDownloadDelegate ()

@property NSInteger bytesTotal;
@property NSInteger bytesDownloaded;

@end


@implementation CMISFileDownloadDelegate

@synthesize filePathForContentRetrieval = _filePathForContentRetrieval;
@synthesize fileRetrievalCompletionBlock = _fileRetrievalCompletionBlock;
@synthesize fileRetrievalFailureBlock = _fileRetrievalFailureBlock;
@synthesize fileRetrievalProgressBlock = _fileRetrievalProgressBlock;
@synthesize bytesTotal = _bytesTotal;
@synthesize bytesDownloaded = _bytesDownloaded;

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    // Create file for file that is downloaded
    BOOL fileCreated = [[NSFileManager defaultManager] createFileAtPath:self.filePathForContentRetrieval contents:nil attributes:nil];

    if (!fileCreated)
    {
        [connection cancel];

        if (self.fileRetrievalFailureBlock)
        {
            NSError *cmisError = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeStorage
                    withDetailedDescription:[NSString stringWithFormat:@"Could not create file at path %@", self.filePathForContentRetrieval]];
            self.fileRetrievalFailureBlock(cmisError);
        }
    }
    else
    {
        self.bytesDownloaded = 0;
        self.bytesTotal = (NSInteger) response.expectedContentLength;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [FileUtil appendToFileAtPath:self.filePathForContentRetrieval data:data];

    // Pass progress to progressBlock
    self.bytesDownloaded += data.length;
    if (self.fileRetrievalProgressBlock != nil)
    {
        self.fileRetrievalProgressBlock(self.bytesDownloaded, self.bytesTotal);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (self.fileRetrievalFailureBlock)
    {
        NSError *cmisError = [CMISErrors cmisError:&error withCMISErrorCode:kCMISErrorCodeConnection];
        self.fileRetrievalFailureBlock(cmisError);
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // Fire completion to block
    if (self.fileRetrievalCompletionBlock)
    {
        self.fileRetrievalCompletionBlock();
    }

    // Cleanup
    self.filePathForContentRetrieval = nil;
    self.fileRetrievalCompletionBlock = nil;
    self.fileRetrievalFailureBlock = nil;
    self.fileRetrievalProgressBlock = nil;
}

@end