//
//  SocialSharingTwitter.m
//
//  Created by John Weaver on 09/26/2016
//
//

#import "SocialSharingTwitter.h"
#import <Accounts/Accounts.h>

@implementation SocialSharingTwitter 

@synthesize callbackId;

- (void) sendTweet:(CDVInvokedUrlCommand *)command {
    
    NSDictionary *options = [command.arguments objectAtIndex: 0];
  
	NSString * strFileURL = [options objectForKey:@"fileURL"];
	NSString * strFileType = [options objectForKey:@"fileType"];
	NSString * strFileName = [options objectForKey:@"fileName"];
    NSString * strMessage = [options objectForKey:@"message"];

    if (strMessage == (id)[NSNull null]) {
      strMessage = nil;
    }

    self.callbackId = command.callbackId;

	[self uploadImageToTwitter:strMessage fileURL:strFileURL fileType:strFileType];
    
}

- (void)uploadImageToTwitter:(NSString *)strMessage fileURL:(NSString *)strFileURL fileType:(NSString *)strFileType fileName:(NSString *)strFileName
{        
		// http://xcodenoobies.blogspot.my/2016/01/how-to-using-slrequest-to-upload-image.html
        ACAccountStore *account = [[ACAccountStore alloc] init];
        ACAccountType *accountType = [account accountTypeWithAccountTypeIdentifier: ACAccountTypeIdentifierTwitter];
        
        [account requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error)
        {
            if (granted == YES)
            {
                NSArray *arrayOfAccounts = [account accountsWithAccountType:accountType];
                
                if ([arrayOfAccounts count] > 0)
                {
                    ACAccount *twitterAccount =
                    [arrayOfAccounts lastObject];                    
                    
                    //NSURL *furl = [NSURL fileURLWithPath:NSTemporaryDirectory()];
                    //NSURL *fileURL = [furl URLByAppendingPathComponent:@"http://i.giphy.com/l0MYsHqH9Ah8GT5Is.gif"];
					//NSURL *url = [NSURL URLWithString:@"http://i.giphy.com/l0MYsHqH9Ah8GT5Is.gif"];

					NSURL *url = [NSURL URLWithString:strFileURL];
                    NSData *imageData = [NSData dataWithContentsOfURL:url];
                   
                    NSURL *requestURL = [NSURL URLWithString:@"https://upload.twitter.com/1.1/media/upload.json"];
                    
                    SLRequest *postRequest = [SLRequest  requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:requestURL parameters:nil];
                    
                    postRequest.account = twitterAccount;
                    
                    [postRequest addMultipartData:imageData withName:@"media" type:strFileType filename: strFileName];
                    
                    [postRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error)
                    {
					     NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
                         
                         NSString *mediaID = [json objectForKey:@"media_id_string"];                        
                         
                         if (mediaID!=nil) 
						 {   
                         
                            NSURL *requestURL2 = [NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/update.json"];
							NSDictionary *message2 = @{@"status": strMessage, @"media_ids": mediaID };
                         
							SLRequest *postRequest2 = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:requestURL2 parameters:message2];
							postRequest2.account = twitterAccount;
                         
							[postRequest2 performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error)
							{
								 // DONE!!!
								 CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
								[self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
	
		                      }];
                             
                         }
                         
                     }];
                }
            }
         }];
	}

@end
