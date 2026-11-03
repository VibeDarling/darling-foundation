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
