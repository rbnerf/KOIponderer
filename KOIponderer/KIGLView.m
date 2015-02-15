                //
//  KIGLView.m
//  KeplerIan
//
//  Created by Richard Nerf on 4/13/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import "KIGLView.h"
#import "KeplerData.h"
#import "KIStackCurve.h"
#import "KPStar+AddOns.h"
#import "KPLightCurve+AddOns.h"
#import "KPData.h"
#import "KPCandidate.h"
#import "KPOcclusion.h"
#import "KINotifications.h"

#import <OpenGL/glu.h>

// GL Transform indices
#define XSCALE 0
#define XSHIFT 12
#define YSCALE 5
#define YSHIFT 13
#define ZSCALE 10
#define ZSHIFT 14
#define ASHIFT 15
#define OLDPHASE 0

int compareFluxes(const void *a, const void *b){
	keplerStack *aa = *(keplerStack **)a;
	keplerStack *bb = *(keplerStack **)b;
	if (aa->flux>bb->flux) {
		return 1;
	} else if(aa->flux==bb->flux) {
		return 0;
	} else {
		return -1;
	}
}

@implementation KIGLView

- (void) longCadencesDidFinishDownloading:(NSNotification *)notification{
	[self plotLightCurves:nil];
}

- (IBAction) fakeSelectedOrbit:(NSButton *) sender {
	[self.window makeFirstResponder:nil];  //Terminates any editing going on with KPCandidate
	KPCandidate *orbit = self.orbitController.selectedObjects.lastObject;
	int sign = (int)sender.tag;
	[self.currentStar fakeOccultationsForCandidate:orbit polarity:sign];
	
	for (KPLightCurve *lightCurve in self.currentStar.kpLightCurves) {
		GLuint bufferID = lightCurve.kpData.glBufferID;
		glBindBuffer(GL_ARRAY_BUFFER, bufferID);
		assert(!glGetError());
		GLsizeiptr byteCount =lightCurve.sampleCount*sizeof(keplerData);
		GLenum bufferUsage = GL_STATIC_DRAW;
		const void *data = lightCurve.kpData.data.bytes;
		glBufferData(GL_ARRAY_BUFFER, byteCount , data, bufferUsage);
		assert(!glGetError());
	}
	[self stackNow:nil];
	[self setNeedsDisplay:YES];
}


#pragma mark - Rev controls

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	long row = _revsTable.selectedRow;
	//NSLog(@"SELECTION:%ld",row);
	NSIndexSet *selections = _revsTable.selectedRowIndexes;
	//NSLog(@"SELECTIONS:%@",selections);
	self.lastSelection = [[NSIndexSet alloc] initWithIndexSet:selections];
	if (row>=0) {
		_revsSelectedControl.enabled = YES;
	} else {
		_revsSelectedControl.enabled = NO;
	}
}

- (IBAction) toggleVisibleRevs:(NSControl *)sender{
	NSUInteger rowIndex = [_revsTable selectedRow];
	NSUInteger index = rowIndex + _firstRevInData;
	if ([_revsToOmit containsIndex:index]) {
		[_revsToOmit removeIndex:index];
	} else {
		[_revsToOmit addIndex:index];
	}
	[self stackNow:nil];
	[self setNeedsDisplay:YES];
}
- (IBAction) redoSelections:(id)sender {
	[_revsTable selectRowIndexes:_lastSelection byExtendingSelection:NO];
}
- (IBAction) changeVisibleRevs:(NSControl *)sender{
	//NSLog(@"Change:%ld",(long)sender.tag);
	NSIndexSet *selections = _revsTable.selectedRowIndexes;
	//self.lastSelection = [[NSIndexSet alloc] initWithIndexSet:selections];
	NSMutableIndexSet *toDos = [[NSMutableIndexSet alloc] initWithIndexSet:selections];
	[toDos shiftIndexesStartingAtIndex:0 by:_firstRevInData];
	NSInteger tag = sender.tag;
	if(tag == -1){
		[_revsToOmit addIndexes:toDos];
	} else if (tag == 1) {
		[_revsToOmit removeIndexes:toDos];
	} else {
		[toDos enumerateIndexesUsingBlock:^(NSUInteger index,
									   BOOL *stop)
		 {
			 if ([_revsToOmit containsIndex:index]) {
				 [_revsToOmit removeIndex:index];
			 } else {
				 [_revsToOmit addIndex:index];
			 }
		 }];
	}
	//[_revsTable reloadData];
	//[_revsTable selectRowIndexes:selections byExtendingSelection:NO];
	[self stackNow:nil];
	[self setNeedsDisplay:YES];
}
- (IBAction) changeSelectedRevs:(NSSegmentedControl *)sender{
	NSIndexSet *selections = _revsTable.selectedRowIndexes;
	//self.lastSelection = [[NSIndexSet alloc] initWithIndexSet:selections];
	NSMutableIndexSet *toDos = [[NSMutableIndexSet alloc] initWithIndexSet:selections];
	[toDos shiftIndexesStartingAtIndex:0 by:_firstRevInData];
	NSInteger segment = sender.selectedSegment;
	if(segment == 0){
		[_revsToOmit addIndexes:toDos];
	} else if (segment == 2) {
		[_revsToOmit removeIndexes:toDos];
	} else {
		[toDos enumerateIndexesUsingBlock:^(NSUInteger index,
											BOOL *stop)
		 {
			 if ([_revsToOmit containsIndex:index]) {
				 [_revsToOmit removeIndex:index];
			 } else {
				 [_revsToOmit addIndex:index];
			 }
		 }];
	}
	_revsSelectedControl.enabled = NO;
	[self stackNow:nil];
	[self setNeedsDisplay:YES];
}

