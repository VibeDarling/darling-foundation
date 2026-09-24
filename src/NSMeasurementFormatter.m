#import <Foundation/NSMeasurementFormatter.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSNumberFormatter.h>
#import "NSUnitFormatterInternal.h"

@implementation NSMeasurementFormatter

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _unitStyle = NSFormattingUnitStyleMedium;
        _locale = [[NSLocale currentLocale] copy];
        _numberFormatter = _NSUnitFormatterNewNumberFormatter();
    }
    return self;
}

- (void)dealloc
{
    [_locale release];
    [_numberFormatter release];
    [super dealloc];
}

- (NSLocale *)locale
{
    return _locale;
}

- (void)setLocale:(NSLocale *)locale
{
    NSLocale *old = _locale;
    _locale = [locale ?: [NSLocale currentLocale] copy];
    [old release];
}

- (NSNumberFormatter *)numberFormatter
{
    return _numberFormatter;
}

- (void)setNumberFormatter:(NSNumberFormatter *)numberFormatter
{
    NSNumberFormatter *old = _numberFormatter;
    _numberFormatter = numberFormatter != nil ? [numberFormatter copy] : _NSUnitFormatterNewNumberFormatter();
    [old release];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSMeasurementFormatter *copy = [[[self class] allocWithZone:zone] init];
    copy->_unitOptions = _unitOptions;
    copy->_unitStyle = _unitStyle;
    [copy setLocale:_locale];
    [copy setNumberFormatter:_numberFormatter];
    return copy;
}

@end
