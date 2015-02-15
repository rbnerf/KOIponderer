//
//  FITSHeaderDataUnit.m
//  KeplerIan
//
//  Created by Richard Nerf on 4/18/14.
//  Copyright (c) 2014 Richard Nerf. All rights reserved.
//

#import "FITSHeaderDataUnit.h"
#import "FITSCard.h"

@implementation FITSHeaderDataUnit
- (id) init {
	self = [super init];
	if (self) {
		self.header = [NSMutableDictionary dictionary];
	}
	return self;
}

- (NSString *) name {
	return [self.header objectForKey:@"EXTNAME"];
}

- (BOOL) unpackCard:(NSData *) cardImage {
	
	NSString *card = [[NSString alloc] initWithBytes:cardImage.bytes length:cardImage.length encoding:NSASCIIStringEncoding];
	NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];
	//NSLog(@"%@",card);
	NSRange wholeCard = NSMakeRange(0, card.length);
	NSString *keyword = [card substringToIndex:8];
	keyword = [keyword stringByTrimmingCharactersInSet:whitespace];
	if ([keyword isEqualToString:@"END"]) {
		return YES;
	}
	NSError *error;
	NSString *pattern;
	//pattern = @"^([A-Z0-9_-]+) *(= ) *(.*)/(.+)$";
	//KLUDGE
	if ([card rangeOfString:@"'"].length) { // quoted string
		pattern = @"^([A-Z0-9_-]+) *(= ) *('[^']+') */(.+)$";
	} else {
		pattern = @"^([A-Z0-9_-]+) *(= ) *([^/]*)/(.+)$";
	}
	NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
	NSArray *matches = [regexp matchesInString:card options:0 range:wholeCard];
	NSTextCheckingResult *match = matches.firstObject;
	if (!match) {
		NSLog(@"UNABLE TO PARSE\n|%@|",card);
		return NO;
	}
	// Should parsing occur here or within the FITSCard object?
	FITSCard *cardItem = [[FITSCard alloc] init];
	cardItem.keyword = keyword;
	NSRange r = [match rangeAtIndex:4];
	NSString *raw = [card substringWithRange:r];
	cardItem.comment = [raw stringByTrimmingCharactersInSet:whitespace];
	r = [match rangeAtIndex:3];
	raw = [card substringWithRange:r];
	raw = [raw stringByTrimmingCharactersInSet:whitespace];
	if([raw hasPrefix:@"'"]){
		raw = [raw substringWithRange:NSMakeRange(1, raw.length-2)];
		raw = [raw stringByTrimmingCharactersInSet:whitespace];
		cardItem.value = raw;
	} else if ([raw isEqualToString:@"T"]){
		cardItem.value = [NSNumber numberWithBool:YES];
	} else if ([raw isEqualToString:@"F"]){
		cardItem.value = [NSNumber numberWithBool:NO];
	} else if ([raw rangeOfString:@"."].length){
		double doubleVal = [raw doubleValue];
		cardItem.value = [NSNumber numberWithDouble:doubleVal];
	} else {
		int intValue = [raw intValue];
		cardItem.value = [NSNumber numberWithInt:intValue];
	}
	[self.header setObject:cardItem forKey:keyword];
	return NO;
}

- (int) integerValueFor:(NSString *) key{
	FITSCard *cardItem = [self.header objectForKey:key];
	assert(cardItem);
	NSNumber *num = cardItem.value;
	assert(num);
	return  num.intValue;
}
- (NSString *) stringValueFor:(NSString *) key{
	FITSCard *cardItem = [self.header objectForKey:key];
	assert(cardItem);
	return cardItem.value;
}
@end