- (IBAction) changeVisibleRevGroups:(NSSegmentedControl *)sender{
	// oddball group logic is a hysterical accident
	NSInteger group = sender.selectedSegment-1;
	if (group==-1) { // Select none
		NSRange everybody = NSMakeRange(_firstRevInData, _lastRevInData-_firstRevInData+1);[_revsToOmit addIndexesInRange:everybody];
	} else if (group == 1) { // Select all
		[_revsToOmit removeAllIndexes];
	} else {
		int theMod = group==0?1:0;
		for (int i = _firstRevInData; i<=_lastRevInData; i++) {
			if (i%2 == theMod) {
				[_revsToOmit removeIndex:i];
			} else {
				[_revsToOmit addIndex:i];
			}
			
		}
	}
	[self stackNow:nil];
	[self setNeedsDisplay:YES];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(NSInteger)rowIndex {
	return [NSNumber numberWithLong:rowIndex + _firstRevInData];
}
- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
	NSTableCellView *result = [tableView makeViewWithIdentifier:@"RevCell" owner:self];
	
	// Set the stringValue of the cell's text field to the nameArray value at row
	NSUInteger rev = row + _firstRevInData;
	result.textField.stringValue = [NSString stringWithFormat:@"%ld", rev];
	NSImageView *imageView = result.imageView;
	if ([_revsToOmit containsIndex:rev]) {
		imageView.image = [NSImage imageNamed:NSImageNameStatusNone];
	} else {
		imageView.image = [NSImage imageNamed:NSImageNameStatusPartiallyAvailable];
	}
	// Return the result
	return result;
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView{
	if (!_revsToOmit) {
		return 0;
	}
	if (_lastRevInData == 0 && _firstRevInData ==0) { // Sentinel when selecting new star/orbit
		return 0;
	}
	return _lastRevInData - _firstRevInData + 1;
}

#pragma mark - Stack

- (IBAction) unGPUStack:(id)sender{
	KIStackCurve *stackCurve = self.stackCurve;
	keplerStack *dataLocal = (keplerStack *)[stackCurve.time_flux_mux bytes];
	NSMutableData *mut = [NSMutableData dataWithLength:stackCurve.time_flux_mux.length];
	keplerStack *dataGPU = mut.mutableBytes;
	glBindBuffer(GL_ARRAY_BUFFER, stackCurve.glBufferID);
	glGetBufferSubData(GL_ARRAY_BUFFER, 0, stackCurve.fullLength*sizeof(keplerStack), dataGPU);
	for (int i=0; i<stackCurve.fullLength; i++) {
		if (isnan(dataLocal[i].flux) && isnan(dataGPU[i].flux)) continue;
		if (dataLocal[i].flux != dataGPU[i].flux) {
			NSLog(@"MISMATCH");
		}
	}
	FILE *f = fopen("/tmp/stack.tsv", "w");
	for (int i=stackCurve.calcFirst; i<stackCurve.calcFirst+stackCurve.calcLength; i++) {
		keplerStack *s = &dataGPU[i];
		fprintf(f, "%f\t%f\t%d\n",s->time,s->flux,s->mux);
	}
	fclose(f);
}
-(void) setupStackBuffers {
	KPStar *star = self.currentStar;
	KPLightCurve *rslc = star.rsLightCurve;
	int stackSampleCount = rslc.sampleCount;
	NSUInteger stackByteCount = stackSampleCount * sizeof(keplerStack);
	
	// TODO check whether the current buffer would work, rather than create a new one.
	KIStackCurve *stackCurve = self.stackCurve = [[KIStackCurve alloc] init];
	stackCurve.time_flux_mux = [NSMutableData dataWithLength:stackByteCount];
	
	GLuint bufferID;
	glGenBuffers(1, &bufferID);
	stackCurve.glBufferID = bufferID;
	/*
	keplerStack *data = (keplerStack *)[stackCurve.time_flux_mux bytes];
	glBindBuffer(GL_ARRAY_BUFFER, bufferID);
	assert(!glGetError());
	GLenum bufferUsage = GL_DYNAMIC_DRAW;
	glBufferData(GL_ARRAY_BUFFER, stackByteCount , data, bufferUsage); //TODO: Is this call useful?
	assert(!glGetError());
	 */
	self.stackableP = [NSNumber numberWithBool:YES];
}
- (void) stackNow: (id) caller{
	if (!_stackP.boolValue) {
		return;
	}
	if (!_stackableP.boolValue) {
		return;
	}
	KPStar *star = self.currentStar;
	KPLightCurve *rslc = star.rsLightCurve;
	if (!rslc.kpData.tempData) {
		KPResamplingMethod rm = KPLinear;
		[self.currentStar resampleLightCurvesAt:self.resamplingMultiplicity.intValue using:rm];
		rslc = star.rsLightCurve;
	}
	keplerData *fluxes = (keplerData *)rslc.kpData.tempData.bytes;
	double rsDeltaT = (rslc.timeMax - rslc.timeMin)/(rslc.sampleCount - 1);
	keplerStack *stack = (keplerStack *)_stackCurve.time_flux_mux.mutableBytes;
	double tau = self.periodNow.doubleValue;
	double phi = self.epochPhase.doubleValue;
	//phi = fmod(phi, 0.5); // Move everything to rev 0?
	double swd = MIN(0.999,MAX(_stackWidthInRevs.doubleValue,.001))*tau; //TODO: practical?
	unsigned nStack = tau/rsDeltaT + 1; // width in samples of potential stack window
	// nstack should be odd, so have a center sample
	if (nStack%2 == 0) {
		nStack++;
	}
	int iCenter = nStack/2+1;
	int iHalfWidth = MIN(swd/rsDeltaT+1,nStack/2);
	
	keplerStack *sItem = stack; // zeroth item within stack window
	double zeroTime = tau*(phi-0.5); // rev zero time for zeroth item
	for (int i=0; i<nStack; i++) {
		sItem->time = i*rsDeltaT + zeroTime;
		sItem->flux = 0.0f;
		sItem->mux = 0;
		sItem++;
	}
	// Where is window over which stack is calculated?
	//double tCenter = tau + phi*tau;
	//double tLeft = tCenter - swd/2;
	//double tRight = tCenter + swd/2;
	int iLeft = iCenter - iHalfWidth;
	int iRight = iCenter + iHalfWidth;
	
	// data limits
	double dataTimeMin = rslc.timeMin;
	double dataTimeMax = rslc.timeMax;
	int dataSamples = rslc.sampleCount;
	// Iterate over valid stack samples, testing against data limits
	int revLo = dataTimeMin/tau;
	int revHi = dataTimeMax/tau + 1;
	for (int i=iLeft; i<=iRight; i++) {
		keplerStack *stk = (stack+i);
		double tstk = stk->time;
		for (int r=revLo; r<=revHi; r++) {
			if ([_revsToOmit containsIndex:r]) {
				continue;
			}
			double t = tstk+r*tau; // a time that can stack into i
			int k = (t - dataTimeMin)/rsDeltaT;  // the index for time t
			// first check if there's any sample at that time
			if (k>=dataSamples) {
				break;
			} else if (k<0) {
				continue;
			}
			keplerData data = fluxes[k];
			GLfloat flux = data.flux;
			if (!isnan(flux)) {
				stk->flux+=flux;
				stk->mux++;
			}
		}
	}
	//BOOL debugg = self.debugPrintP.boolValue;
	NSMutableData *toSortBuffer = [NSMutableData dataWithLength:sizeof(void *)*(iRight-iLeft+1)];
	keplerStack **toSort = toSortBuffer.mutableBytes;
	double fMin = MAXFLOAT, fMax = 0;
	int sortCount = 0;
	if (iLeft>0) { //KLUDGE TO DISCONNECT nearby zero fluxes
		stack[iLeft-1].flux = NAN;
	}
	if (iRight<dataSamples-1) {
		stack[iRight+1].flux = NAN;
	}
	for (int i=iLeft; i<=iRight; i++) {
		keplerStack *stk = (stack+i);
		if (stk->mux==0) {
			stk->flux = NAN;
		} else {
			stk->flux/=stk->mux;
			*(toSort+sortCount)=(stack+i);
			sortCount++;
			fMin = MIN(fMin, stk->flux);
			fMax = MAX(fMax, stk->flux);
		}
	}
	KIStackCurve *slc = self.stackCurve;
	slc.calcLength = 0;
	if (sortCount<=0) {
		//NSLog(@"STACK SORT COUNT=%d",sortCount);
		return;
	}
	if (1) {
		qsort(toSort, sortCount, sizeof(void *),compareFluxes);
	} else {
		qsort_b(toSort, sortCount, sizeof(void *),^(const void *a,const void *b) {
			keplerStack *aa = *(keplerStack **)a;
			keplerStack *bb = *(keplerStack **)b;
			if (aa->flux>bb->flux) {
				return 1;
			} else if(aa->flux==bb->flux) {
				return 0;
			} else {
				return -1;
			}
		});
	}
	int mid=sortCount/2;
	double fMedian = toSort[mid]->flux;
	slc.timeMin = stack[0].time;
	slc.timeMax = stack[nStack-1].time;
	slc.fluxMin = fMin;
	slc.fluxMax = fMax;
	slc.fluxMedian = fMedian;
	slc.fullLength = nStack;
	slc.calcFirst = iLeft;
	slc.calcLength = iRight - iLeft + 1;
	
	glBindBuffer(GL_ARRAY_BUFFER, _stackCurve.glBufferID);
	assert(!glGetError());
	GLsizeiptr byteCount = nStack*sizeof(keplerStack);
	GLenum bufferUsage = GL_DYNAMIC_DRAW;
	glBufferData(GL_ARRAY_BUFFER, byteCount , stack, bufferUsage);
	assert(!glGetError());
}

#pragma mark - Orbits
- (IBAction) calcEclipseTime:(id)sender{
	double tau = self.periodNow.doubleValue;
	double f = self.epochPhase.doubleValue;
	int rev = self.revStepper.intValue;
	self.revNumber.intValue = rev;
	double offset,t;
	if (OLDPHASE) {
		offset = -f*tau;
		t = offset + rev*tau;
	} else {
		offset = f*tau;
		t = +offset + rev*tau;
	}
	self.epochForRev = [NSNumber numberWithDouble:t];
	if(sender)[self setNeedsDisplay:YES];
}

- (IBAction) createCandidate: (id) caller {
	if (_currentStar != nil) {
		KPCandidate *pick = [NSEntityDescription insertNewObjectForEntityForName:@"KPCandidate" inManagedObjectContext:_currentStar.managedObjectContext];
		double period = pick.period = _periodNow.doubleValue;
		if (OLDPHASE) {
			pick.epoch = -_epochPhase.doubleValue*_periodNow.doubleValue;
		} else {
			pick.epoch = _epochPhase.doubleValue*_periodNow.doubleValue;
		}
		double epoch = pick.epoch;
		pick.duration = _eclipseDuration.doubleValue;
		double halfWidth = pick.duration/48;
		pick.kpStar = _currentStar;
		CGFloat red,green,blue,alpha;
		[self.candidateColor getRed:&red green:&green blue:&blue alpha:&alpha];
		pick.fRed = red;
		pick.fGreen = green;
		pick.fBlue = blue;
		pick.ingress = MAX(0.0f, MIN(_eclipseIngress.doubleValue,_eclipseDuration.doubleValue/2));
		double epochMin = epoch-halfWidth;  // limits at gate 0, ignoring gate shorter than duration
		double epochMax = epoch+halfWidth;
		for (KPLightCurve *crv in _currentStar.kpLightCurves) {
			if (crv.visibleP) {  // Only going to deal with curves visible on screen
				double tMin = crv.timeMin;
				double tMax = crv.timeMax;
				int gateFirst = floor(tMin/period);
				int gateLast = ceil(tMax/period);
				GLdouble curveDuration = tMax-tMin;
				int bufferLength = crv.sampleCount;
				GLdouble sampleDuration = curveDuration/bufferLength;
				for (int gate=gateFirst; gate<=gateLast; gate++) {
					// Occultation visible if tMin/gate < right occult
					// and tMax/gate > left occult
					double tMinEpoch = tMin - gate*period;
					double tMaxEpoch = tMax - gate*period;
					if ((tMinEpoch <= epochMax) && (tMaxEpoch >= epochMin)) {
						double occLeft = epochMin + gate*period;
						double occRight = epochMax + gate*period;
						int indexLeft = floor((occLeft - tMin)/sampleDuration);
						indexLeft = MAX(indexLeft, 0);
						int indexRight = ceil((occRight - tMin)/sampleDuration);
						indexRight = MIN(indexRight, bufferLength);
						// TODO refine indexLeft and indexRight by checking sample times
						KPOcclusion *occlusion = [NSEntityDescription insertNewObjectForEntityForName:@"KPOcclusion" inManagedObjectContext:_currentStar.managedObjectContext];
						occlusion.kpCandidate = pick;
						occlusion.indexA = indexLeft;
						occlusion.indexB = indexRight;
						occlusion.kpData = crv.kpData;
						occlusion.gate = gate;
					}
				}
			}
		}
	}
}

#pragma mark - Debug OpenGL

- (void) prepareOpenGL {
	[super prepareOpenGL];
	//NSOpenGLContext *context = self.openGLContext;
	//NSLog(@"GLcontext=%@",context);
	//NSOpenGLPixelFormat *pixelFormat = self.pixelFormat;
	//NSLog(@"PixelFormat=%@",pixelFormat);
}


- (IBAction) readCurrentMatrix: (id) caller{
	glGetDoublev(GL_MODELVIEW_MATRIX,xBox);
	//NSLog(@"Y*%f+%f",kBox[1][1],kBox[3][1]);
}
/*
- (IBAction) readCurrentMatrixX: (id) caller{
	glGetDoublev(GL_MODELVIEW_MATRIX,kBox);
	NSLog(@"X*%f+%f",kBox[0][0],kBox[3][0]);
}
 */
- (IBAction) readCurrentArrayBuffer: (id) caller{
	GLint bufferID,bufferSize,bufferUsage,err;
	glGetIntegerv(GL_ARRAY_BUFFER_BINDING,&bufferID);
	//assert(bufferID);
	glGetBufferParameteriv(GL_ARRAY_BUFFER, GL_BUFFER_SIZE, &bufferSize);
	err = glGetError();
	glGetBufferParameteriv(GL_ARRAY_BUFFER, GL_BUFFER_USAGE, &bufferUsage);
	err = glGetError();
	//NSLog(@"STOP");
//glGetBufferPointerv
//glMapBuffer
//glUnmapBuffer
//glGetBufferSubData
//GL_ARRAY_BUFFER_BINDING
//GL_ELEMENT_ARRAY_BUFFER_BINDING
//GL_MODELVIEW_MATRIX
}

#pragma mark - Initialization

- (void) awakeFromNib {
	if (_nibLoadedOnceAlreadyP) {
		return;
	}
	_nibLoadedOnceAlreadyP = YES;
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(longCadencesDidFinishDownloading:)
												 name:KILongCadencesDidFinishDownloading object:nil];
	[_revsTable setTarget:self];
	[_revsTable setDoubleAction:@selector(toggleVisibleRevs:)];
	float delta = M_PI/128;
	for (int i=0; i<256; i++) {
		float angle = i*delta;
		xStar[i]=cos(angle);
		yStar[i]=sin(angle);
	}
	_revsSelectedControl.enabled = NO;
	self.resamplingMultiplicity = [NSNumber numberWithInt:9];
	self.stackableP = [NSNumber numberWithBool:NO];
	self.stackWidthInRevs = [NSNumber numberWithDouble:0.05];
	self.stackHeightMultiplier = [NSNumber numberWithDouble:5.0];
	self.stackUpDown = [NSNumber numberWithDouble:-0.15];
	
	self.periodPhaseLockedP = [NSNumber numberWithBool:YES];
	//self.periodLocked = nil;
	//self.epochPhaseLocked = nil;
	self.candidateColor = [NSColor redColor];
	self.autoDisplayP = [NSNumber numberWithBool:YES];
	self.gateHighlighted = [NSNumber numberWithInt:-1];
	self.logGateCalcsP = [NSNumber numberWithBool:NO];
	self.logParametersP = [NSNumber numberWithBool:NO];
	self.autoAlignP = [NSNumber numberWithBool:YES];
	self.displayEclipsesP = [NSNumber numberWithBool:NO];
	self.colorIntensity = [NSNumber numberWithFloat:1.0f];
	self.lineWidth = [NSNumber numberWithFloat:1.0f];
	self.tiltFracNow = [NSNumber numberWithFloat:1.0f];
	
	self.periodLocked = self.periodNow = [NSNumber numberWithFloat:20.0f];
	self.epochPhaseLocked = self.epochPhase = [NSNumber numberWithFloat:0.0f];
	
	self.tScaleMin = [NSNumber numberWithFloat:3.0f];
	self.tScaleMax = [NSNumber numberWithFloat:128.0f];
	self.tScaleNow = [NSNumber numberWithFloat:4.0f];
	
	self.fluxOriginNow = [NSNumber numberWithFloat:-0.650f];
	
	self.fluxScaleNow = [NSNumber numberWithFloat:10.0f];
	
	self.orbitOverlayWidth = [NSNumber numberWithFloat:2.0f];
	self.eclipseDuration = [NSNumber numberWithDouble:6.0f];
	self.eclipseIngress = [NSNumber numberWithDouble:0.5f];
	preTiltXform[XSCALE]=preTiltXform[YSCALE]=preTiltXform[ZSCALE]=preTiltXform[ASHIFT]=1.0;
	self.lightCurves = [NSMutableArray array];
	NSUInteger beforeNafter = (NSKeyValueObservingOptionNew |
							   NSKeyValueObservingOptionOld);
	[_revsTable addObserver:self forKeyPath:@"selectedRowIndexes" options:beforeNafter context:(__bridge void *)(_revsTable)]; // doesn't work
	[self addObserver:self forKeyPath:@"stackWidthInRevs" options:beforeNafter context:nil];
	[self addObserver:self forKeyPath:@"stackHeightMultiplier" options:beforeNafter context:nil];
	[self addObserver:self forKeyPath:@"stackUpDown" options:beforeNafter context:nil];
	[self addObserver:self forKeyPath:@"periodPhaseLockedP" options:beforeNafter context:(__bridge void *)(self)];
	[self addObserver:self forKeyPath:@"gateHighlighted" options:beforeNafter context:nil];
	[self addObserver:self forKeyPath:@"colorIntensity" options:beforeNafter context:nil];
	[self addObserver:self forKeyPath:@"lineWidth" options:beforeNafter context:nil];
	[self addObserver:self forKeyPath:@"tiltFracNow" options:beforeNafter context:nil];
	[self addObserver:self forKeyPath:@"periodNow" options:beforeNafter context:nil];
	[self addObserver:self forKeyPath:@"epochPhase" options:beforeNafter context:nil];
	[self addObserver:self forKeyPath:@"tScaleNow" options:beforeNafter context:nil];
	[self addObserver:self forKeyPath:@"orbitOverlayWidth" options:beforeNafter context:nil];
	[self addObserver:self forKeyPath:@"fluxOriginNow" options:beforeNafter context:nil];
	[self addObserver:self forKeyPath:@"fluxScaleNow" options:beforeNafter context:nil];
	[self addObserver:self forKeyPath:@"logGateCalcsP" options:beforeNafter context:nil];
	[self addObserver:self forKeyPath:@"stackP" options:beforeNafter context:nil];
	[self addObserver:self forKeyPath:@"displayEclipsesP" options:beforeNafter context:nil];
	[self addObserver:self forKeyPath:@"eclipseDuration" options:beforeNafter context:nil];
	[self addObserver:self forKeyPath:@"eclipseIngress" options:beforeNafter context:nil];
	[self.starsController addObserver:self forKeyPath:@"selectionIndex" options:beforeNafter//(NSKeyValueObservingOptionInitial |NSKeyValueObservingOptionPrior | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
							  context:(__bridge void *)(self.starsController)];
	[self.orbitController addObserver:self forKeyPath:@"selectionIndex" options:beforeNafter 							  context:(__bridge void *)(self.orbitController)];
}

