#import <Foundation/Foundation.h>

static NSUInteger traceQueries;

@interface AuthoredDiagnosticException : NSException
@end
@implementation AuthoredDiagnosticException
- (NSArray *)callStackSymbols {
    traceQueries++;
    return @[@"authored trace placeholder"];
}
@end

int main(void) {
    @autoreleasepool {
        NSUncaughtExceptionHandler *handler = NSGetUncaughtExceptionHandler();
        if (!handler)
            return 83;
        NSException *exception = [[AuthoredDiagnosticException alloc] initWithName:@"AuthoredFailure"
            reason:@"Expected authored diagnostic test" userInfo:nil];
        handler(exception);
        [exception release];
        return traceQueries == 0 ? 0 : 84;
    }
}
