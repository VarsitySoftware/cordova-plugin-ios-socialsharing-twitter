//
//  SocialSharingTwitter.m
//
//  Created by John Weaver on 09/26/2016
//  inspired by
//  https://raw.githubusercontent.com/liu044100/SocialVideoHelper/master/SocialVideoHelper.m
//

#import "SocialSharingTwitter.h"
#import <Accounts/Accounts.h>
#import <Social/Social.h>



@implementation SocialSharingTwitter 

#define DispatchMainThread(block, ...) if(block) dispatch_async(dispatch_get_main_queue(), ^{ block(__VA_ARGS__); })
#define Video_Chunk_Max_size 1000 * 1000 * 5

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

	[self uploadImageToTwitter:strMessage fileURL:strFileURL fileType:strFileType fileName: strFileName];
    
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
                    ACAccount *twitterAccount = [arrayOfAccounts lastObject];            
					
					NSData *mediaData = nil;

					if ([strFileURL hasPrefix:@"http"]) 
					{
						NSURL *url = [NSURL URLWithString:strFileURL];
						mediaData = [NSData dataWithContentsOfURL:url];         
					}
					else
					{
						NSFileManager* fileManager = [NSFileManager defaultManager];
						mediaData = [fileManager contentsAtPath:strFileURL];
					}					          

					NSArray *componentsArray = [strFileName componentsSeparatedByString:@"."];
					NSString *fileExtension = [componentsArray lastObject];

					if ([fileExtension isEqualToString: @"mov"] || [fileExtension isEqualToString: @"mp4"]) 
					{
						NSURL *requestURL = [NSURL URLWithString:@"https://upload.twitter.com/1.1/media/upload.json"];
                    
						NSDictionary *postParams = @{@"command": @"INIT",
                                @"total_bytes" : [NSNumber numberWithInteger: mediaData.length].stringValue,
                                @"media_type" : strFileType
                                };
    
						SLRequest *postRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:requestURL parameters:postParams];
						postRequest.account = twitterAccount;
						[postRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
							NSLog(@"Twitter Stage1 HTTP Response: %li, responseData: %@", (long)[urlResponse statusCode], [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
							if (error) {
								NSLog(@"Twitter Error stage 1 - %@", error);
								//[SocialVideoHelper uploadError:error withCompletion:completion];
							} else {
								NSMutableDictionary *returnedData = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&error];
            
								NSString *mediaID = [NSString stringWithFormat:@"%@", [returnedData valueForKey:@"media_id_string"]];
            
								[self tweetVideoStage2:mediaData mediaID:mediaID comment:strMessage account:twitterAccount];
            
								NSLog(@"stage one success, mediaID -> %@", mediaID);
							}
						}];
					}
					else
					{
						//NSURL *furl = [NSURL fileURLWithPath:NSTemporaryDirectory()];
						//NSURL *fileURL = [furl URLByAppendingPathComponent:@"http://i.giphy.com/l0MYsHqH9Ah8GT5Is.gif"];
						//NSURL *url = [NSURL URLWithString:@"http://i.giphy.com/l0MYsHqH9Ah8GT5Is.gif"];

						
						NSURL *requestURL = [NSURL URLWithString:@"https://upload.twitter.com/1.1/media/upload.json"];
                    
						SLRequest *postRequest = [SLRequest  requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:requestURL parameters:nil];
                    
						postRequest.account = twitterAccount;
                    
						[postRequest addMultipartData:mediaData withName:@"media" type:strFileType filename: strFileName];
                    
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
								 
	
								  }];
                             
							 }
                         
						 }];
					}

					// DON'T WAIT TO SEND RESPONSE BACK - PREVENTS DELAY IN WAITING FOR TWITTER TO COMPLETE
					CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
					[self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
                }
            }
         }];
	}

	-(void)tweetVideoStage2:(NSData*)videoData mediaID:(NSString *)mediaID comment:(NSString*)comment account:(ACAccount*)account{
    
    NSURL *twitterPostURL = [[NSURL alloc] initWithString:@"https://upload.twitter.com/1.1/media/upload.json"];
    
    NSArray *chunks = [self separateToMultipartData:videoData];
    NSMutableArray *requests = [NSMutableArray array];
    
    for (int i = 0; i < chunks.count; i++) {
        NSString *seg_index = [NSString stringWithFormat:@"%d",i];
        NSDictionary *postParams = @{@"command": @"APPEND",
                                     @"media_id" : mediaID,
                                     @"segment_index" : seg_index,
                                     };
        SLRequest *postRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:twitterPostURL parameters:postParams];
        postRequest.account = account;
        [postRequest addMultipartData:chunks[i] withName:@"media" type:@"video/mp4" filename:@"video"];
        [requests addObject:postRequest];
    }

    __block NSError *theError = nil;
    dispatch_queue_t chunksRequestQueue = dispatch_queue_create("chunksRequestQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(chunksRequestQueue, ^{
        dispatch_group_t requestGroup = dispatch_group_create();
        for (int i = 0; i < (requests.count - 1); i++) {
            dispatch_group_enter(requestGroup);
            SLRequest *postRequest = requests[i];
            [postRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                NSLog(@"Twitter Stage2 - %d HTTP Response: %li, %@", (i+1),(long)[urlResponse statusCode], [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
                if (error) {
                    NSLog(@"Twitter Error stage 2 - %d, error - %@", (i+1), error);
                    theError = error;
                } else {
                    if (i == requests.count - 1) {
                         [self tweetVideoStage3:videoData mediaID:mediaID comment:comment account:account];
                    }
                }
                dispatch_group_leave(requestGroup);
            }];
            dispatch_group_wait(requestGroup, DISPATCH_TIME_FOREVER);
        }
        
        if (theError) {
            //[SocialVideoHelper uploadError:theError withCompletion:completion];
        } else {
            SLRequest *postRequest = requests.lastObject;
            [postRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
                NSLog(@"Twitter Stage2 - final, HTTP Response: %li, %@",(long)[urlResponse statusCode], [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
                if (error) {
                    NSLog(@"Twitter Error stage 2 - final, error - %@", error);
                } else {
                    [self tweetVideoStage3:videoData mediaID:mediaID comment:comment account:account];
                }
            }];
        }
    });
}

