//
//  KSViewController.h
//  KSInstapaperAPI iOS
//
//  Created by Keith Smiley on 12/20/12.
//  Copyright (c) 2012 Keith Smiley. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface KSViewController : UIViewController <UIAlertViewDelegate>

@property (weak, nonatomic) IBOutlet UITextField *selectionField;
@property (weak, nonatomic) IBOutlet UITextField *titleField;
@property (weak, nonatomic) IBOutlet UITextField *urlField;

- (IBAction)authorize:(id)sender;
- (IBAction)sendURL:(id)sender;

@end
