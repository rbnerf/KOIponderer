//
//  KPLightCurve.h
//  KeplerIan
//
//  Created by Richard Nerf on 9/29/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class KPData, KPStar;

@interface KPLightCurve : NSManagedObject

@property (nonatomic, retain) NSString * fileName;
@property (nonatomic) double fluxMax;
@property (nonatomic) double fluxMedian;
@property (nonatomic) double fluxMin;
@property (nonatomic) double fluxShift;
@property (nonatomic) int32_t sampleCount;
@property (nonatomic) double timeMax;
@property (nonatomic) int32_t timeMaxIndex;
@property (nonatomic) double timeMin;
@property (nonatomic) int32_t timeMinIndex;
@property (nonatomic) BOOL visibleP;
@property (nonatomic, retain) KPData *kpData;
@property (nonatomic, retain) KPStar *kpStar;
@property (nonatomic, retain) KPStar *rsStar;

@end
