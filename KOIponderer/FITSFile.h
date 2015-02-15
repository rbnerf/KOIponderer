//
//  FITSFile.h
//  KeplerIan
//
//  Created by Richard Nerf on 4/18/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FITSHeaderDataUnit;

@interface FITSFile : NSObject

@property (copy) NSString *path;
@property (strong) NSData *data;
@property (strong) NSMutableArray *headerAndDataUnits;
@property (strong) FITSHeaderDataUnit *currentHDU;

- (id) initWithContentsOfFile:(NSString *) path;
- (id) initWithContentsOfURL:(NSURL *) url;
- (id) initWithContentsOfData:(NSData *) data downloadedFrom: (NSString *) url;

@end
