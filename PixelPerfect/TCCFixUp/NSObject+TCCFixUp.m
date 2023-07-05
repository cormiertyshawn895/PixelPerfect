#import "NSObject+TCCFixUp.h"

#import <objc/runtime.h>

@interface NSObject ()
- (NSInteger)evaluatePolicyForPromptingforService:(id)arg1 byIdentity:(id)arg2 attributionChain:(id)arg3; // Monterey and earlier
- (NSInteger)promptingPolicyForIdentity:(id)arg1 accessingService:(id)arg2 withAttributionChain:(id)arg3; // Ventura and later
@end

@implementation NSObject (TCCFixUp)

+ (void)load {
    const char* currentprocname = getprogname();
    BOOL is_tccd = strcmp("tccd", currentprocname) == 0;
    if (!is_tccd) {
        return;
    }
    NSLog(@"[TCCFixUp] Loaded");
    Class platformClass = NSClassFromString(@"TCCDPlatformMacOS");
    NSLog(@"[TCCFixUp] TCCDPlatformMacOS is %@", platformClass);
    Method legacyOrigMethod = class_getInstanceMethod(platformClass, @selector(evaluatePolicyForPromptingforService:byIdentity:attributionChain:));
    Method legacyNewMethod = class_getInstanceMethod(platformClass, @selector(_fixUp_evaluatePolicyForPromptingforService:byIdentity:attributionChain:));
    method_exchangeImplementations(legacyOrigMethod, legacyNewMethod);

    Method origMethod = class_getInstanceMethod(platformClass, @selector(promptingPolicyForIdentity:accessingService:withAttributionChain:));
    Method newMethod = class_getInstanceMethod(platformClass, @selector(_fixUp_promptingPolicyForIdentity:accessingService:withAttributionChain:));
    method_exchangeImplementations(origMethod, newMethod);
}

// iPhone and iPad apps installed through Pixel Perfect fail to prompt for TCC. Return a functional prompting policy.
- (NSInteger)_fixUp_evaluatePolicyForPromptingforService:(id)arg1 byIdentity:(id)arg2 attributionChain:(id)arg3 {
    NSInteger policy = [self _fixUp_evaluatePolicyForPromptingforService:arg1 byIdentity:arg2 attributionChain:arg3];
    NSLog(@"[TCCFixUp] Original policy is %ld", (long)policy);
    if (policy != 0) {
        policy = 2;
        NSLog(@"[TCCFixUp] Changing policy to 2");
    } else {
        NSLog(@"[TCCFixUp] Keeping original policy");
    }
    return policy;
}

- (NSInteger)_fixUp_promptingPolicyForIdentity:(id)arg1 accessingService:(id)arg2 withAttributionChain:(id)arg3 {
    NSInteger policy = [self _fixUp_promptingPolicyForIdentity:arg1 accessingService:arg2 withAttributionChain:arg3];
    NSLog(@"[TCCFixUp] Original policy is %ld", (long)policy);
    if (policy != 0) {
        policy = 2;
        NSLog(@"[TCCFixUp] Changing policy to 2");
    } else {
        NSLog(@"[TCCFixUp] Keeping original policy");
    }
    return policy;
}

@end
