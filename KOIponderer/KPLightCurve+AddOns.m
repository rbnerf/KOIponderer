//
//  KPLightCurve+AddOns.m
//  KeplerIan
//
//  Created by Richard Nerf on 5/25/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//
#import "FITSFile.h"
#import "FITSHeaderDataUnit.h"
#import "KeplerData.h"
#import "KPLightCurve+AddOns.h"
#import "KPData.h"

@implementation KPLightCurve (AddOns)

- (double) doubleSwappedFrom:(double *) rawData{
	NSSwappedDouble ovalue = NSConvertHostDoubleToSwapped(*rawData);
	NSSwappedDouble nvalue = NSSwapDouble(ovalue);
	double swvalue = NSConvertSwappedDoubleToHost(nvalue);
	return swvalue;
}
- (float) floatSwappedFrom:(float *) rawData{
	NSSwappedFloat ovalue = NSConvertHostFloatToSwapped(*rawData);
	NSSwappedFloat nvalue = NSSwapFloat(ovalue);
	float swvalue = NSConvertSwappedFloatToHost(nvalue);
	return swvalue;
}
- (id) initFromLocalFITS: (NSURL*) url {
	self.fileName = url.absoluteString.lastPathComponent;
	FITSFile *fitsFile = [[FITSFile alloc] initWithContentsOfURL:url];
	[self initFromFITS:fitsFile];
	return self;
}
- (id) initFromData: (NSData *) data downloadedFrom:(NSString *) urlString {
	self.fileName = urlString.lastPathComponent;
	FITSFile *fitsFile = [[FITSFile alloc] initWithContentsOfData:data downloadedFrom:urlString];
	[self initFromFITS:fitsFile];
	return self;
}
- (void) initFromFITS: (FITSFile *) fitsFile {
	FITSHeaderDataUnit *hdu = [fitsFile.headerAndDataUnits objectAtIndex:1]; //TODO: Generalize
	assert([[hdu stringValueFor:@"XTENSION"] isEqualToString:@"BINTABLE"]);
	assert([[hdu stringValueFor:@"EXTNAME"] isEqualToString:@"LIGHTCURVE"]);
	assert([[hdu stringValueFor:@"TTYPE1"] isEqualToString:@"TIME"]);
	assert([[hdu stringValueFor:@"TTYPE4"] isEqualToString:@"SAP_FLUX"]);
	assert([[hdu stringValueFor:@"TTYPE8"] isEqualToString:@"PDCSAP_FLUX"]);
	int fluxOffset = 16;
	fluxOffset = 32;
	int record = [hdu integerValueFor:@"NAXIS1"];
	assert(record);
	self.sampleCount = [hdu integerValueFor:@"NAXIS2"];
	assert(self.sampleCount);
	char *rawData = (char *)hdu.rawData.bytes;
	// Trim leading and trailing NaN time samples
	int iFirst=-1;
	int iLast=-1;
	for (int i=0; i<self.sampleCount; i++){
		double swtime = [self doubleSwappedFrom:(double *)rawData];
		if (!isnan(swtime)) {
			if (iLast<0) {
				iFirst = i;
			}
			iLast = i;
		}
		rawData+=record;
	}
	rawData = (char *)hdu.rawData.bytes;
	int _length = iLast-iFirst+1;
	self.sampleCount = _length;
	NSMutableData *time_flux = [NSMutableData dataWithLength:_length*sizeof(keplerData)];
	keplerData *data = (keplerData *)[time_flux mutableBytes];
	double _fluxMin,_fluxMax,_timeMin,_timeMax;
	_fluxMin = _timeMin = DBL_MAX;
	_fluxMax = _timeMax = -DBL_MAX;
	GLfloat* toSort = calloc(_length,sizeof(GLfloat));
	GLfloat* fillSort = toSort;
	keplerData *datum;
	int nanCountFlux = 0;
	int nanCountTime = 0;
	int firstValidTime = self.sampleCount+1;
	int lastValidTime = -1;
	for (int i=0; i<self.sampleCount; i++) {
		if(i<iFirst) {rawData+=record; continue;}
		if(i>iLast) break;
		double swtime = [self doubleSwappedFrom:(double *)rawData];
		if (isnan(swtime)) {
			nanCountTime++;
		} else {
			firstValidTime = MIN(firstValidTime,i);
			lastValidTime = MAX(lastValidTime, i);
		}
		float swflux = [self floatSwappedFrom:(float *)(rawData+fluxOffset)];
		//swflux-=[self floatSwappedFrom:(float *)(rawData+16)]; //PDC correction
		datum = data++;
		if (isnan(swflux)) {
			nanCountFlux++;
		} else {
			*fillSort = swflux;
			fillSort++;
		}
		datum->time = swtime;
		datum->flux = swflux;
		_timeMin = fmin(_timeMin, swtime);
		_timeMax = fmax(_timeMax, swtime);
		_fluxMin = fmin(_fluxMin, swflux);
		_fluxMax = fmax(_fluxMax, swflux);
		rawData+=record;
	}
//	if (nanCountTime!=0) {
//		NSLog(@"NANs: %d %d of %d:%d",nanCountTime,nanCountFlux, _length,self.sampleCount);
//	}
	NSManagedObjectContext *moc = self.managedObjectContext;
	KPData *kpData = [NSEntityDescription insertNewObjectForEntityForName:@"KPData" inManagedObjectContext:moc];
	kpData.data = time_flux;
	kpData.dataDescription = @"TIME[BJD-2454833]|PDCSAP_FLUX";
	kpData.kpLightCurve = self;
	qsort_b(toSort, _length-nanCountFlux, sizeof(GLfloat),^(const void *a,const void *b) {
		GLfloat *aa = (GLfloat *)a;
		GLfloat *bb = (GLfloat *)b;
		if (*aa>*bb) {
			return 1;
		} else if(*aa==*bb) {
			return 0;
		} else {
			return -1;
		}
	});
	self.fluxMedian = *(toSort+((_length-nanCountFlux)/2));
	self.timeMin = _timeMin;
	self.timeMax = _timeMax;
	self.fluxMax = _fluxMax;
	self.fluxMin = _fluxMin;
	self.timeMinIndex = firstValidTime;
	self.timeMaxIndex = lastValidTime;
	free(toSort);
}
@end
