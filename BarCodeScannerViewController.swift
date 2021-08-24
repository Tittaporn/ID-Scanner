//
//  BarCodeScannerViewController.swift
//  testIdScanner
//
//  Created by M3ts LLC on 8/2/21.
//


import UIKit
import AVFoundation
import Vision
import CoreVideo
import MLKit

// MARK: - BarCode Scanner Protocol
protocol BarCodeScannerDelegate {
    func scanningValue(drivingLicenseData:BarcodeDriverLicense?, anotherType:String?)
}


class BarCodeScannerViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // MARK: - Outlets
    @IBOutlet weak var btnCancel: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    
    
    // MARK: - Properties
    var didReadIdBarcode = false
    var barcodeScanner :BarcodeScanner!
    var captureDevice: AVCaptureDevice!
    var session = AVCaptureSession()
    var requests = [VNRequest]()
    var isUsingFrontCamera = false
    var barCodeScannerDelegate: BarCodeScannerDelegate?
    var barcodeFormat: BarcodeFormat?
    var imageLayer: AVCaptureVideoPreviewLayer!
    
    // MARK: - Life Cycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupVideoCameraForScanning()
        startBarCodeDetection()
        if let barcodeFormat = barcodeFormat{
            barcodeScanner = BarcodeScanner.barcodeScanner(options: BarcodeScannerOptions(formats: barcodeFormat))
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        session.commitConfiguration()
        session.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        imageLayer.frame = view.frame
    }
    
    override open var shouldAutorotate: Bool {
        return false
    }
    
    // MARK: - Actions
    @IBAction func cancelButtonTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Helper Functions
    func setupVideoCameraForScanning() {
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.high
        captureDevice = AVCaptureDevice.default(for: AVMediaType.video)
        let deviceInput = try! AVCaptureDeviceInput(device: captureDevice!)
        let deviceOutput = AVCaptureVideoDataOutput()
        deviceOutput.alwaysDiscardsLateVideoFrames = true
        deviceOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        deviceOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: DispatchQoS.QoSClass.default))
        session.addInput(deviceInput)
        session.addOutput(deviceOutput)
        imageLayer = AVCaptureVideoPreviewLayer(session: session)
        imageLayer.frame = imageView.bounds
        imageView.layer.addSublayer(imageLayer)
    }
    
    
    func startBarCodeDetection() {
        let request = VNDetectBarcodesRequest(completionHandler: self.barcodeDetectHandler)
        request.symbologies = [VNBarcodeSymbology.PDF417] // or use .QR, etc
        self.requests = [request]
    }
    
    func barcodeDetectHandler(request: VNRequest, error: Error?) {
        guard let observations = request.results else { return }
        let results = observations.map({$0 as? VNBarcodeObservation})
        for result in results {
            let finalResulte =   result!.payloadStringValue!.split(separator: "\n").map{String($0)}
            print("\n=================== finalResulte :: \(finalResulte)======================IN \(#function)\n")
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
        readBarCodeFromScanning(sampleBuffer: sampleBuffer)
        var requestOptions: [VNImageOption:Any] = [:]
        if let camData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
            requestOptions = [.cameraIntrinsics: camData]
        }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: 6)!, options: requestOptions)
        do {
            try imageRequestHandler.perform(self.requests)
        } catch {
            print(error)
        }
    }
    
    func readBarCodeFromScanning(sampleBuffer:CMSampleBuffer) {
        let visionImage = VisionImage(buffer: sampleBuffer)
        visionImage.orientation =  imageOrientation()
        if let barcodeScanner = barcodeScanner{
            var barcodes: [Barcode]
            do {
                barcodes = try barcodeScanner.results(in: visionImage)
                //print("\n===================barcodes.count :: \(barcodes.count)======================IN \(#function)\n")
                if barcodes.count > 0 {
                   // print("the bar code is detected ")
                    DispatchQueue.main.async { [self] in
                        if let drivingLicense = barcodes.first?.driverLicense {
                            self.didReadIdBarcode = true
                            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                            self.barCodeScannerDelegate?.scanningValue(drivingLicenseData: drivingLicense, anotherType: nil)
                        } else if didReadIdBarcode == false {
                            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                            self.barCodeScannerDelegate?.scanningValue(drivingLicenseData: nil, anotherType: barcodes.first?.rawValue)
                        }
                        DispatchQueue.main.async {
                            self.dismiss(animated: true, completion: nil)
                        }
                    }
                }
            } catch let error {
                print("Failed to scan barcodes with error: \(error.localizedDescription).")
                return
            }
        }
    }
    
    // MARK: - Device Orientation
    func currentUIOrientation() -> UIDeviceOrientation {
        let deviceOrientation = { () -> UIDeviceOrientation in
            switch UIApplication.shared.statusBarOrientation {
            case .landscapeLeft:
                return .landscapeRight
            case .landscapeRight:
                return .landscapeLeft
            case .portraitUpsideDown:
                return .portraitUpsideDown
            case .portrait, .unknown:
                return .portrait
            @unknown default:
                fatalError()
            }
        }
        guard Thread.isMainThread else {
            var currentOrientation: UIDeviceOrientation = .portrait
            DispatchQueue.main.sync {
                currentOrientation = deviceOrientation()
            }
            return currentOrientation
        }
        return deviceOrientation()
    }
    
    public  func imageOrientation(fromDevicePosition devicePosition: AVCaptureDevice.Position = .back) -> UIImage.Orientation {
        var deviceOrientation = UIDevice.current.orientation
        if deviceOrientation == .faceDown || deviceOrientation == .faceUp || deviceOrientation == .unknown {
            deviceOrientation = currentUIOrientation()
        }
        switch deviceOrientation {
        case .portrait:
            return devicePosition == .front ? .leftMirrored : .right
        case .landscapeLeft:
            return devicePosition == .front ? .downMirrored : .up
        case .portraitUpsideDown:
            return devicePosition == .front ? .rightMirrored : .left
        case .landscapeRight:
            return devicePosition == .front ? .upMirrored : .down
        case .faceDown, .faceUp, .unknown:
            return .up
        @unknown default:
            fatalError()
        }
    }
}
