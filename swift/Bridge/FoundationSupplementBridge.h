#import <Foundation/Foundation.h>
@interface NSSortDescriptor (DarlingSwiftSupplement)
- (instancetype)initWithDarlingKVCKeyUTF8:(const char *)key ascendingInt:(int)ascending
    NS_SWIFT_NAME(init(darlingKVCKeyUTF8:ascendingInt:));
- (instancetype)initWithDarlingKVCKeyUTF8:(const char *)key ascendingInt:(int)ascending comparator:(NSComparator)comparator
    NS_SWIFT_NAME(init(darlingKVCKeyUTF8:ascendingInt:comparator:));
@end

void DarlingFoundationSortRejectedKeyPath(void);
