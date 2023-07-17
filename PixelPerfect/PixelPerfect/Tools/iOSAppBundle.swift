import AppKit
import Foundation

enum iOSAppIdiom {
    case phone, pad, resizablePad, fullScreen
    
    var description: String {
        switch self {
        case .phone:
            return "Designed for iPhone".localized
        case .pad:
            return "Designed for iPad".localized
        case .resizablePad:
            return "Designed for iPad (Resizable)".localized
        case .fullScreen:
            return "Designed for iPad (Full Screen)".localized
        }
    }
}

class iOSAppBundle: Bundle {
    override init?(path: String) {
        super.init(path: path)
        // Bundle.main is automatically instantiated and cached, it is NSBundle and not iOSAppBundle.
        // Toss it out by checking for respondsToSelector.
        if !self.responds(to: #selector(self.preloadData)) {
            return nil
        }
    }
    
    // MARK: - Basic Properties
    @objc func preloadData() {
        loadContainerPath()
        _ = displayName
        _ = icon
        _ = userDefaults
    }
    
    private var _cachedDisplayName: String?
    var displayName: String {
        if (_cachedDisplayName == nil) {
            _cachedDisplayName = self.displayNameOnDemand
        }
        return _cachedDisplayName!
    }
    
    private var _cachedIcon: NSImage?
    var icon: NSImage {
        if (_cachedIcon == nil) {
            _cachedIcon = NSWorkspace.shared.icon(forFile: self.bundlePath)
        }
        return _cachedIcon!
    }
    
    private var _cachedUserDefaults: UserDefaults?
    var userDefaults: UserDefaults? {
        if (_cachedUserDefaults == nil) {
            forceReloadCachedUserDefaults()
        }
        return _cachedUserDefaults ?? UserDefaults(suiteName: self.bundleIdentifier)
    }
    
    func forceReloadCachedUserDefaults() {
        if let preferenceDomain = preferenceDomain, let containerDefaults = UserDefaults(suiteName: preferenceDomain) {
            _cachedUserDefaults = containerDefaults
        }
    }
    
    private var _cachedContainerPath: String?
    var containerPath: String? {
        loadContainerPath()
        return _cachedContainerPath
    }
    private func loadContainerPath() {
        if (_cachedContainerPath != nil) {
            return
        }
        forceReloadContainerPath()
    }
    func forceReloadContainerPath() {
        let manager = FileManager.default
        let containersRootPath = (containersPathWithTilde as NSString).expandingTildeInPath
        do {
            let subContainers = try manager.contentsOfDirectory(atPath: containersRootPath)
            for container in subContainers {
                let containerPath = "\(containersRootPath)/\(container)"
                if let containerPlist = NSDictionary(contentsOf: URL(fileURLWithPath: "\(containerPath)/\(containerMetadataPlistName)")) {
                    if let metadataIdentifier = containerPlist[containerMetadataIdentifierKey] as? String {
                        if metadataIdentifier == self.bundleIdentifier {
                            _cachedContainerPath = containerPath
                        }
                    }
                }
            }
        } catch {
            print(error)
        }
    }
    
    var preferenceDomain: String? {
        guard let bundleIdentifier = bundleIdentifier else {
            return nil
        }
        
        return containerPath?.appendingPathComponent(containerPreferencePathComponents).appendingPathComponent("\(bundleIdentifier)\(plistExtension)") ?? bundleIdentifier
    }
    
    var isNativeScaling: Bool {
        set {
            guard let defaults = self.userDefaults else {
                return
            }
            if (newValue) {
                defaults.setValue(nil, forKey: lastUsedWindowScaleFactorKey)
                defaults.setValue(1, forKey: scaleFactorKey)
            } else {
                defaults.setValue(nil, forKey: scaleFactorKey)
            }
        }
        get {
            return self.userDefaults?.float(forKey: scaleFactorKey) == 1
        }
    }
    
    var hasCompatibilityIssues: Bool {
        let compatibilityIssuesList = [
            "maccatalyst.com.atebits.Tweetie2"
        ]
        if let bundleID = self.bundleIdentifier {
            return compatibilityIssuesList.contains(bundleID)
        }
        return false
    }
    
    var looksLikeiOSOrScaledCatalystApp: Bool {
        if (self.bundlePath.isiOSAppBundlePath) {
            return true
        }
        guard let infoDict = self.infoDictionary else {
            return true
        }
        if let deviceFamily = infoDict[kUIDeviceFamily] as? [Int] {
            return !deviceFamily.contains(6)
        }
        if (infoDict[kCFBundleSupportedPlatforms] as? [String])?.contains("iPhoneOS") == true {
            return true
        }
        if (infoDict[kDTPlatformName] as? String)?.contains("iphoneos") == true {
            return true
        }
        if (infoDict[kDTSDKName] as? String)?.contains("iphoneos") == true {
            return true
        }
        if (infoDict[kLSRequiresIPhoneOS] as? Bool) == true {
            return true
        }
        return false
    }
    
    var isInstalledThroughPixelPerfect: Bool {
        return FileManager.default.fileExists(atPath: self.bundlePath.appendingPathComponent("Wrapper/\(pixelPerfectMetadataPlistName)"))
    }
    
    var infoPlistURL: URL? {
        return self.url(forResource: "Info", withExtension: "plist")
    }
    
    var infoPlistPath: String? {
        return self.path(forResource: "Info", ofType: "plist")
    }
    
    var idiom: iOSAppIdiom {
        guard let infoDict = self.infoDictionary else {
            return .phone
        }
        let supportsTrueScreenSize: Bool = (infoDict[kUISupportsTrueScreenSizeOnMac] as? Bool) ?? false
        let launchToFullScreenByDefault: Bool = (infoDict[kUILaunchToFullScreenByDefaultOnMac] as? Bool) ?? false
        let hasAllOrientations = (infoDict[kUISupportedInterfaceOrientations] as? Array)?.sorted() == kAllSupportedOrientations.sorted() || (infoDict[kUISupportedInterfaceOrientationsiPad] as? Array)?.sorted() == kAllSupportedOrientations.sorted()
        var requiresFullScreen = ((infoDict[kUIRequiresFullScreen] as? Bool) ?? false)
        if let requiresFullScreeniPad = infoDict[kUIRequiresFullScreeniPad] as? Bool {
            requiresFullScreen = requiresFullScreeniPad
        }
        let isResizable = hasAllOrientations && !requiresFullScreen
        var isPadIdiom = false
        if let deviceFamily = infoDict[kUIDeviceFamily] as? [Int] {
            if (deviceFamily.contains(6) || deviceFamily.contains(2)) {
                isPadIdiom = true
            }
        }
        if (supportsTrueScreenSize && launchToFullScreenByDefault && isPadIdiom && !isResizable) {
            return .fullScreen
        }
        if (isPadIdiom) {
            return isResizable ? .resizablePad : .pad
        }
        return .phone
    }
    
    var unindexed: Bool = false
    
    // MARK: - Actions
    func quitAndRelaunch(_ relaunch: Bool = true) {
        guard let bundleIdentifier = bundleIdentifier else {
            return
        }
        
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        for app in runningApps {
            SystemHelper.killProcessID(app.processIdentifier)
            if (relaunch) {
                Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { timer in
                    self.openApp()
                }
            }
        }
    }
    
    func openApp() {
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: NSWorkspace.OpenConfiguration())
    }
    
    func showInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
    }
    
}