#pragma mark - Respond to Changes

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if(_logParametersP.boolValue) NSLog(@"%@<=>%@",keyPath,change);
    if (context == nil) {
		if (_stackP.boolValue == YES) { // TODO: use a different context to avoid these lines?
			if ([keyPath isEqualToString:@"stackP"]
				|| [keyPath isEqualToString:@"periodNow"]
				|| [keyPath isEqualToString:@"epochPhase"]
				|| [keyPath isEqualToString:@"stackWidthInRevs"]
				|| [keyPath isEqualToString:@"stackHeightMultiplier"]
				|| [keyPath isEqualToString:@"stackUpDown"]
				) {
				[self stackNow:nil];
			}
		}
		if (_periodPhaseLockedP.boolValue && [keyPath isEqualToString:@"periodNow"]) {
			double phaseNew;
			if (OLDPHASE) {
				phaseNew = self.revStepper.intValue*(_periodNow.doubleValue - _periodLocked.doubleValue);
				phaseNew += _periodLocked.doubleValue*_epochPhaseLocked.doubleValue;
				phaseNew /= _periodNow.doubleValue;
			} else {
				double tZero = _epochForRev.doubleValue - self.revStepper.intValue*_periodNow.doubleValue;
				phaseNew = tZero/_periodNow.doubleValue;
			}
			self.epochPhase = [NSNumber numberWithDouble:phaseNew];
		}
        [self setNeedsDisplay:YES];
	} else if (context == (__bridge void *)(self)){
		self.periodLocked = self.periodNow;
		self.epochPhaseLocked = self.epochPhase;
	} else if (context == (__bridge void *)(self.orbitController)) {
		[_revsToOmit removeAllIndexes];[_revsTable reloadData];
		[self fetchParametersFromSelectedOrbit];
    } else if (context == (__bridge void *)(self.starsController)) {
		[_revsToOmit removeAllIndexes];[_revsTable reloadData];
		_firstRevInData=0;
		_lastRevInData=0;
		self.revNumber.intValue = 0;
		self.revStepper.intValue = 0;
		if (self.currentStar) {
			//NSLog(@"DEAL WITH %@",self.currentStar);
			for (KPLightCurve *crv in self.currentStar.kpLightCurves) {
				if (crv.kpData.glBufferID>0) {
					[crv removeObserver:self forKeyPath:@"visibleP"];
					GLuint bID = crv.kpData.glBufferID;
					//NSLog(@"-----%d Buffer Deleted",bID);
					glDeleteBuffers(1, &bID);
					crv.kpData.glBufferID=0;
				}
			}
			self.bufferedCount = 0;
			self.currentStar = nil;
		}
		self.stackableP = [NSNumber numberWithBool:NO];
		if (_stackCurve && _stackCurve.glBufferID) {
			GLuint bID = _stackCurve.glBufferID;
			glDeleteBuffers(1, &bID);
			_stackCurve.glBufferID=0;
		}
		NSUInteger n = self.starsController.selectionIndex;
		if (n != NSNotFound) {
			if (!self.haveKludgedOpenGLViewP) {
				self.haveKludgedOpenGLViewP = YES;
				NSRect bnds = self.bounds;
				bnds.size.width++;
				self.bounds = bnds;
			}
			self.currentStar = [self.starsController.arrangedObjects objectAtIndex:n];
			[self performSelectorOnMainThread:@selector(plotLightCurves:) withObject:self waitUntilDone:NO];
			//[self plotLightCurves:nil];
		}
	}  else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void) fetchParametersFromSelectedOrbit{
	NSUInteger n = self.orbitController.selectionIndex;
	if (n != NSNotFound) {
		KPCandidate *orbit = [self.orbitController.arrangedObjects objectAtIndex:n];
		double periodNow = orbit.period;
		///if (_periodMin.doubleValue > periodNow) {
		//self.periodSlider.minValue = periodNow;
		///	self.periodMin = [NSNumber numberWithDouble:periodNow];
		///}
		///if (_periodMax.doubleValue < periodNow) {
		//self.periodSlider.maxValue = periodNow;
		///	self.periodMax = [NSNumber numberWithDouble:periodNow];
		///}
		self.periodNow = [NSNumber numberWithDouble:periodNow];
		int rev = (orbit.epoch/orbit.period);
		self.revStepper.intValue = rev;
		self.revNumber.intValue = rev;
		double epochPhase;
		if (OLDPHASE) {
			epochPhase = -(orbit.epoch - rev*orbit.period)/orbit.period;
		} else {
			epochPhase = (orbit.epoch - rev*orbit.period)/orbit.period;
		}
		self.epochPhase = [NSNumber numberWithDouble:epochPhase];
		self.eclipseDuration = [NSNumber numberWithDouble:orbit.duration];
		self.eclipseIngress = [NSNumber numberWithDouble:orbit.ingress];
		self.periodLocked = self.periodNow;
		self.epochPhaseLocked = self.epochPhase;
		[self setNeedsDisplay:YES];
	}
}

