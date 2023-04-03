import Cocoa

protocol AppExceptionTableCellViewDelegate: AnyObject {
    func didToggleCheckbox(_ cell: AppExceptionTableCellView)
}

class AppExceptionTableCellView: NSTableCellView {
    @IBOutlet weak var iconView: NSImageView!
    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var enablementSwitch: NSSwitch!
    weak var delegate: AppExceptionTableCellViewDelegate?
    
    @IBAction func switchClicked(_ sender: Any) {
        delegate?.didToggleCheckbox(self)
    }
}

class ExceptionTableView: NSTableView {
    override func menu(for event: NSEvent) -> NSMenu? {
        if (self.numberOfRows > 0) {
            return super.menu(for: event)
        }
        return nil
    }
}
