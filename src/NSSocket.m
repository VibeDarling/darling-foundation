#import <Foundation/NSSocket.h>
#import <Foundation/NSSocket_bsd.h>
#import <Foundation/NSError.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>

#include <errno.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <netinet/in.h>
#include <arpa/inet.h>

@implementation NSSocket

+ (id)allocWithZone:(NSZone *)zone {
    if (self == [NSSocket class]) {
        return [NSSocket_bsd allocWithZone:zone];
    }
    return [super allocWithZone:zone];
}

- (id)initWithFileDescriptor:(int)descriptor {
    [self release];
    return [[NSSocket_bsd alloc] initWithDescriptor:descriptor];
}

- (id)initConnectedToSocket:(NSSocket **)other {
    int pipes[2];
    if (pipe(pipes) == 0) {
        if (other)
            *other = [[[NSSocket_bsd alloc] initWithDescriptor:pipes[0]] autorelease];
        [self release];
        return [[NSSocket_bsd alloc] initWithDescriptor:pipes[1]];
    }
    [self release];
    return nil;
}

- (id)initTCPStream {
    int fd = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (fd < 0) {
        [self release];
        return nil;
    }
    [self release];
    return [[NSSocket_bsd alloc] initWithDescriptor:fd];
}

- (int)fileDescriptor {
    return -1;
}

- (NSError *)close {
    return nil;
}

- (NSError *)connectToHost:(NSHost *)host port:(NSInteger)port immediate:(BOOL *)immediate {
    return nil;
}

- (BOOL)hasBytesAvailable {
    return NO;
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)length {
    return 0;
}

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)length {
    return 0;
}

- (NSSocket *)acceptWithError:(NSError **)errorp {
    return nil;
}

@end

@implementation NSSocket_bsd

- (id)initWithDescriptor:(int)descriptor {
    self = [super init];
    if (self) {
        _descriptor = descriptor;
    }
    return self;
}

- (id)initWithFileDescriptor:(int)fd {
    return [self initWithDescriptor:fd];
}

+ (id)socketWithDescriptor:(int)descriptor {
    return [[[self alloc] initWithDescriptor:descriptor] autorelease];
}

- (int)descriptor {
    return _descriptor;
}

- (int)fileDescriptor {
    return _descriptor;
}

- (void)setDescriptor:(int)descriptor {
    _descriptor = descriptor;
}

- (NSUInteger)hash {
    return (NSUInteger)_descriptor;
}

- (BOOL)isEqual:(id)other {
    if (![other isKindOfClass:[NSSocket_bsd class]])
        return NO;
    return (_descriptor == ((NSSocket_bsd *)other)->_descriptor);
}

- (NSError *)close {
    if (_descriptor >= 0) {
        int res = close(_descriptor);
        _descriptor = -1;
        if (res < 0)
            return [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
    }
    return nil;
}

- (BOOL)hasBytesAvailable {
    if (_descriptor < 0)
        return NO;
    struct timeval tv = {0, 0};
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(_descriptor, &fds);
    if (select(_descriptor + 1, &fds, NULL, NULL, &tv) > 0)
        return FD_ISSET(_descriptor, &fds) ? YES : NO;
    return NO;
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)length {
    if (_descriptor < 0)
        return -1;
    return read(_descriptor, (void *)buffer, length);
}

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)length {
    if (_descriptor < 0)
        return -1;
    return write(_descriptor, (const void *)buffer, length);
}

@end
