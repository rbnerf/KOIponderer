//
//  KPCandidate.h
//  KeplerIan
//
//  Created by Richard Nerf on 9/2/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class KPOcclusion, KPStar;

@interface KPCandidate : NSManagedObject

@property (nonatomic, retain) NSString * comment;
@property (nonatomic) float depth;
@property (nonatomic, retain) NSString * disposition;
@property (nonatomic) double duration;
@property (nonatomic) double epoch;
@property (nonatomic) float fBlue;
@property (nonatomic) float fGreen;
@property (nonatomic) float fRed;
@property (nonatomic, retain) NSString * id;
@property (nonatomic) float impact;
@property (nonatomic) float ingress;
@property (nonatomic, retain) NSString * koiID;
@property (nonatomic) double period;
@property (nonatomic, retain) NSString * starID;
@property (nonatomic) BOOL visibleP;
@property (nonatomic, retain) NSSet *kpOcclusions;
@property (nonatomic, retain) KPStar *kpStar;
@end

@interface KPCandidate (CoreDataGeneratedAccessors)

- (void)addKpOcclusionsObject:(KPOcclusion *)value;
- (void)removeKpOcclusionsObject:(KPOcclusion *)value;
- (void)addKpOcclusions:(NSSet *)values;
- (void)removeKpOcclusions:(NSSet *)values;

@end