-(void)tweetVideoStage3:(NSData*)videoData mediaID:(NSString *)mediaID comment:(NSString*)comment account:(ACAccount*)account {
   
    NSURL *twitterPostURL = [[NSURL alloc] initWithString:@"https://upload.twitter.com/1.1/media/upload.json"];
    
    NSDictionary *postParams = @{@"command": @"FINALIZE",
                               @"media_id" : mediaID };
    
    SLRequest *postRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:twitterPostURL parameters:postParams];
    
    // Set the account and begin the request.
    postRequest.account = account;
    [postRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        NSLog(@"Twitter Stage3 HTTP Response: %li, %@", (long)[urlResponse statusCode], [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
        if (error) {
            NSLog(@"Twitter Error stage 3 - %@", error);
            //[SocialVideoHelper uploadError:error withCompletion:completion];
        } else {
            [self tweetVideoStage4:videoData mediaID:mediaID comment:comment account:account];
        }
    }];
}

-(void)tweetVideoStage4:(NSData*)videoData mediaID:(NSString *)mediaID comment:(NSString*)comment account:(ACAccount*)account {
    NSURL *twitterPostURL = [[NSURL alloc] initWithString:@"https://api.twitter.com/1.1/statuses/update.json"];
    
    if (comment == nil) {
        //comment = [NSString stringWithFormat:@"#SocialVideoHelper# https://github.com/liu044100/SocialVideoHelper"];
		comment = @"";
    }
    
    // Set the parameters for the third twitter video request.
    NSDictionary *postParams = @{@"status": comment,
                               @"media_ids" : @[mediaID]};
    
    SLRequest *postRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodPOST URL:twitterPostURL parameters:postParams];
    postRequest.account = account;
    [postRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        NSLog(@"Twitter Stage4 HTTP Response: %li", (long)[urlResponse statusCode]);
        if (error) {
            NSLog(@"Twitter Error stage 4 - %@", error);
            //[SocialVideoHelper uploadError:error withCompletion:completion];
        } else {
            if ([urlResponse statusCode] == 200){
                NSLog(@"Twitter upload success !");
                //[SocialVideoHelper uploadSuccessWithCompletion:completion];
            }
        }
    }];
}

-(NSArray*)separateToMultipartData:(NSData*)videoData{
    NSMutableArray *multipartData = [NSMutableArray new];
    CGFloat length = videoData.length;
    CGFloat standard_length = Video_Chunk_Max_size;
    if (length <= standard_length) {
        [multipartData addObject:videoData];
        NSLog(@"need not separate as chunk, data size -> %ld bytes", (long)videoData.length);
    } else {
        NSUInteger count = ceil(length/standard_length);
        for (int i = 0; i < count; i++) {
            NSRange range;
            if (i == count - 1) {
                range = NSMakeRange(i * standard_length, length - i * standard_length);
            } else {
                range = NSMakeRange(i * standard_length, standard_length);
            }
            NSData *part_data = [videoData subdataWithRange:range];
            [multipartData addObject:part_data];
            NSLog(@"chunk index -> %d, data size -> %ld bytes", (i+1), (long)part_data.length);
        }
    }
    return multipartData.copy;
}

@end
