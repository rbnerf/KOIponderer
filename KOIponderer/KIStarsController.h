//
//  KIStarsController.h
//  KeplerIan
//
//  Created by Richard Nerf on 6/9/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class KDWindowController,KPStar;

@interface KIStarsController : NSArrayController

@property (assign) NSInteger lastTag;
@property (strong) KDWindowController *downloadWindowController;
@property (strong) KPStar *star;

- (void) processFITSDataDict:(NSDictionary *)dataDict;
- (IBAction)removeLightCurves:(id)sender;
- (IBAction)populateSelectedStar:(id)sender;

@end
