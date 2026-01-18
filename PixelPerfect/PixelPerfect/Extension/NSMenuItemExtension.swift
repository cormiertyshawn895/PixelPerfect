import AppKit

extension NSMenuItem {
    public convenience init(title: String, action: Selector?, keyEquivalent: String, symbolName: String?) {
        self.init(title: title, action: action, keyEquivalent: keyEquivalent)
        if #available(macOS 26.0, *) {
            if let name = symbolName {
                self.image = NSImage(systemSymbolName: name, accessibilityDescription: title)
            }
        }
    }
}
