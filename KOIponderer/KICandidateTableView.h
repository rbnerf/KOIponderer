//
//  KICandidateTableView.h
//  KOIponderer
//
//  Created by Richard Nerf on 1/21/15.
//  Copyright (c) 2015 Richard Nerf. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class KIGLView;

@interface KICandidateTableView : NSTableView

@property (weak) IBOutlet KIGLView *glView;

@end
