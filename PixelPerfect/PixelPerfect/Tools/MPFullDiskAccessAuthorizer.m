//
//  MPFullDiskAccessAuthorizer.m
//  PermissionsKit
//
//  Created by Sergii Kryvoblotskyi on 9/12/18.
//  Copyright © 2018 MacPaw. All rights reserved.
//

#import "MPFullDiskAccessAuthorizer.h"
#import <pwd.h>

@interface MPFullDiskAccessAuthorizer()

@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) NSWorkspace *workspace;
@property (nonatomic, copy) NSString *userHomeFolderPath;

@end

@implementation MPFullDiskAccessAuthorizer

- (instancetype)initWithFileManager:(NSFileManager *)fileManager workspace:(NSWorkspace *)workspace
{
    self = [super init];
    if (self)
    {
        _fileManager = fileManager;
        _workspace = workspace;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithFileManager:[NSFileManager defaultManager] workspace:[NSWorkspace sharedWorkspace]];
}

#pragma mark - Public

- (MPAuthorizationStatus)authorizationStatus
{
    if (@available(macOS 10.14, *))
    {
        return [self _fullDiskAuthorizationStatus];
    }
    else
    {
        return MPAuthorizationStatusAuthorized;
    }
}

- (void)requestAuthorizationWithCompletion:(nonnull void (^)(MPAuthorizationStatus))completionHandler
{
    if (@available(macOS 10.14, *))
    {
        [self _openPreferences];
    }
    else
    {
        completionHandler(MPAuthorizationStatusAuthorized);
    }
}

#pragma mark - Private


- (MPAuthorizationStatus)_checkFDAUsingFile:(NSString *)path
{
    int fd = open([path cStringUsingEncoding:NSUTF8StringEncoding], O_RDONLY);
    if (fd != -1)
    {
        close(fd);
        return MPAuthorizationStatusAuthorized;
    }
    
    if (errno == EPERM || errno == EACCES)
    {
        return MPAuthorizationStatusDenied;
    }
    
    return MPAuthorizationStatusNotDetermined;
}

- (MPAuthorizationStatus)_fullDiskAuthorizationStatus
{
    // We can't use just a single file to test FDA because:
    // a) the file might not exist
    // b) user might not have access to file even thought FDA is enabled
    // Therefore, if any of these files is readable - we have FDA,
    // otherwise if any exists, but can't be read, - we don't
    NSArray<NSString *> *testFiles = @[
        [self.userHomeFolderPath stringByAppendingPathComponent:@"Library/Safari/CloudTabs.db"],
        [self.userHomeFolderPath stringByAppendingPathComponent:@"Library/Safari/Bookmarks.plist"],
        @"/Library/Application Support/com.apple.TCC/TCC.db",
        @"/Library/Preferences/com.apple.TimeMachine.plist",
    ];
    
    MPAuthorizationStatus resultStatus = MPAuthorizationStatusNotDetermined;
    for (NSString *file in testFiles)
    {
        MPAuthorizationStatus status = [self _checkFDAUsingFile: file];
        if (status == MPAuthorizationStatusAuthorized)
        {
            resultStatus = MPAuthorizationStatusAuthorized;
            break;
        }
        if (status == MPAuthorizationStatusDenied)
        {
            resultStatus = MPAuthorizationStatusDenied;
        }
    }
    
    return resultStatus;
}

- (NSString *)userHomeFolderPath
{
    @synchronized (self)
    {
        if (!_userHomeFolderPath)
        {
            BOOL isSandboxed = (nil != NSProcessInfo.processInfo.environment[@"APP_SANDBOX_CONTAINER_ID"]);
            if (isSandboxed)
            {
                struct passwd *pw = getpwuid(getuid());
                assert(pw);
                _userHomeFolderPath = [NSString stringWithUTF8String:pw->pw_dir];
            }
            else
            {
                _userHomeFolderPath = NSHomeDirectory();
            }
        }
    }
    return _userHomeFolderPath;
}

- (void)_openPreferences
{
    [self.workspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"]];
}

@end
