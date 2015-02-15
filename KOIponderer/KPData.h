//
//  KPData.h
//  KOIponderer
//
//  Created by Richard Nerf on 1/15/15.
//  Copyright (c) 2015 Richard Nerf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class KPLightCurve, KPOcclusion;

@interface KPData : NSManagedObject

@property (nonatomic, retain) NSData * data;
@property (nonatomic, retain) NSString * dataDescription;
@property (nonatomic) int32_t glBufferID;
@property (nonatomic, retain) NSData * tempData;
@property (nonatomic, retain) KPLightCurve *kpLightCurve;
@property (nonatomic, retain) NSSet *kpOcclusions;
@end

@interface KPData (CoreDataGeneratedAccessors)

- (void)addKpOcclusionsObject:(KPOcclusion *)value;
- (void)removeKpOcclusionsObject:(KPOcclusion *)value;
- (void)addKpOcclusions:(NSSet *)values;
- (void)removeKpOcclusions:(NSSet *)values;

@end
