//
//  KPOcclusion.m
//  KeplerIan
//
//  Created by Richard Nerf on 6/28/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import "KPOcclusion.h"
#import "KPCandidate.h"
#import "KPData.h"
#import "KeplerData.h"

@implementation KPOcclusion

@dynamic indexA;
@dynamic indexB;
@dynamic gate;
@dynamic tMid;
@dynamic kpCandidate;
@dynamic kpData;

- (double) tMid {
	int indexC = (self.indexA+self.indexB)/2;
	keplerData *data = (keplerData *)[self.kpData.data bytes];
	keplerData *datum = (data + indexC);
	return (double)datum->time;
}
@end