- (IBAction)plotLightCurves:(id)sender{
	if (self.bufferedCount) return;
	NSArray *lightCurves = self.lightCurveController.arrangedObjects;
	if (lightCurves.count == 0) {
		[self setNeedsDisplay:YES];
		return;
	}
	KPResamplingMethod rm = KPLinear;
	[self.currentStar resampleLightCurvesAt:self.resamplingMultiplicity.intValue using:rm];
	[self setupStackBuffers];
	/*NSEnumerator *curves = [lightCurves reverseObjectEnumerator];
	for (KPLightCurve *lightCurve in curves) {
		NSLog(@"%@",lightCurve);
	}*/
	_fluxMin = _timeMin = DBL_MAX;
	_fluxMax = _timeMax = -DBL_MAX;
	double top = 0.0; double bot = 0.0; double del= 0.0; // measured relative to median of curve
	for (KPLightCurve *lightCurve in lightCurves) {
		[lightCurve addObserver:self forKeyPath:@"visibleP" options:0 context:nil];
		// Should mins & maxes include only visibleP?
		_timeMin = MIN(_timeMin, lightCurve.timeMin);
		_timeMax = MAX(_timeMax, lightCurve.timeMax);
		_fluxMin = MIN(_fluxMin, lightCurve.fluxMin);
		_fluxMax = MAX(_fluxMax, lightCurve.fluxMax);
		top = MAX(top, lightCurve.fluxMax-lightCurve.fluxMedian); // TODO - check whether these vars are used anymore!
		bot = MIN(bot, lightCurve.fluxMin-lightCurve.fluxMedian);
		del = MAX(del, lightCurve.fluxMax-lightCurve.fluxMin);
		keplerData *data = (keplerData *)[lightCurve.kpData.data bytes];
		GLuint bufferID;
		glGenBuffers(1, &bufferID);
		assert(!glGetError());
		//NSLog(@"++++%d Buffer Generated",bufferID);
		lightCurve.kpData.glBufferID = bufferID;
		glBindBuffer(GL_ARRAY_BUFFER, bufferID);
		assert(!glGetError());
		GLsizeiptr byteCount =lightCurve.sampleCount*sizeof(keplerData);
		GLenum bufferUsage = GL_STATIC_DRAW;
		//NSLog(@"====%d Buffer holds %ld bytes",bufferID,byteCount);
		glBufferData(GL_ARRAY_BUFFER, byteCount , data, bufferUsage);
		assert(!glGetError());
		{ GLint kufferID,kufferSize,kufferUsage;
			glGetIntegerv(GL_ARRAY_BUFFER_BINDING,&kufferID);
			//assert(bufferID == kufferID);
			glGetBufferParameteriv(GL_ARRAY_BUFFER, GL_BUFFER_SIZE, &kufferSize);
			//assert(byteCount == kufferSize);
			glGetBufferParameteriv(GL_ARRAY_BUFFER, GL_BUFFER_USAGE, &kufferUsage);
			assert(kufferUsage == bufferUsage);
		}
		self.bufferedCount++;
	}
	// Setup rev controls
	self.revsToOmit = [[NSMutableIndexSet alloc] init];
	
	BOOL medianCenteredP = YES;
	
	if (medianCenteredP) {
		preTiltXform[XSCALE] = 1.9f/(_timeMax - _timeMin);
		preTiltXform[YSCALE] = 1.0f;
		preTiltXform[XSHIFT] = (0-(0.95*(_timeMax + _timeMin)/(_timeMax - _timeMin)));
		preTiltXform[YSHIFT] = 0.0f;
	} else {
		preTiltXform[XSCALE] = 2.0f/(_timeMax - _timeMin);
		preTiltXform[YSCALE] = 2.0f/(_fluxMax - _fluxMin);
		preTiltXform[XSHIFT] = (0-((_timeMax + _timeMin)/(_timeMax - _timeMin)));
		preTiltXform[YSHIFT] = (0-((_fluxMax + _fluxMin)/(_fluxMax - _fluxMin)));
	}
	[self setNeedsDisplay:YES];
}


