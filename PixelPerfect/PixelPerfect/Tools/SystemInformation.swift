import Foundation

class SystemInformation {
    static let shared = SystemInformation()
    private var _isAppleSilicon = true
    private var _isTranslated = false
    
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
