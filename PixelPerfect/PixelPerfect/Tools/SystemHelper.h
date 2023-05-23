#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SystemHelper : NSObject

+ (void)killProcessID:(pid_t)processID;

@end

NS_ASSUME_NONNULL_END
