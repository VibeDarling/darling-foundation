#import "FoundationSupplementBridge.h"
@implementation NSSortDescriptor (DarlingSwiftSupplement)
- (instancetype)initWithDarlingKVCKeyUTF8:(const char *)key ascendingInt:(int)ascending {
    return [self initWithKey:[NSString stringWithUTF8String:key] ascending:ascending != 0];
}
- (instancetype)initWithDarlingKVCKeyUTF8:(const char *)key ascendingInt:(int)ascending comparator:(NSComparator)comparator {
    return [self initWithKey:[NSString stringWithUTF8String:key] ascending:ascending != 0 comparator:comparator];
}
@end

#include <darling-boundary-diagnostics.h>
void DarlingFoundationSortRejectedKeyPath(void) {
    static const char event[] = "foundation.sort.invalid-keypath\n";
    darling_diagnostic_send(getenv("DARLING_BOUNDARY_SOCKET"), event, sizeof(event)-1);
}

char *DarlingFoundationFormatDate(double time, int dateStyle, int timeStyle) {
    @autoreleasepool {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = (NSDateFormatterStyle)dateStyle;
        formatter.timeStyle = (NSDateFormatterStyle)timeStyle;
        NSString *text = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:time]];
        [formatter release];
        return strdup(text.UTF8String ?: "");
    }
}

// The date relative to now in its largest whole unit: "in 3 hours", "2 days ago".
char *DarlingFoundationFormatRelativeDate(double time, int named, int width) {
    static const struct {
        NSCalendarUnit unit;
        const char *wide, *abbreviated, *next, *last;
    } units[] = {
        { NSCalendarUnitYear, "year", "yr.", "next year", "last year" },
        { NSCalendarUnitMonth, "month", "mo.", "next month", "last month" },
        { NSCalendarUnitWeekOfMonth, "week", "wk.", "next week", "last week" },
        { NSCalendarUnitDay, "day", "day", "tomorrow", "yesterday" },
        { NSCalendarUnitHour, "hour", "hr.", NULL, NULL },
        { NSCalendarUnitMinute, "minute", "min.", NULL, NULL },
        { NSCalendarUnitSecond, "second", "sec.", NULL, NULL },
    };
    @autoreleasepool {
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSCalendarUnit all = 0;
        for (size_t i = 0; i < sizeof(units) / sizeof(*units); i++)
            all |= units[i].unit;
        NSDateComponents *parts = [calendar components:all fromDate:[NSDate date]
            toDate:[NSDate dateWithTimeIntervalSinceReferenceDate:time] options:0];
        char *text = NULL;
        for (size_t i = 0; i < sizeof(units) / sizeof(*units) && !text; i++) {
            NSInteger value = [parts valueForComponent:units[i].unit];
            if (value == 0)
                continue;
            if (named && (value == 1 || value == -1) && units[i].next)
                return strdup(value > 0 ? units[i].next : units[i].last);
            long count = value < 0 ? -(long)value : (long)value;
            const char *word = width <= 1 ? units[i].wide : units[i].abbreviated;
            const char *plural = width <= 1 && count != 1 ? "s" : "";
            if (value > 0)
                asprintf(&text, "in %ld %s%s", count, word, plural);
            else
                asprintf(&text, "%ld %s%s ago", count, word, plural);
        }
        return text ? text : strdup(named ? "now" : "in 0 seconds");
    }
}
