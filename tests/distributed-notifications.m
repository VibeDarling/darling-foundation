#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

@interface DNCProbe : NSObject {
@public
  NSDistributedNotificationCenter *center;
  BOOL done, valid;
  int count;
}
- (void)payload:(NSNotification *)note;
- (void)finish:(NSNotification *)note;
- (void)ack:(NSNotification *)note;
@end
@implementation DNCProbe
- (void)payload:(NSNotification *)note {
  count++;
  NSDictionary *info = [note userInfo];
  valid =
      [NSThread isMainThread] &&
      [[info objectForKey:@"pid"] intValue] != getpid() &&
      [[[info objectForKey:@"nested"] objectForKey:@"answer"] intValue] == 42 &&
      [[info objectForKey:@"bytes"] isEqual:[NSData dataWithBytes:"abc"
                                                           length:3]];
  [center removeObserver:self name:@"DNC.Payload" object:@"object"];
  [center postNotificationName:@"DNC.Ack"
                        object:@"object"
                      userInfo:nil
                       options:NSDistributedNotificationDeliverImmediately |
                               NSDistributedNotificationPostToAllSessions];
}
- (void)finish:(NSNotification *)note {
  done = YES;
}
- (void)ack:(NSNotification *)note {
  done = YES;
}
@end

static BOOL pump(DNCProbe *probe) {
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:8];
  while (!probe->done && [deadline timeIntervalSinceNow] > 0)
    [[NSRunLoop currentRunLoop]
           runMode:NSDefaultRunLoopMode
        beforeDate:[NSDate dateWithTimeIntervalSinceNow:.05]];
  return probe->done;
}

