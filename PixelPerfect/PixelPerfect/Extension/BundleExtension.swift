import Foundation

extension Bundle {
    var cfBundleVersionInt: Int? {
        get {
            if let bundleVersion = self.infoDictionary?[kCFBundleVersion] as? String, let intVersion = Int(bundleVersion) {
                return intVersion
            }
            return nil
        }
    }
    
    var cfBundleVersionString: String? {
        get {
            return self.infoDictionary?[kCFBundleShortVersionString] as? String
        }
    }
    
    var resolvedInfoDictictionary: [String: Any] {
        return self.localizedInfoDictionary ?? self.infoDictionary ?? [:]
    }
    
    var bundleNameOnDemand: String {
        return resolvedInfoDictictionary[bundleNameKey] as? String ?? ((self.bundlePath as NSString).lastPathComponent as NSString).deletingPathExtension
    }
    
    var displayNameOnDemand: String {
        return resolvedInfoDictictionary[kCFBundleDisplayName] as? String ?? resolvedInfoDictictionary[bundleNameKey] as? String ?? ((self.bundlePath as NSString).lastPathComponent as NSString).deletingPathExtension
    }
}
