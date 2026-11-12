#import <Foundation/Foundation.h>
@interface NSSortDescriptor (DarlingSwiftSupplement)
- (instancetype)initWithDarlingKVCKeyUTF8:(const char *)key ascendingInt:(int)ascending
    NS_SWIFT_NAME(init(darlingKVCKeyUTF8:ascendingInt:));
- (instancetype)initWithDarlingKVCKeyUTF8:(const char *)key ascendingInt:(int)ascending comparator:(NSComparator)comparator
    NS_SWIFT_NAME(init(darlingKVCKeyUTF8:ascendingInt:comparator:));
@end

void DarlingFoundationSortRejectedKeyPath(void);

// Date.FormatStyle and Date.RelativeFormatStyle (FormatStyles.swift). The
// strings are UTF-8, allocated with malloc; the caller frees them.
// Styles are NSDateFormatterStyle values; time is since the reference date.
char *DarlingFoundationFormatDate(double time, int dateStyle, int timeStyle);
// named: "yesterday" and the like where they apply. width: 0 wide, 1 spelled
// out, 2 abbreviated, 3 narrow (Date.RelativeFormatStyle.UnitsStyle).
char *DarlingFoundationFormatRelativeDate(double time, int named, int width);
