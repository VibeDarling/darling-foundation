/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful, but WITHOUT
 ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <Foundation/NSFormatter.h>

@class NSDate, NSTimeZone;

typedef NS_ENUM(NSUInteger, NSISO8601DateFormatOptions) {
	NSISO8601DateFormatWithInternetDateTime = 1 << 0,
	NSISO8601DateFormatWithWeekDate = 1 << 1,
	NSISO8601DateFormatWithFullDate = 1 << 2,
	NSISO8601DateFormatWithDashSeparatorInDate = 1 << 4,
	NSISO8601DateFormatWithColonSeparatorInTime = 1 << 5,
	NSISO8601DateFormatWithColonSeparatorInTimeZone = 1 << 6,
	NSISO8601DateFormatWithSpaceSeparator = 1 << 7,
	NSISO8601DateFormatWithFractionalSeconds = 1 << 8,
};

@interface NSISO8601DateFormatter : NSFormatter <NSSecureCoding> {
	NSISO8601DateFormatOptions _options;
	NSTimeZone *_timeZone;
}

@property NSISO8601DateFormatOptions formatOptions;
@property (retain) NSTimeZone *timeZone;

- (NSString *)stringFromDate: (NSDate *) date;
- (NSDate *)dateFromString: (NSString *) string;
+ (NSString *)stringFromDate: (NSDate *) date timeZone: (NSTimeZone *) timeZone formatOptions: (NSISO8601DateFormatOptions) options;

@end
