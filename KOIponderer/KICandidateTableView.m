//
//  KICandidateTableView.m
//  KOIponderer
//
//  Created by Richard Nerf on 1/21/15.
//  Copyright (c) 2015 Richard Nerf. All rights reserved.
//

#import "KICandidateTableView.h"
#import "KIGLView.h"

@implementation KICandidateTableView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (void)textDidEndEditing:(NSNotification *)aNotification {
	//NSLog(@"%@", aNotification);
	[_glView fetchParametersFromSelectedOrbit];
}
@end
