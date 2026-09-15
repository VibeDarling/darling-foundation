#import <Foundation/NSObject.h>

@class NSString;

@interface NSLayoutConstraint : NSObject
{
    id _firstItem;
    NSInteger _firstAttribute;
    NSInteger _relation;
    id _secondItem;
    NSInteger _secondAttribute;
    double _multiplier;
    double _constant;
    float _priority;
    NSString *_identifier;
    NSString *_symbolicConstant;
    BOOL _active;
    BOOL _shouldBeArchived;
}

@end
