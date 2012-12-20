//
//  KSInstapaperAPI.h
//  InstapaperAPI Mac Example
//
//  Created by Keith Smiley on 11/24/12.
//  Copyright (c) 2012 Keith Smiley. All rights reserved.
//

#import "AFHTTPClient.h"

NS_ENUM(NSInteger, KSInstapaperErrorCode) {
    KSInstapaperNoUsername,
    KSInstapaperUnreachable,
    KSInstapaperUnreachableURLQueued,
    KSInstapaperInvalidCredentials,
    KSInstapaperServiceIssues,
    KSInstapaperKeychainError,
    KSInstapaperNoStoredAccount,
    KSInstapaperNoURLError,
    KSInstapaperUnknownError
};

extern NSString * const KSInstapaperErrorDomain;

@interface KSInstapaperAPI : AFHTTPClient


// The shared API client that is called whenever a method needs to be called
+ (KSInstapaperAPI *)sharedClient;

/*
    Called to verify that the user's credentials are valid.

    Parameters:
        The Username is required
        Since Instapaper doesn't require user's to have Passwords it is not required, just pass nil or an empty string
    
    This function returns (in the form of a block) if the username was authorized or not
        Will return YES with the user's credentials are valid
        Otherwise it will return NO and an error
*/
- (void)authorizeUsername:(NSString *)username
              andPassword:(NSString *)password
          withReturnBlock:(void(^)(BOOL authorized, NSError *error))block;


/*
    Called to send a URL to Instapaper
        an account must be stored first by calling authorizeUsername:andPassword:withReturnBlock

    Parameters:
        URL is required otherwise a KSInstapaperNoURLError will be returned
        Title is optional for the title displayed for the Instapaper entry
        Selection is optional subtext for the Instapaper entry
            EX: The Tweet text associated with a saved link
*/
- (void)sendInstapaperURL:(NSURL *)url
                    title:(NSString *)title
                selection:(NSString *)selection
          withReturnBlock:(void(^)(BOOL sent, NSError *error))block;


/*
    This helper method returns YES if there is a stored Instapaper account otherwise NO
*/
- (BOOL)hasStoredAccount;


/*
    This method returns the username of the stored account, it verifies that there is one first
        If there is not a stored account it will return nil an a KSInstapaperNoStoredAccount
        It could also return a KSInstapaperKeychainError if there was an error retrieving the account

    While recommended, the error parameter is optional
*/
- (NSString *)getAccountUsernameWithError:(NSError **)error;

/*
    This method deletes the current stored account
        It returns YES if the account was deleted NO otherwise
            It would only return no if there was a KSInstapaperKeychainError and it couldn't be deleted
        It returns YES if there was no stored account

    While recommended, the error parameter is optional
*/
- (BOOL)deleteStoredAccountWithError:(NSError **)error;


/*
    This method is for setting whether or not you would like to Queue URLs when they were not successfully saved
        Saving may fail because of the current internet connection or because of an Instapaper service outage
        The application then montiors the connection to Instapapaer and when it's established next it attempts to save them

    If Instapaper connectivity doesn't come back before the application is exited the URLs are stored in NSUserDefaults
        Then the next time the application is launched the stored URLs are taken from NSUserDefaults and it attempts to save them
*/
- (void)setQueueInstapaperURLs:(BOOL)queue;

@end
