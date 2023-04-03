import Foundation

extension String {
    var isiOSAppBundlePath: Bool {
        return self.contains(wrapperTranslocatedPattern)
        || FileManager.default.fileExists(atPath: "\(self)/\(wrappedBundleComponentName)")
        || self.contains(playcoverPathComponents)
    }
    
    func appendingPathComponent(_ str: String) -> String {
        return (self as NSString).appendingPathComponent(str)
    }
    
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
    var paddedWithSpaceSuffix: String {
        if (self.hasSuffix(" ") || self.hasSuffix("。")) {
            return self
        }
        return self.appending(" ")
    }
}
