/*
 * NSAttributedString's attributed-string format is declared in Foundation's header
 * because OpenSwiftUI's SPI shim wraps the selector, and an undeclared selector is a
 * compile error rather than a runtime one. The format itself needs its specifiers read
 * as attribute names, which is not implemented, so this checks the part that is:
 * the selector is reachable rather than going through "unrecognized selector".
 *
 * Every [[NSAttributedString alloc] init...] returns the placeholder class, which is
 * where the implementation lives.
 */
#import <Foundation/NSAttributedString.h>
#import <Foundation/NSException.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    @autoreleasepool {
        @try {
            NSAttributedString *result =
                [[NSAttributedString alloc]
                  initWithFormat:(NSAttributedString *)@"%@"
                          options:0
                           locale:nil
                        arguments:nil];
            printf("returned %s\n", result ? "an object" : "nil");
        }
        @catch (NSException *exception) {
            const char *reason = [[exception reason] UTF8String] ?: "";
            if (strstr(reason, "unrecognized selector") != NULL) {
                printf("FAIL %s\n", reason);
                return 1;
            }
            printf("FAIL raised %s: %s\n", [[exception name] UTF8String], reason);
            return 1;
        }
        printf("ok   the selector is implemented rather than unrecognized\n");
    }
    return 0;
}
