//
//  KPOcclusion.h
//  KeplerIan
//
//  Created by Richard Nerf on 6/28/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class KPCandidate, KPData;

@interface KPOcclusion : NSManagedObject

@property (nonatomic) int16_t indexA;
@property (nonatomic) int16_t indexB;
@property (nonatomic) int32_t gate;
@property (nonatomic) double tMid;
@property (nonatomic, retain) KPCandidate *kpCandidate;
@property (nonatomic, retain) KPData *kpData;

@end
