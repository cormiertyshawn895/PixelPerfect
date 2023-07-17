import EventKit
import Foundation

class SystemInformation {
    static let shared = SystemInformation()
    private var _isAppleSilicon = true
    private var _isTranslated = false
    private var _isSIPEnabled = true
    private var _isAppleSiliconVM = false
    
    private init() {
        if let path = Bundle.main.path(forResource: "SupportPath", ofType: "plist"),
           let loaded = NSDictionary(contentsOfFile: path) as? Dictionary<String, Any> {
            self.configurationDictionary = loaded
        }
        
        self.determineArchitecture()
        self.checkForConfigurationUpdates()
    }
    
    // MARK: - Architecture Determination
    var isAppleSilicon: Bool {
        return _isAppleSilicon
    }
    
    private func determineArchitecture() {
        let processIsTranslated = _processIsTranslated()
        _isTranslated = (processIsTranslated == EMULATED_EXECUTION)
        let machineArchitectureName = _machineArchitectureName()
        _isAppleSilicon = machineArchitectureName.contains("arm") || _isTranslated
        let sipStatus = Process.runNonAdminTask(toolPath: csrutilToolPath, arguments: ["status"])
        _isSIPEnabled = !sipStatus.lowercased().contains("disabled")
        let platform = _platform()
        _isAppleSiliconVM = platform.hasPrefix("VirtualMac")
    }
    
    private let NATIVE_EXECUTION = Int32(0)
    private let EMULATED_EXECUTION = Int32(1)
    private let UNKNOWN_EXECUTION = -Int32(1)
    
    private func _processIsTranslated() -> Int32 {
        let key = "sysctl.proc_translated"
        var ret = Int32(0)
        var size: Int = 0
        sysctlbyname(key, nil, &size, nil, 0)
        let result = sysctlbyname(key, &ret, &size, nil, 0)
        if result == -1 {
            if errno == ENOENT {
                return 0
            }
            return -1
        }
        return ret
    }
    
