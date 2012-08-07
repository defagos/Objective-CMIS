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

#import "CMISFileDownloadDelegate.h"
#import "CMISErrors.h"
#import "CMISFileUtil.h"

@interface CMISFileDownloadDelegate ()

@property NSInteger bytesTotal;
@property NSInteger bytesDownloaded;

@end


@implementation CMISFileDownloadDelegate

@synthesize fileStreamForContentRetrieval = _fileStreamForContentRetrieval;
@synthesize fileRetrievalCompletionBlock = _fileRetrievalCompletionBlock;
@synthesize fileRetrievalFailureBlock = _fileRetrievalFailureBlock;
@synthesize fileRetrievalProgressBlock = _fileRetrievalProgressBlock;
@synthesize bytesTotal = _bytesTotal;
@synthesize bytesDownloaded = _bytesDownloaded;

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    // Create file for file that is downloaded
    BOOL isStreamReady = self.fileStreamForContentRetrieval.streamStatus == NSStreamStatusOpen;
    if (!isStreamReady) {
        [self.fileStreamForContentRetrieval open];
        isStreamReady = self.fileStreamForContentRetrieval.streamStatus == NSStreamStatusOpen;
    } else { // stream is already open, reset it
        isStreamReady = [self.fileStreamForContentRetrieval setProperty:[NSNumber numberWithInteger:0]
                                                                 forKey:NSStreamFileCurrentOffsetKey];
    }

    if (!isStreamReady)
    {
        [connection cancel];

        if (self.fileRetrievalFailureBlock)
        {
            NSError *cmisError = [CMISErrors createCMISErrorWithCode:kCMISErrorCodeStorage
                                             withDetailedDescription:@"Could not open output stream"];
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
    const uint8_t *bytes = data.bytes;
    NSUInteger length = data.length;
    NSUInteger offset = 0;
    do {
        NSUInteger written = [self.fileStreamForContentRetrieval write:&bytes[offset] maxLength:length - offset];
        if (written <= 0) {
            log(@"Error while writing downloaded data to file");
            [connection cancel];
            return;
        } else {
            offset += written;
        }
    } while (offset < length);

    // Pass progress to progressBlock
    self.bytesDownloaded += data.length;
    if (self.fileRetrievalProgressBlock)
    {
        self.fileRetrievalProgressBlock(self.bytesDownloaded, self.bytesTotal);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self.fileStreamForContentRetrieval close];
    
    if (self.fileRetrievalFailureBlock)
    {
        NSError *cmisError = [CMISErrors cmisError:error withCMISErrorCode:kCMISErrorCodeConnection];
        self.fileRetrievalFailureBlock(cmisError);
    }

    // Cleanup
    self.fileRetrievalCompletionBlock = nil;
    self.fileRetrievalFailureBlock = nil;
    self.fileRetrievalProgressBlock = nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self.fileStreamForContentRetrieval close];

    // Fire completion to block
    if (self.fileRetrievalCompletionBlock)
    {
        self.fileRetrievalCompletionBlock();
    }

    // Cleanup
    self.fileRetrievalCompletionBlock = nil;
    self.fileRetrievalFailureBlock = nil;
    self.fileRetrievalProgressBlock = nil;
}

@end