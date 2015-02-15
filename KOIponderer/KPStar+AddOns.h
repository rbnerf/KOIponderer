//
//  KPStar+AddOns.h
//  KeplerIan
//
//  Created by Richard Nerf on 5/25/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import "KPStar.h"

typedef NS_OPTIONS(NSUInteger, KPResamplingMethod) {
    KPNearest = 0,
    KPLinear = 1,
    KPLanczos = 2
};

@class KPCandidate;

@interface KPStar (AddOns)

- (void) resampleLightCurvesAt:(int)multiplicity using:(KPResamplingMethod)method;
- (void) fakeOccultationsForCandidate: (KPCandidate *) candidate polarity:(int) polarity;

@end
