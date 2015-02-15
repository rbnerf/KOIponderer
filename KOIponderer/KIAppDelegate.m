//
//  KIAppDelegate.m
//  KOIponderer
//
//  Created by Richard Nerf on 4/13/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import "KIAppDelegate.h"
#import "FITSFile.h"

#import "KIGLView.h"
#import "KDWindowController.h"
#import "KPStar.h"
#import "KPCandidate.h"
#import "KPLightCurve.h"

@implementation KIAppDelegate

@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize managedObjectContext = _managedObjectContext;

#pragma mark - Initialization

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSSortDescriptor *sortOnTimeMin = [NSSortDescriptor sortDescriptorWithKey:@"timeMin" ascending:YES];
	self.lightCurveController.sortDescriptors = @[sortOnTimeMin];
	self.hasLightCurvesP = [NSPredicate predicateWithFormat:@"kpLightCurves.@count > 0"];
	
	NSSortDescriptor *sortOnPeriod = [NSSortDescriptor sortDescriptorWithKey:@"period" ascending:YES];
	self.orbitController.sortDescriptors = @[sortOnPeriod];
	
	NSSortDescriptor *sortOnKOI = [NSSortDescriptor sortDescriptorWithKey:@"koiID" ascending:YES];
	NSSortDescriptor *sortOnCandidateCount = [NSSortDescriptor sortDescriptorWithKey:@"kpCandidates.@count" ascending:NO];
	self.starController.sortDescriptors = @[sortOnCandidateCount,sortOnKOI];
	if (_needToInitializeDBP) {
		NSURL* url = [[NSBundle mainBundle] URLForResource:@"KOIs" withExtension:@"csv"];
		NSLog(@"%@",url);
		[self readKOIcsvFromURL:url];
	}
	
}
#pragma mark CoreData
// Returns the directory the application uses to store the Core Data store file. This code uses a directory named "com.gnerph.KOIponderer" in the user's Application Support directory.
- (NSURL *)applicationFilesDirectory
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *appSupportURL = [[fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
    return [appSupportURL URLByAppendingPathComponent:@"com.gnerph.KOIponderer"];
}

// Creates if necessary and returns the managed object model for the application.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel) {
        return _managedObjectModel;
    }
	
    NSURL *modelDirURL = [[NSBundle mainBundle] URLForResource:@"KOIponderer" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelDirURL];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.)
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator) {
        return _persistentStoreCoordinator;
    }
    
    NSManagedObjectModel *mom = [self managedObjectModel];
    if (!mom) {
        NSLog(@"%@:%@ No model to generate a store from", [self class], NSStringFromSelector(_cmd));
        return nil;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *applicationFilesDirectory = [self applicationFilesDirectory];
    NSError *error = nil;
    
    NSDictionary *properties = [applicationFilesDirectory resourceValuesForKeys:@[NSURLIsDirectoryKey] error:&error];
    
    if (!properties) {
        BOOL ok = NO;
        if ([error code] == NSFileReadNoSuchFileError) {
            ok = [fileManager createDirectoryAtPath:[applicationFilesDirectory path] withIntermediateDirectories:YES attributes:nil error:&error];
			_needToInitializeDBP = ok;
        }
        if (!ok) {
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    } else {
        if (![properties[NSURLIsDirectoryKey] boolValue]) {
            // Customize and localize this error.
            NSString *failureDescription = [NSString stringWithFormat:@"Expected a folder to store application data, found a file (%@).", [applicationFilesDirectory path]];
            
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            [dict setValue:failureDescription forKey:NSLocalizedDescriptionKey];
            error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:101 userInfo:dict];
            
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    }
    
    NSURL *url = [applicationFilesDirectory URLByAppendingPathComponent:@"KOIponderer.sqlite"];
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
							 [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
							 [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
    if (![coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:url options:options error:&error]) {
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    _persistentStoreCoordinator = coordinator;
    
    return _persistentStoreCoordinator;
}

// Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) 
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:@"Failed to initialize the store" forKey:NSLocalizedDescriptionKey];
        [dict setValue:@"There was an error building up the data file." forKey:NSLocalizedFailureReasonErrorKey];
        NSError *error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];

    return _managedObjectContext;
}

// Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
    return [[self managedObjectContext] undoManager];
}
- (BOOL) validateMenuItem:(NSMenuItem *)menuItem { // For Save MenuItem
	//NSLog(@"MENU VALIDATION");
	if ([_managedObjectContext hasChanges]) {
		return YES;
	}
	return NO;
}
// Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
- (IBAction)saveAction:(id)sender
{
    NSError *error = nil;
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
    }
    
    if (![[self managedObjectContext] save:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }
}

