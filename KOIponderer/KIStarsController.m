//
//  KIStarsController.m
//  KeplerIan
//
//  Created by Richard Nerf on 6/9/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import "KIStarsController.h"
#import "KPStar.h"
#import "KPLightCurve+AddOns.h"
#import "KDWindowController.h"
#import "KPCandidate.h"
#import "KPOcclusion.h"


@implementation KIStarsController

- (void)add:(NSControl *)sender {
	_lastTag = sender.tag;
	[super add:sender];
	//NSUInteger theIndex = self.selectionIndex;
	//NSLog(@"STAR ADDED at %lu", theIndex);
}
- (id) newObject {
	self.star = [super newObject];
	switch (_lastTag) {
		case 1:
			[self loadCurvesFromFilesystem];
			break;
			
		case 2:
			[self loadCurvesFromDownload];
			break;
			
		default:
			break;
	}
	//NSLog(@"%ld NEW STAR:%@",_lastTag,self.star);
	return self.star;
}
- (void)insert:(id)sender {
	[super insert:sender];
	//NSLog(@"STAR INSERTED");
}
- (void) loadCurvesFromDownload {
	if (!_downloadWindowController) {
		self.downloadWindowController = [[KDWindowController alloc] init];
		_downloadWindowController.delegate = self;
	} else {
		[_downloadWindowController.kidSearchField setEnabled:YES];
	}
	[_downloadWindowController showWindow:self];
}
- (void) processFITSDataDict:(NSDictionary *)dataDict{
	NSManagedObjectContext *moc = self.managedObjectContext;
	BOOL firstP = YES;
	for (NSString *key in dataDict) {
		if (firstP) {
			firstP = NO;
			self.star.dataPath = [key stringByDeletingLastPathComponent];
			self.star.id = self.star.dataPath.lastPathComponent;
			self.star.name = self.star.id;
		}
		NSData *data = [dataDict valueForKey:key];
		KPLightCurve *curve = [NSEntityDescription insertNewObjectForEntityForName:@"KPLightCurve" inManagedObjectContext:moc];
		curve.kpStar = self.star;
		curve = [curve initFromData:data downloadedFrom:key];
	}
	for (KPCandidate *pick in self.star.kpCandidates) {
		double period = pick.period;
		double epoch = pick.epoch;
		int epochRev = epoch/period;
		double epoch0 = epoch - epochRev*period;
		for (KPLightCurve *crv in self.star.kpLightCurves) {
			if (crv.visibleP) {  // Only going to deal with curves visible on screen
				double tMin = crv.timeMin;
				double tMax = crv.timeMax;
				double halfWidth = pick.duration/48;
				double epochMin = epoch0-halfWidth;  // limits at gate 0, ignoring gate shorter than duration
				double epochMax = epoch0+halfWidth;
				int revFirst = floor(tMin/period);
				int revLast = ceil(tMax/period);
				GLdouble curveDuration = tMax-tMin;
				int bufferLength = crv.sampleCount;
				GLdouble sampleDuration = curveDuration/bufferLength;
				for (int rev=revFirst; rev<=revLast; rev++) {
					// Occultation visible if tMin/gate < right occult
					// and tMax/gate > left occult
					double tMinEpoch = tMin - rev*period;
					double tMaxEpoch = tMax - rev*period;
					if ((tMinEpoch <= epochMax) && (tMaxEpoch >= epochMin)) {
						double occLeft = epochMin + rev*period;
						double occRight = epochMax + rev*period;
						int indexLeft = floor((occLeft - tMin)/sampleDuration);
						indexLeft = MAX(indexLeft, 0);
						int indexRight = ceil((occRight - tMin)/sampleDuration);
						indexRight = MIN(indexRight, bufferLength);
						// TODO refine indexLeft and indexRight by checking sample times
						KPOcclusion *occlusion = [NSEntityDescription insertNewObjectForEntityForName:@"KPOcclusion" inManagedObjectContext:self.star.managedObjectContext];
						occlusion.kpCandidate = pick;
						occlusion.indexA = indexLeft;
						occlusion.indexB = indexRight-1; //KLUDGE
						occlusion.kpData = crv.kpData;
						occlusion.gate = rev;
					}
				}
			}
		}
	}
}
- (void)loadCurvesFromFilesystem {
	KPStar *star = self.star;
	NSOpenPanel *oPanel = [NSOpenPanel openPanel];
	
	[oPanel setAllowsMultipleSelection:NO];
	[oPanel setCanChooseDirectories:YES];
	[oPanel setCanChooseFiles:NO];
	//[oPanel setAllowedFileTypes:@[@"fits"]];
	[oPanel beginWithCompletionHandler:^(NSInteger result){
		if (result == NSFileHandlingPanelOKButton) {
			NSManagedObjectContext *moc = self.managedObjectContext;
			NSURL *url = [[oPanel URLs] lastObject];
			NSString *path = url.absoluteString;
			[star setPrimitiveValue:path forKey:@"dataPath"];
			[star setPrimitiveValue:path.lastPathComponent forKey:@"name"];
			NSFileManager *mgr = [NSFileManager defaultManager];
			NSArray *fileURLs = [mgr contentsOfDirectoryAtURL:url includingPropertiesForKeys:nil options:0 error:nil];
			BOOL firstP=YES;
			for (NSURL *fileURL in fileURLs) {
				NSString *file = fileURL.absoluteString;
				if ([file hasSuffix:@"llc.fits"] ) {
					if (firstP) {
						firstP=NO;
						NSString *fn = file.lastPathComponent;
						NSString *fid = [fn substringWithRange:NSMakeRange(4, 9)];
						star.id = fid;
					}
					KPLightCurve *curve = [NSEntityDescription insertNewObjectForEntityForName:@"KPLightCurve" inManagedObjectContext:moc];
					curve.kpStar = star;
					curve = [curve initFromLocalFITS:fileURL];
				}
			}
		}
	}];
}
- (IBAction)removeLightCurves:(id)sender{
	for (KPStar *star in self.selectedObjects) {
		star.dataPath=nil;
		for (KPLightCurve *crv in star.kpLightCurves) {
			[self.managedObjectContext deleteObject:crv];
		}
	}
}
- (IBAction)populateSelectedStar:(id)sender {
	if (!_downloadWindowController) {
		self.downloadWindowController = [[KDWindowController alloc] init];
		_downloadWindowController.delegate = self;
	}
	[_downloadWindowController showWindow:self];
	NSArray *selections = self.selectedObjects;
	KPStar *star = selections.lastObject;
	self.star = star;
	[self removeLightCurves:nil];
	//[star addObserver:self forKeyPath:@"kpLightCurves" options:0 context:nil];
	[_downloadWindowController loadCurvesForKeplerID:star.id];
	
}
/*- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	NSLog(@"%@",keyPath);
}*/
@end
