/*global cordova,window,console*/
/**
 * A Social Sharing for Twitter plugin for Cordova
 * 
 * Developed by John Weaver for Varsity Software
 */

var SocialSharingTwitter = function ()
{

};

SocialSharingTwitter.prototype.sendTweet = function (success, fail, options)
{
    if (!options) {
        options = {};
    }

    var params = {
        fileURL: options.fileURL ? options.fileURL : null,
        fileType: options.fileType ? options.fileType : null,
        fileName: options.fileName ? options.fileName : null,
        message: options.message ? options.message : null        
    };

    return cordova.exec(success, fail, "SocialSharingTwitter", "sendTweet", [params]);

};

window.socialSharingTwitter = new SocialSharingTwitter();
