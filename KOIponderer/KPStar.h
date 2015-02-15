//
//  KPStar.h
//  KeplerIan
//
//  Created by Richard Nerf on 9/29/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class KPCandidate, KPLightCurve;

@interface KPStar : NSManagedObject

@property (nonatomic, retain) NSString * comment;
@property (nonatomic, retain) NSString * dataPath;
@property (nonatomic, retain) NSString * id;
@property (nonatomic, retain) NSString * koiID;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSSet *kpCandidates;
@property (nonatomic, retain) NSSet *kpLightCurves;
@property (nonatomic, retain) KPLightCurve *rsLightCurve;
@end

@interface KPStar (CoreDataGeneratedAccessors)

- (void)addKpCandidatesObject:(KPCandidate *)value;
- (void)removeKpCandidatesObject:(KPCandidate *)value;
- (void)addKpCandidates:(NSSet *)values;
- (void)removeKpCandidates:(NSSet *)values;

- (void)addKpLightCurvesObject:(KPLightCurve *)value;
- (void)removeKpLightCurvesObject:(KPLightCurve *)value;
- (void)addKpLightCurves:(NSSet *)values;
- (void)removeKpLightCurves:(NSSet *)values;

@end
