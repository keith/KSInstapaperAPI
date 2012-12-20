//
//  KSViewController.m
//  KSInstapaperAPI iOS
//
//  Created by Keith Smiley on 12/20/12.
//  Copyright (c) 2012 Keith Smiley. All rights reserved.
//

#import "KSViewController.h"
#import "KSInstapaperAPI.h"

@interface KSViewController ()

@end

@implementation KSViewController

- (IBAction)authorize:(id)sender
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Instapaper Login"
                                                    message:@"Enter your Instapaper Credentials"
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"OK", nil];
    
    [alert setAlertViewStyle:UIAlertViewStyleLoginAndPasswordInput];
    [alert show];
}

- (IBAction)sendURL:(id)sender
{
    [self resignFirstResponder];

    NSURL *url = [NSURL URLWithString:self.urlField.text];
    NSString *title = self.titleField.text;
    NSString *selection = self.selectionField.text;
    
    [[KSInstapaperAPI sharedClient] sendInstapaperURL:url
                                                title:title
                                            selection:selection
                                      withReturnBlock:^(BOOL sent, NSError *error)
    {
        if (sent) {
            NSLog(@"Success!");
        } else {
            NSLog(@"Failed to send URL %@", [error description]);
        }
    }];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1) {
        NSString *username = [[alertView textFieldAtIndex:0] text];
        NSString *password = [[alertView textFieldAtIndex:1] text];
        
        [[KSInstapaperAPI sharedClient] authorizeUsername:username
                                              andPassword:password
                                          withReturnBlock:^(BOOL authorized, NSError *error)
        {
            if (authorized) {
                NSLog(@"Authorized");
            } else {
                NSLog(@"Failed to authorize: %@", [error description]);
                
                if (error.code == KSInstapaperInvalidCredentials) {
                    NSLog(@"Invalid credentials");
                }
            }
        }];
    }
}

#pragma mark - UIViewController Jazz

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
