import Foundation

extension String {
    var isiOSAppBundlePath: Bool {
        if self.contains(".Trash") {
            return false
        }
        let maybeValid = self.contains(wrapperTranslocatedPattern)
        || self.contains(playcoverPathComponents)
        || FileManager.default.fileExists(atPath: self.appendingPathComponent(wrappedBundleComponentName))
        if (!maybeValid) {
            return false
        }
        let isSIPEnabled = SystemInformation.shared.isSIPEnabled
        if (isSIPEnabled) {
            if (!FileManager.default.fileExists(atPath: self.appendingPathComponent("Wrapper/\(bundleMetadataPlistName)"))
                || FileManager.default.fileExists(atPath: self.appendingPathComponent("Wrapper/\(pixelPerfectMetadataPlistName)"))) {
                return false
            }
        }
        if (!isSIPEnabled && FileManager.default.fileExists(atPath: self.appendingPathComponent("Wrapper/iTunesMetadata.plist"))) {
            return false
        }
        return true
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
