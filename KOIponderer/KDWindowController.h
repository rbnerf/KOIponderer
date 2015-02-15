//
//  KDWindowController.h
//  adapted from KeplerDownloader
//
//  Created by Richard Nerf on 8/27/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WebView,WebFrame,KIStarsController;

@interface KDWindowController : NSWindowController <NSApplicationDelegate,NSURLDownloadDelegate>

//@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet WebView *webView;
@property (copy) NSString *rootURLString;
@property (strong) NSNumber *validDataURLP;
@property (assign) BOOL loadIsInProgressP;
@property (assign) BOOL loadDidFailP;
@property (assign) BOOL urlIsWellFormedP;
@property (weak) IBOutlet NSProgressIndicator *webViewProgress;
@property (weak) IBOutlet NSProgressIndicator *dataDownloadProgress;
@property (weak) IBOutlet NSSearchField *kidSearchField;
@property (weak) KIStarsController *delegate;
@property (strong) NSMutableDictionary *urlDataDict;

- (IBAction) doDownload:(id)sender;
- (IBAction) searchForKeplerID:(id)sender;
- (void) loadCurvesForKeplerID:(NSString *)keplerID;

- (void) webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame;
- (void) webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame;
- (void) webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame;
@end