@interface DNCCollector : NSObject {
@public
  NSMutableArray *values;
  BOOL mainThread;
}
- (void)note:(NSNotification *)note;
@end
@implementation DNCCollector
- (id)init {
  if ((self = [super init])) {
    values = [NSMutableArray new];
    mainThread = YES;
  }
  return self;
}
- (void)note:(NSNotification *)note {
  mainThread = mainThread && [NSThread isMainThread];
  [values addObject:[[note userInfo] objectForKey:@"seq"] ?: @0];
}
- (void)dealloc {
  [values release];
  [super dealloc];
}
@end
static void settle(void) {
  NSDate *end = [NSDate dateWithTimeIntervalSinceNow:.15];
  while ([end timeIntervalSinceNow] > 0)
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:end];
}
#define REQUIRE(...)                                                           \
  do {                                                                         \
    if (!(__VA_ARGS__)) {                                                      \
      fprintf(stderr, "semantics line %d failed: %s\n", __LINE__,              \
              #__VA_ARGS__);                                                   \
      return 10;                                                               \
    }                                                                          \
  } while (0)
static int semantics(NSDistributedNotificationCenter *center) {
  REQUIRE([NSDistributedNotificationCenter
              notificationCenterForType:NSLocalNotificationCenterType] ==
          center);
  DNCCollector *drop = [DNCCollector new], *coalesce = [DNCCollector new],
               *hold = [DNCCollector new], *immediate = [DNCCollector new];
  [center addObserver:drop
                selector:@selector(note:)
                    name:@"DNC.S"
                  object:nil
      suspensionBehavior:NSNotificationSuspensionBehaviorDrop];
  [center addObserver:coalesce
             selector:@selector(note:)
                 name:@"DNC.S"
               object:nil];
  [center addObserver:hold
                selector:@selector(note:)
                    name:@"DNC.S"
                  object:nil
      suspensionBehavior:NSNotificationSuspensionBehaviorHold];
  [center addObserver:immediate
                selector:@selector(note:)
                    name:@"DNC.I"
                  object:nil
      suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
  [center setSuspended:YES];
  for (int i = 1; i <= 2; i++)
    [center postNotificationName:@"DNC.S"
                          object:@"O"
                        userInfo:@{
                          @"seq" : @(i)
                        }
              deliverImmediately:NO];
  settle();
  REQUIRE([drop->values count] == 0 && [coalesce->values count] == 0 &&
          [hold->values count] == 0);
  [center setSuspended:NO];
  REQUIRE([drop->values count] == 0 && [coalesce->values isEqual:@[ @2 ]] &&
          [hold->values isEqual:@[ @1, @2 ]]);
  [center setSuspended:YES];
  for (int i = 3; i <= 4; i++)
    [center postNotificationName:@"DNC.S"
                          object:@"O"
                        userInfo:@{
                          @"seq" : @(i)
                        }
              deliverImmediately:NO];
  settle();
  [center postNotificationName:@"DNC.I"
                        object:nil
                      userInfo:@{
                        @"seq" : @5
                      }
            deliverImmediately:NO];
  settle();
  REQUIRE([center suspended] && [drop->values count] == 0 &&
          [coalesce->values isEqual:@[ @2, @4 ]] &&
          [hold->values isEqual:@[ @1, @2, @3, @4 ]] &&
          [immediate->values isEqual:@[ @5 ]]);
  [center postNotificationName:@"DNC.S"
                        object:@"O"
                      userInfo:@{
                        @"seq" : @6
                      }
            deliverImmediately:YES];
  settle();
  REQUIRE([center suspended] && [drop->values isEqual:@[ @6 ]] &&
          [coalesce->values isEqual:@[ @2, @4, @6 ]] &&
          [hold->values isEqual:@[ @1, @2, @3, @4, @6 ]]);
  REQUIRE(drop->mainThread && coalesce->mainThread && hold->mainThread &&
          immediate->mainThread);
  [center setSuspended:NO];
  BOOL rejected = NO;
  @try {
    [center postNotificationName:nil object:nil];
  } @catch (NSException *e) {
    rejected = [[e name] isEqualToString:NSInvalidArgumentException];
  }
  REQUIRE(rejected);
  rejected = NO;
  @try {
    [center postNotificationName:@"DNC.S"
                          object:nil
                        userInfo:@{@"bad" : [NSSet set]}];
  } @catch (NSException *e) {
    rejected = [[e name] isEqualToString:NSInvalidArgumentException];
  }
  REQUIRE(rejected);
  rejected = NO;
  @try {
    [center postNotificationName:@"DNC.S"
                          object:nil
                        userInfo:@{
                          @"large" : [NSMutableData dataWithLength:65537]
                        }];
  } @catch (NSException *e) {
    rejected = [[e name] isEqualToString:NSInvalidArgumentException];
  }
  REQUIRE(rejected);
  // This private-path access is solely a fixture for malformed wire input to
  // our own transport, never an inspection of a guest implementation.
  NSString *path =
      [[center valueForKey:@"_distributedState"] valueForKey:@"path"];
  int fd = socket(AF_UNIX, SOCK_DGRAM, 0);
  REQUIRE(fd >= 0);
  struct sockaddr_un address = {0};
  address.sun_family = AF_UNIX;
  strncpy(address.sun_path, [path fileSystemRepresentation],
          sizeof(address.sun_path) - 1);
  address.sun_len = SUN_LEN(&address);
  REQUIRE(sendto(fd, "not a plist", 11, 0, (struct sockaddr *)&address,
                 address.sun_len) == 11);
  NSData *bad = [NSPropertyListSerialization
      dataWithPropertyList:@{
        @"version" : @1,
        @"name" : @17
      }
                    format:NSPropertyListBinaryFormat_v1_0
                   options:0
                     error:NULL];
  REQUIRE(sendto(fd, [bad bytes], [bad length], 0, (struct sockaddr *)&address,
                 address.sun_len) == [bad length]);
  close(fd);
  settle();
  REQUIRE([drop->values isEqual:@[ @6 ]] &&
          [coalesce->values isEqual:@[ @2, @4, @6 ]]);
  [center removeObserver:drop];
  [center removeObserver:coalesce];
  [center removeObserver:hold];
  [center removeObserver:immediate];
  [drop release];
  [coalesce release];
  [hold release];
  [immediate release];
  puts("Distributed suspension, immediate delivery, payload limits and "
       "malformed input passed");
  return 0;
}

int main(int argc, char **argv) {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSDistributedNotificationCenter *center =
      [NSDistributedNotificationCenter defaultCenter];
  if (!center) {
    fputs("Distributed default center is nil\n", stderr);
    return 1;
  }
  fprintf(stderr, "probe uid=%u pid=%d\n", getuid(), getpid());
  if (argc < 2)
    return 2;
  if (!strcmp(argv[1], "post-probe")) {
    [center postNotificationName:@"DNC.Payload"
                          object:@"object"
                        userInfo:@{}
              deliverImmediately:YES];
    [pool drain];
    return 0;
  }
  if (!strcmp(argv[1], "semantics"))
    return semantics(center);
  DNCProbe *probe = [DNCProbe new];
  probe->center = center;
  if (!strcmp(argv[1], "receive")) {
    if (argc < 3)
      return 2;
    [center addObserver:probe
               selector:@selector(payload:)
                   name:@"DNC.Payload"
                 object:@"object"];
    [center addObserver:probe
               selector:@selector(finish:)
                   name:@"DNC.Done"
                 object:nil];
    FILE *ready = fopen(argv[2], "w");
    if (!ready)
      return 3;
    fputs("ready\n", ready);
    fclose(ready);
    if (!pump(probe) || !probe->valid || probe->count != 1) {
      fprintf(stderr, "receiver failed count=%d valid=%d done=%d\n",
              probe->count, probe->valid, probe->done);
      return 4;
    }
    puts("Cross-process payload, main-thread delivery, filters and removal "
         "passed");
  } else if (!strcmp(argv[1], "send") || !strcmp(argv[1], "send-all")) {
    BOOL all = !strcmp(argv[1], "send-all");
    NSDistributedNotificationOptions options =
        NSDistributedNotificationDeliverImmediately |
        (all ? NSDistributedNotificationPostToAllSessions : 0);
    if (all)
      [center postNotificationName:@"DNC.Payload"
                            object:@"object"
                          userInfo:@{
                            @"pid" : @(getpid()),
                            @"nested" : @{@"answer" : @0}
                          }
                deliverImmediately:YES];
    [center addObserver:probe
               selector:@selector(ack:)
                   name:@"DNC.Ack"
                 object:@"object"];
    NSDictionary *info = @{
      @"pid" : @(getpid()),
      @"nested" : @{@"answer" : @42},
      @"bytes" : [NSData dataWithBytes:"abc" length:3]
    };
    [center postNotificationName:@"DNC.Wrong"
                          object:@"object"
                        userInfo:info
                         options:options];
    [center postNotificationName:@"DNC.Payload"
                          object:@"wrong"
                        userInfo:info
                         options:options];
    [center postNotificationName:@"DNC.Payload"
                          object:@"object"
                        userInfo:info
                         options:options];
    if (!pump(probe)) {
      fputs("sender did not receive acknowledgement\n", stderr);
      return 5;
    }
    [center postNotificationName:@"DNC.Payload"
                          object:@"object"
                        userInfo:info
                         options:options];
    [center postNotificationName:@"DNC.Done"
                          object:nil
                        userInfo:nil
                         options:options];
    puts("Cross-process acknowledgement passed");
  } else
    return 2;
  [center removeObserver:probe];
  [probe release];
  [pool drain];
  return 0;
}
