#import "SystemHelper.h"

@implementation SystemHelper

+ (void)killProcessID:(pid_t)processID {
    const char *command = [NSString stringWithFormat:@"kill -9 %d", processID].UTF8String;
    system(command);
}

@end
