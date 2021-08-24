//
//  IdentificationViewController.swift
//  testIdScanner
//
//  Created by M3ts LLC on 8/2/21.
//



import UIKit
import MLKit

class IdentificationViewController: UIViewController {
   
    @IBAction func cameraButtonTapped(_ sender: Any) {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "BarCodeReadingViewController") as!  BarCodeScannerViewController
        viewController.modalTransitionStyle = .crossDissolve
        viewController.modalPresentationStyle = .overFullScreen
        viewController.barCodeScannerDelegate = self
        viewController.barcodeFormat = .PDF417
        self.present(viewController, animated: true, completion: nil)
    }
}

// MARK: - Actions
extension IdentificationViewController :BarCodeScannerDelegate {
    func scanningValue(drivingLicenseData: BarcodeDriverLicense?, anotherType: String?) {
        print("\n\n===================== drivingLicenseData  : \(drivingLicenseData?.firstName) ===================== IN Function :\(#function) \(#line) \(#file) =====================\n\n")
        if let driverLicenseData = drivingLicenseData {
            print("\n=================== First Name :: \(driverLicenseData.firstName)======================IN \(#function)\n")
            print("\n=================== Last Name :: \(driverLicenseData.lastName)======================IN \(#function)\n")
            print("\n=================== License Number :: \(driverLicenseData.licenseNumber)======================IN \(#function)\n")
        }
    }
}
