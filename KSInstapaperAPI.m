//
//  KSInstapaperAPI.m
//  InstapaperAPI Mac Example
//
//  Created by Keith Smiley on 11/24/12.
//  Copyright (c) 2012 Keith Smiley. All rights reserved.
//

#import "KSInstapaperAPI.h"
#import "AFJSONRequestOperation.h"
#import "Reachability.h"
#import "SSKeychain.h"

/**
 The Domain for which the errors (except for those of SSKeychain) are under
 
 This can be compared when the error is returned with something like:
 `[[error domain] isEqualToString:kKSInstapaperErrorDomain]`
 **/
NSString * const KSInstapaperErrorDomain = @"com.keithsmiley.KSInstapaperAPI";


// The name for which the user's credentials are saved in SSKeychain
static NSString * const kKSInstapaperKeychainKey = @"Instapaper";

// The domain for Reachability's hostname monitor
static NSString * const kKSInstapaperReachabilityString = @"instapaper.com";

// The main API path and paths
static NSString * const kKSInstapaperAPIURLString = @"https://www.instapaper.com/api/";
static NSString * const kKSInstapaperAuthPath = @"authenticate";
static NSString * const kKSInstapaperAddPath = @"add";

// NSUserDefaults keys
static NSString * const kKSInstapaperQueueURLsPreference = @"KSInstapaperQueueURLs";
static NSString * const kKSInstapaperQueuedURLs = @"KSInstapaperQueuedURLs";


// Dictionary keys for queued URLs
static NSString * const kKSDictionaryURLKey = @"url";
static NSString * const kKSDictionaryTitleKey = @"title";
static NSString * const kKSDictionarySelectionKey = @"selection";

// Keys for Instapaper parameters
static NSString * const kKSInstapaperUsernameKey = @"username";
static NSString * const kKSInstapaperPasswordKey = @"password";
static NSString * const kKSInstapaperURLKey = @"url";
static NSString * const kKSInstapaperTitleKey = @"title";
static NSString * const kKSInstapaperSelectionKey = @"selection";


@interface KSInstapaperAPI()
// The array of NSDictionarys holding the queue URLs and their titles and selections
@property (nonatomic, strong) NSMutableArray *queuedURLs;

// The boolean for whether or not URLs should be queued
@property (nonatomic, strong) NSNumber *queueURLs;
@end

@implementation KSInstapaperAPI

+ (KSInstapaperAPI *)sharedClient
{
    static KSInstapaperAPI *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[self alloc] initWithBaseURL:[NSURL URLWithString:kKSInstapaperAPIURLString]];
    });
    
    return _sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url
{
    self = [super initWithBaseURL:url];
    if (!self) {
        return nil;
    }
    
    // Retrieve the previously stored queued URLs and remove them from the defaults
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kKSInstapaperQueuedURLs]) {
        self.queuedURLs = [NSMutableArray array];
        self.queuedURLs = [[[NSUserDefaults standardUserDefaults] arrayForKey:kKSInstapaperQueuedURLs] mutableCopy];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kKSInstapaperQueuedURLs];
    }
    
    // Retrieve whether or not to queue URLs. Ignore it if there are previously stored URLs
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kKSInstapaperQueueURLsPreference] && !self.queuedURLs) {
        self.queueURLs = [[NSUserDefaults standardUserDefaults] objectForKey:kKSInstapaperQueueURLsPreference];
    } else {
        self.queueURLs = @YES;
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kKSInstapaperQueueURLsPreference];
    }

    [[NSUserDefaults standardUserDefaults] synchronize];

    [self registerHTTPOperationClass:[AFHTTPRequestOperation class]];

    // If there were previously stored URLs attempt to send them again
    if (self.queuedURLs && self.queuedURLs.count > 0) {
        [self sendQueuedURLsToInstapaper];
    }

    return self;
}

