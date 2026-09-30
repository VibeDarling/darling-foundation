#import <Foundation/NSSelectInputSource.h>
#import <Foundation/NSSocket_bsd.h>
#import <Foundation/NSRunLoop.h>
#import <CoreFoundation/CoreFoundation.h>

@implementation NSSelectInputSource

- (id)initWithSocket:(NSSocket *)socket {
    self = [super init];
    if (self) {
        _socket = [socket retain];
        _delegate = nil;
        _eventMask = 0;
        _isValid = YES;
    }
    return self;
}

- (void)dealloc {
    [_socket release];
    [super dealloc];
}

+ (id)socketInputSourceWithSocket:(NSSocket *)socket {
    return [[[self alloc] initWithSocket:socket] autorelease];
}

- (NSSocket *)socket {
    return _socket;
}

- (BOOL)isValid {
    return _isValid;
}

- (void)invalidate {
    _isValid = NO;
    _delegate = nil;
}

- (id)delegate {
    return _delegate;
}

- (void)setDelegate:(id)object {
    _delegate = object;
}

- (NSUInteger)selectEventMask {
    return _eventMask;
}

- (void)setSelectEventMask:(NSUInteger)eventMask {
    _eventMask = eventMask;
}

- (NSUInteger)processImmediateEvents:(NSUInteger)selectEvent {
    if ((selectEvent &= _eventMask) == 0)
        return 0;

    if (_delegate != nil && [_delegate respondsToSelector:@selector(selectInputSource:selectEvent:)]) {
        [_delegate selectInputSource:self selectEvent:selectEvent];
    }
    return selectEvent;
}

@end

static void socketCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    NSSelectInputSource *sis = (__bridge NSSelectInputSource *)info;
    [sis processImmediateEvents:NSSelectReadEvent];
}

@implementation NSRunLoop (NSSelectInputSource)

- (void)addInputSource:(id)source forMode:(NSString *)mode {
    if ([source isKindOfClass:[NSSelectInputSource class]]) {
        NSSelectInputSource *sis = (NSSelectInputSource *)source;
        NSSocket *sock = [sis socket];
        int fd = -1;
        if ([sock respondsToSelector:@selector(descriptor)]) {
            fd = [(NSSocket_bsd *)sock descriptor];
        } else if ([sock respondsToSelector:@selector(fileDescriptor)]) {
            fd = [sock fileDescriptor];
        }
        if (fd >= 0) {
            CFSocketContext ctx = { 0, (void *)CFBridgingRetain(sis), NULL, NULL, NULL };
            CFSocketRef cfSock = CFSocketCreateWithNative(kCFAllocatorDefault, fd, kCFSocketReadCallBack, socketCallback, &ctx);
            if (cfSock) {
                CFOptionFlags flags = CFSocketGetSocketFlags(cfSock);
                // Nie zamykaj natywnego deskryptora przy zwalnianiu CFSocket
                CFSocketSetSocketFlags(cfSock, flags & ~kCFSocketCloseOnInvalidate);
                CFRunLoopSourceRef rlSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, cfSock, 0);
                if (rlSource) {
                    CFRunLoopAddSource([self getCFRunLoop], rlSource, (CFStringRef)mode);
                    CFRelease(rlSource);
                }
                CFRelease(cfSock);
            }
        }
    }
}

- (void)removeInputSource:(id)source forMode:(NSString *)mode {
}

@end
