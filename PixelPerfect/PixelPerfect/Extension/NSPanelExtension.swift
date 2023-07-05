import AppKit

extension NSOpenPanel {
    func beginSheetModalForAppWindow(completionHandler handler: @escaping (NSApplication.ModalResponse) -> Void) {
        if let window = AppDelegate.appWindow {
            self.beginSheetModal(for: window) { (response) in
                handler(response)
            }
        } else {
            let response = self.runModal()
            handler(response)
        }
    }
}