- (void)dealloc
{
    // If there are queued URLs store the to the defaults 
    if (self.queuedURLs && self.queuedURLs.count > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:self.queuedURLs forKey:kKSInstapaperQueuedURLs];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)setQueueInstapaperURLs:(BOOL)queue
{
    // Set whether or not to queue URLs and immediately store it in the defaults
    self.queueURLs = [NSNumber numberWithBool:queue];
    [[NSUserDefaults standardUserDefaults] setObject:self.queueURLs forKey:kKSInstapaperQueueURLsPreference];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - User methods

- (void)authorizeUsername:(NSString *)username
              andPassword:(NSString *)password
          withReturnBlock:(void(^)(BOOL authorized, NSError *error))block
{
    // Trim the username and password of random whitespace
    username = [username stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    password = [password stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // If a username wasn't entered return a nicely formatted error, ready to be used in an NSAlert
    if (!username || [username length] < 1) {
        if (block) {
            block(NO, [self instapaperUsernameError]);
        }
        return;
    }
    
    // Prepare the parameters for the request
    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithCapacity:2];
    [params setValue:username forKey:kKSInstapaperUsernameKey];
    
    // If a password was entered (since it doesn't have to be) add it to the parameters
    if (password && [password length] > 0) {
        [params setValue:password forKey:kKSInstapaperPasswordKey];
    }
    
    // If Instapaper is unreachable
    if (![[Reachability reachabilityWithHostname:kKSInstapaperReachabilityString] isReachable]) {
        if (block) {
            block(NO, [self instapaperUnreachableError]);
        }
        return;
    }

    // Check the credentials with Instapaper
    [self getPath:kKSInstapaperAuthPath
       parameters:params
          success:^(AFHTTPRequestOperation *operation, id responseObject)
    {
        // Clear out the old credentials (multiple accounts just doesn't seem like a necessary feature)
        [self deleteStoredAccountWithError:nil];
        
        // Attempt to store the new credentials in the keychain
        NSError *storeError = nil;
        BOOL stored = [SSKeychain setPassword:password
                                   forService:kKSInstapaperKeychainKey
                                      account:username
                                        error:&storeError];

        if (stored) {
            if (block) {
                block(YES, nil);
            }
        } else {
            // Returns no just to be safe if the username and password could not be stored
            if (block) {
                NSLog(@"KSInstapaper Keychain Error: %@", [storeError localizedDescription]);
                block(NO, [self instapaperKeychainError]);
            }
        }
    }
          failure:^(AFHTTPRequestOperation *operation, NSError *error)
    {
        // Return the correct error depending on the status code, if no block is passed idk wtf you're doing.
        if (block) {
            switch (operation.response.statusCode) {
                case 401:
                case 403:
                    block(NO, [self instapaperCredentialsError]);
                    break;
                case 500:
                    block(NO, [self instapaperServiceError]);
                    break;
                default:
                    NSLog(@"KSInstapaper Unknown Error: %@", [error localizedDescription]);
                    block(NO, [self instapaperUnknownError]);
                    break;
            }
        }
    }];
}

- (void)sendInstapaperURL:(NSURL *)url
                    title:(NSString *)title
                selection:(NSString *)selection
          withReturnBlock:(void(^)(BOOL sent, NSError *error))block
{
    // Make sure a URL was passed
    if (![[url absoluteString] length] > 0) {
        if (block) {
            block(NO, [self instapaperNoURLError]);
        }
        return;
    }

    // Make sure there is a stored account
    if (![self hasStoredAccount]) {
        if (block) {
            block(NO, [self instapaperNoAccountError]);
        }
        return;
    }
    
    // Retrieve the user's Instapaper account
    NSError *keychainError = nil;
    NSArray *accounts = [SSKeychain accountsForService:kKSInstapaperKeychainKey
                                                 error:&keychainError];
    
    if (keychainError) {
        if (block) {
            block(NO, [self instapaperKeychainError]);
        }
        return;
    }
    
    // Set the username and password from the keychain
    NSString *username = [accounts[0] valueForKey:kSSKeychainAccountKey];
    NSString *password = [SSKeychain passwordForService:kKSInstapaperKeychainKey
                                                account:username
                                                  error:&keychainError];
    
    if (keychainError) {
        if (block) {
            block(NO, [self instapaperKeychainError]);
        }
        return;
    }
    
    // If Instapaper is unreachable make sure to queue the URL
    if (![[Reachability reachabilityWithHostname:kKSInstapaperReachabilityString] isReachable]) {
        if ([self.queueURLs boolValue])
        {
            [self queueURL:[self URLDictionaryToQueueWithURL:url
                                                       title:title
                                                   selection:selection]];

            Reachability *reach = [Reachability reachabilityWithHostname:kKSInstapaperReachabilityString];
            [reach setReachableBlock:^(Reachability *reach) {
                if (reach.isReachable) {
                    [self sendQueuedURLsToInstapaper];
                }
            }];
            
            [reach startNotifier];

            if (block) {
                block(NO, [self instapaperUnreachableButURLQueueError]);
            }
        } else {
            if (block) {
                block(NO, [self instapaperUnreachableError]);
            }
        }
        return;
    }
    
    // Prepare the parameters for the request
    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithCapacity:5];
    [params setValue:username forKey:kKSInstapaperUsernameKey];
    
    // If a password was entered (since it doesn't have to be) add it to the parameters
    if (password && [password length] > 0) {
        [params setValue:password forKey:kKSInstapaperPasswordKey];
    }
    
    // Set the applicable Instapaper parameters
    [params setValue:url forKey:kKSInstapaperURLKey];
    
    if (title && title.length > 0) {
        [params setValue:title forKey:kKSInstapaperTitleKey];
    }
    
    if (selection && selection.length > 0) {
        [params setValue:selection forKey:kKSInstapaperSelectionKey];
    }
    
    [self postPath:kKSInstapaperAddPath
        parameters:params
           success:^(AFHTTPRequestOperation *operation, id responseObject)
    {
        if (block) {
            block(YES, nil);
        }
    }
           failure:^(AFHTTPRequestOperation *operation, NSError *error)
    {
        [self queueURL:[self URLDictionaryToQueueWithURL:url title:title selection:selection]];

        if (block) {
            NSLog(@"Instapaper Unknown add error: %@", [error localizedDescription]);
            block(NO, [self instapaperUnknownError]);
        }
    }];
}

// Called when the network is back up and tries to send the queued URLs
- (void)sendQueuedURLsToInstapaper
{
    for (NSDictionary *URLDict in self.queuedURLs) {
        [self sendInstapaperURL:[URLDict valueForKey:kKSDictionaryURLKey]
                          title:[URLDict valueForKey:kKSDictionaryTitleKey]
                      selection:[URLDict valueForKey:kKSDictionarySelectionKey]
                withReturnBlock:^(BOOL sent, NSError *error)
        {
            if (sent) {
                [self.queuedURLs removeObject:URLDict];
            }
        }];
    }
    
    if (self.queuedURLs.count > 0) {
        Reachability *reach = [Reachability reachabilityWithHostname:kKSInstapaperReachabilityString];
        [reach setReachableBlock:^(Reachability *reach) {
            if (reach.isReachable) {
                [self sendQueuedURLsToInstapaper];
            }
        }];
        
        [reach startNotifier];
    } else {
        self.queuedURLs = nil;
    }
}

- (NSDictionary *)URLDictionaryToQueueWithURL:(NSURL *)url title:(NSString *)title selection:(NSString *)selection
{
    return @{kKSDictionaryURLKey : url, kKSDictionaryTitleKey : title, kKSDictionarySelectionKey : selection};
}

- (void)queueURL:(NSDictionary *)URLDict
{
    if (![self.queueURLs boolValue]) {
        return;
    }

    if (!self.queuedURLs) {
        self.queuedURLs = [NSMutableArray array];
    }
    
    if (![self.queuedURLs containsObject:URLDict]) {
        [self.queuedURLs addObject:URLDict];
    }
}

#pragma mark - Helper methods

- (BOOL)hasStoredAccount
{
    // Check the number of store accounts
    NSArray *accounts = [SSKeychain accountsForService:kKSInstapaperKeychainKey];
    if (accounts.count > 0)
    {
        // Make sure the account has a username
        if ([[[accounts objectAtIndex:0] valueForKey:kSSKeychainAccountKey] length] > 0) {
            return YES;
        } else {
            return NO;
        }
    } else {
        return NO;
    }
}

- (NSString *)getAccountUsernameWithError:(NSError **)error
{
    // Check to see if there is a stored account
    if ([self hasStoredAccount]) {
        // Retrieve the account and attempt to return it
        NSError *accountError = nil;
        NSString *accountUsername = [[[SSKeychain accountsForService:kKSInstapaperKeychainKey
                                                               error:&accountError] objectAtIndex:0]
                                                         valueForKey:kSSKeychainAccountKey];

        if (accountError) {
            NSLog(@"KSInstapaper Get Username Keychain Error: %@", [accountError localizedDescription]);
            if (error) {
                *error = [self instapaperKeychainError];
            }
        }
        
        return accountUsername;
    }

    if (error) {
        *error = [self instapaperNoAccountError];
    }

    return nil;
}

- (BOOL)deleteStoredAccountWithError:(NSError **)error
{
    // If there is a store account, attempt to delete it
    if ([self hasStoredAccount])
    {
        NSString *accountUsername = [[SSKeychain accountsForService:kKSInstapaperKeychainKey][0]
                                                        valueForKey:kSSKeychainAccountKey];
        
        NSError *deletionError = nil;
        BOOL deleted = [SSKeychain deletePasswordForService:kKSInstapaperKeychainKey
                                                    account:accountUsername
                                                      error:&deletionError];

        if (!deleted) {
            NSLog(@"KSInstapaper Keychain Deletion Error: %@", [deletionError localizedDescription]);
            if (error) {
                *error = [self instapaperKeychainError];
            }
        }
        return deleted;
    }
    
    // If there wasn't a stored account then everything is kosher
    return YES;
}


#pragma mark - Custom NSErrors

// To localize these errors add these strings to your Localizable.strings file and get them translated
// If you do this I'd love to give these translations back to the community (I may do this myself in the future)

#pragma mark User Errors

// The error returned when no username is passed to the authorize method
- (NSError *)instapaperUsernameError
{
    return [NSError errorWithDomain:KSInstapaperErrorDomain
                               code:KSInstapaperNoUsername
                           userInfo:@{
         NSLocalizedDescriptionKey : NSLocalizedString(@"Instapaper Error", @"Error title"),
NSLocalizedRecoverySuggestionErrorKey : NSLocalizedString(@"You must enter a username.", @"Error prompt to enter valid username")}];
}

// The error returned when the entered Instapaper credentials are incorrect
- (NSError *)instapaperCredentialsError
{
    return [NSError errorWithDomain:KSInstapaperErrorDomain
                               code:KSInstapaperInvalidCredentials
                           userInfo:@{
         NSLocalizedDescriptionKey : NSLocalizedString(@"Instapaper Error", @"Error title"),
NSLocalizedRecoverySuggestionErrorKey : NSLocalizedString(@"Invalid Instapaper username or password.", @"Service credentials are invalid")}];
}

// The error returned when no URL is sent to `sendInstapaperURL:`
- (NSError *)instapaperNoURLError
{
    return [NSError errorWithDomain:KSInstapaperErrorDomain
                               code:KSInstapaperNoURLError
                           userInfo:@{
         NSLocalizedDescriptionKey : NSLocalizedString(@"Instapaper Error", @"Error title"),
NSLocalizedRecoverySuggestionErrorKey : NSLocalizedString(@"No URL to send to Instapaper", @"User didn't provide URL")}];
}

#pragma mark Network Errors

// The error returned when Instapaper is unreachable for some reason
- (NSError *)instapaperUnreachableError
{
    return [NSError errorWithDomain:KSInstapaperErrorDomain
                               code:KSInstapaperUnreachable userInfo:@{
         NSLocalizedDescriptionKey : NSLocalizedString(@"Instapaper Error", @"Error title"),
NSLocalizedRecoverySuggestionErrorKey : NSLocalizedString(@"Cannot access Instapaper, please try again later.", @"Service is currently unreachable.")}];
}

// The error returned when Instapaper is unreachable for some reason but the URL is queued
- (NSError *)instapaperUnreachableButURLQueueError
{
    return [NSError errorWithDomain:KSInstapaperErrorDomain
                               code:KSInstapaperUnreachableURLQueued
                           userInfo:@{
         NSLocalizedDescriptionKey : NSLocalizedString(@"Instapaper Error", @"Error title"),
NSLocalizedRecoverySuggestionErrorKey : NSLocalizedString(@"Cannot access Instapaper, the URL was queued to be added to Instapaper the next time a connection can be made.", @"Service is unreachable URL is queued for later use.")}];
}

// The error returned when Instapaper returns a service error
- (NSError *)instapaperServiceError
{
    return [NSError errorWithDomain:KSInstapaperErrorDomain
                               code:KSInstapaperServiceIssues
                           userInfo:@{
         NSLocalizedDescriptionKey : NSLocalizedString(@"Instapaper Error", @"Error title"),
NSLocalizedRecoverySuggestionErrorKey : NSLocalizedString(@"Instapaper appears to be experiencing issues, please try again later.", @"Service issues")}];
}

#pragma mark Custom Keychain Errors

// The error returned when SSKeychain fails to store the user's credentials
- (NSError *)instapaperKeychainError
{
    return [NSError errorWithDomain:KSInstapaperErrorDomain
                               code:KSInstapaperKeychainError
                           userInfo:@{
         NSLocalizedDescriptionKey : NSLocalizedString(@"Instapaper Error", @"Error title"),
NSLocalizedRecoverySuggestionErrorKey : NSLocalizedString(@"Failed to access your keychain.", @"Keychain errors")}];
}

#pragma mark Other Errors

// The error returned when there is no stored account yet it is accessed
- (NSError *)instapaperNoAccountError
{
    return [NSError errorWithDomain:KSInstapaperErrorDomain
                               code:KSInstapaperNoStoredAccount
                           userInfo:@{
         NSLocalizedDescriptionKey : NSLocalizedString(@"Instapaper Error", @"Error title"),
NSLocalizedRecoverySuggestionErrorKey : NSLocalizedString(@"There is no stored Instapaper account.", @"No account error")}];
}

// The error returned when the error is unknown, to make sure NSAlerts will always be pretty, meanwhile the returned error is logged.
- (NSError *)instapaperUnknownError
{
    return [NSError errorWithDomain:KSInstapaperErrorDomain
                               code:KSInstapaperUnknownError
                           userInfo:@{
         NSLocalizedDescriptionKey : NSLocalizedString(@"Instapaper Error", @"Error title"),
NSLocalizedRecoverySuggestionErrorKey : NSLocalizedString(@"An unknown error occurred, please try again.", @"Unknown error")}];
}

@end
