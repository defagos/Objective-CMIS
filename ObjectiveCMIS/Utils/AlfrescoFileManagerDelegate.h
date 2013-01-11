//
//  AlfrescoFileManagerDelegate.h
//  AlfrescoSDKExample
//
//  Created by Tauseef Mughal on 18/12/2012.
//  Copyright (c) 2012 Alfresco. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol AlfrescoFileManagerDelegate <NSObject>

/**
 some APIs don't fully implement NSStream properties, such as streamStatus. But we need that in the CMIS lib
 */
+ (BOOL)fileStreamIsOpen:(NSStream *)stream;

/**
 Call this function to get the home directory for the app
 */
+ (NSString *)homeDirectory;

/**
 Call this function to get the documents directory for the app
 */
+ (NSString *)documentsDirectory;

/**
 Call this function to get the temporary directory for the app
 */
+ (NSString *)temporaryDirectory;

/**
 Call this to check if a file exists at the path location
 
 @returns bool - True if the file/folder exists
 */
+ (BOOL)fileExistsAtPath:(NSString *)path;

/**
 Call this to check if a file exists at the path location passing in a memory reference pointer to a BOOL which
 indicates if the path points to a directory
 
 @returns bool - True if the file/folder exists
 */
+ (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory;

/*
 Call this to create a file with data passed in at a given location
 
 @returns bool - True if the file was created successfully
 */
+ (BOOL)createFileAtPath:(NSString *)path contents:(NSData *)data error:(NSError **)error;

/*
 Call this to create a directory at a given path. Set the createIntermediateDirectories to true if you would like to
 create leading directories if they do not exist
 
 @returns bool - True if the directory was created successfully
 */
+ (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error;

/*
 Call this to remove an item at a given path
 
 @returns bool - True if the file/folder was removed successfully
 */
+ (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error;

/*
 Call this to copy an item from a given path to another path within the current file system
 
 @returns bool - True if the file was copied successfully
 */
+ (BOOL)copyItemAtPath:(NSString *)sourcePath toPath:(NSString *)destinationPath error:(NSError **)error;

/*
 Call this to move an item from a given path to another within the current file system
 
 @returns bool - True if the item was moved successfully
 */
+ (BOOL)moveItemAtPath:(NSString *)sourcePath toPath:(NSString *)destinationPath error:(NSError **)error;

/*
 Call this to return the attributes of a given item at a path
 
 @returns dictionary - dictionary containing fileSize, isFolder and lastModifiedDate
 */
+ (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error;

/*
 Call this to return an array of all items in a given directory
 
 @returns array - array containing a list of items in a given directory
 */
+ (NSArray *)contentsOfDirectoryAtPath:(NSString *)directoryPath error:(NSError **)error;

/*
 Enumerates through a given directory either including or not including sub directories
 */
+ (void)enumerateThroughDirectory:(NSString *)directory includingSubDirectories:(BOOL)includeSubDirectories error:(NSError **)error withBlock:(void (^)(NSString *fullFilePath))block;

/*
 Returns the data representation of the file at a given URL
 
 @returns data - NSData representation of the item at the given URL location
 */
+ (NSData *)dataWithContentsOfURL:(NSURL *)url;

/*
 Call this to append data to the file at a given path
 */
+ (void)appendToFileAtPath:(NSString *)filePath data:(NSData *)data;

/*
 Call this to retrieve the internal filePath from a file name
 
 @returns string - the filePath in relation to a given fileName
 */
+ (NSString *)internalFilePathFromName:(NSString *)fileName;


+ (id)inputStreamWithFileAtPath:(NSString *)filePath;

+ (void)encodeContentFromInputStream:(NSInputStream *)inputStream andAppendToFile:(NSString *)filePath;

@end