#pragma mark - Termination

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    // Save changes in the application's managed object context before the application terminates.
    
    if (!_managedObjectContext) {
        return NSTerminateNow;
    }
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
        return NSTerminateCancel;
    }
    
    if (![[self managedObjectContext] hasChanges]) {
        return NSTerminateNow;
    }
    
    NSError *error = nil;
    if (![[self managedObjectContext] save:&error]) {

        // Customize this code block to include application-specific recovery steps.              
        BOOL result = [sender presentError:error];
        if (result) {
            return NSTerminateCancel;
        }

        NSString *question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];

        NSInteger answer = [alert runModal];
        
        if (answer == NSAlertAlternateReturn) {
            return NSTerminateCancel;
        }
    }

    return NSTerminateNow;
}

#pragma mark - Utility: initialization of KOI Core Data

- (IBAction)readKOIsAsCSV:(id)sender{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	panel.allowsMultipleSelection = YES;
	panel.canChooseDirectories = NO;
	panel.canChooseFiles = YES;
	panel.allowedFileTypes = @[@"csv",@"tsv"];
	[panel beginWithCompletionHandler:^(NSInteger result){
		if (result == NSFileHandlingPanelOKButton) {
			NSArray *urls = [panel URLs];
			for (NSURL *url in urls) {
				[self readKOIcsvFromURL:url];
			}
		}
	}];
}
- (void) readKOIcsvFromURL:(NSURL *)url {
	NSArray *colors = @[[NSColor orangeColor],[NSColor yellowColor],[NSColor greenColor],
						[NSColor blueColor], [NSColor purpleColor], [NSColor magentaColor]];
	NSUInteger colorCount = colors.count;
	NSArray *keys = @[@"koiID",
					  @"disposition",
					  @"period",
					  @"epoch",
					  @"duration",
					  @"depth",
					  @"ingress",
					  @"impact",
					  @"starID"];
				
	NSString *contents = [NSString stringWithContentsOfURL:url encoding:NSASCIIStringEncoding error:nil];
	NSArray *lines = [contents componentsSeparatedByString:@"\n"];
	BOOL skipColumnNamesP = YES;
	KPStar *lastStar;
	int n=0;
	for (NSString *line in lines) {
		if (skipColumnNamesP) {
			skipColumnNamesP = NO;
			continue;
		}
		n++;
		NSArray *columns = [line componentsSeparatedByString:@","];
		if (columns.count != keys.count) {
			NSLog(@"Skipping at csv:%d",n);
			continue;
		}
		NSDictionary *values = [NSDictionary dictionaryWithObjects:columns forKeys:keys];
		KPCandidate *orbit = [NSEntityDescription insertNewObjectForEntityForName:@"KPCandidate" inManagedObjectContext:_managedObjectContext];
		orbit.koiID = [values valueForKey:@"koiID"];
		orbit.disposition = [values valueForKey:@"disposition"];
		orbit.period = [[values valueForKey:@"period"] floatValue];
		orbit.epoch = [[values valueForKey:@"epoch"] floatValue];
		orbit.duration = [[values valueForKey:@"duration"] floatValue];
		orbit.depth = [[values valueForKey:@"depth"] floatValue];
		orbit.ingress = [[values valueForKey:@"ingress"] floatValue];
		orbit.impact = [[values valueForKey:@"impact"] floatValue];
		orbit.starID = [values valueForKey:@"starID"];
		if (![orbit.starID isEqualToString:lastStar.id]) {
			lastStar = [NSEntityDescription insertNewObjectForEntityForName:@"KPStar" inManagedObjectContext:_managedObjectContext];
			lastStar.id = orbit.starID;
			lastStar.koiID = lastStar.name = [orbit.koiID substringToIndex:6];
		}
		orbit.kpStar = lastStar;
		long koiIndex = [[orbit.koiID substringFromIndex:8] integerValue]-1;
		NSColor *theColor = [colors objectAtIndex:koiIndex%colorCount];
		orbit.fRed = theColor.redComponent;
		orbit.fGreen = theColor.greenComponent;
		orbit.fBlue = theColor.blueComponent;
	}
}

#pragma mark - NSValidatedUserInterfaceItem Protocol

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
    SEL theAction = [anItem action];
	
    if (theAction == @selector(saveAction:)) {
                    return YES;
	}
	return NO;
}

# pragma mark - DB Garbage Collection

- (IBAction)deleteResampledCurves:(id)sender{
	NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"KPLightCurve"];
	NSPredicate *noKPStar = [NSPredicate predicateWithFormat:@"kpStar == NULL"];
	fetch.predicate = noKPStar;
	NSError *error;
	NSArray * lcs = [self.managedObjectContext executeFetchRequest:fetch error:&error];
	NSLog (@"%lu resampled curves",(unsigned long)lcs.count);
	for (KPLightCurve *lc in lcs) {
		[self.managedObjectContext deleteObject:lc];
	}
}
@end
