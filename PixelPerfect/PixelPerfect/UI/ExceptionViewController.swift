import Cocoa
import UniformTypeIdentifiers

class ExceptionViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSMenuItemValidation, AppExceptionTableCellViewDelegate {
    var query: NSMetadataQuery!
    var hasFilesystemPermission = true
    var process: Process?
    var pipe: Pipe?
    var waitingPaths: [String] = []
    
    @Published var finishedGathering = false
    @Published var apps: [iOSAppBundle] = []
    
    @IBOutlet weak var explanationLabel: NSTextField!
    @IBOutlet weak var roundedBoxView: NSBox!
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var horizontalLineView: NSBox!
    @IBOutlet weak var actionContainerView: NSView!
    @IBOutlet weak var addButton: NSButton!
    
    @IBOutlet weak var loadingStackView: NSStackView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var getAppsImageButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var getAppsImageButton: NSButton!
    @IBOutlet weak var loadingButton: NSButton!
    @IBOutlet weak var bottomStackView: NSStackView!
    @IBOutlet weak var updateButton: NSButton!
    @IBOutlet weak var resetButton: NSButton?
    @IBOutlet weak var enableButton: NSButton?
    
    var sheetViewController: SheetViewController?
    var installationViewController: InstallationViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.layer?.backgroundColor = NSColor.clear.cgColor
        NotificationCenter.default.addObserver(self, selector: #selector(didFinishGathering), name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: nil)
        
        if #available(macOS 14.0, *) {
            hasFilesystemPermission = MPFullDiskAccessAuthorizer().authorizationStatus() == .authorized
        }

