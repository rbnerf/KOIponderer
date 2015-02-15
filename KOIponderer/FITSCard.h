//
//  FITSCard.h
//  KeplerIan
//
//  Created by Richard Nerf on 4/19/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FITSCard : NSObject

@property (strong) NSString *keyword;
@property (strong) id value;
@property (strong) NSString *comment;

@end
