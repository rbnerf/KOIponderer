//
//  KIGLView.h
//  KeplerIan
//
//  Created by Richard Nerf on 4/13/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class KPStar,KIStackCurve;

@interface KIGLView : NSOpenGLView <NSTableViewDataSource, NSTableViewDelegate>
{
	GLdouble preTiltXform[16];
	GLdouble postTiltXform[16];
	GLdouble xBox[16];
	///GLdouble yBox[16];
	GLdouble aBox[16];
	GLdouble kBox[4][4];
	GLfloat xStar[256];
	GLfloat yStar[256];
}

#pragma mark - Fake Data

- (IBAction) fakeSelectedOrbit:(id) sender;

#pragma mark - Stack

@property (strong) KIStackCurve *stackCurve;
@property (strong) NSNumber *stackP;
@property (strong) NSNumber *stackableP;
@property (strong) IBOutlet NSNumber *stackWidthInRevs;
@property (assign) GLdouble preDragStackWidthInRevs;
@property (strong) IBOutlet NSNumber *stackHeightMultiplier;
@property (assign) GLdouble preDragStackHeightMultiplier;
@property (strong) IBOutlet NSNumber *stackUpDown;
@property (assign) GLdouble preDragStackUpDown;
@property (strong) NSNumber *resamplingMultiplicity;
#pragma mark - Table Array Controllers

@property (weak) IBOutlet NSArrayController *lightCurveController;
@property (weak) IBOutlet NSArrayController *starsController;
@property (weak) IBOutlet NSArrayController *orbitController;
@property (weak) IBOutlet NSTableHeaderView *orbitHeader;

#pragma mark - IBOutlets used in drawRect:

@property (weak) IBOutlet NSStepper *revStepper;
@property (weak) IBOutlet NSTextField *revNumber;
@property (strong) NSMutableIndexSet *revsToOmit;
@property (strong) NSIndexSet *lastSelection;
@property (assign) int firstRevInData;
@property (assign) int lastRevInData;
@property (weak) IBOutlet NSTableView *revsTable;
@property (weak) IBOutlet NSSegmentedControl *revsSelectedControl;

#pragma mark - Algorithmic (private?)

@property (strong) NSMutableArray *lightCurves;
@property (assign) GLdouble timeMin;
@property (assign) GLdouble timeMax;
@property (assign) GLdouble fluxMin;
@property (assign) GLdouble fluxMax;
@property (strong) KPStar *currentStar;
@property (assign) int bufferedCount;

#pragma mark - Miscellaneous flags

@property (assign) BOOL nibLoadedOnceAlreadyP; //View-based table causes repetition.
@property (strong) NSNumber *logGateCalcsP;
@property (strong) NSNumber *logParametersP;
@property (strong) NSNumber *autoDisplayP;
@property (strong) NSNumber *autoAlignP;
@property (assign) BOOL haveKludgedOpenGLViewP;
@property (strong) NSNumber *periodPhaseLockedP;

#pragma mark - Ancillary display parameters

@property (strong) NSNumber *colorIntensity;
@property (strong) NSNumber *lineWidth;
@property (strong) NSNumber *displayEclipsesP;
@property (strong) NSNumber *orbitOverlayWidth;
@property (strong) NSNumber *gateHighlighted;
@property (assign) BOOL verticalGraticuleP;
@property (assign) BOOL stackGraticuleP;
@property (assign) BOOL graticuleP;

#pragma mark - Primary display parameters

@property (strong) NSColor *candidateColor;

#pragma mark - Time (X) parameters

@property (strong) NSNumber *periodNow;
@property (strong) NSNumber *periodLocked;
@property (strong) NSNumber *epochPhase;  // fraction of periodNow (may have sign problem)
@property (strong) NSNumber *epochPhaseLocked;
@property (strong) NSNumber *epochForRev;
@property (strong) NSNumber *eclipseDuration;
@property (strong) NSNumber *eclipseIngress;
@property (strong) NSNumber *tScaleMin;
@property (strong) NSNumber *tScaleNow;
@property (strong) NSNumber *tScaleMax;

#pragma mark - Light Flux (Y) parameters

@property (strong) NSNumber *fluxOriginNow;
@property (strong) NSNumber *fluxScaleNow;
@property (strong) NSNumber *tiltFracNow;


#pragma mark - Geometry controls via mouse drags

@property (assign) GLdouble xMouseDown;
@property (assign) GLdouble yMouseDown;
@property (assign) GLdouble mousePeriodFactor; // Calculated from data
@property (assign) GLdouble mouseEpochFactor; // Calculated from data
#pragma mark Undo for mouse drag
@property (assign) GLdouble preDragFluxOrigin;
@property (assign) GLdouble preDragFluxScale;
@property (assign) GLdouble preDragFluxTilt;
@property (assign) GLdouble preDragTimeScale;
@property (assign) GLdouble preDragPeriod;
@property (assign) GLdouble preDragPhase;


#pragma mark - IBActions

- (IBAction) plotLightCurves:(id)sender;
- (IBAction) calcEclipseTime:(id)sender;
- (IBAction) createCandidate: (id) caller;
- (IBAction) readCurrentMatrix: (id) caller;
- (IBAction) readCurrentArrayBuffer: (id) caller;
- (IBAction) stackNow: (id) caller;
- (IBAction) changeVisibleRevs:(id)sender;
- (IBAction) changeVisibleRevGroups:(NSSegmentedControl *)sender;
- (IBAction) changeSelectedRevs:(NSSegmentedControl *)sender;
- (IBAction) toggleVisibleRevs:(id)sender;
- (IBAction) redoSelections:(id)sender;
- (IBAction) unGPUStack:(id)sender;
- (void) longCadencesDidFinishDownloading:(NSNotification *)notification;

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;
- (void) fetchParametersFromSelectedOrbit;

@end
