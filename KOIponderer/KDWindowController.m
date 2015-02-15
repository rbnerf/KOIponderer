//
//  KDWindowController.m
//  adapted from KeplerDownloader
//
//  Created by Richard Nerf on 8/27/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import "KDWindowController.h"
#import "WebKit/WebKit.h"
#import "FITSFile.h"
#import "KIStarsController.h"
#import "KINotifications.h"

@implementation KDWindowController

- (id)init
{
	self = [self initWithWindowNibName:@"Downloader"];	
	if (self) {
		self.rootURLString = @"http://archive.stsci.edu/pub/kepler/lightcurves/";
		self.validDataURLP = [NSNumber numberWithBool:NO];
		[_dataDownloadProgress setHidden:YES];
		[_webViewProgress setUsesThreadedAnimation:YES];
		[_webViewProgress setHidden:NO];
		[_webViewProgress startAnimation:nil];
		[[_webView mainFrame] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:_rootURLString]]];
		[_webViewProgress stopAnimation:nil];
	}
	return self;
}
- (void) downloadDataFromURL: (NSURL *) url {
	NSOperationQueue *opQueue = [NSOperationQueue mainQueue];
	NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
	NSURLSession *theSession = [NSURLSession
								sessionWithConfiguration: sessionConfig
								delegate: nil
								delegateQueue: opQueue];
	NSURLSessionDataTask *dataTask =[theSession dataTaskWithURL: url
			   completionHandler:^(NSData *data, NSURLResponse *response,
								   NSError *error) {
				   //NSLog(@"Got response %@ with error %@.\n", response, error);
				   //NSLog(@"DATA:%lu from %@",
						 //(unsigned long)data.length,url.lastPathComponent);
				   [self.urlDataDict setValue:data forKey:url.absoluteString];
				   //NSLog(@"GOT:%lu",self.urlDataDict.count);
				   [_dataDownloadProgress incrementBy:1];
				   if (_dataDownloadProgress.doubleValue>=_dataDownloadProgress.maxValue) {
					   [_dataDownloadProgress setHidden:YES];
					   [self.delegate processFITSDataDict:_urlDataDict];
					   [[NSNotificationCenter defaultCenter]
						postNotificationName:KILongCadencesDidFinishDownloading object:self];
					   [self.window close];
				   }
			   }];
	[dataTask resume];
}
- (IBAction) searchForKeplerID:(NSSearchField *)sender{
	NSString *keplerID = sender.stringValue;
	NSURL *url = [self URLForKeplerIDString:keplerID];
	[_webViewProgress setHidden:NO];
	[_webViewProgress startAnimation:nil];
	[[_webView mainFrame] loadRequest:[NSURLRequest requestWithURL:url]];
	[_webViewProgress stopAnimation:nil];
	//NSLog(@"SEARCH");
}
- (IBAction) doDownload:(id)sender {
	NSString *urlString = [_webView mainFrameURL];
	NSURL *url = [NSURL URLWithString:urlString];
	NSError *error = nil;
	if(1) {
		NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:url options:NSXMLDocumentTidyHTML error:&error ];
		NSString *downDir = [NSHomeDirectory() stringByAppendingPathComponent:  @"Downloads"];
		NSString *kepID = [NSString stringWithFormat:@"Kepler%@",url.lastPathComponent];
		//NSLog(@"%@",kepID);
		downDir = [downDir stringByAppendingPathComponent:kepID];
		error=nil;
		//BOOL madDirP =
		[[NSFileManager defaultManager] createDirectoryAtPath:downDir withIntermediateDirectories:YES attributes:nil error:&error];
		if (error) {
			[[NSAlert alertWithError:error] runModal];
			return;
		}
		NSMutableArray *urls = [NSMutableArray array];
		NSXMLNode *aNode = [doc rootElement];
		while ((aNode = aNode.nextNode)) {
			if([aNode.name isEqualToString:@"a"]) {
				NSString *fileName = aNode.stringValue; //KLUDGE?
				if ([fileName hasSuffix:@"_llc.fits"]) {
					NSURL *dataURL = [url URLByAppendingPathComponent:fileName];
					[urls addObject:dataURL];
				}
			}
		}
		_dataDownloadProgress.maxValue = urls.count;
		_dataDownloadProgress.doubleValue = 0;
		[_dataDownloadProgress setHidden:NO];
		self.urlDataDict = [NSMutableDictionary dictionary];
		for (NSURL *dataURL in urls) {
			[self downloadDataFromURL:dataURL];
		}
		//NSLog(@"Data requested:%lu",urls.count);
	}
}
- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{
	[[NSAlert alertWithError:error] runModal];
}
- (void)downloadDidFinish:(NSURLDownload *)download
{
	[_dataDownloadProgress incrementBy:1];
	if (_dataDownloadProgress.doubleValue>=_dataDownloadProgress.maxValue) {
		[_dataDownloadProgress setHidden:YES];
		[[NSNotificationCenter defaultCenter]
		 postNotificationName:KILongCadencesDidFinishDownloading object:self];
		NSLog(@"%@ %@",@"dataDownloadDidFinish %@", download);
	}
	//
}

- (NSURL *) URLForKeplerIDString:(NSString *) keplerID {
	long kID = keplerID.integerValue;
	if (kID==0) {
		return [NSURL URLWithString:self.rootURLString];
	}
	NSString *kIDString = [NSString stringWithFormat:@"%09ld",kID];
	NSString *urlString = self.rootURLString;
	urlString = [urlString stringByAppendingPathComponent:[kIDString substringToIndex:4]];
	urlString = [urlString stringByAppendingPathComponent:kIDString];
	//NSLog(@"%@", urlString);
	return [NSURL URLWithString:urlString];
}

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame {
	_loadIsInProgressP = YES;
	self.validDataURLP = [NSNumber numberWithBool:NO];
	//NSLog(@"didStartProvisionalLoad:%@",frame);
}
- (void) webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame{
	_loadIsInProgressP = NO;
	if (_loadDidFailP) {
		return;
	}
	NSString *urlString = [sender mainFrameURL];
	NSString *kepID = [urlString lastPathComponent];
	NSString *kepJD = [[urlString stringByDeletingLastPathComponent] lastPathComponent];
	if ((kepID.length == 9) && [kepJD isEqualToString:[kepID substringToIndex:4]]) {
		self.validDataURLP = @YES;
	}
	//NSLog(@"FINISHED:%@",kepID);
}
- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame{
	if ([title hasPrefix:@"404 Not Found"]) {
		_loadDidFailP = YES;
	}
}
- (void) loadCurvesForKeplerID:(NSString *)keplerID{
	_kidSearchField.stringValue = keplerID;
	[self searchForKeplerID:_kidSearchField];
	[_kidSearchField setEnabled: NO];
}
@end
