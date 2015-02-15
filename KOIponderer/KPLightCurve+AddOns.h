//
//  KPLightCurve+AddOns.h
//  KeplerIan
//
//  Created by Richard Nerf on 5/25/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import "KPLightCurve.h"

@interface KPLightCurve (AddOns)

- (id) initFromLocalFITS: (NSURL*) url;
- (id) initFromData: (NSData *) data downloadedFrom:(NSString *) urlString;

@end
