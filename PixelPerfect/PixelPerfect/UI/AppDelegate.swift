import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var showDebugOptionsMenuItem: NSMenuItem!
    @IBOutlet weak var separatorAboveInstallIPA: NSMenuItem!
    @IBOutlet weak var installIPAMenuItem: NSMenuItem!
    @IBOutlet weak var downloadIPAMenuItem: NSMenuItem!
    @IBOutlet weak var fileMenu: NSMenu!
    
    // MARK: - Static Helper Variables
    static var current: AppDelegate {
        return NSApplication.shared.delegate as! AppDelegate
    }
    
    static var showDebugOptions: Bool {
        get {
            return UserDefaults.standard.bool(forKey: defaultsKeyShowDebugOptions)
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: defaultsKeyShowDebugOptions)
        }
    }
    
    static var rootVC: ExceptionViewController? {
        get {
            return self.appWindow?.contentViewController as? ExceptionViewController
        }
    }
    
    static var appWindow: NSWindow? {
        if let mainWindow = NSApp.mainWindow {
            return mainWindow
        }
        for window in NSApp.windows {
            if let typed = window as? PixelPerfectWindow {
                return typed
            }
        }
        return nil
    }
    
    // MARK: - Lifecycle
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let _ = SystemInformation.shared
        NSApp.activate(ignoringOtherApps: true)
        updateShowDebugOptions()
        if (!SystemInformation.shared.isAppleSilicon) {
            fileMenu.removeItem(separatorAboveInstallIPA)
            fileMenu.removeItem(installIPAMenuItem)
            fileMenu.removeItem(downloadIPAMenuItem)
        }
        SystemInformation.shared.fixTCCPrompts()
    }
    
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        print("Opening \(filenames)")
        guard let rootVC = AppDelegate.rootVC else {
            print("No root VC, skipping")
            return
        }
        if rootVC.canInstallDecryptedIPA() {
            rootVC.installIPAFromPaths(paths: filenames, checkIfCanInstall: true)
        }
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    private func updateShowDebugOptions() {
        showDebugOptionsMenuItem.state = AppDelegate.showDebugOptions ? .on : .off
    }
    
    // MARK: - IBActions
    @IBAction func chooseAppClicked(_ sender: Any) {
        AppDelegate.rootVC?.chooseAppToAdd(self)
    }
    
    @IBAction func installDecryptedIPAClicked(_ sender: Any) {
        AppDelegate.rootVC?.chooseDecryptedIPA(self)
    }
    
    @IBAction func downloadDecryptedIPAClicked(_ sender: Any) {
        AppDelegate.rootVC?.downloadDecryptedIPA(self)
    }
    
    @IBAction func reloadClicked(_ sender: Any) {
        AppDelegate.rootVC?.searchForApps()
    }
    
    @IBAction func toggleShowDebugOptions(_ sender: Any) {
        AppDelegate.showDebugOptions.toggle()
        updateShowDebugOptions()
        AppDelegate.rootVC?.updateTableViewMenu()
    }
    
    @IBAction func checkForUpdates(_ sender: Any? = nil) {
        SystemInformation.shared.checkForConfigurationUpdates()
        if (SystemInformation.shared.hasNewerVersion == true) {
            self.promptForUpdateAvailable()
        } else {
            Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(promptForUpdateAvailable), userInfo: nil, repeats: false)
        }
    }
    
    @IBAction func showHelp(_ sender: Any) {
        AppDelegate.safelyOpenURL("https://github.com/cormiertyshawn895/PixelPerfect#using-pixel-perfect")
    }
    
    @IBAction func openProjectPageClicked(_ sender: Any) {
        AppDelegate.safelyOpenURL("https://github.com/cormiertyshawn895/PixelPerfect")
    }
    
    @IBAction func tipsClicked(_ sender: Any) {
        AppDelegate.safelyOpenURL("https://github.com/cormiertyshawn895/PixelPerfect#troubleshooting-tips")
    }
    
    @IBAction func issueTracker(_ sender: Any) {
        AppDelegate.safelyOpenURL("https://github.com/cormiertyshawn895/PixelPerfect/issues?q=")
    }
    
    @IBAction func openIssue(_ sender: Any? = nil) {
        AppDelegate.safelyOpenURL("https://github.com/cormiertyshawn895/PixelPerfect/issues/new")
    }
    
    // MARK: - Helper Methods
    static func safelyOpenURL(_ urlString: String?) {
        if let page = urlString, let url = URL(string: page) {
            NSWorkspace.shared.open(url)
        }
    }
    
    static func showOptionSheet(title: String, text: String, firstButtonText: String, secondButtonText: String, thirdButtonText: String, prefersKeyWindow: Bool = false, lastButtonCanEscape: Bool = true, callback: @escaping ((_ response: NSApplication.ModalResponse)-> ())) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.alertStyle = NSAlert.Style.informational
        alert.addButton(withTitle: firstButtonText)
        if secondButtonText.count > 0 {
            alert.addButton(withTitle: secondButtonText)
        }
        if thirdButtonText.count > 0 {
            alert.addButton(withTitle: thirdButtonText)
        }
        if (lastButtonCanEscape) {
            alert.buttons.last?.keyEquivalent = "\u{1b}"
        }
        if let window = prefersKeyWindow ? NSApp.keyWindow : self.appWindow {
            alert.beginSheetModal(for: window) { (response) in
                callback(response)
            }
        } else {
            let response = alert.runModal()
            callback(response)
        }
    }
    
    @objc func promptForUpdateAvailable() {
        if (SystemInformation.shared.hasNewerVersion == true) {
            var titleString = "Update available.".localized
            if let latestVersionNumber = SystemInformation.shared.latestVersionNumber, let latestBuildNumber = SystemInformation.shared.latestBuildNumber {
                titleString = String(format: "%@ %@ (Build %d) is available.".localized, Bundle.main.bundleNameOnDemand, latestVersionNumber, latestBuildNumber) as String
            }
            AppDelegate.showOptionSheet(title: titleString,
                                        text: "",
                                        firstButtonText: "Download".localized,
                                        secondButtonText: "Learn More...".localized,
                                        thirdButtonText: "Cancel".localized) { (response) in
                if (response == .alertFirstButtonReturn) {
                    AppDelegate.safelyOpenURL(SystemInformation.shared.latestZIP)
                } else if (response == .alertSecondButtonReturn) {
                    AppDelegate.safelyOpenURL(SystemInformation.shared.releasePage)
                }
            }
        } else {
            AppDelegate.showOptionSheet(title: String(format: "%@ %@ is already the latest available version.".localized, Bundle.main.bundleNameOnDemand, Bundle.main.cfBundleVersionString ?? ""),
                                        text:"",
                                        firstButtonText: "View Release Page...".localized,
                                        secondButtonText: "OK".localized,
                                        thirdButtonText: "") { (response) in
                if (response == .alertFirstButtonReturn) {
                    AppDelegate.safelyOpenURL(SystemInformation.shared.releasePage)
                }
            }
        }
    }
}

