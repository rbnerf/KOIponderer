//
//  KIStackCurve.h
//  KeplerIan
//
//  Created by Richard Nerf on 12/8/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KIStackCurve : NSObject

@property (strong) NSMutableData *time_flux_mux;
@property (assign) int fullLength;
@property (assign) int calcFirst;
@property (assign) int calcLength;
@property (assign) GLdouble timeMin;
@property (assign) GLdouble timeMax;
@property (assign) GLdouble fluxMin;
@property (assign) GLdouble fluxMax;
@property (assign) GLdouble fluxMedian;
@property (assign) GLdouble fluxShift;

@property (assign) GLuint glBufferID;

@end
