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
        var resolved: [String: Any] = [:]
        if let infoDict = self.infoDictionary {
            resolved.merge(infoDict, uniquingKeysWith: { (_, new) in new })
        }
        if let locDict = self.localizedInfoDictionary {
            resolved.merge(locDict, uniquingKeysWith: { (_, new) in new })
        }
        return resolved
    }
    
    var bundleNameOnDemand: String {
        return resolvedInfoDictictionary[bundleNameKey] as? String ?? ((self.bundlePath as NSString).lastPathComponent as NSString).deletingPathExtension
    }
    
    var displayNameOnDemand: String {
        return resolvedInfoDictictionary[kCFBundleDisplayName] as? String ?? resolvedInfoDictictionary[bundleNameKey] as? String ?? ((self.bundlePath as NSString).lastPathComponent as NSString).deletingPathExtension
    }
    
    var nonLocalizedDisplayNameOnDemand: String {
        let infoDict = self.infoDictionary
        return infoDict?[kCFBundleDisplayName] as? String ?? infoDict?[bundleNameKey] as? String ?? ((self.bundlePath as NSString).lastPathComponent as NSString).deletingPathExtension
    }
}
