//
//  QRCodeReaderViewController.swift
//  Smartime
//
//  Created by Ricardo Pereira on 13/05/2015.
//  Copyright (c) 2015 Ricardo Pereira. All rights reserved.
//

import UIKit
import AVFoundation

public typealias ResultCallback = (QRCodeReaderViewController, String) -> ()
public typealias ErrorCallback = (QRCodeReaderViewController, NSError) -> ()
public typealias CancelCallback = (QRCodeReaderViewController) -> ()

enum QRCodeReaderViewControllerErrorCodes: Int {
    case UnavailableMetadataObjectType = 1
}

public class QRCodeReaderViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    private let metadataObjectTypes: [String]
    
    public var resultCallback: ResultCallback?
    public var errorCallback: ErrorCallback?
    public var cancelCallback: CancelCallback?
    
    private var avSession: AVCaptureSession?
    private var avDevice: AVCaptureDevice?
    private var avVideoPreviewLayer: AVCaptureVideoPreviewLayer?
    
    private var lastCapturedString: String?
    
    // Constants
    private let fTorchLevel: Float = 0.25
    private let torchLevel = 0.25
    private let torchActivationDelay = 0.25
    private let errorDomain = "eu.ricardopereira.QRCodeReaderViewController"
    
    public convenience init() {
        self.init(metadataObjectTypes: [AVMetadataObjectTypeQRCode])
    }
    
    public init(metadataObjectTypes: [String]) {
        self.metadataObjectTypes = metadataObjectTypes
        super.init(nibName: nil, bundle: nil)
        self.title = "QR Code"
    }
    
    public required init(coder aDecoder: NSCoder) {
        self.metadataObjectTypes = [AVMetadataObjectTypeQRCode]
        super.init(coder: aDecoder)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        // Config
        self.view.backgroundColor = UIColor.blackColor()
        
        // Gestures
        let torchGesture = UILongPressGestureRecognizer(target: self, action: Selector("handleTorchRecognizerTap:"))
        torchGesture.minimumPressDuration = torchLevel
        let swipeDownGesture = UISwipeGestureRecognizer(target: self, action: "handleSwipeDown:")
        swipeDownGesture.direction = .Down
        
        self.view.addGestureRecognizer(torchGesture)
        self.view.addGestureRecognizer(swipeDownGesture)
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if let _ = cancelCallback {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: Selector("cancelItemSelected:"))
        } else {
            self.navigationItem.leftBarButtonItem = nil
            
        }
        
        lastCapturedString = nil
        
        if errorCallback == nil, let _ = cancelCallback {
            errorCallback = { error in
                if let performCancel = self.cancelCallback {
                    self.avSession?.stopRunning()
                    performCancel(self)
                }
            }
        }
        
        self.avSession = AVCaptureSession()
        
        avVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: avSession);
        avVideoPreviewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill;
        avVideoPreviewLayer?.frame = self.view.bounds;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            self.avDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
            
            if let session = self.avSession, let device = self.avDevice {
                // AVCaptureDevice
                if device.lowLightBoostSupported && device.lockForConfiguration(nil) {
                    device.automaticallyEnablesLowLightBoostWhenAvailable = true
                    device.unlockForConfiguration()
                }
                
                session.beginConfiguration()
                
                var error: NSError?
                var input = AVCaptureDeviceInput(device: device, error: &error)
                
                if let e = error {
                    println("QRCodeReaderViewController: Error getting input device: \(e)")
                    session.commitConfiguration()
                    
                    if let performError = self.errorCallback {
                        dispatch_async(dispatch_get_main_queue()) {
                            session.stopRunning()
                            performError(self, e)
                        }
                    }
                    return
                }
                
                session.addInput(input)
                
                let output = AVCaptureMetadataOutput()
                
                session.addOutput(output)
                
                for type in self.metadataObjectTypes {
                    // FIXME: Forced unwrap
                    if !contains(output.availableMetadataObjectTypes as! [String], type) {
                        if let performError = self.errorCallback {
                            dispatch_async(dispatch_get_main_queue()) {
                                session.stopRunning()
                                performError(self, NSError(domain: self.errorDomain, code: QRCodeReaderViewControllerErrorCodes.UnavailableMetadataObjectType.rawValue, userInfo: [NSLocalizedDescriptionKey : "Unable to scan object of type \(type)"]))
                            }
                        }
                        return
                    }
                }
                
                output.metadataObjectTypes = self.metadataObjectTypes
                output.setMetadataObjectsDelegate(self, queue: dispatch_get_main_queue())
                
                session.commitConfiguration()
                
                dispatch_async(dispatch_get_main_queue()) {
                    if let videoLayer = self.avVideoPreviewLayer, let conn = videoLayer.connection {
                        if conn.supportsVideoOrientation {
                            //conn.videoOrientation = videoOrientationFromDeviceOrientation(UIDevice.currentDevice().orientation);
                        }
                    }
                    session.startRunning()
                }
            }
            
        }
        
        self.view.layer.addSublayer(self.avVideoPreviewLayer)
    }
    
    public override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        avVideoPreviewLayer?.removeFromSuperlayer();
        avVideoPreviewLayer = nil;
        avSession = nil;
        avDevice = nil;
    }
    
    public override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        avVideoPreviewLayer?.bounds = self.view.bounds;
        avVideoPreviewLayer?.position = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
    }
    
    public override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        // The device has already rotated, that's why this method is being called
        if let videoLayer = self.avVideoPreviewLayer, let conn = videoLayer.connection {
            if conn.supportsVideoOrientation {
                conn.videoOrientation = self.videoOrientationFromDeviceOrientation(UIDevice.currentDevice().orientation);
            }
        }
    }
    
    private func videoOrientationFromDeviceOrientation(orientation: UIDeviceOrientation) -> AVCaptureVideoOrientation {
        switch (orientation) {
        case .Portrait:
            return AVCaptureVideoOrientation.Portrait
        case .LandscapeLeft:
            return AVCaptureVideoOrientation.LandscapeRight
        case .LandscapeRight:
            return AVCaptureVideoOrientation.LandscapeLeft
        case .PortraitUpsideDown:
            return AVCaptureVideoOrientation.PortraitUpsideDown
        default:
            return AVCaptureVideoOrientation.Portrait
        }
    }
    
    
    // MARK: UI Actions
    
    func cancelItemSelected(sender: AnyObject) {
        avSession?.stopRunning;
        cancelCallback?(self);
    }
    
    func handleSwipeDown(sender: UIGestureRecognizer) {
        avSession?.stopRunning;
        cancelCallback?(self);
    }
    
    func handleTorchRecognizerTap(sender: UIGestureRecognizer) {
        switch(sender.state) {
        case UIGestureRecognizerState.Began:
            turnTorchOn()
        case UIGestureRecognizerState.Changed, UIGestureRecognizerState.Possible:
            break
        case UIGestureRecognizerState.Ended, UIGestureRecognizerState.Cancelled, UIGestureRecognizerState.Failed:
            turnTorchOff()
        default:
            break
        }
    }
    
    
    // MARK: Torch
    
    func turnTorchOn() {
        if let device = avDevice {
            if device.hasTorch && device.torchAvailable && device.isTorchModeSupported(.On) && device.lockForConfiguration(nil) {
                device.setTorchModeOnWithLevel(fTorchLevel, error: nil)
                device.unlockForConfiguration()
            }
        }
    }
    
    func turnTorchOff() {
        if let device = avDevice {
            if device.hasTorch && device.torchAvailable && device.isTorchModeSupported(.Off) && device.lockForConfiguration(nil) {
                device.torchMode = .Off
                device.unlockForConfiguration()
            }
        }
    }
    
    
    // MARK: AVCaptureMetadataOutputObjectsDelegate
    
    public func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {
        var metadataStr: String?
        
        for metadata in metadataObjects {
            if contains(self.metadataObjectTypes, metadata.type) {
                metadataStr = metadata.stringValue;
                break
            }
        }
        
        if let result = metadataStr {
            if lastCapturedString != result {
                lastCapturedString = result
                avSession?.stopRunning()
                resultCallback?(self, result)
            }
        }
    }
    
}