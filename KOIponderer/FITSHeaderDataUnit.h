//
//  FITSHeaderDataUnit.h
//  KeplerIan
//
//  Created by Richard Nerf on 4/18/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FITSHeaderDataUnit : NSObject

@property (strong) NSMutableDictionary *header;
@property (strong) NSData *rawData;

@property (readonly) NSString *name;

- (BOOL) unpackCard:(NSData *) cardImage;
- (int) integerValueFor:(NSString *) key;
- (NSString *) stringValueFor:(NSString *) key;

@end
