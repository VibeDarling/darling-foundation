#import <Foundation/NSURLComponents.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSException.h>
#import <Foundation/NSValue.h>
#import <CoreFoundation/CFURLComponents.h>

@implementation NSURLComponents

- (instancetype)init
{
    self = [super init];
    if (self) {
        _components = _CFURLComponentsCreate(kCFAllocatorDefault);
        if (!_components) { [self release]; return nil; }
    }
    return self;
}

- (instancetype)initWithString:(NSString *)string
{
    self = [super init];
    if (self) {
        _components = _CFURLComponentsCreateWithString(kCFAllocatorDefault, (CFStringRef)string);
        if (!_components) { [self release]; return nil; }
    }
    return self;
}

+ (instancetype)componentsWithString:(NSString *)string
{
    return [[[self alloc] initWithString:string] autorelease];
}

- (instancetype)initWithURL:(NSURL *)url resolvingAgainstBaseURL:(BOOL)resolve
{
    return [self initWithString:resolve ? [url absoluteString] : [url relativeString]];
}

+ (instancetype)componentsWithURL:(NSURL *)url resolvingAgainstBaseURL:(BOOL)resolve
{
    return [[[self alloc] initWithURL:url resolvingAgainstBaseURL:resolve] autorelease];
}

- (NSString *)scheme
{
    return [(NSString *)_CFURLComponentsCopyScheme(_components) autorelease];
}

- (void)setScheme:(NSString *)scheme
{
    if (!_CFURLComponentsSetScheme(_components, (CFStringRef)scheme))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL scheme"];
}

- (NSString *)host
{
    return [(NSString *)_CFURLComponentsCopyHost(_components) autorelease];
}

- (void)setHost:(NSString *)host
{
    if (!_CFURLComponentsSetHost(_components, (CFStringRef)host))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL host"];
}

- (NSURL *)URL
{
    return [(NSURL *)_CFURLComponentsCopyURL(_components) autorelease];
}

- (NSURL *)URLRelativeToURL:(NSURL *)baseURL
{
    return [(NSURL *)_CFURLComponentsCopyURLRelativeToURL(_components, (CFURLRef)baseURL) autorelease];
}

- (NSString *)string
{
    return [(NSString *)_CFURLComponentsCopyString(_components) autorelease];
}

/* Each component as given (percent-encoded on the way in and decoded on the way out), and as it
   appears in the URL; setting an invalid percent-encoded value raises, as in Apple's Foundation. */
