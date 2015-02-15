//
//  FITSFile.m
//  KeplerIan
//
//  Created by Richard Nerf on 4/18/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import "FITSFile.h"
#import "FITSHeaderDataUnit.h"
#define FITSBLK 2880
@implementation FITSFile

- (int) unpackDataBeginningAt: (int) currentBlock {
	// If early part of header, just read block and increment
	// If header contains END card, then calculate and consume DATA blocks, nil out currentHDU, and increment currentBlock
	
	FITSHeaderDataUnit *hdu = self.currentHDU;
	NSRange rng = NSMakeRange(currentBlock*FITSBLK, FITSBLK);
	NSData *blk = [self.data subdataWithRange:rng];
	// header data comes in 80 byte card images
	NSUInteger cardCount = [blk length]/80;
	int currentCard;
	for (currentCard=0; currentCard<cardCount; currentCard++) {
		NSRange rng = NSMakeRange(currentCard*80, 80);
		NSData *card = [blk subdataWithRange:rng];
		BOOL endedP = [hdu unpackCard:card];
		if (endedP) {
			currentBlock++;
			int n = [hdu integerValueFor:@"NAXIS"];
			int len = 1;
			for (int i=1; i<=n; i++) {
				NSString *key = [NSString stringWithFormat:@"NAXIS%d",i];
				int m = [hdu integerValueFor:key];
				len *= m;
			}
			if (n) {
				NSRange dataRange = NSMakeRange(currentBlock*FITSBLK, len);
				hdu.rawData = [self.data subdataWithRange:dataRange];
				int dataBlocks = ceil((double)len/FITSBLK);
				currentBlock += dataBlocks;
			}
			self.currentHDU = nil;
			return currentBlock;
		}
	}
	return 1+currentBlock;
}

- (void) unpackHDUs {
	// FITS data comes in blocks of 2880 bytes
	if (!self.headerAndDataUnits) {
		self.headerAndDataUnits = [NSMutableArray array];
	}
	NSUInteger fileLength = [self.data length];
	NSUInteger blocksInFile = fileLength/FITSBLK;
	
	int currentBlock=0;
	while (currentBlock<blocksInFile) {
		if (!self.currentHDU) {
			self.currentHDU = [[FITSHeaderDataUnit alloc] init];
			[self.headerAndDataUnits addObject:self.currentHDU];
		}
		currentBlock = [self unpackDataBeginningAt:currentBlock];
	}
	self.data = nil;
}

- (id) initWithContentsOfFile:(NSString *) path {
	self = [super init];
	if (self) {
		self.path = path;
		self.data = [NSData dataWithContentsOfFile:path];
		[self unpackHDUs];
	}
	return self;
}

- (id) initWithContentsOfURL:(NSURL *) url {
	self = [super init];
	if (self) {
		self.path = url.absoluteString;
		self.data = [NSData dataWithContentsOfURL:url];
		[self unpackHDUs];
	}
	return self;
}
- (id) initWithContentsOfData:(NSData *) data downloadedFrom: (NSString *) url{
	self = [super init];
	if (self) {
		self.path = url;
		self.data = data;
		[self unpackHDUs];
	}
	return self;
}

@end
