import UIKit

class OnboardingViewController: UIViewController {

    @IBOutlet weak var driverNameTextField: UITextField!
    @IBOutlet weak var stateCodeTextField: UITextField!
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        if let name = driverNameTextField.text, !name.isEmpty,
           let code = stateCodeTextField.text, !code.isEmpty {
            StorageManager.saveDriverName(name)
            StorageManager.saveStateCode(code)
            // Assuming permit date is selected from a picker or input field
            // Save permit issue date here using StorageManager.savePermitIssueDate(_:)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let driverName = StorageManager.getDriverName(), !driverName.isEmpty {
            driverNameTextField.text = driverName
        }
        
        if let stateCode = StorageManager.getStateCode(), !stateCode.isEmpty {
            stateCodeTextField.text = stateCode
        }
    }
}
