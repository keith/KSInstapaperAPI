//
//  KSAppDelegate.h
//  KSInstapaperAPI Mac
//
//  Created by Keith Smiley on 12/20/12.
//  Copyright (c) 2012 Keith Smiley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface KSAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTextField *usernameField;
@property (weak) IBOutlet NSSecureTextField *passwordField;
@property (weak) IBOutlet NSTextField *urlField;
@property (weak) IBOutlet NSTextField *titleField;
@property (weak) IBOutlet NSTextField *selectionField;
@property (weak) IBOutlet NSProgressIndicator *authorizeProgress;
@property (weak) IBOutlet NSProgressIndicator *sendProgress;

- (IBAction)authorizeUsername:(id)sender;
- (IBAction)sendURL:(id)sender;

@end
