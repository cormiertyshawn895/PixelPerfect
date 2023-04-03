import Cocoa

class PixelPerfectWindow: NSWindow {
}

class WindowController: NSWindowController {
    override func windowDidLoad() {
        super.windowDidLoad()
        self.windowFrameAutosaveName = windowAutoSaveName
    }
}
