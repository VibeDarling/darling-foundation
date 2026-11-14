#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>

static int failures;

static void expect(BOOL condition, NSString *label)
{
    printf("%s %s\n", condition ? "PASS" : "FAIL", [label UTF8String]);
    failures += !condition;
}

// -[NSUnarchiver _decodeByte] is private. Stock applications send it from their legacy (typedstream) decoders and
// stop with "unrecognized selector" when it is missing. It reads one typedstream byte, the same as the
// -decodeByte this Foundation already has; the unsigned result is a GUESS.
@interface NSUnarchiver (PrivateDeclaration)
- (uint8_t)_decodeByte;
@end

@interface Bytes : NSObject <NSCoding>
@property (assign) uint8_t first, second, third;
@end

@implementation Bytes

- (void)encodeWithCoder:(NSCoder *)coder
{
    char values[3] = {0x41, (char)0xC8, 0x00};
    [coder encodeValueOfObjCType:"c" at:&values[0]];
    [coder encodeValueOfObjCType:"c" at:&values[1]];
    [coder encodeValueOfObjCType:"c" at:&values[2]];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    expect([coder respondsToSelector:@selector(_decodeByte)], @"the unarchiver answers _decodeByte");
    if (![coder respondsToSelector:@selector(_decodeByte)])
        return self;
    NSUnarchiver *unarchiver = (NSUnarchiver *)coder;
    _first = [unarchiver _decodeByte];
    _second = [unarchiver _decodeByte];
    _third = [unarchiver _decodeByte];
    return self;
}

@end

int main(void)
{
    @autoreleasepool
    {
        Bytes *bytes = [[[Bytes alloc] init] autorelease];
        NSData *archive = [NSArchiver archivedDataWithRootObject:bytes];
        Bytes *copy = [NSUnarchiver unarchiveObjectWithData:archive];
        expect([copy isKindOfClass:[Bytes class]], @"the object decodes");
        expect(copy.first == 0x41, [NSString stringWithFormat:@"first byte (%02x)", copy.first]);
        expect(copy.second == 0xC8, [NSString stringWithFormat:@"a byte with the high bit set is not sign-extended (%02x)", copy.second]);
        expect(copy.third == 0x00, [NSString stringWithFormat:@"third byte (%02x)", copy.third]);
    }
    printf(failures ? "FAILED\n" : "PASS: NSUnarchiver _decodeByte\n");
    return failures != 0;
}
