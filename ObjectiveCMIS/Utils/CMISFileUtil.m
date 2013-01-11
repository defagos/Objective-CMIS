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

#import "CMISFileUtil.h"
#import "CMISBase64Encoder.h"

@implementation FileUtil

+ (NSInputStream *)inputStreamWithFileAtPath:(NSString *)filePath
{
    return [NSInputStream inputStreamWithFileAtPath:filePath];
}

+ (void)encodeContentFromInputStream:(NSInputStream *)inputStream andAppendToFile:(NSString *)filePath
{
    [CMISBase64Encoder encodeContentFromInputStream:inputStream andAppendToFile:filePath];
}


+ (void)appendToFileAtPath:(NSString *)filePath data:(NSData *)data
{
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:filePath];

    if (fileHandle)
    {
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:data];
    }

    // Always clean up after the file is written to
    [fileHandle closeFile];
}

/*
+ (unsigned long long)fileSizeForFileAtPath:(NSString *)filePath error:(NSError * *)outError
{
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:outError];

    if (*outError == nil) {
        return [attributes fileSize];
    }

    return 0LL;
}
*/

+ (BOOL)fileStreamIsOpen:(NSStream *)stream
{
    BOOL isStreamOpen = NO;
    NSOutputStream *outputStream = (NSOutputStream *)stream;
    isStreamOpen = outputStream.streamStatus == NSStreamStatusOpen;
    return isStreamOpen;
}



+ (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)outError
{
    return [[NSFileManager defaultManager] attributesOfItemAtPath:path error:outError];
}



+ (BOOL)createFileAtPath:(NSString *)filePath contents:(NSData *)data error:(NSError **)error
{
    return [[NSFileManager defaultManager] createFileAtPath:filePath
                                                   contents:data
                                                 attributes:nil];
}

+ (BOOL)removeItemAtPath:(NSString *)filePath error:(NSError **)error
{
    return [[NSFileManager defaultManager] removeItemAtPath:filePath error:error];
}

+ (NSString *)internalFilePathFromName:(NSString *)fileName
{
    return [NSString stringWithFormat:@"%@/%@", NSTemporaryDirectory(), fileName];
}


+ (NSString *)temporaryDirectory
{
    return NSTemporaryDirectory();
}


#pragma the following are not yet required in CMIS lib.
+ (BOOL)fileExistsAtPath:(NSString *)path
{
    return YES;
}

+ (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory
{
    return YES;
}


+ (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error
{
    return YES;
}

+ (BOOL)copyItemAtPath:(NSString *)sourcePath toPath:(NSString *)destinationPath error:(NSError **)error
{
    return YES;
}

+ (BOOL)moveItemAtPath:(NSString *)sourcePath toPath:(NSString *)destinationPath error:(NSError **)error
{
    return YES;
}

+ (NSArray *)contentsOfDirectoryAtPath:(NSString *)directoryPath error:(NSError **)error
{
    return nil;
}

+ (void)enumerateThroughDirectory:(NSString *)directory includingSubDirectories:(BOOL)includeSubDirectories error:(NSError **)error withBlock:(void (^)(NSString *fullFilePath))block{}

+ (NSData *)dataWithContentsOfURL:(NSURL *)url
{
    return nil;
}

+ (NSString *)homeDirectory
{
    return nil;
}

+ (NSString *)documentsDirectory
{
    return nil;
}


@end