import Cocoa

class InstallationViewController: NSViewController {
    @IBOutlet weak var iconView: NSImageView!
    @IBOutlet weak var installationLabel: NSTextField?
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        iconView.image = NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Applications/iOS App Installer.app")
        updateInstallationStatus()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        progressIndicator.startAnimation(nil)
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        progressIndicator.stopAnimation(nil)
    }
    
    var installingIPAName: String = "" {
        didSet {
            updateInstallationStatus()
        }
    }
    
    private func updateInstallationStatus() {
        installationLabel?.stringValue = String(format: "Installing “%@”".localized, installingIPAName)
    }
    
    static func instantiate() -> InstallationViewController {
        return NSStoryboard.main?.instantiateController(withIdentifier: "InstallationViewController") as! InstallationViewController
    }
    
}
