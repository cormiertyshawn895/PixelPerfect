import Foundation

// MARK: - Pixel Perfect Defaults Key
let defaultsKeyShowDebugOptions = "ShowDebugOptions"
let defaultsKeyUnindexedExceptions = "UnindexedExceptions"
let windowAutoSaveName = "position"
let disableLibraryValidationKey = "DisableLibraryValidation"

// MARK: - iOS Apps Defaults Key
let bundleNameKey = "CFBundleName"
let scaleFactorKey = "iOSMacScaleFactor"
let lastUsedWindowScaleFactorKey = "UINSLastUsedWindowScaleFactor"
let mainSceneWindowKey = "NSWindow Frame MainSceneWindow"

// MARK: - Bundle Lookup
let appBundlePredicateFormat = "kMDItemContentType == 'com.apple.application-bundle'"
let applicationsPath = "/Applications"
let containersPathWithTilde = "~/Library/Containers"
let containerMetadataPlistName = ".com.apple.containermanagerd.metadata.plist"
let containerMetadataIdentifierKey = "MCMMetadataIdentifier"
let containerPreferencePathComponents = "Data/Library/Preferences"
let playcoverPathComponents = "Library/Containers/io.playcover.PlayCover"
let wrapperTranslocatedPattern = "/Wrapper/"
let wrappedBundleComponentName = "WrappedBundle"
let infoPlistName = "Info.plist"
let bundleMetadataPlistName = "BundleMetadata.plist"
let pixelPerfectMetadataPlistName = "PixelPerfectMetadata.plist"

// MARK: - SubPaths
let libraryValidationPath = "/Library/Preferences/com.apple.security.libraryvalidation.plist"
let tccFixUpSubPath = "TCCFixUp.framework/Versions/A/TCCFixUp"

// MARK: - Bundle Keys
let kCFBundleDisplayName = "CFBundleDisplayName"
let kCFBundleVersion = "CFBundleVersion"
let kCFBundleShortVersionString = "CFBundleShortVersionString"
let kUIDeviceFamily = "UIDeviceFamily"
let kUISupportsTrueScreenSizeOnMac = "UISupportsTrueScreenSizeOnMac"
let kUILaunchToFullScreenByDefaultOnMac = "UILaunchToFullScreenByDefaultOnMac"
let kUIRequiresFullScreen = "UIRequiresFullScreen"
let kUIRequiresFullScreeniPad = "UIRequiresFullScreen~ipad"
let kUISupportedInterfaceOrientations = "UISupportedInterfaceOrientations"
let kUISupportedInterfaceOrientationsiPhone = "UISupportedInterfaceOrientations~iphone"
let kUISupportedInterfaceOrientationsiPad = "UISupportedInterfaceOrientations~ipad"
let kUIInterfaceOrientationPortrait = "UIInterfaceOrientationPortrait"
let kUIInterfaceOrientationPortraitUpsideDown = "UIInterfaceOrientationPortraitUpsideDown"
let kUIInterfaceOrientationLandscapeLeft = "UIInterfaceOrientationLandscapeLeft"
let kUIInterfaceOrientationLandscapeRight = "UIInterfaceOrientationLandscapeRight"
let kAllSupportedOrientations = [kUIInterfaceOrientationPortrait, kUIInterfaceOrientationPortraitUpsideDown, kUIInterfaceOrientationLandscapeLeft, kUIInterfaceOrientationLandscapeRight]
let kCFBundleSupportedPlatforms = "CFBundleSupportedPlatforms"
let kDTPlatformName = "DTPlatformName"
let kDTSDKName = "DTSDKName"
let kLSRequiresIPhoneOS = "LSRequiresIPhoneOS"

// MARK: - Extensions
let appExtension = ".app"
let plistExtension = ".plist"

// MARK: - Text
let alertButtonSpacer = "  "

// MARK: - Paths
let tempDir = "/tmp"
let nvramToolPath = "/usr/sbin/nvram"
let csrutilToolPath = "/usr/bin/csrutil"
let launchctlToolPath = "/bin/launchctl"
let pgrepToolPath = "/usr/bin/pgrep"
let defaultsToolPath = "/usr/bin/defaults"

// MARK: - Boot Args
let bootArgsKey = "boot-args"
let allowAnySignatureKey = "amfi_allow_any_signature"
let allowAnySignatureYes = "amfi_allow_any_signature=1"
let getOutOfMyWayYes = "amfi_get_out_of_my_way=1"
let getOutOfMyWayAltYes = "amfi_get_out_of_my_way=0x1"
let arm64eABIKey = "-arm64e_preview_abi"
