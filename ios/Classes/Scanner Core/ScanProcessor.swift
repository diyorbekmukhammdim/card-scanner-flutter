//
//  CardScanProcessorCore.swift
//  Card ScanProcessor
//
//  Created by Mohammed Sadiq on 26/07/20.
//  Updated by <siz> on 2025
//

import UIKit
import GoogleMLKit

public protocol ScanProcessorDelegate {
    func scanProcessor(_ scanProcessor: ScanProcessor, didFinishScanning card: CardDetails)
}

public class ScanProcessor {
    var scanProcessorDelegate: ScanProcessorDelegate?
    var card: CardDetails = CardDetails()

    var datesCollectedSoFar: [String] = []
    var validScansSoFar: Int = 0
    var singleFrameCardScanner: SingleFrameCardScanner
    var cardDetailsScanOptimizer: CardDetailsScanOptimizer
    var cardScanOptions: CardScannerOptions

    init(withOptions cardScanOptions: CardScannerOptions) {
        self.cardScanOptions = cardScanOptions
        self.singleFrameCardScanner = SingleFrameCardScanner(withOptions: cardScanOptions)
        self.cardDetailsScanOptimizer = CardDetailsScanOptimizer(scannerOptions: cardScanOptions)
    }

    func startScanning() {
        let cameraViewController: CameraViewController = makeCameraViewController()
        UIApplication.shared.keyWindow?.rootViewController?.present(
            cameraViewController,
            animated: true,
            completion: nil
        )
    }

    func makeCameraViewController() -> CameraViewController {
        let cameraViewController: CameraViewController = CameraViewController()
        cameraViewController.cameraDelegate = self
        cameraViewController.cameraOrientation = cardScanOptions.cameraOrientation
        cameraViewController.prompt = cardScanOptions.prompt
        cameraViewController.modalPresentationStyle = .fullScreen

        return cameraViewController
    }
}

// MARK: - CameraDelegate
extension ScanProcessor: CameraDelegate {
    func camera(_ camera: CameraViewController, didCaptureImage image: UIImage) {
        let visionImage = VisionImage(image: image)
        visionImage.orientation = image.imageOrientation

        let textRecognizer = TextRecognizer.textRecognizer()

        textRecognizer.process(visionImage) { visionText, error in
            guard error == nil, let visionText = visionText else {
                return
            }

            // Single-frame scanner bilan ishlash
            guard let cardDetails = self.singleFrameCardScanner.scanSingleFrame(visionText: visionText) else {
                return
            }

            self.cardDetailsScanOptimizer.processCardDetails(cardDetails: cardDetails)

            if self.cardDetailsScanOptimizer.isReadyToFinishScan() {
                self.vibrateToIndicateScanEnd()

                self.card.cardNumber = self.cardDetailsScanOptimizer.getOptimalCardDetails()?.cardNumber ?? ""
                self.card.cardHolderName = self.cardDetailsScanOptimizer.getOptimalCardDetails()?.cardHolderName ?? ""
                self.card.expiryDate = self.cardDetailsScanOptimizer.getOptimalCardDetails()?.expiryDate ?? ""

                self.scanProcessorDelegate?.scanProcessor(self, didFinishScanning: self.card)
                camera.stopScanning()
            }
        }
    }

    func vibrateToIndicateScanEnd() {
        let impactFeedbackgenerator = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedbackgenerator.prepare()
        impactFeedbackgenerator.impactOccurred()
    }

    func cameraDidStopScanning(_ camera: CameraViewController) {
        if cardDetailsScanOptimizer.isReadyToFinishScan() {
            scanProcessorDelegate?.scanProcessor(self, didFinishScanning: card)
        }
    }
}
