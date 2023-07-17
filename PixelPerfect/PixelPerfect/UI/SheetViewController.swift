import Cocoa

enum GuidanceType {
    case asLowering
    case asVMLowering
}

let instructionsURLPrefix = "https://cormiertyshawn895.github.io/instruction/?arch="

class SheetViewController: NSViewController {
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var captionLabel: NSTextField!
    @IBOutlet weak var qrCodeImageView: NSImageView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var viewInstructionsButton: NSButton!
    @IBOutlet weak var closeButton: NSButton!
    var guidanceType: GuidanceType = .asLowering
    var titleText: String {
        return String(format: "To install a decrypted IPA on this %@, you need to disable System Integrity Protection.".localized, SystemInformation.shared.macCategoryString) as String
    }
    
    var instructionsURL: URL {
        return URL(string: "\(instructionsURLPrefix)\(instructionsArch)")!
    }
    
    var instructionsArch: String {
        get {
            switch (self.guidanceType) {
            case .asLowering:
                return "sip-as-lowering"
            case .asVMLowering:
                return "sip-as-vm-lowering"
            }
        }
    }
    
    static func instantiate() -> SheetViewController {
        return NSStoryboard.main?.instantiateController(withIdentifier: "SheetViewController") as! SheetViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        updateTextAndQRCode()
        self.view.window?.preventsApplicationTerminationWhenModal = false
        self.view.window?.styleMask.remove(.resizable)
    }
    
    override func cancelOperation(_ sender: Any?) {
        self.dismiss(nil)
    }
    
    @IBAction func closeButtonClicked(_ sender: Any) {
        self.dismiss(nil)
    }
    
    @IBAction func viewInstructionsClicked(_ sender: Any) {
        NSWorkspace.shared.open(self.instructionsURL)
    }
    
    func updateTextAndQRCode() {
        titleLabel.stringValue = self.titleText
        let isVM = self.guidanceType == .asVMLowering
        var caption = ""
        if !isVM {
            caption += "Afterwards, you can only install and use decrypted iPhone and iPad apps. iPhone and iPad apps downloaded from the App Store will no longer open.".localized
            caption += "\n\n"
            caption += "This option is for advanced users only.".localized
            caption += " "
        }
        caption += "Scan this QR code on your iPhone, iPad, or Android device to view step-by-step instructions.".localized
        captionLabel.stringValue = caption
        qrCodeImageView.isHidden = false
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        viewInstructionsButton.title = String(format: "Preview instructions on %@...".localized, SystemInformation.shared.macCategoryString)
        DispatchQueue.global(qos: .userInteractive).async {
            let image = QRCodeGenerator.generate(string: self.instructionsURL.absoluteString, size: CGSize(width: 140, height: 140))
            image?.isTemplate = true
            DispatchQueue.main.async {
                self.qrCodeImageView.image = image
                self.progressIndicator.stopAnimation(nil)
                self.progressIndicator.isHidden = true
            }
        }
    }
}
