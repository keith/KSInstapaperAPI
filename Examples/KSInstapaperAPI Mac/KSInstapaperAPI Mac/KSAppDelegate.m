//
//  KSAppDelegate.m
//  KSInstapaperAPI Mac
//
//  Created by Keith Smiley on 12/20/12.
//  Copyright (c) 2012 Keith Smiley. All rights reserved.
//

#import "KSAppDelegate.h"
#import "KSInstapaperAPI.h"

@implementation KSAppDelegate

#pragma mark - IBActions

- (IBAction)authorizeUsername:(id)sender
{
    [self.authorizeProgress startAnimation:self];
    
    NSString *username = self.usernameField.stringValue;
    NSString *password = self.passwordField.stringValue;

    [[KSInstapaperAPI sharedClient] authorizeUsername:username
                                          andPassword:password
                                      withReturnBlock:^(BOOL authorized, NSError *error)
    {
        [self.authorizeProgress stopAnimation:self];

        if (authorized) {
            NSLog(@"Authorized Username");
        } else {
            NSLog(@"Failed to authorize username: %@", error);
            
            if (error.code == KSInstapaperInvalidCredentials) {
                NSLog(@"Invalid credentials");
            }

            [[NSAlert alertWithError:error] runModal];
        }
    }];
}

- (IBAction)sendURL:(id)sender
{
    NSURL *url = [NSURL URLWithString:self.urlField.stringValue];
    NSString *title = self.titleField.stringValue;
    NSString *selection = self.selectionField.stringValue;
    
    [self.sendProgress startAnimation:self];
    
    [[KSInstapaperAPI sharedClient] sendInstapaperURL:url
                                                title:title
                                            selection:selection
                                      withReturnBlock:^(BOOL sent, NSError *error)
    {
        [self.sendProgress stopAnimation:self];
        
        if (sent) {
            NSLog(@"Sent URL successfully");
        } else {
            NSLog(@"Failed to save URL: %@", error);
            [[NSAlert alertWithError:error] runModal];
        }
    }];
}

#pragma mark - NSApplicationDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return true;
}


@end
