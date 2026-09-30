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

#import <Foundation/NSISO8601DateFormatter.h>
#import <Foundation/NSDateFormatter.h>
#import <Foundation/NSMutableString.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSLocale.h>

// The patterns are fixed by the options, so formatting needs no per-formatter state
// beyond the mask itself.
static NSString *ISO8601Pattern(NSISO8601DateFormatOptions options)
{
	NSISO8601DateFormatOptions effective = options;

	// The full-date form is the internet date time with millisecond precision.
	if (effective & NSISO8601DateFormatWithFullDate)
	{
		effective |= NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
	}

	if ((effective & (NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithWeekDate)) == 0)
	{
		effective |= NSISO8601DateFormatWithInternetDateTime;
	}

	NSString *date;
	if (effective & NSISO8601DateFormatWithWeekDate)
	{
		// Week dates count weeks from the first week that has a Thursday in it.
		date = (effective & NSISO8601DateFormatWithDashSeparatorInDate)
			? @"YYYY-'W'ww-e"
			: @"YYYY'W'ww'e";
	}
	else
	{
		date = (effective & NSISO8601DateFormatWithDashSeparatorInDate)
			? @"yyyy-MM-dd"
			: @"yyyyMMdd";
	}

	NSString *separator = (effective & NSISO8601DateFormatWithSpaceSeparator) ? @" " : @"'T'";

	NSString *time = (effective & NSISO8601DateFormatWithColonSeparatorInTime) ? @"HH:mm:ss" : @"HHmmss";

	NSMutableString *pattern = [NSMutableString stringWithFormat:@"%@%@%@", date, separator, time];

	if (effective & NSISO8601DateFormatWithFractionalSeconds)
	{
		[pattern appendString:@".SSS"];
	}

	// ZZZZZ keeps the colon in the zone offset; the shorter patterns drop it.
	if (effective & NSISO8601DateFormatWithColonSeparatorInTimeZone)
	{
		[pattern appendString:@"ZZZZZ"];
	}
	else
	{
		[pattern appendString:@"Z"];
	}

	return pattern;
}

static NSDateFormatter *ISO8601Formatter(NSISO8601DateFormatOptions options, NSTimeZone *timeZone)
{
	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	// A fixed locale keeps the numeric fields independent of the user's region.
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
	[formatter setDateFormat:ISO8601Pattern(options)];
	if (timeZone)
	{
		[formatter setTimeZone:timeZone];
	}
	return formatter;
}

@implementation NSISO8601DateFormatter

- (instancetype)init
{
	self = [super init];
	if (self)
	{
		_options = NSISO8601DateFormatWithInternetDateTime;
	}
	return self;
}

- (void)dealloc
{
	[_timeZone release];
	[super dealloc];
}

- (NSISO8601DateFormatOptions)formatOptions
{
	return _options;
}

- (void)setFormatOptions: (NSISO8601DateFormatOptions) formatOptions
{
	_options = formatOptions;
}

- (NSTimeZone *)timeZone
{
	return _timeZone;
}

- (void)setTimeZone: (NSTimeZone *) timeZone
{
	[_timeZone release];
	_timeZone = [timeZone retain];
}

- (NSString *)stringFromDate: (NSDate *) date
{
	if (!date)
	{
		return nil;
	}
	return [ISO8601Formatter(_options, _timeZone) stringFromDate:date];
}

- (NSDate *)dateFromString: (NSString *) string
{
	if (!string)
	{
		return nil;
	}
	return [ISO8601Formatter(_options, _timeZone) dateFromString:string];
}

+ (NSString *)stringFromDate: (NSDate *) date timeZone: (NSTimeZone *) timeZone formatOptions: (NSISO8601DateFormatOptions) options
{
	if (!date)
	{
		return nil;
	}
	return [ISO8601Formatter(options, timeZone) stringFromDate:date];
}

- (instancetype)initWithCoder: (NSCoder *) aDecoder
{
	return [self init];
}

- (void)encodeWithCoder: (NSCoder *) aCoder
{
}

- (BOOL)supportsSecureCoding
{
	return YES;
}

@end
