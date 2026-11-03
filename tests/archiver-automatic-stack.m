#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSUInteger stackQueries;
static NSUInteger encodingAttempts;

static id authoredStackQuery(id receiver, SEL selector) {
    (void)receiver;
    (void)selector;
    stackQueries++;
    return @[];
}

@interface AuthoredEncodingFailure : NSObject <NSCoding>
@end
@implementation AuthoredEncodingFailure
- (void)encodeWithCoder:(NSCoder *)coder {
    (void)coder;
    encodingAttempts++;
    @throw [NSException exceptionWithName:@"AuthoredEncodingFailure"
                                  reason:@"Expected authored failure" userInfo:nil];
}
- (id)initWithCoder:(NSCoder *)coder {
    (void)coder;
    return [self init];
}
@end

int main(void) {
    @autoreleasepool {
        Method method = class_getClassMethod([NSThread class], @selector(callStackSymbols));
        if (!method)
            return 87;
        IMP original = method_setImplementation(method, (IMP)authoredStackQuery);
        @try {
            if ([[NSThread callStackSymbols] count] != 0 || stackQueries != 1)
                return 88;
            stackQueries = 0;
            AuthoredEncodingFailure *object = [[[AuthoredEncodingFailure alloc] init] autorelease];
            NSError *error = nil;
            NSData *result = [NSKeyedArchiver archivedDataWithRootObject:object
                                                requiringSecureCoding:NO error:&error];
            NSError *underlying = [[error userInfo] objectForKey:NSUnderlyingErrorKey];
            if (encodingAttempts != 1 || result != nil || error == nil ||
                ![[error domain] isEqualToString:NSCocoaErrorDomain] || [error code] != 4866 ||
                underlying == nil || ![[underlying domain] isEqualToString:NSCocoaErrorDomain] ||
                [underlying code] != 4864)
                return 89;
            if (stackQueries != 0)
                return 85;
            if ([NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:NO error:NULL] != nil ||
                encodingAttempts != 2 || stackQueries != 0)
                return 86;
            error = nil;
            NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:@"authored"
                                                 requiringSecureCoding:NO error:&error];
            if (archive == nil || error != nil ||
                ![[NSKeyedUnarchiver unarchiveObjectWithData:archive] isEqual:@"authored"] || stackQueries != 0)
                return 90;
            return 0;
        } @catch (NSException *exception) {
            (void)exception;
            return 91;
        } @finally {
            method_setImplementation(method, original);
        }
    }
}