        setUpButtons()
        setUpScrollView()
        setUpTableView()
        searchForApps()
        reloadUpdateButton()
    }
    
    // MARK: - UI Setup
    func setUpButtons() {
        addButton.title = self.view.userInterfaceLayoutDirection == .leftToRight ? "  \(addButton.title)" : "\(addButton.title)  "
        updateButton.title = " \(updateButton.title) "
        (loadingButton.cell as? NSButtonCell)?.imageDimsWhenDisabled = false
        addButton.sendAction(on: [.leftMouseDown])
    }
    
    func setUpScrollView() {
        scrollView.wantsLayer = true
        scrollView.layer?.masksToBounds = true
        scrollView.layer?.cornerCurve = .continuous
        scrollView.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        scrollView.layer?.cornerRadius = 5
    }
    
    func setUpTableView() {
        tableView.selectionHighlightStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 48
        if !hasFilesystemPermission {
            return
        }
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
        tableView.registerForDraggedTypes([.fileURL])
        tableView.doubleAction = #selector(doubleClickOnResultRow)
        updateTableViewMenu()
    }
    
    func updateTableViewMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Reset".localized, action: #selector(tableViewResetItemClicked(_:)), keyEquivalent: "", symbolName: "arrow.clockwise"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show in Finder".localized, action: #selector(tableViewShowClickedItemInFinderClicked(_:)), keyEquivalent: "", symbolName: "finder"))
        if (SystemInformation.shared.canInstallAnyIPA) {
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: iOSAppIdiom.phone.description, action: #selector(tableViewUsePhoneIdiomClicked(_:)), keyEquivalent: "", symbolName: "iphone"))
            menu.addItem(NSMenuItem(title: iOSAppIdiom.pad.description, action: #selector(tableViewUsePadIdiomClicked(_:)), keyEquivalent: "", symbolName: "ipad"))
            menu.addItem(NSMenuItem(title: iOSAppIdiom.resizablePad.description, action: #selector(tableViewUseResizablePadIdiomClicked(_:)), keyEquivalent: "", symbolName: "square.resize"))
            menu.addItem(NSMenuItem(title: iOSAppIdiom.fullScreen.description, action: #selector(tableViewUseFullScreenGameIdiomClicked(_:)), keyEquivalent: "", symbolName: "arrow.up.backward.and.arrow.down.forward.rectangle"))
        }
        if (AppDelegate.showDebugOptions) {
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Copy Bundle Identifier".localized, action: #selector(tableViewCopyBundleIdentifierClicked(_:)), keyEquivalent: "", symbolName: "document.on.document"))
            menu.addItem(NSMenuItem(title: "Copy Preferences Domain".localized, action: #selector(tableViewCopyPreferencesPathClicked(_:)), keyEquivalent: "", symbolName: "globe"))
            menu.addItem(NSMenuItem(title: "Show Preferences".localized, action: #selector(tableViewShowPreferencesClicked(_:)), keyEquivalent: "", symbolName: "gear"))
        }
        tableView.menu = menu
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action, tableView.clickedRow >= 0 else {
            return true
        }
        let app = apps[tableView.clickedRow]
        var menuItemIdiom: iOSAppIdiom?
        if (action == #selector(tableViewUsePhoneIdiomClicked(_:))) {
            menuItemIdiom = .phone
        }
        if (action == #selector(tableViewUsePadIdiomClicked(_:))) {
            menuItemIdiom = .pad
        }
        if (action == #selector(tableViewUseResizablePadIdiomClicked(_:))) {
            menuItemIdiom = .resizablePad
        }
        if (action == #selector(tableViewUseFullScreenGameIdiomClicked(_:))) {
            menuItemIdiom = .fullScreen
        }
        if menuItemIdiom == nil {
            return true
        }
        menuItem.isHidden = !app.isInstalledThroughPixelPerfect
        menuItem.state = (menuItemIdiom == app.idiom) ? .on : .off
        return true
    }
    
    // MARK: - State Update
    func reloadUpdateButton() {
        let hasNewerVersion = SystemInformation.shared.hasNewerVersion
        updateButton.isHidden = !hasNewerVersion
    }
    
    func sortPersistAndReload() {
        apps.sort { app1, app2 in
            return app1.displayName.compare(app2.displayName, locale: NSLocale.current) == .orderedAscending
        }
        self.reloadStateAndTableData()
    }
    
    func reloadStateAndTableData() {
        updateLoadingState()
        tableView.reloadData()
    }
    
    func updateLoadingState() {
        let hasApps = apps.count > 0
        scrollView.layer?.opacity = (!finishedGathering || !hasApps) ? 0 : 1
        horizontalLineView.isHidden = !finishedGathering || !hasFilesystemPermission
        actionContainerView.isHidden = !finishedGathering || !hasFilesystemPermission
        loadingStackView.isHidden = finishedGathering && hasApps
        loadingButton.isEnabled = finishedGathering
        loadingButton.usesSingleLineMode = false
        if (finishedGathering) {
            if (hasFilesystemPermission) {
                if (SystemInformation.shared.deviceMissingFairPlay) {
                    loadingButton.title = "Download iPhone and iPad apps from\n your favorite decryption service".localized.appending(" ↗")
                } else {
                    loadingButton.title = SystemInformation.shared.isAppleSilicon ? "Download iPhone and iPad apps \n from the App Store".localized.appending(" ↗") : "iPhone and iPad apps require \n a Mac with Apple silicon.".localized
                }
            } else {
                explanationLabel.stringValue = "Full Disk Access is required for iPhone and iPad apps to run at native resolution with pixel-perfect graphics and razor sharp text.".localized
                getAppsImageButton.image = NSImage(named: "FullDiskAccess")
                getAppsImageButtonHeightConstraint.constant = 50
                loadingButton.title = "Allow Full Disk Access\n in System Settings".localized.appending(" ↗")
                loadingButton.contentTintColor = NSColor.controlTextColor
                resetButton?.removeFromSuperview()
                enableButton?.title = "Open System Settings".localized
            }
        } else {
            loadingButton.title = "Loading applications...".localized
        }
        progressIndicator.isHidden = finishedGathering
        getAppsImageButton.isHidden = !finishedGathering
        if (finishedGathering) {
            progressIndicator.stopAnimation(nil)
        } else {
            progressIndicator.startAnimation(nil)
        }
    }
    
    func openFullDiskAccessSettingsIfNeeded() -> Bool {
        if (hasFilesystemPermission) {
            return false
        }
        MPFullDiskAccessAuthorizer().requestAuthorization { _ in }
        return true
    }
    
    // MARK: - IBActions
    @IBAction func updateAvailableClicked(_ sender: Any) {
        AppDelegate.current.promptForUpdateAvailable()
    }
    
    @IBAction func loadingButtonClicked(_ sender: Any) {
        if (openFullDiskAccessSettingsIfNeeded()) {
            return
        }
        if (SystemInformation.shared.deviceMissingFairPlay) {
            downloadDecryptedIPA(self)
        } else if (SystemInformation.shared.isAppleSilicon) {
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/App Store.app"), configuration: NSWorkspace.OpenConfiguration())
        } else {
            AppDelegate.safelyOpenURL("https://support.apple.com/HT211814")
        }
    }
    
    @IBAction func addButtonClicked(_ sender: Any) {
        let candidateSources: [NSRunningApplication] = NSWorkspace.shared.runningApplications
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Choose App…".localized, action: #selector(chooseAppToAdd(_:)), keyEquivalent: "", symbolName: "arrow.up.forward"))
        menu.addItem(NSMenuItem.separator())
        if (candidateSources.count > 0) {
            menu.addItem(NSMenuItem.separator())
            for candidate in candidateSources {
                guard let path = candidate.bundleURL?.path else {
                    continue
                }
                if !path.isiOSAppBundlePath {
                    continue
                }
                guard let exception = exceptionForPath(path: (candidate.bundleURL?.path)) else {
                    continue
                }
                if (exception.isNativeScaling) {
                    continue
                }
                let menuItem = NSMenuItem(title: exception.displayName, action: #selector(addFromCandidateSource(_:)), keyEquivalent: "", symbolName: "app.grid")
                if let imageCopy = exception.icon.copy() as? NSImage {
                    imageCopy.size = NSSize(width: 18, height: 18)
                    menuItem.image = imageCopy
                }
                menuItem.representedObject = exception
                menu.addItem(menuItem)
            }
        }
        if (SystemInformation.shared.isAppleSilicon) {
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Install Decrypted IPA…".localized, action: #selector(chooseDecryptedIPA(_:)), keyEquivalent: "", symbolName: "plus.square"))
            menu.addItem(NSMenuItem(title: "Download Decrypted IPA…".localized, action: #selector(downloadDecryptedIPA(_:)), keyEquivalent: "", symbolName: "square.and.arrow.down"))
        }
        let point = NSPoint(x: 0, y: addButton.bounds.size.height)
        menu.popUp(positioning: nil, at: point, in: addButton)
    }
    
    @IBAction func resetClicked(_ sender: Any) {
        if (openFullDiskAccessSettingsIfNeeded()) {
            return
        }
        if apps.count == 0 {
            return
        }
        setAppsNativeScaling(apps: apps, enabled: false, removeUnindexed: true, showSummary: true)
    }
    
    @IBAction func selectAllClicked(_ sender: Any) {
        if (openFullDiskAccessSettingsIfNeeded()) {
            return
        }
        if apps.count == 0 {
            return
        }
        setAppsNativeScaling(apps: apps, enabled: true, showSummary: true)
    }
    
    // MARK: - Update Scaling Status
    func didToggleCheckbox(_ cell: AppExceptionTableCellView) {
        let row = tableView.row(for: cell)
        let exception = apps[row]
        setAppsNativeScaling(apps: [exception], enabled: cell.enablementSwitch.state == .on, needsReload: false)
    }
    
    func setAppsNativeScaling(apps: [iOSAppBundle], enabled: Bool, removeUnindexed: Bool = false, needsReload: Bool = true, showSummary: Bool = false) {
        var appsNeedingRelaunch: [iOSAppBundle] = []
        for app in apps {
            let oldValue = app.isNativeScaling
            app.isNativeScaling = enabled
            if (!enabled && removeUnindexed && app.unindexed) {
                self.apps.removeAll { pending in
                    pending == app
                }
                modifyDefaultsForUnindexedItem(exception: app, remove: true)
            }
            if (oldValue != enabled) {
                guard let bundleIdentifier = app.bundleIdentifier else {
                    continue
                }
                let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
                if (runningApps.count == 0) {
                    continue
                }
                appsNeedingRelaunch.append(app)
            }
        }
        if (needsReload) {
            reloadStateAndTableData()
        }
        let needsRelaunch = appsNeedingRelaunch.count > 0
        if (showSummary || needsRelaunch) {
            let relaunchSummary = summaryForMultipleApps(apps: appsNeedingRelaunch)
            let mainSummary = summaryForMultipleApps(apps: apps)
            let mainTitle = enabled ? String(format: "Native resolution has been enabled for %@.".localized, mainSummary) : String(format: "%@ has been reset to scaled resolution.".localized, mainSummary)
            
            let relaunchTitle = enabled ? String(format: "%@ will run at native resolution after it is reopened.".localized, relaunchSummary) : String(format: "%@ will reset to scaled resolution after it is reopened.".localized, relaunchSummary)
            let relaunchText = String(format: "You can choose to quit %@ now, or do it on your own later.".localized, relaunchSummary)
            let quitAndReopenText = alertButtonSpacer.appending(String(format: "Quit & Reopen".localized)).appending(alertButtonSpacer)
            let laterText = String(format: "Later".localized)
            
            let resolvedTitle = showSummary ? mainTitle : relaunchTitle
            var resolvedText = ""
            if (needsRelaunch) {
                resolvedText = showSummary ? "\(relaunchTitle.paddedWithSpaceSuffix)\(relaunchText)" : relaunchText
            }
            let resolvedFirstButtonText = needsRelaunch ? quitAndReopenText : "OK".localized
            let resolvedSecondButtonText = needsRelaunch ? laterText : ""
            
            AppDelegate.showOptionSheet(title: resolvedTitle, text: resolvedText, firstButtonText: resolvedFirstButtonText, secondButtonText: resolvedSecondButtonText, thirdButtonText: "") { response in
                if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                    for app in appsNeedingRelaunch {
                        app.quitAndRelaunch()
                    }
                }
            }
        }
    }
    
    // MARK: - Table View: Data Source
    func numberOfRows(in tableView: NSTableView) -> Int {
        return apps.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "AppCellID"), owner: nil) as? AppExceptionTableCellView else {
            return nil
        }
        let exception = apps[row]
        view.iconView.image = exception.icon
        view.label.stringValue = exception.displayName
        view.enablementSwitch.state = exception.isNativeScaling ? .on : .off
        view.delegate = self
        return view
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 48
    }
    
    // MARK: - Table View: Interactions
    @objc func doubleClickOnResultRow(_ sender: Any?) {
        showClickedItem(inFinder: false)
    }
    
    @objc private func tableViewShowClickedItemInFinderClicked(_ sender: AnyObject) {
        showClickedItem(inFinder: true)
    }
    
    @objc private func tableViewResetItemClicked(_ sender: AnyObject) {
        guard tableView.clickedRow >= 0 else {
            return
        }
        let index = tableView.clickedRow
        let exception = apps[index]
        self.setAppsNativeScaling(apps: [exception], enabled: false, removeUnindexed: true, needsReload: true)
    }
    
    @objc private func showClickedItem(inFinder: Bool) {
        guard tableView.clickedRow >= 0 else {
            return
        }
        let exception = apps[tableView.clickedRow]
        if (inFinder) {
            exception.showInFinder()
        } else {
            exception.openApp()
        }
    }
    
    @objc private func tableViewCopyBundleIdentifierClicked(_ sender: AnyObject) {
        if let bundleID = apps[tableView.clickedRow].bundleIdentifier {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(bundleID, forType: .string)
        }
    }
    
    @objc private func tableViewCopyPreferencesPathClicked(_ sender: AnyObject) {
        if let preferenceDomain = apps[tableView.clickedRow].preferenceDomain {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(preferenceDomain, forType: .string)
        }
    }
    
    @objc private func tableViewShowPreferencesClicked(_ sender: AnyObject) {
        if let preferenceDomain = apps[tableView.clickedRow].preferenceDomain {
            let script = NSAppleScript(source: "tell application \"Terminal\" to do script \"defaults read \(preferenceDomain)\"")
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
            if let error = error {
                print(error)
            }
        }
    }
    
    @objc private func tableViewUsePhoneIdiomClicked(_ sender: AnyObject) {
        updateSelectedRowAppWithNewIdiom(idiom: .phone)
    }
    
    @objc private func tableViewUsePadIdiomClicked(_ sender: AnyObject) {
        updateSelectedRowAppWithNewIdiom(idiom: .pad)
    }
    
    @objc private func tableViewUseResizablePadIdiomClicked(_ sender: AnyObject) {
        updateSelectedRowAppWithNewIdiom(idiom: .resizablePad)
    }
    
    @objc private func tableViewUseFullScreenGameIdiomClicked(_ sender: AnyObject) {
        updateSelectedRowAppWithNewIdiom(idiom: .fullScreen)
    }
    
    func updateSelectedRowAppWithNewIdiom(idiom: iOSAppIdiom) {
        guard tableView.clickedRow >= 0 else {
            return
        }
        let app = apps[tableView.clickedRow]
        updateAppWithNewIdiom(app, idiom: idiom)
    }
    
    func updateAppWithNewIdiom(_ app: iOSAppBundle, idiom: iOSAppIdiom) {
        guard var infoDictionary = app.infoDictionary, let infoPlistURL = app.infoPlistURL else {
            return
        }
        if (app.idiom == idiom) {
            return
        }
        switch idiom {
        case .phone:
            infoDictionary[kUIDeviceFamily] = [1]
            infoDictionary[kUILaunchToFullScreenByDefaultOnMac] = nil
            infoDictionary[kUISupportsTrueScreenSizeOnMac] = nil
        case .pad:
            infoDictionary[kUIDeviceFamily] = [1, 2]
            infoDictionary[kUIRequiresFullScreen] = true
            infoDictionary[kUIRequiresFullScreeniPad] = nil
            infoDictionary[kUILaunchToFullScreenByDefaultOnMac] = nil
            infoDictionary[kUISupportsTrueScreenSizeOnMac] = nil
            infoDictionary[kUISupportedInterfaceOrientationsiPad] = kAllSupportedOrientations
        case .resizablePad:
            infoDictionary[kUIDeviceFamily] = [1, 2]
            infoDictionary[kUIRequiresFullScreen] = nil
            infoDictionary[kUIRequiresFullScreeniPad] = nil
            infoDictionary[kUILaunchToFullScreenByDefaultOnMac] = nil
            infoDictionary[kUISupportsTrueScreenSizeOnMac] = nil
            infoDictionary[kUISupportedInterfaceOrientationsiPad] = kAllSupportedOrientations
        case .fullScreen:
            infoDictionary[kUIDeviceFamily] = [1, 2]
            infoDictionary[kUIRequiresFullScreen] = true
            infoDictionary[kUIRequiresFullScreeniPad] = nil
            infoDictionary[kUILaunchToFullScreenByDefaultOnMac] = true
            infoDictionary[kUISupportsTrueScreenSizeOnMac] = true
            infoDictionary[kUISupportedInterfaceOrientations] = kAllSupportedOrientations
            infoDictionary[kUISupportedInterfaceOrientationsiPhone] = nil
            infoDictionary[kUISupportedInterfaceOrientationsiPad] = nil
        }
        var success = false
        DispatchQueue.global(qos: .userInteractive).async {
            app.userDefaults?.setValue(nil, forKey: mainSceneWindowKey)
            do {
                try (infoDictionary as NSDictionary).write(to: infoPlistURL)
                _ = self.signComponent(at: app.bundlePath)
                success = true
            } catch {
                print("Write failed: \(error)")
                print("Trying to escalate permissions: \(error)")
                let tempDir = NSTemporaryDirectory()
                let tempInfoPlistPath = tempDir.appendingPathComponent("\(UUID().uuidString)-Info.plist")
                let tempInfoPlistURL = URL(fileURLWithPath: tempInfoPlistPath)
                do {
                    try (infoDictionary as NSDictionary).write(to: tempInfoPlistURL)
                    if SystemInformation.shared.runUnameToPreAuthenticate() == errAuthorizationSuccess, let infoPlistPath = app.infoPlistPath {
                        if SystemInformation.shared.runTask(toolPath: "/bin/cp", arguments: [tempInfoPlistPath, infoPlistPath]) == errAuthorizationSuccess {
                            if SystemInformation.shared.runTask(toolPath: "/usr/bin/codesign", arguments: ["--force", "--sign", "-", "--preserve-metadata=identifier,entitlements", app.bundlePath]) == errAuthorizationSuccess {
                                success = true
                            }
                        }
                    }
                } catch {
                    print("Write to temp directory failed: \(error)")
                }
            }
            STPrivilegedTask.flushBundleCache(app)
            if (success) {
                DispatchQueue.main.async {
                    self.showAlertForUpdatedIdiom(app: app, idiom: idiom)
                }
            }
        }
    }
    
    func showAlertForUpdatedIdiom(app: iOSAppBundle, idiom: iOSAppIdiom) {
        guard let bundleIdentifier = app.bundleIdentifier else {
            return
        }
        let isRunning = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).count > 0
        let mainTitle = String(format: "%@ is now %@.".localized, app.displayName, idiom.description)
        let text = String(format: "This new design takes effect when you reopen %@. If %@ quits unexpectedly, try to open it again.".localized, app.displayName, app.displayName)
        let firstButtonTitle = isRunning ? alertButtonSpacer + String(format: "Quit %@".localized, app.displayName) + alertButtonSpacer : "OK".localized
        let secondButtonTitle = isRunning ? "Not Now".localized : ""
        AppDelegate.showOptionSheet(title: mainTitle, text: text, firstButtonText: firstButtonTitle, secondButtonText: secondButtonTitle, thirdButtonText: "") { response in
            if (isRunning && response == .alertFirstButtonReturn) {
                app.quitAndRelaunch(false)
            }
        }
    }
    
    // MARK: - Table View: Drag and Drop
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation
    {
        if dropOperation == .above && appPathsForInfo(info: info).count > 0 {
            return .copy
        }
        return []
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        let paths = appPathsForInfo(info: info)
        if (paths.count > 0) {
            addExceptionForPaths(paths: paths)
            return true
        }
        return false
    }
    
    func appPathsForInfo(info: NSDraggingInfo) -> [String] {
        guard let items = info.draggingPasteboard.pasteboardItems else {
            return []
        }
        
        var paths: [String] = []
        print("Dropped \(items)")
        for item in items {
            if let data = item.data(forType: .fileURL), let url = URL(dataRepresentation: data, relativeTo: nil) {
                print(url)
                let path = url.path
                let resourceValues = try? url.resourceValues(forKeys: [URLResourceKey.contentTypeKey])
                print("Resource value = \(String(describing: resourceValues))")
                if let fileType = resourceValues?.contentType {
                    print("File type is \(fileType)")
                    if fileType.conforms(to: UTType.applicationBundle) || fileType.conforms(to: UTType.unixExecutable) {
                        paths.append(path)
                    }
                }
            }
        }
        return paths
    }
    
    // MARK: - Spotlight: Looking Up Apps
    func searchForApps() {
        if !hasFilesystemPermission {
            finishedGathering = true
            updateLoadingState()
            return
        }
        
        finishedGathering = false
        updateLoadingState()
        if query != nil {
            query.stop()
        }
        query = NSMetadataQuery()
        let pred = NSPredicate(format: appBundlePredicateFormat)
        query.predicate = pred
        query.start()
    }
    
    @objc func didFinishGathering(_ notification: Notification) {
        apps = []
        DispatchQueue.global(qos: .userInteractive).async {
            self.updateApps()
        }
    }
    
    func updateApps() {
        var seenSet: [String] = []
        for result in query.results {
            guard let item = result as? NSMetadataItem else {
                continue
            }
            guard let path = item.value(forAttribute: NSMetadataItemPathKey as String) as? String else {
                continue
            }
            if (!path.isiOSAppBundlePath) {
                continue
            }
            guard let bundle = iOSAppBundle(path: path), let bundleID = bundle.bundleIdentifier else {
                continue
            }
            if (seenSet.contains(bundleID) == false) {
                bundle.preloadData()
                apps.append(bundle)
                seenSet.append(bundleID)
            }
        }
        
        if let existingUnindexedExceptions = UserDefaults.standard.array(forKey: defaultsKeyUnindexedExceptions) as? [String] {
            for unindexed in existingUnindexedExceptions {
                let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: unindexed)?.path ?? unindexed
                if let bundle = iOSAppBundle(path: path), let bundleID = bundle.bundleIdentifier {
                    bundle.unindexed = true
                    if (seenSet.contains(bundleID) == false) {
                        bundle.preloadData()
                        apps.append(bundle)
                        seenSet.append(bundleID)
                    }
                }
            }
        }
        
        let fileManager = FileManager.default
        func updatePlayCoverApps(forComponents: String) {
            let directoryURL = URL(fileURLWithPath: ("~/\(forComponents)" as NSString).expandingTildeInPath)
            do {
                let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                for item in contents {
                    var isDirectory: ObjCBool = false
                    let path = item.path
                    if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
                        if isDirectory.boolValue && path.hasSuffix(appExtension) {
                            if let bundle = iOSAppBundle(path: path) {
                                guard let bundleID = bundle.bundleIdentifier else {
                                    continue
                                }
                                if (seenSet.contains(bundleID) == false) {
                                    bundle.preloadData()
                                    apps.append(bundle)
                                    seenSet.append(bundleID)
                                }
                            }
                        }
                    }
                }
            } catch {
                print("Error while enumerating files: \(error.localizedDescription)")
            }
        }
        updatePlayCoverApps(forComponents: playcoverPathComponents)
        updatePlayCoverApps(forComponents: playcover3PathComponents)

        apps.sort { app1, app2 in
            return app1.displayName.compare(app2.displayName, locale: NSLocale.current) == .orderedAscending
        }
        DispatchQueue.main.async {
            self.finishedGathering = true
            self.reloadStateAndTableData()
        }
    }
    
    // MARK: - Add Exception
    @objc func chooseAppToAdd(_ sender: Any) {
        presentAppPicker()
    }
    
    @objc func chooseDecryptedIPA(_ sender: Any) {
        if self.canInstallDecryptedIPA() {
            presentAppPicker(forIPA: true)
        }
    }
    
    @objc func downloadDecryptedIPA(_ sender: Any) {
        let currentTimeZone = TimeZone.current.identifier
        if currentTimeZone == "Asia/Shanghai" || currentTimeZone == "Asia/Urumqi" {
            AppDelegate.safelyOpenURL("https://www.bing.com/search?q=Decrypt+IPA+Store")
        } else {
            AppDelegate.safelyOpenURL("https://www.google.com/search?q=Decrypt+IPA+Store")
        }
    }
    
    func canInstallDecryptedIPA() -> Bool {
        if !SystemInformation.shared.isAppleSilicon {
            print("Requires Apple Silicon")
            return false
        }
        if SystemInformation.shared.isSIPEnabled {
            if sheetViewController == nil {
                sheetViewController = SheetViewController.instantiate()
                if SystemInformation.shared.isAppleSiliconVM {
                    sheetViewController?.guidanceType = .asVMLowering
                }
            }
            if let sheetViewController = sheetViewController {
                if sheetViewController.view.window == nil {
                    self.presentAsSheet(sheetViewController)
                }
            }
            return false
        }
        if !SystemInformation.shared.isAnySignatureAllowed {
            let text = String(format: "By allowing decrypted iPhone and iPad apps, your %@ can run them with a high degree of compatibility. Your %@ will automatically restart afterwards.".localized, SystemInformation.shared.macCategoryString, SystemInformation.shared.macCategoryString)
            AppDelegate.showOptionSheet(title: "Would you like to allow decrypted iPhone and iPad apps?".localized, text: text, firstButtonText: "Allow and Restart".localized, secondButtonText: "Cancel".localized, thirdButtonText: "") { response in
                if (response == .alertFirstButtonReturn) {
                    SystemInformation.shared.ensureAnySignatureIsAllowed()
                }
            }
            return false
        }
        return true
    }
    
    func presentAppPicker(forIPA: Bool = false) {
        if (openFullDiskAccessSettingsIfNeeded()) {
            return
        }
        let dialog = NSOpenPanel()
        if (!forIPA) {
            dialog.directoryURL = URL(fileURLWithPath: applicationsPath)
        }
        dialog.showsResizeIndicator = true
        dialog.allowsMultipleSelection = true
        dialog.canChooseDirectories = false
        dialog.allowedContentTypes = []
        if forIPA, let ipaType = UTType("com.apple.itunes.ipa") {
            dialog.allowedContentTypes = [ ipaType, UTType.zip ]
        } else {
            dialog.allowedContentTypes = [UTType.applicationBundle]
        }
        
        dialog.beginSheetModalForAppWindow { response in
            self.handleAppPickerResult(response: response, dialog: dialog, forIPA: forIPA)
        }
    }
    
    func handleAppPickerResult(response: NSApplication.ModalResponse, dialog: NSOpenPanel, forIPA: Bool) {
        if (response !=  NSApplication.ModalResponse.OK) {
            return
        }
        let results = dialog.urls
        if results.count <= 0 {
            return
        }
        let paths = results.map({ url in
            return url.path
        })
        if (forIPA) {
            installIPAFromPaths(paths: paths)
        } else {
            addExceptionForPaths(paths: paths)
        }
    }
    
    @objc func addFromCandidateSource(_ sender: NSMenuItem) {
        if let exception = sender.representedObject as? iOSAppBundle {
            addExceptionWithoutReload(exception: exception)
            sortPersistAndReload()
        }
    }
    
    func addExceptionForPaths(paths: [String]) {
        var alreadyOptimized: [iOSAppBundle] = []
        var hasCompatibilityIssues: [iOSAppBundle] = []
        for path in paths {
            guard let exception = exceptionForPath(path: path) else {
                continue
            }
            if (exception.hasCompatibilityIssues) {
                hasCompatibilityIssues.append(exception)
            } else if (exception.looksLikeiOSOrScaledCatalystApp) {
                addExceptionWithoutReload(exception: exception)
            } else {
                alreadyOptimized.append(exception)
            }
        }
        if (alreadyOptimized.count > 0 || hasCompatibilityIssues.count > 0) {
            let summary = self.summaryForMultipleApps(apps: alreadyOptimized)
            var title = ""
            var text = ""
            if (alreadyOptimized.count > 0) {
                let moreThanOne = alreadyOptimized.count > 1
                title = moreThanOne ? String(format: "%@ are already optimized for Mac.".localized, summary) : String(format: "%@ is already optimized for Mac.".localized, summary)
                text = moreThanOne ? String(format: "%@ already run in native scaling. Enabling them anyways will likely have no effect.".localized, summary) : String(format: "%@ already runs in native scaling. Enabling it anyways will likely have no effect.".localized, summary)
            }
            if (hasCompatibilityIssues.count > 0) {
                let moreThanOne = hasCompatibilityIssues.count > 1
                let compatSummary = self.summaryForMultipleApps(apps: hasCompatibilityIssues)
                let compatTitle = moreThanOne ? String(format: "%@ are incompatible with native scaling.".localized, compatSummary) : String(format: "%@ is incompatible with native scaling.".localized, compatSummary)
                let compatText = String(format: "When running %@ in native scaling, you may experience compatibility issues.".localized, compatSummary)
                title = title.count > 0 ? "\(title.paddedWithSpaceSuffix)\(compatTitle)" : compatTitle
                text = text.count > 0 ? "\(text.paddedWithSpaceSuffix)\(compatText)" : compatText
            }
            let joined = alreadyOptimized + hasCompatibilityIssues
            let joinedSummary = self.summaryForMultipleApps(apps: joined)
            AppDelegate.showOptionSheet(title: title, text: text, firstButtonText: String(format: "Skip %@".localized, joinedSummary), secondButtonText: "Enable Anyways".localized, thirdButtonText: "") { response in
                if (response == .alertSecondButtonReturn) {
                    for app in joined {
                        self.addExceptionWithoutReload(exception: app)
                    }
                    self.sortPersistAndReload()
                }
            }
        }
        sortPersistAndReload()
    }
    
    func addExceptionWithoutReload(exception: iOSAppBundle, afterIPAInstall: Bool = false) {
        let existingMatch = apps.first { existing in
            return (existing.bundleIdentifier == exception.bundleIdentifier) || (existing.bundlePath == exception.bundlePath)
        }
        if let existingMatch = existingMatch {
            print("Bundle \(existingMatch) already exists, updating it instead.")
            if (!afterIPAInstall) {
                setAppsNativeScaling(apps: [existingMatch], enabled: true, needsReload: false)
            }
            return
        }
        
        // Unindexed exception
        apps.append(exception)
        if (!afterIPAInstall) {
            exception.isNativeScaling = true
            exception.unindexed = true
            modifyDefaultsForUnindexedItem(exception: exception, remove: false)
        }
    }
    
    func modifyDefaultsForUnindexedItem(exception: iOSAppBundle, remove: Bool) {
        let item = exception.bundleIdentifier ?? exception.bundlePath
        var unindexedExceptions: [String] = []
        if let existingUnindexedExceptions = UserDefaults.standard.array(forKey: defaultsKeyUnindexedExceptions) as? [String] {
            unindexedExceptions = existingUnindexedExceptions
        }
        if (remove) {
            unindexedExceptions.removeAll { inString in
                inString == item
            }
        } else if (!unindexedExceptions.contains(item)) {
            unindexedExceptions.append(item)
        }
        UserDefaults.standard.set(unindexedExceptions, forKey: defaultsKeyUnindexedExceptions)
    }
    
    func exceptionForPath(path: String?) -> iOSAppBundle? {
        guard let resolvedPath = path else {
            return nil
        }
        guard let bundle = iOSAppBundle(path: resolvedPath) else {
            return nil
        }
        return bundle
    }
    
    func summaryForMultipleApps(apps: [iOSAppBundle]) -> String {
        let firstApp = apps.first?.displayName ?? ""
        var summary = ""
        let count = apps.count
        if (count > 2) {
            summary = String(format: "“%@” and %d other apps".localized, firstApp, count - 1)
        } else if (count > 1) {
            summary = String(format: "“%@” and %d other app".localized, firstApp, count - 1)
        } else {
            summary = String(format: "“%@”".localized, firstApp)
        }
        return summary
    }
    
    // MARK: - IPA Install
    func installIPAFromPaths(paths: [String], checkIfCanInstall: Bool = false) {
        if paths.count == 0 {
            return
        }
        if (checkIfCanInstall && !canInstallDecryptedIPA()) {
            return
        }
        if installationViewController == nil {
            installationViewController = InstallationViewController.instantiate()
        }
        guard let installationViewController = installationViewController else {
            return
        }
        if let _ = installationViewController.view.window {
            waitingPaths.append(contentsOf: paths)
            return
        }
        updateInstallationStatus(path: paths.first)
        self.presentAsSheet(installationViewController)
        DispatchQueue.global(qos: .userInteractive).async {
            self.sync_installIPAFromPaths(paths: paths)
            DispatchQueue.main.async {
                self.dismiss(installationViewController)
                let copied = self.waitingPaths
                self.waitingPaths = []
                self.installIPAFromPaths(paths: copied, checkIfCanInstall: false)
            }
        }
    }
    
    func updateInstallationStatus(path: String?) {
        guard let path = path else {
            return
        }
        let name = (path as NSString).lastPathComponent
        self.syncMainQueue {
            installationViewController?.installingIPAName = name
        }
    }
    
    func sync_installIPAFromPaths(paths: [String]) {
        let tempDir = NSTemporaryDirectory()
        for path in paths {
            updateInstallationStatus(path: path)
            let extractDir = tempDir.appendingPathComponent(UUID().uuidString)
            print("Extracting to \(extractDir)")
            let success = unzipFile(at: path, to: extractDir)
            if success {
                print("Extraction is successful")
                let tempAppPath = renameAndWrapAppBundle(atPath: extractDir)
                moveAppAtTempPathToApplicationsFolder(tempAppPath: tempAppPath)
            }
        }
    }
    
    func applicationsDestinationForAppNamed(_ appName: String) -> String {
        let preName = (appName as NSString).deletingPathExtension
        let fileExtension = (appName as NSString).pathExtension
        return _recursiveDestinationForAppNamed(name: preName, fileExtension: fileExtension, atIndex: 1)
    }
    
    private func _recursiveDestinationForAppNamed(name: String, fileExtension: String, atIndex: Int) -> String {
        let fileManager = FileManager.default
        let proposedName = atIndex > 1 ? "\(name) \(atIndex).\(fileExtension)" : "\(name).\(fileExtension)"
        let proposedPath = applicationsPath.appendingPathComponent(proposedName)
        if !fileManager.fileExists(atPath: proposedPath) {
            return proposedPath
        }
        return _recursiveDestinationForAppNamed(name: name, fileExtension: fileExtension, atIndex: atIndex + 1)
    }
    
    func moveAppAtTempPathToApplicationsFolder(tempAppPath: String?) {
        guard let tempAppPath = tempAppPath else {
            return
        }
        let fileManager = FileManager.default
        let appName = (tempAppPath as NSString).lastPathComponent
        let appPath = applicationsDestinationForAppNamed(appName)
        do {
            try fileManager.moveItem(atPath: tempAppPath, toPath: appPath)
        } catch {
            print(error)
            return
        }
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: appPath), configuration: NSWorkspace.OpenConfiguration())
        guard let newBundle = iOSAppBundle(path: appPath) else {
            return
        }
        DispatchQueue.main.async {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
                newBundle.forceReloadContainerPath()
                newBundle.forceReloadCachedUserDefaults()
                self.addExceptionWithoutReload(exception: newBundle, afterIPAInstall: true)
                self.sortPersistAndReload()
            }
        }
    }
    
    func renameAndWrapAppBundle(atPath extractDir: String) -> String? {
        let fileManager = FileManager.default
        let uuidDir = extractDir.appendingPathComponent(UUID().uuidString)
        let existingPayloadDir = extractDir.appendingPathComponent("Payload")
        let payloadDir = uuidDir.appendingPathComponent("Payload")
        do {
            try fileManager.createDirectory(atPath: uuidDir, withIntermediateDirectories: true)
            try fileManager.moveItem(atPath: existingPayloadDir, toPath: payloadDir)
        } catch {
            print(error)
            return nil
        }

        guard let appBundlePath = getAppBundlePath(inDirectory: payloadDir) else {
            return nil
        }
        let appBundleName = (appBundlePath as NSString).lastPathComponent
        guard let bundle = Bundle(path: appBundlePath), let infoDict = bundle.infoDictionary, let executable = infoDict["CFBundleExecutable"] as? String else {
            return nil
        }
        let appDisplayName = "\(bundle.nonLocalizedDisplayNameOnDemand).app"
        let executablePath = appBundlePath.appendingPathComponent(executable)
        let result = makeExecutable(atPath: executablePath)
        print("Make executable result \(result)")

        let pluginsPath = appBundlePath.appendingPathComponent("PlugIns")
        let extensionsPath = appBundlePath.appendingPathComponent("Extensions")
        let frameworksPath = appBundlePath.appendingPathComponent("Frameworks")
        let watchAppsPath = appBundlePath.appendingPathComponent("Watch")
        _ = signEmbeddedComponents(atPath: pluginsPath)
        _ = signEmbeddedComponents(atPath: extensionsPath)
        _ = signEmbeddedComponents(atPath: frameworksPath)
        _ = signEmbeddedComponents(atPath: watchAppsPath)
        _ = signComponent(at: appBundlePath)

        let wrapperDir = uuidDir.appendingPathComponent("Wrapper")
        let bundleMetadataFromPath = Bundle.main.path(forResource: "BundleMetadata", ofType: "plist")
        let bundleMetadataToPath = wrapperDir.appendingPathComponent(bundleMetadataPlistName)
        let pixelPerfectCanary = wrapperDir.appendingPathComponent(pixelPerfectMetadataPlistName)
        let wrappedBundlePath = uuidDir.appendingPathComponent("WrappedBundle")
        let symlinkDestination = "Wrapper".appendingPathComponent(appBundleName)
        let finalAppPath = extractDir.appendingPathComponent(appDisplayName)
        do {
            try fileManager.moveItem(atPath: payloadDir, toPath: wrapperDir)
            if let bundleMetadataFromPath = bundleMetadataFromPath {
                try fileManager.copyItem(atPath: bundleMetadataFromPath, toPath: bundleMetadataToPath)
            }
            fileManager.createFile(atPath: pixelPerfectCanary, contents: nil)
            try fileManager.createSymbolicLink(atPath: wrappedBundlePath, withDestinationPath: symlinkDestination)
            try fileManager.moveItem(atPath: uuidDir, toPath: finalAppPath)
        } catch {
            print(error)
            return nil
        }
        
        return finalAppPath
    }

    func signEmbeddedComponents(atPath path: String) -> Bool {
        let fileManager = FileManager.default
        guard let components = try? fileManager.contentsOfDirectory(atPath: path) else {
            return false
        }
        for component in components {
            let subPath = path.appendingPathComponent(component)
            _ = signComponent(at: subPath)
        }
        return true
    }

    func signComponent(at sourcePath: String) -> Bool {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--force", "--sign", "-", "--preserve-metadata=identifier,entitlements", sourcePath]
        process.standardOutput = pipe

        do {
            try process.run()
        } catch {
            return false
        }

        process.waitUntilExit()
        let resultData = pipe.fileHandleForReading.readDataToEndOfFile()
        let result = String (data: resultData, encoding: .utf8) ?? ""
        print(result)

        return process.terminationStatus <= 1
    }

    func makeExecutable(atPath path: String) -> Bool {
        let fileManager = FileManager.default
        guard fileManager.isExecutableFile(atPath: path) == false else {
            return true
        }
        
        let attributes = [FileAttributeKey.posixPermissions: NSNumber(value: 0o755)]
        do {
            try fileManager.setAttributes(attributes, ofItemAtPath: path)
            return true
        } catch {
            print(error)
            return false
        }
    }

    func getAppBundlePath(inDirectory directory: String) -> String? {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else {
            return nil
        }
        
        for file in contents {
            if file.hasSuffix(".app") {
                return directory.appendingPathComponent(file)
            }
        }
        return nil
    }
    
    func unzipFile(at sourcePath: String, to destinationPath: String) -> Bool {
        Process.runNonAdminTaskWait(toolPath: "/usr/bin/unzip", arguments: ["-o", sourcePath, "-d", destinationPath])
        return true
    }
}