    private func _machineArchitectureName() -> String {
        var sysinfo = utsname()
        let result = uname(&sysinfo)
        guard result == EXIT_SUCCESS else { return "unknown" }
        let data = Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN))
        guard let identifier = String(bytes: data, encoding: .ascii) else { return "unknown" }
        return identifier.trimmingCharacters(in: .controlCharacters)
    }
    
    var isAppleSiliconVM: Bool {
        return _isAppleSiliconVM
    }
    
    private func _platform() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0,  count: size)
        sysctlbyname("hw.model", &machine, &size, nil, 0)
        return String(cString: machine)
    }
    
    var isSIPEnabled: Bool {
        return _isSIPEnabled
    }
    
    var deviceMissingFairPlay: Bool {
        return (isAppleSilicon && !isSIPEnabled) || isAppleSiliconVM
    }
    
    var isAnySignatureAllowed: Bool {
        let args = bootArgs
        if !args.contains(arm64eABIKey) {
            return false
        }
        if let libraryValidationDisabled = UserDefaults(suiteName: libraryValidationPath)?.bool(forKey: disableLibraryValidationKey) {
            if !libraryValidationDisabled {
                return false
            }
        }
        return args.contains(allowAnySignatureYes) || args.contains(getOutOfMyWayYes) || args.contains(getOutOfMyWayAltYes)
    }
    
    var canInstallAnyIPA: Bool {
        return isAppleSilicon && isAnySignatureAllowed
    }
    
    var macCategoryString: String {
        return isAppleSiliconVM ? "virtual Mac".localized : "Mac"
    }
    
    var bootArgs: [String] {
        var argsString = Process.runNonAdminTask(toolPath: nvramToolPath, arguments: [bootArgsKey])
        if argsString.contains("Error getting variable") || argsString.contains("data was not found") || argsString.contains("TCCFixUp") {
            return []
        }
        argsString = argsString.replacingOccurrences(of: "\(bootArgsKey)\t", with: "")
        argsString = argsString.replacingOccurrences(of: "\n", with: " ")
        return argsString.components(separatedBy: " ")
    }
    
    func ensureAnySignatureIsAllowed() {
        if isAnySignatureAllowed {
            return
        }
        if (self.runUnameToPreAuthenticate() != errAuthorizationSuccess) {
            return
        }
        _ = runTask(toolPath: defaultsToolPath, arguments: ["write", libraryValidationPath, disableLibraryValidationKey, "-bool", "true"])
        var filteredArgs = bootArgs.filter { arg in
            return !arg.contains(allowAnySignatureKey) && !arg.contains(arm64eABIKey) && arg.count > 0
        }
        filteredArgs.append(allowAnySignatureYes)
        filteredArgs.append(arm64eABIKey)
        let newArgsString = filteredArgs.joined(separator: " ")
        let result = runTask(toolPath: nvramToolPath, arguments: ["\(bootArgsKey)=\(newArgsString)"])
        if result == errAuthorizationSuccess {
            self.performReboot()
        }
    }
    
    func runUnameToPreAuthenticate() -> OSStatus {
        return self.runTask(toolPath: "/usr/bin/uname", arguments: ["-a"], path: tempDir, wait: true)
    }
    
    func runTask(toolPath: String, arguments: [String], path: String = tempDir, wait: Bool = true) -> OSStatus {
        let priviledgedTask = STPrivilegedTask()
        priviledgedTask.launchPath = toolPath
        priviledgedTask.arguments = arguments
        priviledgedTask.currentDirectoryPath = path
        let err: OSStatus = priviledgedTask.launch()
        if (err != errAuthorizationSuccess) {
            if (err == errAuthorizationCanceled) {
                print("User cancelled")
            } else {
                print("Something went wrong with authorization \(err)")
                // For error codes, see http://www.opensource.apple.com/source/libsecurity_authorization/libsecurity_authorization-36329/lib/Authorization.h
            }
            print("Critical error: Failed to authenticate")
            return err
        }
        if wait == true {
            priviledgedTask.waitUntilExit()
        }
        let readHandle = priviledgedTask.outputFileHandle
        if let outputData = readHandle?.readDataToEndOfFile(), let outputString = String(data: outputData, encoding: .utf8) {
            print("Output string is \(outputString), terminationStatus is \(priviledgedTask.terminationStatus)")
        }
        return err
    }
    
    func performReboot() {
        STPrivilegedTask.restart()
    }
    
    /* iPhone and iPad apps installed through Pixel Perfect fail to prompt for TCC.
       Insert into tccd to return a functional prompting policy.
     */
    func fixTCCPrompts() {
        if !canInstallAnyIPA {
            return
        }
        guard let tccFixUpPath = Bundle.main.privateFrameworksPath?.appendingPathComponent(tccFixUpSubPath) else {
            return
        }
        let tccdProcessIDStrings = Process.runNonAdminTask(toolPath: pgrepToolPath, arguments: ["tccd"]).components(separatedBy: .newlines)
        for tccdProcessIDString in tccdProcessIDStrings {
            if let pid = Int32(tccdProcessIDString) {
                SystemHelper.killProcessID(pid)
            }
        }
        _ = Process.runNonAdminTask(toolPath: launchctlToolPath, arguments: ["setenv", "DYLD_INSERT_LIBRARIES", tccFixUpPath])
        // Call EventKit to spin tccd back up with the inserted library
        _ = EKEventStore.authorizationStatus(for: .event)
        _ = Process.runNonAdminTask(toolPath: launchctlToolPath, arguments: ["unsetenv", "DYLD_INSERT_LIBRARIES"])
    }
    
    // MARK: - Update Configuration
    func checkForConfigurationUpdates() {
        guard let support = self.supportPath, let configurationPath = URL(string: support) else { return }
        self.downloadAndParsePlist(plistPath: configurationPath) { (newDictionary) in
            self.configurationDictionary = newDictionary
        }
    }
    
    func downloadAndParsePlist(plistPath: URL, completed: @escaping ((Dictionary<String, Any>) -> ())) {
        let task = URLSession.shared.dataTask(with: plistPath) { (data, response, error) in
            if error != nil {
                print("Error loading \(plistPath). \(String(describing: error))")
            }
            do {
                let data = try Data(contentsOf:plistPath)
                if let newDictionary = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? Dictionary<String, Any> {
                    print("Downloaded dictionary \(String(describing: self.configurationDictionary))")
                    completed(newDictionary)
                }
            } catch {
                print("Error loading fetched support data. \(error)")
            }
        }
        
        task.resume()
    }
    
    func refreshUpdateBadge() {
        self.syncMainQueue {
            if self.hasNewerVersion {
                print("update available")
                AppDelegate.rootVC?.reloadUpdateButton()
            }
        }
    }
    
    var hasNewerVersion: Bool {
        get {
            if let versionNumber = Bundle.main.cfBundleVersionInt, let remoteVersion = self.latestBuildNumber {
                print("\(versionNumber), \(remoteVersion)")
                if (versionNumber < remoteVersion) {
                    return true
                }
            }
            return false
        }
    }
    
    private var configurationDictionary: Dictionary<String, Any>? {
        didSet {
            self.refreshUpdateBadge()
        }
    }
    
    var latestVersionNumber: String? {
        return configurationDictionary?["LatestVersionNumber"] as? String
    }
    
    var latestBuildNumber: Int? {
        return configurationDictionary?["LatestBuildNumber"] as? Int
    }
    
    var latestZIP: String? {
        return configurationDictionary?["LatestZIP"] as? String
    }
    
    var supportPath: String? {
        return configurationDictionary?["SupportPathURL"] as? String
    }
    
    var releasePage: String? {
        return configurationDictionary?["ReleasePage"] as? String
    }
    
    // MARK: - Helper
    func syncMainQueue(closure: (() -> ())) {
        if !Thread.isMainThread {
            DispatchQueue.main.sync {
                closure()
            }
        } else {
            closure()
        }
    }
}
