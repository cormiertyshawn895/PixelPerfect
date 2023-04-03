import Cocoa
import UniformTypeIdentifiers

class ExceptionViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, AppExceptionTableCellViewDelegate {
    var query: NSMetadataQuery!
    @Published var finishedGathering = false
    @Published var apps: [iOSAppBundle] = []
    
    @IBOutlet weak var roundedBoxView: NSBox!
    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var horizontalLineView: NSBox!
    @IBOutlet weak var actionContainerView: NSView!
    @IBOutlet weak var addButton: NSButton!
    
    @IBOutlet weak var loadingStackView: NSStackView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var getAppsImageView: NSImageView!
    @IBOutlet weak var loadingButton: NSButton!
    @IBOutlet weak var updateButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.layer?.backgroundColor = NSColor.clear.cgColor
        NotificationCenter.default.addObserver(self, selector: #selector(didFinishGathering), name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: nil)
        
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
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
        tableView.registerForDraggedTypes([.fileURL])
        tableView.doubleAction = #selector(doubleClickOnResultRow)
        updateTableViewMenu()
    }
    
    func updateTableViewMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Reset".localized, action: #selector(tableViewResetItemClicked(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show in Finder".localized, action: #selector(tableViewShowClickedItemInFinderClicked(_:)), keyEquivalent: ""))
        if (AppDelegate.showDebugOptions) {
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Copy Bundle Identifier".localized, action: #selector(tableViewCopyBundleIdentifierClicked(_:)), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Copy Preferences Domain".localized, action: #selector(tableViewCopyPreferencesPathClicked(_:)), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Show Preferences".localized, action: #selector(tableViewShowPreferencesClicked(_:)), keyEquivalent: ""))
        }
        tableView.menu = menu
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
        horizontalLineView.isHidden = !finishedGathering
        actionContainerView.isHidden = !finishedGathering
        loadingStackView.isHidden = finishedGathering && hasApps
        loadingButton.isEnabled = finishedGathering
        loadingButton.usesSingleLineMode = false
        if (finishedGathering) {
            loadingButton.title = SystemInformation.shared.isAppleSilicon ? "Download iPhone and iPad apps \n from the App Store".localized.appending(" ↗") : "iPhone and iPad apps require \n a Mac with Apple silicon.".localized
        } else {
            loadingButton.title = "Loading applications...".localized
        }
        progressIndicator.isHidden = finishedGathering
        getAppsImageView.isHidden = !finishedGathering
        if (finishedGathering) {
            progressIndicator.stopAnimation(nil)
        } else {
            progressIndicator.startAnimation(nil)
        }
    }
    
    // MARK: - IBActions
    @IBAction func updateAvailableClicked(_ sender: Any) {
        AppDelegate.current.promptForUpdateAvailable()
    }
    
    @IBAction func loadingButtonClicked(_ sender: Any) {
        if (SystemInformation.shared.isAppleSilicon) {
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/App Store.app"), configuration: NSWorkspace.OpenConfiguration())
        } else {
            AppDelegate.safelyOpenURL("https://support.apple.com/HT211814")
        }
    }
    
    @IBAction func addButtonClicked(_ sender: Any) {
        let candidateSources: [NSRunningApplication] = NSWorkspace.shared.runningApplications
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Choose App…".localized, action: #selector(chooseAppToAdd(_:)), keyEquivalent: ""))
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
                let menuItem = NSMenuItem(title: exception.displayName, action: #selector(addFromCandidateSource(_:)), keyEquivalent: "")
                if let imageCopy = exception.icon.copy() as? NSImage {
                    imageCopy.size = NSSize(width: 18, height: 18)
                    menuItem.image = imageCopy
                }
                menuItem.representedObject = exception
                menu.addItem(menuItem)
            }
        }
        let point = NSPoint(x: 0, y: addButton.bounds.size.height)
        menu.popUp(positioning: nil, at: point, in: addButton)
    }
    
    @IBAction func resetClicked(_ sender: Any) {
        setAppsNativeScaling(apps: apps, enabled: false, removeUnindexed: true, showSummary: true)
    }
    
    @IBAction func selectAllClicked(_ sender: Any) {
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
        let directoryURL = URL(fileURLWithPath: ("~/\(playcoverPathComponents)" as NSString).expandingTildeInPath)
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
        let dialog = NSOpenPanel()
        dialog.directoryURL = URL(fileURLWithPath: applicationsPath)
        dialog.showsResizeIndicator = true
        dialog.allowsMultipleSelection = true
        dialog.canChooseDirectories = false
        dialog.allowedContentTypes = [UTType.applicationBundle, UTType.unixExecutable]
        
        if (dialog.runModal() !=  NSApplication.ModalResponse.OK) {
            return
        }
        let results = dialog.urls
        if results.count <= 0 {
            return
        }
        let paths = results.map({ url in
            return url.path
        })
        addExceptionForPaths(paths: paths)
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
    
    func addExceptionWithoutReload(exception: iOSAppBundle) {
        let existingMatch = apps.first { existing in
            return (existing.bundleIdentifier == exception.bundleIdentifier) || (existing.bundlePath == exception.bundlePath)
        }
        if let existingMatch = existingMatch {
            print("Bundle \(existingMatch) already exists, updating it instead.")
            setAppsNativeScaling(apps: [existingMatch], enabled: true, needsReload: false)
            return
        }
        
        // Unindexed exception
        apps.append(exception)
        exception.unindexed = true
        exception.isNativeScaling = true
        modifyDefaultsForUnindexedItem(exception: exception, remove: false)
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
}
