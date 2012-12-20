//
//  KSInstapaperAPI.h
//  InstapaperAPI Mac Example
//
//  Created by Keith Smiley on 11/24/12.
//  Copyright (c) 2012 Keith Smiley. All rights reserved.
//

#import "AFHTTPClient.h"

NS_ENUM(NSInteger, KSInstapaperErrorCode) {
    /*
        Returned when authorizeUsername:andPassword:withReturnBlock
            is called with a blank Username
    */
    KSInstapaperNoUsername,
    
    /*
        Returned in two cases
            1. Instapaper is unreachable, regardless of why, when you try to authorize user credentials
            2. Instapaper is unreachable AND URLs are NOT set to be queued with setQueueInstapaperURLs
     */
    KSInstapaperUnreachable,
    
    /*
        Returned when Instapaper is unreachable upon trying to send a URL
            BUT that URL was queued to be sent to Instapaper as soon as it's reachable
     */
    KSInstapaperUnreachableURLQueued,
    
    /*
        Returned when authorizing a user and the input is invalid
        Or returned when sending a URL to invalid saved credentials
            This would only happen if the user changed their Instapaper credentials
                Since they authorized them through the application
     */
    KSInstapaperInvalidCredentials,
    
    /*
        Returned when Instapaper returns a 500 service error
     */
    KSInstapaperServiceIssues,
    
    /*
        Returned when there are issues adding to or querying the keychain
     */
    KSInstapaperKeychainError,
    
    /*
        Returned when a URL is sent when there is no stored account
        Or returned when getAccountUsernameWithError: is called with no stored account
     */
    KSInstapaperNoStoredAccount,
    
    /*
        Returned when a blank URL sent to Instapaper
     */
    KSInstapaperNoURLError,
    
    /*
        Returned when Instapaper returns a 400 exceeded rate limit error
     */
    KSInstapaperRateLimitError,
    
    /*
        Returned when no status codes are matched but the request failed. Also logs the 'real error'
     */
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
- (void)queueInstapaperURLs:(BOOL)queue;

/*
    This method can be called when you want to forceable reattempt to send the URLs to Instapaper
        EX: When the application is relaunched you can call it to send all queued URLs to Instapaper
 
    Use this when KSInstapaperAPI hasn't been called yet so the Reachability notifiers have not been started
 */
- (void)sendQueuedURLsToInstapaper;

@end
