/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <dirent.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

NSDistributedNotificationCenterType const NSLocalNotificationCenterType = @"NSLocalNotificationCenterType";
static const NSUInteger DNCMessageLimit = 65536;
static const NSUInteger DNCQueueLimit = 256;
static char *defaultSocketPath;
static pid_t defaultSocketOwner;
static void removeDefaultSocket(void) {
    if (defaultSocketPath && defaultSocketOwner==getpid()) unlink(defaultSocketPath);
}

@interface _DNCObserver : NSObject {
@public
    id target; // Registration does not own the observer; removal precedes its destruction.
    SEL selector;
    NSString *name, *object;
    NSNotificationSuspensionBehavior behavior;
    NSMutableArray *pending;
    BOOL active;
}
@end
@implementation _DNCObserver
- (void)dealloc { [name release]; [object release]; [pending release]; [super dealloc]; }
@end

@interface _DNCState : NSObject {
@public
    int fd;
    pid_t owner;
    CFSocketRef socket;
    CFRunLoopSourceRef source;
    NSString *root, *directory, *path;
    NSMutableArray *observers;
}
@end
@implementation _DNCState
- (id)init { if ((self=[super init])) {fd=-1;owner=getpid();observers=[NSMutableArray new];} return self; }
- (void)dealloc {
    if (source) {CFRunLoopSourceInvalidate(source);CFRelease(source);}
    if (socket) {CFSocketInvalidate(socket);CFRelease(socket);}
    else if (fd>=0) close(fd);
    if (path && owner==getpid()) unlink([path fileSystemRepresentation]);
    [path release];[directory release];[root release];[observers release];[super dealloc];
}
@end

@interface NSDistributedNotificationCenter (DNCPrivate)
- (void)_readDistributedMessages;
- (void)_flushDistributedPending;
@end

static BOOL privateDirectory(NSString *path, BOOL create) {
    const char *p=[path fileSystemRepresentation];
    if (create && mkdir(p,0700)<0 && errno!=EEXIST) return NO;
    struct stat st;
    if (lstat(p,&st)<0) return NO;
    if (!S_ISDIR(st.st_mode) || st.st_uid!=getuid() || (st.st_mode&077)!=0) {errno=EACCES;return NO;}
    return YES;
}

static BOOL socketAddress(NSString *path, struct sockaddr_un *address) {
    const char *p=[path fileSystemRepresentation];
    if (strlen(p)>=sizeof(address->sun_path)) {errno=ENAMETOOLONG;return NO;}
    memset(address,0,sizeof(*address));address->sun_family=AF_UNIX;
    strcpy(address->sun_path,p);address->sun_len=SUN_LEN(address);
    return YES;
}

static void distributedReadable(CFSocketRef socket,CFSocketCallBackType type,CFDataRef address,const void *data,void *info) {
    NSAutoreleasePool *pool=[NSAutoreleasePool new];
    [(NSDistributedNotificationCenter *)info _readDistributedMessages];
    [pool drain];
}

// Darling has no GUI audit-session service. Use the inherited host desktop
// session, not getsid(): each launch can create a separate Unix session.
static uint64_t desktopSession(void) {
    const char *session=getenv("XDG_SESSION_ID");
    if (!session || !*session) session=getenv("WAYLAND_DISPLAY");
    if (!session || !*session) session="darling-prefix";
    uint64_t hash=UINT64_C(14695981039346656037);
    for (const unsigned char *p=(const unsigned char *)session;*p;p++) hash=(hash^*p)*UINT64_C(1099511628211);
    return hash;
}

static void sendToDirectory(_DNCState *state,NSString *directory,NSData *data) {
    if (!privateDirectory(directory,NO)) return;
    DIR *dir=opendir([directory fileSystemRepresentation]);if (!dir) return;
    struct dirent *entry;
    while ((entry=readdir(dir))) {
        if (strncmp(entry->d_name,"n-",2)) continue;
        NSString *entryName=[NSString stringWithUTF8String:entry->d_name];
        if (!entryName) continue;
        NSString *peer=[directory stringByAppendingPathComponent:entryName];
        struct stat st;struct sockaddr_un address;
        if (lstat([peer fileSystemRepresentation],&st)<0 || !S_ISSOCK(st.st_mode) || st.st_uid!=getuid() ||
            (st.st_mode&077)!=0 || !socketAddress(peer,&address)) continue;
        // Distributed notifications are best effort; never wait for a stalled
        // receiver's queue, and never remove another process's socket path.
        sendto(state->fd,[data bytes],[data length],MSG_DONTWAIT,(struct sockaddr *)&address,address.sun_len);
    }
    closedir(dir);
}

