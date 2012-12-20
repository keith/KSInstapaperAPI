# KSInstapaperAPI

This is an Instapaper API client that allows queuing of URLs to be saved later in the event that the user's connection lets them down. KSInstapaper handles the networking using [AFNetworking](http://afnetworking.com/), the user's password storage using [SSKeychain](https://github.com/soffes/sskeychain) and the networking reachability using Tony Million's [Reachability](https://github.com/tonymillion/Reachability)

## Usage

There are Mac and iOS example projects included in this repo but just to show you how simple it is.

To authorize and store a user simply call:

	[[KSInstapaperAPI sharedClient] authorizeUsername:username
	                                      andPassword:password
	                                  withReturnBlock:^(BOOL authorized, NSError *error)
	{
	    if (authorized) {
	        // Do stuff
	    } else {
	        // Do failed stuff

	        if (error.code == KSInstapaperInvalidCredentials) {
	            // User entered invalid credentails
	        }
	    }
	}];

To save a URL with the newly stored credentials:

	[[KSInstapaperAPI sharedClient] sendInstapaperURL:url
	                                                title:title
	                                            selection:selection
	                                      withReturnBlock:^(BOOL sent, NSError *error)
	{
	    if (sent) {
	        // Sent successfully
	    } else {
	        if (error.code == KSInstapaperUnreachableURLQueued) {
	            // Queued URL 
	        }
	    }
	}];


Also I recommend you add `[[KSInstapaperAPI sharedClient] sendQueuedURLsToInstapaper];` to some early point within your application. This way `KSInstapaperAPI` is allocated and if there are left over URLs that were queued during the user's last session within your application they will be immediately sent (assuming good network connetivity). You can also call it at any time to forceable send queued URLs. Although assuming everything works correctly that should never be necessary.

If for some reason you don't want to queue URLs when they cannot be added simple call `[[KSInstapaperAPI sharedClient] queueInstapaperURLs:false]`. Note that this may be overridden if you already have queued URLs. But assuming you call it before doing any sends it won't be an issue.

There are also some handly helper methods like:

	- (BOOL)hasStoredAccount;
	- (NSString *)getAccountUsernameWithError:(NSError **)error;
	- (BOOL)deleteStoredAccountWithError:(NSError **)error;

Also everything in `KSInstapaperAPI.h` is documented thouroughly.


### Installation

As mentioned before `KSInstapaperAPI` relies on `AFNetworking`, `SSKeychain` and `Reachability` you could add all these frameworks seperately but I suggest you use [CocoaPods](http://cocoapods.org/)

Simply add:

	pod 'KSInstapaperAPI', '~> 0.1.0'

To your Podfile to install it and all it's dependiencies. Then just `#import "KSInstapaperAPI.h"` and you're good to go.


### Support/Development

Please submit any issues you find through Github and I will look at them immediately. Also if you feel like improving up `KSInstapaperAPI` that would be awesome and I'll gladly accept pull requests.