#define NSURLCOMPONENT(getter, setter, Name) \
- (NSString *)getter { return [(NSString *)_CFURLComponentsCopy##Name(_components) autorelease]; } \
- (void)setter:(NSString *)value { _CFURLComponentsSet##Name(_components, (CFStringRef)value); } \
- (NSString *)percentEncoded##Name { return [(NSString *)_CFURLComponentsCopyPercentEncoded##Name(_components) autorelease]; } \
- (void)setPercentEncoded##Name:(NSString *)value \
{ \
    if (!_CFURLComponentsSetPercentEncoded##Name(_components, (CFStringRef)value)) \
        [NSException raise:NSInvalidArgumentException format:@"invalid characters in percentEncoded" #Name]; \
}

NSURLCOMPONENT(user, setUser, User)
NSURLCOMPONENT(password, setPassword, Password)
NSURLCOMPONENT(path, setPath, Path)
NSURLCOMPONENT(query, setQuery, Query)
NSURLCOMPONENT(fragment, setFragment, Fragment)

- (NSString *)percentEncodedHost
{
    return [(NSString *)_CFURLComponentsCopyPercentEncodedHost(_components) autorelease];
}

- (void)setPercentEncodedHost:(NSString *)host
{
    if (!_CFURLComponentsSetPercentEncodedHost(_components, (CFStringRef)host))
        [NSException raise:NSInvalidArgumentException format:@"invalid characters in percentEncodedHost"];
}

- (NSString *)encodedHost
{
    return [self percentEncodedHost];
}

- (void)setEncodedHost:(NSString *)host
{
    [self setPercentEncodedHost:host];
}

- (NSNumber *)port
{
    return [(NSNumber *)_CFURLComponentsCopyPort(_components) autorelease];
}

- (void)setPort:(NSNumber *)port
{
    if (!_CFURLComponentsSetPort(_components, (CFNumberRef)port))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL port"];
}

static NSRange NSRangeFromCFURLRange(CFRange range)
{
    return range.location == kCFNotFound ? NSMakeRange(NSNotFound, 0) : NSMakeRange(range.location, range.length);
}

- (NSRange)rangeOfScheme { return NSRangeFromCFURLRange(_CFURLComponentsGetRangeOfScheme(_components)); }
- (NSRange)rangeOfUser { return NSRangeFromCFURLRange(_CFURLComponentsGetRangeOfUser(_components)); }
- (NSRange)rangeOfPassword { return NSRangeFromCFURLRange(_CFURLComponentsGetRangeOfPassword(_components)); }
- (NSRange)rangeOfHost { return NSRangeFromCFURLRange(_CFURLComponentsGetRangeOfHost(_components)); }
- (NSRange)rangeOfPort { return NSRangeFromCFURLRange(_CFURLComponentsGetRangeOfPort(_components)); }
- (NSRange)rangeOfPath { return NSRangeFromCFURLRange(_CFURLComponentsGetRangeOfPath(_components)); }
- (NSRange)rangeOfQuery { return NSRangeFromCFURLRange(_CFURLComponentsGetRangeOfQuery(_components)); }
- (NSRange)rangeOfFragment { return NSRangeFromCFURLRange(_CFURLComponentsGetRangeOfFragment(_components)); }

- (id)copyWithZone:(NSZone *)zone
{
    NSURLComponents *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        CFRelease(copy->_components);
        copy->_components = _CFURLComponentsCreateCopy(kCFAllocatorDefault, _components);
    }
    return copy;
}

- (BOOL)isEqual:(id)other
{
    if (other == self) return YES;
    if (![other isKindOfClass:[NSURLComponents class]]) return NO;
    NSString *mine = [self string], *theirs = [other string];
    return mine == theirs || [mine isEqual:theirs];
}

- (NSUInteger)hash
{
    return [[self string] hash];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %p> %@", [self class], self, [self string]];
}

- (NSArray *)queryItems
{
    NSArray *pairs = [(NSArray *)_CFURLComponentsCopyQueryItems(_components) autorelease];
    if (!pairs) return nil;
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:[pairs count]];
    for (NSDictionary *pair in pairs) {
        [items addObject:[[[NSURLQueryItem alloc]
            initWithName:[pair objectForKey:(NSString *)_kCFURLComponentsNameKey]
            value:[pair objectForKey:(NSString *)_kCFURLComponentsValueKey]] autorelease]];
    }
    return [[items copy] autorelease];
}

- (NSArray *)percentEncodedQueryItems
{
    NSArray *pairs = [(NSArray *)_CFURLComponentsCopyPercentEncodedQueryItems(_components) autorelease];
    if (!pairs) return nil;
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:[pairs count]];
    for (NSDictionary *pair in pairs) {
        [items addObject:[[[NSURLQueryItem alloc]
            initWithName:[pair objectForKey:(NSString *)_kCFURLComponentsNameKey]
            value:[pair objectForKey:(NSString *)_kCFURLComponentsValueKey]] autorelease]];
    }
    return [[items copy] autorelease];
}

- (void)setPercentEncodedQueryItems:(NSArray *)items
{
    if (!items) {
        _CFURLComponentsSetPercentEncodedQuery(_components, NULL);
        return;
    }
    NSMutableArray *names = [NSMutableArray arrayWithCapacity:[items count]];
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:[items count]];
    for (NSURLQueryItem *item in items) {
        [names addObject:[item name]];
        [values addObject:[item value] ?: [NSNull null]];
    }
    if (!_CFURLComponentsSetPercentEncodedQueryItems(_components, (CFArrayRef)names, (CFArrayRef)values))
        [NSException raise:NSInvalidArgumentException format:@"invalid characters in percentEncodedQueryItems"];
}

- (void)setQueryItems:(NSArray *)items
{
    if (!items) {
        _CFURLComponentsSetPercentEncodedQuery(_components, NULL);
        return;
    }
    NSMutableArray *names = [NSMutableArray arrayWithCapacity:[items count]];
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:[items count]];
    for (NSURLQueryItem *item in items) {
        [names addObject:[item name]];
        [values addObject:[item value] ?: [NSNull null]];
    }
    _CFURLComponentsSetQueryItems(_components, (CFArrayRef)names, (CFArrayRef)values);
}

- (void)dealloc
{
    if (_components) CFRelease(_components);
    [super dealloc];
}

@end