- (void)drawRect:(NSRect)dirtyRect {
	GLenum lastError;
	[self calcEclipseTime:nil];
	int gateIndex = _gateHighlighted.intValue;
	GLfloat clrs[] = {1.0,1.0,1.0,0.5,1.0,1.0,0.5,1.0,0.5,0.5,0.75,0.75,0.75,0.5,0.75,0.75,0.5,0.75,0.5,0.5};
	double colorFactor = _colorIntensity.doubleValue;
	[super drawRect:dirtyRect];
	BOOL debugPrintP = [_logGateCalcsP boolValue];
    glClearColor(0, 0, 0, 0); // black background
    glClear(GL_COLOR_BUFFER_BIT);
	if (!self.currentStar || ![self.autoDisplayP boolValue]) {
		NSRect bounds = self.bounds;
		double aspectRatio = bounds.size.width/bounds.size.height;
		{
			glColor3f(1.0f, 0.85f, 0.35f);
			glBegin(GL_POLYGON);
			{
				for (int i=0; i<256; i++) {
					glVertex3f(0.6*xStar[i], 0.6*aspectRatio*yStar[i], 0.0);
				}
			}
			glEnd();
			glColor3f(0.0f, 0.0f, 0.0f);
			glBegin(GL_POLYGON);
			{
				for (int i=0; i<256; i++) {
					glVertex3f(0.05*xStar[i]-0.5, 0.05*aspectRatio*yStar[i], 0.0);
				}
			}
			glEnd();
		}
		return;
	}
	
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	lastError = glGetError();
	glLineWidth(1.0f);
	if(1){ // cursor
		glColor3f(1.0f, 1.0f, 1.0f);
		glBegin(GL_LINES);
		glVertex3f(0.0, 1.0, 0.0f);
		glVertex3f(0.0, -1.0, 0.0f);
		glEnd();
		glFlush();
	}
	if (self.bufferedCount==0) return;
	if (_graticuleP) {
		glLineWidth(3.0f);
		glColor3f(1.0f, 1.0f, 1.0f);
		
		if (_verticalGraticuleP) {
			if (_stackGraticuleP) {
				CGFloat red,green,blue,alpha;
				[self.candidateColor getRed:&red green:&green blue:&blue alpha:&alpha];
				glColor3f(red, green, blue);
			}
			glBegin(GL_LINES);
			glVertex3f(0.333, 1.0, 0.0f);
			glVertex3f(0.333, -1.0, 0.0f);
			glEnd();
			glBegin(GL_LINES);
			glVertex3f(-0.333, 1.0, 0.0f);
			glVertex3f(-0.333, -1.0, 0.0f);
			glEnd();
		} else {
			glBegin(GL_LINES);
			glVertex3f(1.0, 0.333, 0.0f);
			glVertex3f(-1.0, 0.333, 0.0f);
			glEnd();
			glBegin(GL_LINES);
			glVertex3f(1.0, -0.333, 0.0f);
			glVertex3f(-1.0, -0.333, 0.0f);
			glEnd();
		}
		glFlush();
	}
	GLdouble period = self.periodNow.doubleValue;
	GLdouble theTimeScale = self.tScaleNow.doubleValue;
	
	// setup the intial scales for x & y
	double xWidth = 0.95f*theTimeScale/2;
	preTiltXform[XSCALE] = xWidth/period; // ratio of the width in screen coords to the width in data coords
	double epochPhase = _epochPhase.doubleValue;
	
	preTiltXform[XSHIFT] = 0; // symmetric after projection back to time zero.
	preTiltXform[YSCALE] = 1.0f;
	preTiltXform[YSHIFT] = 0.0f;
		
	//int k = 0; // used to change the color of data gates
	NSArray *allLightCurves = self.lightCurveController.arrangedObjects;
	NSArray *lightCurves = [allLightCurves filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"visibleP = YES"]];
	//NSEnumerator *curves = [lightCurves reverseObjectEnumerator];
	lastError = glGetError();
	assert(!lastError);
	int subCurve = 0; //sub/superset of curve for a given rev
	if(0){
		_firstRevInData = _timeMin/period;
		_lastRevInData = _timeMax/period;
	} else {
		_firstRevInData = (_timeMin-period/2)/period;
		_firstRevInData = MAX(0,_firstRevInData);
		_lastRevInData = (_timeMax+period/2)/period;
	}
	int countRevsInData = MAX(1,_lastRevInData-_firstRevInData);
	float deltaTilt = _tiltFracNow.doubleValue/countRevsInData;
	_mousePeriodFactor = 1.0f/preTiltXform[XSCALE]/countRevsInData;
	_mouseEpochFactor = 1.0f/xWidth;
	int thisRev = self.revStepper.intValue;
	int n=-1;
	for (KPLightCurve *lightCurve in lightCurves) {
		n++;
		lastError = glGetError();
		assert(!lastError);
		//if (!lightCurve.visibleP) continue;
		keplerData *data = (keplerData *)[lightCurve.kpData.data bytes];
		GLsizeiptr byteCount =lightCurve.sampleCount*sizeof(keplerData);

		// Figure out where periodicities are in light curve
		GLdouble firstCurveTime = lightCurve.timeMin;
		GLdouble lastCurveTime = lightCurve.timeMax;
		GLdouble curveDuration = lastCurveTime - firstCurveTime;
		int firstCurveIndex = lightCurve.timeMinIndex;
		int lastCurveIndex = lightCurve.timeMaxIndex;
		int validSamples = lastCurveIndex - firstCurveIndex;
		GLdouble sampleDuration = curveDuration/validSamples;
		
		// Setup overall scaling
		preTiltXform[YSCALE] = _fluxScaleNow.doubleValue/lightCurve.fluxMedian;
		GLdouble preTilt = preTiltXform[YSHIFT] = -_fluxScaleNow.doubleValue + _fluxOriginNow.doubleValue;
		
		glMatrixMode(GL_MODELVIEW);
		glLoadMatrixd(preTiltXform); //                                 GEOMETRY
		
		// Get buffer on GPU to display
		GLint bufferID = lightCurve.kpData.glBufferID;
		lastError = glGetError();
		assert(!lastError);
		glBindBuffer(GL_ARRAY_BUFFER, bufferID);
		lastError = glGetError();
		assert(!lastError);
		glVertexPointer(2, GL_FLOAT, 0, (void*)offsetof(keplerData,time)); // 0 indicates tightly-packed
		
		// phased => rev shifted to coincide with curve display
		double phasedTimeZero;
		if (OLDPHASE) {
			phasedTimeZero = -(epochPhase + 0.5)*period;
		} else {
			phasedTimeZero = (epochPhase - 0.5)*period;
		}
		int firstPhasedRevInCurve = (firstCurveTime- phasedTimeZero)/period;
		int lastPhasedRevInCurve  = (lastCurveTime - phasedTimeZero)/period;
		_firstRevInData = MIN(_firstRevInData,firstPhasedRevInCurve);
		_lastRevInData = MAX(_lastRevInData, lastPhasedRevInCurve);
		for (int phasedRev = firstPhasedRevInCurve; phasedRev <= lastPhasedRevInCurve; phasedRev++) {
			
			// Geometric transform depends only on rev & user parameters
			double revShift;
			if (OLDPHASE) {
				revShift = -xWidth*(phasedRev - epochPhase);
			} else {
				revShift = -xWidth*(phasedRev + epochPhase);
			}
			GLdouble postTilt=preTilt+(int)(phasedRev-_firstRevInData)*deltaTilt;
			glGetDoublev(GL_MODELVIEW_MATRIX,postTiltXform);
			postTiltXform[YSHIFT] = postTilt;
			postTiltXform[XSHIFT] = revShift;
			glMatrixMode(GL_MODELVIEW);
			glLoadMatrixd(postTiltXform); //                                 GEOMETRY
			
			// color each sub/superset
			if ((subCurve==gateIndex) || (phasedRev==thisRev)) {
				glColor3f(1.0f,1.0f,1.0f);
			} else {
				glColor3f(colorFactor*clrs[phasedRev%20], colorFactor*clrs[(phasedRev+1)%20], colorFactor*clrs[(phasedRev+2)%20]);
			}
			subCurve++;
			
			// Which samples to display for this phased rev
			double timeCenter;
			if (OLDPHASE) {
				timeCenter = period*(phasedRev - epochPhase);
			} else {
				timeCenter = period*(phasedRev + epochPhase);
			}
			double timeBeginRev = timeCenter - period/2;
			double timeEndRev = timeBeginRev + period;
			timeBeginRev = MAX(timeBeginRev, firstCurveTime);
			timeEndRev = MIN(timeEndRev, lastCurveTime);
			int firstIndexToPlot = (timeBeginRev - firstCurveTime)/sampleDuration;
			int lastIndexToPlot = (timeEndRev - firstCurveTime)/sampleDuration;
			int countToPlot = lastIndexToPlot - firstIndexToPlot + 1;
			
			//NSLog(@"Rev:%d:%d-%d",phasedRev,firstIndexToPlot,lastIndexToPlot);
			if(countToPlot<=0) continue;
			// display a batch into current gate
			
			glVertexPointer(2, GL_FLOAT, 0, (void*)offsetof(keplerData,time));
			glEnableClientState(GL_VERTEX_ARRAY);
			GLint kufferID,kufferSize;
			glGetIntegerv(GL_ARRAY_BUFFER_BINDING,&kufferID);
			assert(bufferID == kufferID);
			glGetBufferParameteriv(GL_ARRAY_BUFFER, GL_BUFFER_SIZE, &kufferSize);
			
			keplerData *datum = (data + firstIndexToPlot);
			if(byteCount == kufferSize) {
				glLineWidth(_lineWidth.floatValue);
				if (![_revsToOmit containsIndex:phasedRev]) {
					glDrawArrays(GL_LINE_STRIP, firstIndexToPlot, countToPlot);  //DRAW DATA
				}
				if (_displayEclipsesP.boolValue) {
					glLineWidth(_orbitOverlayWidth.floatValue);
					for (KPOcclusion *occlusion in lightCurve.kpData.kpOcclusions) {
						KPCandidate *orbit = occlusion.kpCandidate;
						glColor3f(orbit.fRed, orbit.fGreen, orbit.fBlue);
						int left = occlusion.indexA;
						int right = occlusion.indexB;
						if (left < lastIndexToPlot && right > firstIndexToPlot) {
							left = MAX(firstIndexToPlot, left);
							right = MIN(lastIndexToPlot, right);
							glDrawArrays(GL_LINE_STRIP, left, 1+right-left); //DRAW ECLIPSE
						}
					}
				}
			} else {
				
				NSLog(@"TROUBLE:b=%d i=%d m=%d %f",lightCurve.kpData.glBufferID,firstIndexToPlot,countToPlot,datum->time);
			}
			glDisableClientState(GL_VERTEX_ARRAY);
			if (debugPrintP) {
				glGetDoublev(GL_MODELVIEW_MATRIX,xBox);
				NSLog(@"b=%d\ti=%d\tm=%d\n%d\t%f\t%f\t%f\t%f\tT=%f\tF=%f",lightCurve.kpData.glBufferID,firstIndexToPlot,countToPlot
					  ,phasedRev,xBox[XSCALE],xBox[XSHIFT],xBox[YSCALE],xBox[YSHIFT],datum->time,datum->flux);
			}
			lastError = glGetError();
			assert(!lastError);
		}
	}
	[_revsTable reloadData];
	if(1){ // eclipse duration cursors
		glLineWidth(1.0f);
		glGetDoublev(GL_MODELVIEW_MATRIX,aBox);
		double ingressInHours = MAX(0.0f, MIN(_eclipseIngress.doubleValue,_eclipseDuration.doubleValue/2));
		double ingressOnScreen = ingressInHours/24.0f*aBox[XSCALE];
		double right = _eclipseDuration.doubleValue/48.0f*aBox[XSCALE];
		double left = -right;
		double rightish = right-ingressOnScreen;
		double leftish = left+ingressOnScreen;
		glColor3f(1.0f, 0.0f, 0.0f);
		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();
		glBegin(GL_LINES);
		glVertex3f(left, 1.0, 0.0f);
		glVertex3f(left, -1.0, 0.0f);
		glEnd();
		glBegin(GL_LINES);
		glVertex3f(right, 1.0, 0.0f);
		glVertex3f(right, -1.0, 0.0f);
		glEnd();
		glBegin(GL_LINES);
		glVertex3f(leftish, 1.0, 0.0f);
		glVertex3f(leftish, -1.0, 0.0f);
		glEnd();
		glBegin(GL_LINES);
		glVertex3f(rightish, 1.0, 0.0f);
		glVertex3f(rightish, -1.0, 0.0f);
		glEnd();
		glFlush();
	}
	if (self.stackP.boolValue && self.stackCurve && self.stackCurve.calcLength>0) {
		// Setup overall scaling
		KIStackCurve *lightCurve = self.stackCurve;
		preTiltXform[YSCALE] = _fluxScaleNow.doubleValue/lightCurve.fluxMedian;
		preTiltXform[YSCALE] *= _stackHeightMultiplier.doubleValue;
		preTiltXform[YSHIFT] = -_fluxScaleNow.doubleValue*_stackHeightMultiplier.doubleValue + _fluxOriginNow.doubleValue;
		preTiltXform[YSHIFT] += _stackUpDown.doubleValue;
		preTiltXform[XSHIFT] = -xWidth*_epochPhase.doubleValue;
		glMatrixMode(GL_MODELVIEW);
		glLoadMatrixd(preTiltXform); //                                 GEOMETRY
		
		// Get buffer on GPU to display
		GLint bufferID = lightCurve.glBufferID;
		lastError = glGetError();
		assert(!lastError);
		glBindBuffer(GL_ARRAY_BUFFER, bufferID);
		lastError = glGetError();
		assert(!lastError);
		glEnableClientState(GL_VERTEX_ARRAY);
		glVertexPointer(2, GL_FLOAT, sizeof(keplerStack), (void*)offsetof(keplerStack,time));
		glLineWidth(_lineWidth.floatValue*3);
		CGFloat red,green,blue,alpha;
		[self.candidateColor getRed:&red green:&green blue:&blue alpha:&alpha];
		glColor3f(red, green, blue);
		int firstDataIndex = lightCurve.calcFirst;
		//int lastDataIndex = firstDataIndex + lightCurve.calcLength -1;
		int firstIndexToPlot = 0;//
		int countToPlot = lightCurve.fullLength;//TODO this may be wrong!
		glDrawArrays(GL_LINE_STRIP, firstIndexToPlot, countToPlot);
		glDisableClientState(GL_VERTEX_ARRAY);
		if (debugPrintP) {
			keplerStack *stk = (keplerStack *) lightCurve.time_flux_mux.bytes;
			keplerStack sB = stk[firstDataIndex];
			glGetDoublev(GL_MODELVIEW_MATRIX,xBox);
			NSLog(@"\nSB=%d\t\t\t\t\t%f\t%f\t%f\t%f\tT=%f\tF=%f",lightCurve.glBufferID,xBox[XSCALE],xBox[XSHIFT],xBox[YSCALE],xBox[YSHIFT],sB.time,sB.flux);
		}
	}
    glFlush();
}


