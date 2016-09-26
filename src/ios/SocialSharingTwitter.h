//
//  SocialSharingTwitter.h
//  
//
//  Created by John Weaver on 09/26/2016.
//
//

#import <Cordova/CDVPlugin.h>

@interface DeleteFiles : CDVPlugin < UINavigationControllerDelegate, UIScrollViewDelegate>

@property (copy)   NSString* callbackId;

- (void)sendTweet:(CDVInvokedUrlCommand *)command;

@end
