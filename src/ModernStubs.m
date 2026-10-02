#import <Foundation/Foundation.h>

@interface NSConstantArray : NSArray {
@public
    NSUInteger _count;
    id const *const _objects;
}
@end

@implementation NSConstantArray

- (NSUInteger)count
{
    return _count;
}

- (id)objectAtIndex:(NSUInteger)index
{
    if (index >= _count)
    {
        [NSException raise:NSRangeException format:@"Index %lu out of bounds [0, %lu)", (unsigned long)index, (unsigned long)_count];
        return nil;
    }
    return (id)_objects[index];
}

- (id)objectAtIndexedSubscript:(NSUInteger)index
{
    return [self objectAtIndex:index];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len
{
    if (state->state >= _count)
    {
        return 0;
    }
    state->itemsPtr = (id __unsafe_unretained *)_objects;
    state->state = _count;
    state->mutationsPtr = (unsigned long *)self;
    return _count;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

@end

@interface __NSConstantDictionaryKeyEnumerator : NSEnumerator {
    id const *_keys;
    NSUInteger _count;
    NSUInteger _idx;
}
- (id)initWithKeys:(id const *)keys count:(NSUInteger)count;
@end

@implementation __NSConstantDictionaryKeyEnumerator

- (id)initWithKeys:(id const *)keys count:(NSUInteger)count
{
    self = [super init];
    if (self)
    {
        _keys = keys;
        _count = count;
        _idx = 0;
    }
    return self;
}

- (id)nextObject
{
    if (_idx < _count)
    {
        return (id)_keys[_idx++];
    }
    return nil;
}

@end

@interface NSConstantDictionary : NSDictionary {
@public
    NSUInteger _hashOptions;
    NSUInteger _count;
    id const *const _keys;
    id const *const _objects;
}
@end

@implementation NSConstantDictionary

- (NSUInteger)count
{
    return _count;
}

- (id)objectForKey:(id)key
{
    if (key == nil)
        return nil;

    for (NSUInteger i = 0; i < _count; i++)
    {
        if ([key isEqual:(id)_keys[i]])
        {
            return (id)_objects[i];
        }
    }
    return nil;
}

- (id)objectForKeyedSubscript:(id)key
{
    return [self objectForKey:key];
}

- (NSEnumerator *)keyEnumerator
{
    return [[[__NSConstantDictionaryKeyEnumerator alloc] initWithKeys:_keys count:_count] autorelease];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len
{
    if (state->state >= _count)
    {
        return 0;
    }
    state->itemsPtr = (id __unsafe_unretained *)_keys;
    state->state = _count;
    state->mutationsPtr = (unsigned long *)self;
    return _count;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

@end

struct __NSArray0_struct {
    Class isa;
    NSUInteger count;
};
extern struct __NSArray0_struct __NSArray0__struct;

struct __NSDictionary0_struct {
    Class isa;
    NSUInteger count;
};
extern struct __NSDictionary0_struct __NSDictionary0__struct;

__attribute__((constructor))
static void init_modern_stubs(void) {
    __NSArray0__struct.isa = [NSConstantArray class];
    __NSDictionary0__struct.isa = [NSConstantDictionary class];
}
