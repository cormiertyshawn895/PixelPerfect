#import "NSColor+RIUAlternatingColor.h"

@implementation NSColor (RIUAlternatingColor)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
+ (NSArray<NSColor *> *)controlAlternatingRowBackgroundColors {
    return @[ NSColor.clearColor, [NSColor colorNamed:@"AlternateRowBackground"] ];
}
#pragma clang diagnostic pop

+ (NSArray<NSColor *> *)alternatingContentBackgroundColors {
    return @[ NSColor.clearColor, [NSColor colorNamed:@"AlternateRowBackground"] ];
}

@end
