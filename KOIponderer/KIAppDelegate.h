//
//  KIAppDelegate.h
//  KeplerIan
//
//  Created by Richard Nerf on 4/13/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class KIGLView, KDWindowController;

@interface KIAppDelegate : NSObject <NSApplicationDelegate>

#pragma mark - IBOutlets

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet KIGLView *keplerGLView;
@property (weak) IBOutlet NSArrayController *lightCurveController;
@property (weak) IBOutlet NSArrayController *orbitController;
@property (weak) IBOutlet NSArrayController *starController;


@property (strong) NSPredicate *hasLightCurvesP;

#pragma mark - CoreData

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (assign) BOOL needToInitializeDBP;

#pragma mark - IBActions

- (IBAction)saveAction:(id)sender;
- (IBAction)readKOIsAsCSV:(id)sender;
- (IBAction)deleteResampledCurves:(id)sender;
- (BOOL) validateMenuItem:(NSMenuItem *)menuItem;

@end
