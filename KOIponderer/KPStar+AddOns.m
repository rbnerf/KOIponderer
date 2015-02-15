//
//  KPStar+AddOns.m
//  KeplerIan
//
//  Created by Richard Nerf on 5/25/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import "KPStar+AddOns.h"
#import "KPLightCurve+AddOns.h"
#import "KPData.h"
#import "KeplerData.h"
#import "KPCandidate.h"

#define OLD_INTERVAL 0.02;

double eclipseByGeometry(double exteriorContactTime, double time, double interiorContactTime){
	if (exteriorContactTime == interiorContactTime) {
		return 0.0;
	}
	double tMid = 0.5*(exteriorContactTime+interiorContactTime);
	double radius = fabs(interiorContactTime - exteriorContactTime)/2;
	double x = fabs(time - tMid)/radius;
	double theta = acos(x);
	double triangle = x * sqrt(1.0f - x*x);
	double ans = theta - triangle;
	ans /= M_PI;
	if (fabs(time-exteriorContactTime)>fabs(time-interiorContactTime)) {
		ans = 1.0f - ans;
	}
	return ans;
}

@implementation KPStar (AddOns)



- (void) fakeOccultationsForCandidate: (KPCandidate *) candidate polarity:(int) polarity {
	double period = candidate.period;
	double epoch = candidate.epoch;
	double duration = candidate.duration/24;
	double halfWidth = duration/2;
	double ingress = candidate.ingress/24;
	//double taper = M_PI/ingress;
	double ppmDepth = polarity*candidate.depth;
	int epochRev = epoch/period;
	double epoch0 = epoch - epochRev*period;
	
	double contact1,contact2,center,contact3,contact4;
	contact1 = contact2 = contact3 = contact4 = center = 0.0; // inhibit warnings
	for (KPLightCurve *lc in self.kpLightCurves) {
		// Need mutable trace data
		NSData *olData = lc.kpData.data;
		NSMutableData *data = [NSMutableData dataWithData:olData];
		keplerData *timeFlux = (keplerData *)data.mutableBytes;
		//
		double depth = ppmDepth*lc.fluxMedian/1000000;
		//double tMin = lc.timeMin;
		//double tMax = lc.timeMax;
		//int firstRev = (tMax+halfWidth)/period;
		int rev = -1;
		//int dips = 0;
		contact4 = rev*period + epoch0 + halfWidth;
		for (int i=0; i<lc.sampleCount; i++) {
			double t = timeFlux[i].time;
			if (isnan(t)) continue;
			while (contact4 < t) {
				//NSLog(@"%d %d",rev,dips);
				rev++;
				center = rev*period + epoch0;
				contact1 = center - halfWidth;
				contact2 = contact1 + ingress;
				contact4 = center + halfWidth;
				contact3 = contact4 - ingress;
				//dips=0;
			}
			double f = timeFlux[i].flux;
			if (isnan(f)) continue;
			double ramp;
			if (contact1<t && t<contact2){
				ramp = depth * eclipseByGeometry(contact1, t, contact2);
				timeFlux[i].flux -= ramp;
				//dips++;
			} else if (contact2<=t && t<= contact3){
				timeFlux[i].flux -= depth;
				//dips++;
			} else if (contact3 < t && t < contact4) {
				double ramp = depth * eclipseByGeometry(contact4, t, contact3);
				timeFlux[i].flux -= ramp;
				//dips++;
			}
		}
		lc.kpData.data = data;
		KPLightCurve *rslc = self.rsLightCurve;
		self.rsLightCurve = nil;
		if (rslc)[self.managedObjectContext deleteObject:rslc];
	}
	
}
- (void) resampleLightCurvesAt:(int)multiplicity using:(KPResamplingMethod)method{
	method = KPLinear;
	switch (method) {
		case KPLinear:
			[self resampleByLinearInterpolationAt:multiplicity];
			break;
		case KPNearest:
			[self resampleByNearestNeighborAt:multiplicity];
			break;
		default:
			[self resampleByNearestNeighborAt:multiplicity];
			break;
	}
}
- (void) resampleByLinearInterpolationAt:(int) multiplicity {
	double oldInterval = OLD_INTERVAL;
	double rsInterval = oldInterval/multiplicity;
	if (self.rsLightCurve) {
		[self.managedObjectContext deleteObject:self.rsLightCurve];
		self.rsLightCurve = nil;
	}
	KPLightCurve *resampledCurves = [NSEntityDescription insertNewObjectForEntityForName:@"KPLightCurve" inManagedObjectContext:self.managedObjectContext];
	self.rsLightCurve = resampledCurves;
	NSSortDescriptor *tMinSorter = [NSSortDescriptor sortDescriptorWithKey:@"timeMin" ascending:YES];
	NSArray *lightCurvesByTime = [self.kpLightCurves sortedArrayUsingDescriptors:@[tMinSorter]];
	
	KPLightCurve *earliestCurve = lightCurvesByTime.firstObject;
	KPLightCurve *latestCurve = lightCurvesByTime.lastObject;
	double rsTimeMin = earliestCurve.timeMin-oldInterval; // Pad each end of resampled curve
	double rsTimeMax = latestCurve.timeMax+oldInterval;
	resampledCurves.fluxMax = resampledCurves.fluxMin = resampledCurves.fluxMedian = resampledCurves.fluxShift = NAN;
	// rs0 indicates a virtual array starting at time zero
	// rs  indicates the actual array created during resampling
	int rs0FirstIndex = floor((rsTimeMin)/rsInterval); // no hiRes samples before first real sample
	int rs0LastIndex = ceil(rsTimeMax/rsInterval);
	int rsSampleCount = rs0LastIndex - rs0FirstIndex + 1;
	resampledCurves.sampleCount = rsSampleCount;
	resampledCurves.timeMinIndex = 0; //TODO verify!
	resampledCurves.timeMaxIndex = rsSampleCount-1;
	resampledCurves.timeMin = rs0FirstIndex*rsInterval;
	resampledCurves.timeMax = rs0LastIndex*rsInterval;
	double rsFirstTime = rs0FirstIndex*rsInterval;
	NSMutableData *rsTimeFluxData = [NSMutableData dataWithLength:rsSampleCount*sizeof(keplerData)];
	keplerData *rsTimeFlux = (keplerData *)[rsTimeFluxData mutableBytes];
	// Initialize with time and NaN's
	for (int i = 0; i<rsSampleCount; i++) {
		rsTimeFlux[i].time = rsFirstTime+i*rsInterval;
		rsTimeFlux[i].flux = NAN;
	}
	
	for (KPLightCurve *lightCurve in lightCurvesByTime) {
		NSData *oldData = lightCurve.kpData.data;
		keplerData *oldTimeFlux = (keplerData *)oldData.bytes;
		double tLeft, tMid, tRight;// = oldTimeFlux[0].time - oldInterval;
		double fluxMedian = lightCurve.fluxMedian;
		double fluxLeft, fluxRight;// = oldTimeFlux[0].flux/fluxMedian;
		//int iLeft = (tLeft-rsFirstTime)/rsInterval;
		//tLeft -= oldInterval/2;
		int nMid, nLeft, nRight; // = (tLeft-rsFirstTime)/rsInterval;
		int iLast = lightCurve.sampleCount-1;
		tLeft = NAN;
		fluxLeft = NAN;
		for (int i = 0; i < iLast; i++) {
			tRight = oldTimeFlux[i].time;
			fluxRight =  oldTimeFlux[i].flux/fluxMedian;
			if (isnan(tLeft)) { // NO LEFT
				if (isnan(tRight)) { // NO LEFT OR RIGHT
					continue;
				} else { // NO LEFT, BUT RIGHT
					tMid = tRight - oldInterval/2;
					nRight = (tRight-rsFirstTime)/rsInterval;
					nMid = (tMid-rsFirstTime)/rsInterval;
					fluxRight = oldTimeFlux[i].flux/fluxMedian;
					for (int n = nMid; n <= nRight; n++) {
						rsTimeFlux[n].flux = fluxRight;
					}
				}
			} else { // LEFT
				if (isnan(tRight)) { // LEFT BUT NO RIGHT
					tMid = tLeft + oldInterval/2;
					nMid = (tMid-rsFirstTime)/rsInterval;
					fluxLeft = oldTimeFlux[i-1].flux/fluxMedian;
					nLeft = (tLeft-rsFirstTime)/rsInterval;
					for (int n = nLeft; n <= nMid; n++) {
						rsTimeFlux[n].flux = fluxLeft;
					}
				} else { // LEFT AND RIGHT
					double deltaT = tRight - tLeft;
					nLeft = (tLeft-rsFirstTime)/rsInterval;
					nRight = (tRight-rsFirstTime)/rsInterval;
					fluxLeft = oldTimeFlux[i-1].flux/fluxMedian;
					fluxRight = oldTimeFlux[i].flux/fluxMedian;
					double deltaF = fluxRight - fluxLeft;
					for (int n=nLeft+1; n<=nRight; n++) {
						double ft = (rsTimeFlux[n].time - tLeft)/deltaT;
						rsTimeFlux[n].flux = ft*deltaF + fluxLeft;
					}
				}
			}
			tLeft = tRight;
		}
	}
	KPData *kpData = [NSEntityDescription insertNewObjectForEntityForName:@"KPData" inManagedObjectContext:self.managedObjectContext];
	kpData.tempData = rsTimeFluxData;
	kpData.dataDescription = @"RESAMPLED(LI):TIME[BJD-2454833]|PDCSAP_FLUX";
	kpData.kpLightCurve = resampledCurves;
}
- (void) resampleByNearestNeighborAt:(int) multiplicity {
	double oldInterval = OLD_INTERVAL;
	double rsInterval = oldInterval/multiplicity;
	KPLightCurve *resampledCurves = [NSEntityDescription insertNewObjectForEntityForName:@"KPLightCurve" inManagedObjectContext:self.managedObjectContext];
	self.rsLightCurve = resampledCurves;
	NSSortDescriptor *tMinSorter = [NSSortDescriptor sortDescriptorWithKey:@"timeMin" ascending:YES];
	NSArray *lightCurvesByTime = [self.kpLightCurves sortedArrayUsingDescriptors:@[tMinSorter]];
	
	KPLightCurve *earliestCurve = lightCurvesByTime.firstObject;
	KPLightCurve *latestCurve = lightCurvesByTime.lastObject;
	double rsTimeMin = earliestCurve.timeMin-oldInterval; // Pad each end of resampled curve
	double rsTimeMax = latestCurve.timeMax+oldInterval;
	resampledCurves.fluxMax = resampledCurves.fluxMin = resampledCurves.fluxMedian = resampledCurves.fluxShift = NAN;
	// rs0 indicates a virtual array starting at time zero
	// rs  indicates the actual array created during resampling
	int rs0FirstIndex = floor((rsTimeMin)/rsInterval); // no hiRes samples before first real sample
	int rs0LastIndex = ceil(rsTimeMax/rsInterval);
	int rsSampleCount = rs0LastIndex - rs0FirstIndex + 1;
	resampledCurves.sampleCount = rsSampleCount;
	resampledCurves.timeMinIndex = 0; //TODO verify!
	resampledCurves.timeMaxIndex = rsSampleCount-1;
	resampledCurves.timeMin = rs0FirstIndex*rsInterval;
	resampledCurves.timeMax = rs0LastIndex*rsInterval;
	double rsFirstTime = rs0FirstIndex*rsInterval;
	NSMutableData *rsTimeFluxData = [NSMutableData dataWithLength:rsSampleCount*sizeof(keplerData)];
	keplerData *rsTimeFlux = (keplerData *)[rsTimeFluxData mutableBytes];
	// Initialize with time and NaN's
	for (int i = 0; i<rsSampleCount; i++) {
		rsTimeFlux[i].time = rsFirstTime+i*rsInterval;
		rsTimeFlux[i].flux = NAN;
	}
	
	for (KPLightCurve *lightCurve in lightCurvesByTime) {
		NSData *oldData = lightCurve.kpData.data;
		keplerData *oldTimeFlux = (keplerData *)oldData.bytes;
		double tLeft, tMid, tRight;// = oldTimeFlux[0].time - oldInterval;
		double fluxMedian = lightCurve.fluxMedian;
		double fluxLeft, fluxRight;// = oldTimeFlux[0].flux/fluxMedian;
		//int iLeft = (tLeft-rsFirstTime)/rsInterval;
		//tLeft -= oldInterval/2;
		int nMid, nLeft, nRight; // = (tLeft-rsFirstTime)/rsInterval;
		int iLast = lightCurve.sampleCount-1;
		tLeft = NAN;
		fluxLeft = NAN;
		for (int i = 0; i < iLast; i++) {
			tRight = oldTimeFlux[i].time;
			fluxRight =  oldTimeFlux[i].flux/fluxMedian;
			if (isnan(tLeft)) { // NO LEFT
				if (isnan(tRight)) { // NO LEFT OR RIGHT
					continue;
				} else { // NO LEFT, BUT RIGHT
					tMid = tRight - oldInterval/2;
					nRight = (tRight-rsFirstTime)/rsInterval;
					nMid = (tMid-rsFirstTime)/rsInterval;
					fluxRight = oldTimeFlux[i].flux/fluxMedian;
				}
				nLeft = -9999;
			} else { // LEFT
				if (isnan(tRight)) { // LEFT BUT NO RIGHT
					tMid = tLeft + oldInterval/2;
					nMid = (tMid-rsFirstTime)/rsInterval;
					nRight = -9999;
					fluxLeft = oldTimeFlux[i-1].flux/fluxMedian;
				} else { // LEFT AND RIGHT
					tMid = (tLeft + tRight)/2;
					nMid = (tMid-rsFirstTime)/rsInterval;
					nRight = (tRight-rsFirstTime)/rsInterval;
					fluxLeft = oldTimeFlux[i-1].flux/fluxMedian;
					fluxRight = oldTimeFlux[i].flux/fluxMedian;
				}
				nLeft = (tLeft-rsFirstTime)/rsInterval;
			}
			if (nLeft>=0) {
				for (int n = nLeft; n <= nMid; n++) {
					rsTimeFlux[n].flux = fluxLeft;
				}
			}
			if (nRight>=0) {
				for (int n = nMid+1; n <= nRight; n++) {
					rsTimeFlux[n].flux = fluxRight;
				}
			}
			tLeft = tRight;
		}
	}
	KPData *kpData = [NSEntityDescription insertNewObjectForEntityForName:@"KPData" inManagedObjectContext:self.managedObjectContext];
	kpData.tempData = rsTimeFluxData;
	kpData.dataDescription = @"RESAMPLED(NN):TIME[BJD-2454833]|PDCSAP_FLUX";
	kpData.kpLightCurve = resampledCurves;
}

@end
