//
//  BookmarksHelper.m
//  Strongbox
//
//  Created by Mark on 21/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "BookmarksHelper.h"
#import "Utils.h"

@implementation BookmarksHelper

+ (NSURL *)getExpressUrlFromBookmark:(NSString *)bookmark {
    NSError* error;
    NSString* updated;
    
    return [BookmarksHelper getUrlFromBookmark:bookmark readOnly:NO updatedBookmark:&updated error:&error];
}

+ (NSURL *)getExpressReadOnlyUrlFromBookmark:(NSString *)bookmark {
    NSError* error;
    NSString* updated;
    
    return [BookmarksHelper getUrlFromBookmark:bookmark readOnly:YES updatedBookmark:&updated error:&error];
}

+ (NSData *)getBookmarkDataFromUrl:(NSURL *)url error:(NSError * _Nonnull __autoreleasing *)error {
    return [BookmarksHelper getBookmarkDataFromUrl:url readOnly:NO error:error];
}

+ (NSData *)getBookmarkDataFromUrl:(NSURL *)url readOnly:(BOOL)readOnly error:(NSError *_Nonnull*)error {
    NSURLBookmarkCreationOptions options = kNilOptions;
    
    #if !TARGET_OS_IPHONE
        options |= readOnly ? NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess : kNilOptions; // NSURLBookmarkCreationMinimalBookmark;
        options |= NSURLBookmarkCreationWithSecurityScope;
    #else
        options |= NSURLBookmarkCreationMinimalBookmark; // iOS
    #endif

    [url startAccessingSecurityScopedResource]; // MMcG: Do not check return here explicitly because it will fail if the URL was not generated from a bookmark - i.e. if it was just passed in by the system - This is fine we will continue and successfully generate a bookmark (or not).

    NSData *bookmark = [url bookmarkDataWithOptions:options
                     includingResourceValuesForKeys:nil
                                      relativeToURL:nil
                                              error:error];

    [url stopAccessingSecurityScopedResource];

    if (!bookmark) {
        NSLog(@"Error while creating bookmark for URL (%@): %@", url, *error);
        return nil;
    }

    return bookmark;
}

+ (NSString *)getBookmarkFromUrl:(NSURL *)url readOnly:(BOOL)readOnly error:(NSError *_Nonnull*)error {
    NSData* bookmark = [BookmarksHelper getBookmarkDataFromUrl:url readOnly:readOnly error:error];
    return [bookmark base64EncodedStringWithOptions:kNilOptions];
}

+ (NSURL *)getUrlFromBookmark:(NSString *)bookmarkInB64
                     readOnly:(BOOL)readOnly
              updatedBookmark:(NSString *_Nonnull*)updatedBookmark
                        error:(NSError *_Nonnull*)error {
    if(bookmarkInB64 == nil) {
        if(error) {
            *error = [Utils createNSError:@"Could not decode bookmark." errorCode:-1];
        }
        return nil;
    }

    NSData* bookmarkData = [[NSData alloc] initWithBase64EncodedString:bookmarkInB64
                                                               options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if(bookmarkData == nil) {
        if(error) {
            *error = [Utils createNSError:@"Could not decode bookmark." errorCode:-1];
        }
        return nil;
    }

    NSData* updated = nil;
    NSURL* ret = [BookmarksHelper getUrlFromBookmarkData:bookmarkData readOnly:readOnly updatedBookmark:&updated error:error];
    
    if(updated) {
        *updatedBookmark = [updated base64EncodedStringWithOptions:kNilOptions];
    }
    
    return ret;
}

+ (NSURL *)getUrlFromBookmarkData:(NSData *)bookmark updatedBookmark:(NSData * _Nonnull __autoreleasing *)updatedBookmark error:(NSError * _Nonnull __autoreleasing *)error {
    return [BookmarksHelper getUrlFromBookmarkData:bookmark readOnly:NO updatedBookmark:updatedBookmark error:error];
}

+ (NSURL *)getUrlFromBookmarkData:(NSData *)bookmark readOnly:(BOOL)readOnly updatedBookmark:(NSData * _Nonnull __autoreleasing *)updatedBookmark error:(NSError * _Nonnull __autoreleasing *)error {
    NSURLBookmarkResolutionOptions options = NSURLBookmarkResolutionWithoutUI; // MMcG: 8-May-2020 - Attempt to improve stale bookmark issues...
    #if !TARGET_OS_IPHONE
        options |= NSURLBookmarkResolutionWithSecurityScope;
    #endif

    BOOL bookmarkDataIsStale;
    NSURL* bookmarkFileURL = [NSURL URLByResolvingBookmarkData:bookmark
                                                       options:options
                                                 relativeToURL:nil
                                           bookmarkDataIsStale:&bookmarkDataIsStale
                                                         error:error];

    if(!bookmarkFileURL) {
        NSLog(@"Could not get bookmark URL.");
        return nil;
    }
    
    if(bookmarkDataIsStale) {
        if ([bookmarkFileURL startAccessingSecurityScopedResource]) {
            NSLog(@"Regenerating Bookmark -> bookmarkDataIsStale = %d => [%@]", bookmarkDataIsStale, bookmarkFileURL);
            
            NSData* fileIdentifier = [BookmarksHelper getBookmarkDataFromUrl:bookmarkFileURL readOnly:readOnly error:error];
            
            [bookmarkFileURL stopAccessingSecurityScopedResource];
            
            if(!fileIdentifier) {
                NSLog(@"Error regenerating: [%@]", *error);
                return nil;
            }

            *updatedBookmark = fileIdentifier;
            return bookmarkFileURL;
        }
        else {
            NSLog(@"Regen Bookmark security failed....");
            if(error) {
                *error = [Utils createNSError:@"Regen Bookmark security failed." errorCode:-1];
            }
            return nil;
        }
    }

    return bookmarkFileURL;
}

+ (NSData *)dataWithContentsOfBookmark:(NSString *)bookmarkInB64 error:(NSError**)error {
    NSString* updatedBookmark;
    
    NSURL* url = [BookmarksHelper getUrlFromBookmark:bookmarkInB64 readOnly:NO updatedBookmark:&updatedBookmark error:error];

    if(url && [url startAccessingSecurityScopedResource]) {
        //NSLog(@"Reading File at [%@]", url);
        NSData* ret = [NSData dataWithContentsOfURL:url options:kNilOptions error:error];
        
        [url stopAccessingSecurityScopedResource];
        
        return ret;
    }
    else {
        NSLog(@"Could not read file... [%@]", *error);
    }
    
    return nil;
}

@end