#pragma mark - Mouse interactions

- (NSPoint) fractionalLocation: (NSEvent *) event{
	NSPoint eventLocation = [event locationInWindow];
    NSPoint picked = [self convertPoint:eventLocation fromView:nil];
	NSRect bounds = self.bounds;
	double halfWidth = bounds.size.width/2;
	double halfHeight = bounds.size.height/2;
	double x = (picked.x - halfWidth)/halfWidth;
	double y = (picked.y - halfHeight)/halfHeight;
	return NSMakePoint(x, y);
}
- (void)mouseDown:(NSEvent *)event {
    NSPoint pt = [self fractionalLocation:event];
	NSUInteger modifierFlags = [NSEvent modifierFlags];
	if(modifierFlags & NSFunctionKeyMask){
		_verticalGraticuleP = YES;
		_stackGraticuleP = YES;
	} else if(modifierFlags & NSShiftKeyMask){
		_verticalGraticuleP = YES;
		_stackGraticuleP = NO;
	} else {
		_verticalGraticuleP = NO;
	}
	_graticuleP = YES;
	
	///_xMouseLast =
	_xMouseDown = pt.x;
	///_yMouseLast =
	_yMouseDown = pt.y;
	_preDragFluxOrigin = _fluxOriginNow.doubleValue;
	_preDragFluxScale = _fluxScaleNow.doubleValue;
	_preDragFluxTilt = _tiltFracNow.doubleValue;
	_preDragPeriod = _periodNow.doubleValue;
	_preDragPhase = _epochPhase.doubleValue;
	_preDragTimeScale = _tScaleNow.doubleValue;
	_preDragStackHeightMultiplier = _stackHeightMultiplier.doubleValue;
	_preDragStackUpDown = _stackUpDown.doubleValue;
	_preDragStackWidthInRevs = _stackUpDown.doubleValue;
	//
    //NSLog(@"DOWN:%f %f", pt.x,pt.y);
}
- (void)mouseDragged:(NSEvent *)event {
	NSPoint pt = [self fractionalLocation:event];
	double xMouseNow,yMouseNow;
	xMouseNow = pt.x;
	yMouseNow = pt.y;
	GLdouble xDeltaDrag = xMouseNow - _xMouseDown;
	GLdouble yDeltaDrag = yMouseNow - _yMouseDown;
	///_xShift = _xMouseNow - _xMouseLast;
	///_yShift = _yMouseNow - _yMouseLast;
	NSUInteger modifierFlags = [NSEvent modifierFlags];
	if(modifierFlags & NSFunctionKeyMask)
	{
		if ((_xMouseDown)>0.33) {
			GLdouble newW = _preDragStackWidthInRevs+yDeltaDrag;
			newW = MIN(newW, 0.999);
			newW = MAX(newW, 0.001);
			self.stackWidthInRevs = [NSNumber numberWithDouble:newW];
		} else if ((_xMouseDown)<-0.33){
			self.stackUpDown = [NSNumber numberWithDouble:_preDragStackUpDown+yDeltaDrag];
		} else {
			self.stackHeightMultiplier = [NSNumber numberWithDouble:_preDragStackHeightMultiplier+25*yDeltaDrag];
		}
	}
	else if(modifierFlags & NSShiftKeyMask)
	{
		if ((_xMouseDown)>0.33) {
			self.tiltFracNow = [NSNumber numberWithDouble:_preDragFluxTilt+yDeltaDrag];
		} else if ((_xMouseDown)<-0.33){
			self.fluxOriginNow = [NSNumber numberWithDouble:_preDragFluxOrigin+yDeltaDrag];
		} else {
			self.fluxScaleNow = [NSNumber numberWithDouble:_preDragFluxScale+25*yDeltaDrag];
		}
	}
	else
	{		
		if ((yMouseNow)>0.33) {
			GLdouble period = _preDragPeriod - xDeltaDrag*_mousePeriodFactor;
			self.periodNow = [NSNumber numberWithDouble:period];
		} else if ((yMouseNow)<-0.33){
			GLdouble epochPhase = _preDragPhase - xDeltaDrag*_mouseEpochFactor; //!OLDPHASE
			self.epochPhase = [NSNumber numberWithDouble:epochPhase];
		} else {
			GLdouble tScale = _preDragTimeScale + 10*xDeltaDrag;
			tScale = MAX(tScale, _tScaleMin.doubleValue);
			tScale = MIN(tScale, _tScaleMax.doubleValue);
			self.tScaleNow = [NSNumber numberWithDouble:tScale];
		}
	}
	[self setNeedsDisplay:YES];
    //NSLog(@"DRAGGED:%@", event);
}
- (void)mouseUp:(NSEvent *)event {
	self.periodLocked = self.periodNow;
    self.epochPhaseLocked = self.epochPhase;
	_graticuleP = NO;
	[self setNeedsDisplay:YES];
}


@end