@implementation NSDistributedNotificationCenter
+ (NSDistributedNotificationCenter *)defaultCenter {
    static NSDistributedNotificationCenter *center;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        center=[[self alloc] init];
        _DNCState *state=center->_distributedState;
        defaultSocketPath=strdup([state->path fileSystemRepresentation]);
        defaultSocketOwner=getpid();atexit(removeDefaultSocket);
    });
    return center;
}
+ (NSDistributedNotificationCenter *)notificationCenterForType:(NSDistributedNotificationCenterType)type {
    if (![type isEqualToString:NSLocalNotificationCenterType])
        [NSException raise:NSInvalidArgumentException format:@"Unknown distributed notification center type: %@",type];
    return [self defaultCenter];
}
- (id)init {
    if (!(self=[super init])) return nil;
    _DNCState *state=[_DNCState new];_distributedState=state;
    state->root=[[NSString stringWithFormat:@"/var/run/.dnc1-%u",getuid()] copy];
    state->directory=[[state->root stringByAppendingPathComponent:[NSString stringWithFormat:@"g-%016llx",(unsigned long long)desktopSession()]] copy];
    if (!privateDirectory(state->root,YES) || !privateDirectory(state->directory,YES)) goto failed;
    char *temporary=strdup([[state->directory stringByAppendingPathComponent:@"n-XXXXXX"] fileSystemRepresentation]);
    if (!temporary) goto failed;
    int file=mkstemp(temporary);
    if (file<0) {free(temporary);goto failed;}
    close(file);unlink(temporary);state->path=[[NSString stringWithUTF8String:temporary] copy];free(temporary);
    struct sockaddr_un address;
    if (!socketAddress(state->path,&address)) goto failed;
    state->fd=socket(AF_UNIX,SOCK_DGRAM,0);
    if (state->fd<0 || fcntl(state->fd,F_SETFD,FD_CLOEXEC)<0 ||
        fcntl(state->fd,F_SETFL,O_NONBLOCK)<0 || bind(state->fd,(struct sockaddr *)&address,address.sun_len)<0 ||
        chmod([state->path fileSystemRepresentation],0600)<0) goto failed;
    // A vchroot-expanded UNIX socket path must still name the endpoint bound
    // above; long prefixes must fail instead of silently using a truncated path.
    struct stat bound;
    if (lstat([state->path fileSystemRepresentation],&bound)<0 || !S_ISSOCK(bound.st_mode)) goto failed;
    CFSocketContext context={0,self,NULL,NULL,NULL};
    state->socket=CFSocketCreateWithNative(NULL,state->fd,kCFSocketReadCallBack,distributedReadable,&context);
    if (!state->socket) goto failed;
    state->source=CFSocketCreateRunLoopSource(NULL,state->socket,0);
    if (!state->source) goto failed;
    CFRunLoopAddSource(CFRunLoopGetMain(),state->source,kCFRunLoopCommonModes);
    return self;
failed:;
    int error=errno;
    [self release];
    [NSException raise:NSInternalInconsistencyException format:@"Cannot initialize distributed notification transport: errno %d",error];
    return nil;
}
- (void)dealloc {[_distributedState release];[super dealloc];}
- (void)addObserver:(id)observer selector:(SEL)selector name:(NSNotificationName)name object:(NSString *)object suspensionBehavior:(NSNotificationSuspensionBehavior)behavior {
    if (!observer || !selector || (name && ![name isKindOfClass:[NSString class]]) ||
        (object && ![object isKindOfClass:[NSString class]]) || behavior<1 || behavior>4)
        [NSException raise:NSInvalidArgumentException format:@"Invalid distributed notification registration"];
    _DNCObserver *record=[_DNCObserver new];record->target=observer;record->selector=selector;
    record->name=[name copy];record->object=[object copy];record->behavior=behavior;
    record->pending=[NSMutableArray new];record->active=YES;
    @synchronized(self) { [((_DNCState *)_distributedState)->observers addObject:record]; }
    [record release];
}
- (void)addObserver:(id)observer selector:(SEL)selector name:(NSNotificationName)name object:(NSString *)object {
    [self addObserver:observer selector:selector name:name object:object suspensionBehavior:NSNotificationSuspensionBehaviorCoalesce];
}
- (void)removeObserver:(id)observer name:(NSNotificationName)name object:(NSString *)object {
    @synchronized(self) {
        NSMutableArray *records=((_DNCState *)_distributedState)->observers;
        for (NSInteger i=[records count]-1;i>=0;i--) {
            _DNCObserver *record=[records objectAtIndex:i];
            if (record->target==observer && (!name || [name isEqualToString:record->name]) && (!object || [object isEqualToString:record->object])) {
                record->active=NO;[record->pending removeAllObjects];[records removeObjectAtIndex:i];
            }
        }
    }
}
- (void)removeObserver:(id)observer { [self removeObserver:observer name:nil object:nil]; }
- (void)postNotification:(NSNotification *)note { [self postNotificationName:[note name] object:[note object] userInfo:[note userInfo]]; }
- (void)postNotificationName:(NSNotificationName)name object:(NSString *)object { [self postNotificationName:name object:object userInfo:nil]; }
- (void)postNotificationName:(NSNotificationName)name object:(NSString *)object userInfo:(NSDictionary *)info { [self postNotificationName:name object:object userInfo:info deliverImmediately:NO]; }
- (void)postNotificationName:(NSNotificationName)name object:(NSString *)object userInfo:(NSDictionary *)info deliverImmediately:(BOOL)immediate {
    [self postNotificationName:name object:object userInfo:info options:immediate?NSDistributedNotificationDeliverImmediately:0];
}
- (void)postNotificationName:(NSNotificationName)name object:(NSString *)object userInfo:(NSDictionary *)info options:(NSDistributedNotificationOptions)options {
    if (![name isKindOfClass:[NSString class]] || (object && ![object isKindOfClass:[NSString class]]) ||
        (info && ![info isKindOfClass:[NSDictionary class]]) || (options&~(NSDistributedNotificationDeliverImmediately|NSDistributedNotificationPostToAllSessions)))
        [NSException raise:NSInvalidArgumentException format:@"Invalid distributed notification"];
    NSMutableDictionary *message=[NSMutableDictionary dictionaryWithObjectsAndKeys:@1,@"version",name,@"name",@((options&NSDistributedNotificationDeliverImmediately)!=0),@"immediate",nil];
    if (object) [message setObject:object forKey:@"object"];
    if (info) [message setObject:info forKey:@"info"];
    if (![NSPropertyListSerialization propertyList:message isValidForFormat:NSPropertyListBinaryFormat_v1_0])
        [NSException raise:NSInvalidArgumentException format:@"Distributed notification userInfo must be a property list"];
    NSError *error=nil;
    NSData *data=[NSPropertyListSerialization dataWithPropertyList:message format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
    if (!data || [data length]>DNCMessageLimit)
        [NSException raise:NSInvalidArgumentException format:@"Distributed notification payload is invalid or exceeds %lu bytes: %@",(unsigned long)DNCMessageLimit,error];
    _DNCState *state=_distributedState;
    if (!(options&NSDistributedNotificationPostToAllSessions)) {sendToDirectory(state,state->directory,data);return;}
    DIR *root=opendir([state->root fileSystemRepresentation]);if (!root) return;
    struct dirent *entry;
    while ((entry=readdir(root))) if (!strncmp(entry->d_name,"g-",2))
        {
        NSString *entryName=[NSString stringWithUTF8String:entry->d_name];
        if (entryName) sendToDirectory(state,[state->root stringByAppendingPathComponent:entryName],data);
    }
    closedir(root);
}
- (BOOL)suspended { @synchronized(self) {return _suspended;} }
- (void)setSuspended:(BOOL)value {
    @synchronized(self) {_suspended=value;}
    if (!value) {
        if ([NSThread isMainThread]) [self _flushDistributedIfResumed];
        else [self performSelectorOnMainThread:@selector(_flushDistributedIfResumed) withObject:nil waitUntilDone:NO];
    }
}
- (void)_flushDistributedIfResumed {
    @synchronized(self) {if (!_suspended) [self _flushDistributedPending];}
}
- (void)_deliverDistributed:(NSNotification *)note to:(_DNCObserver *)record {
    if (!record->active) return;
    id observer=[record->target retain];
    @try {((void(*)(id,SEL,id))objc_msgSend)(observer,record->selector,note);}
    @finally {[observer release];}
}
- (void)_flushDistributedPending {
    @synchronized(self) {
        NSArray *records=[(((_DNCState *)_distributedState)->observers) copy];
        @try {
            for (_DNCObserver *record in records) {
                NSArray *notes=[record->pending copy];[record->pending removeAllObjects];
                @try {for (NSNotification *note in notes) [self _deliverDistributed:note to:record];}
                @finally {[notes release];}
            }
        } @finally {[records release];}
    }
}
- (void)_receiveDistributed:(NSDictionary *)message {
    NSString *name=[message objectForKey:@"name"], *object=[message objectForKey:@"object"];
    NSDictionary *info=[message objectForKey:@"info"];
    NSNumber *immediate=[message objectForKey:@"immediate"], *version=[message objectForKey:@"version"];
    if (![name isKindOfClass:[NSString class]] || (object && ![object isKindOfClass:[NSString class]]) ||
        (info && ![info isKindOfClass:[NSDictionary class]]) || ![immediate isKindOfClass:[NSNumber class]] ||
        ![version isKindOfClass:[NSNumber class]] || [version intValue]!=1) return;
    NSNotification *note=[NSNotification notificationWithName:name object:object userInfo:info];
    @synchronized(self) {
        NSMutableArray *matches=[NSMutableArray array];BOOL force=[immediate boolValue];
        for (_DNCObserver *record in ((_DNCState *)_distributedState)->observers)
            if ((!record->name || [record->name isEqualToString:name]) && (!record->object || [record->object isEqualToString:object])) {
                [matches addObject:record];
                if (record->behavior==NSNotificationSuspensionBehaviorDeliverImmediately) force=YES;
            }
        BOOL previous=_suspended;
        @try {
            if (force && [matches count]) {_suspended=NO;[self _flushDistributedPending];}
            for (_DNCObserver *record in matches) {
                if (!record->active) continue;
                if (!_suspended) {[self _deliverDistributed:note to:record];continue;}
                if (record->behavior==NSNotificationSuspensionBehaviorDrop) continue;
                if (record->behavior==NSNotificationSuspensionBehaviorCoalesce) {
                    for (NSInteger i=[record->pending count]-1;i>=0;i--) {
                        NSNotification *old=[record->pending objectAtIndex:i];
                        if ([[old name] isEqualToString:name] && ((!object && ![old object]) || [object isEqualToString:[old object]]))
                            [record->pending removeObjectAtIndex:i];
                    }
                }
                if ([record->pending count]>=DNCQueueLimit) {
                    _suspended=NO;[self _flushDistributedPending];_suspended=previous;
                }
                if (record->active) [record->pending addObject:note];
            }
        } @finally {if (force && [matches count]) _suspended=previous;}
    }
}
- (void)_readDistributedMessages {
    _DNCState *state=_distributedState;
    unsigned char bytes[65537];
    for (NSUInteger n=0;n<64;n++) {
        ssize_t size=recv(state->fd,bytes,sizeof(bytes),MSG_DONTWAIT);
        if (size<0) {if (errno==EINTR) {n--;continue;}break;}
        if (!size || (NSUInteger)size>DNCMessageLimit) continue;
        NSData *data=[NSData dataWithBytes:bytes length:size];
        id message=nil;
        @try {message=[NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];}
        @catch (NSException *exception) {continue;}
        if ([message isKindOfClass:[NSDictionary class]]) [self _receiveDistributed:message];
    }
}
@end
