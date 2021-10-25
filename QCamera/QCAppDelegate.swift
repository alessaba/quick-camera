//
//  AppDelegate.swift
//  Quick Camera
//
//  Created by Simon Guest on 1/22/17.
//  Copyright © 2013-2021 Simon Guest. All rights reserved.
//

import Cocoa
import AVKit
import AVFoundation

@NSApplicationMain
class QCAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, QCUsbWatcherDelegate{

    let usb = QCUsbWatcher()
    func deviceCountChanged() {
        self.detectVideoDevices()
        self.startCaptureWithVideoDevice(defaultDevice: selectedDeviceIndex)
    }

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var selectSourceMenu: NSMenuItem!
    @IBOutlet weak var playerView: NSView!
	
	@IBOutlet weak var aspectRatioItem: NSMenuItem!
	@IBOutlet weak var borderlessItem: NSMenuItem!
	
    var isMirrored: Bool = UserDefaults.standard.bool(forKey: "isMirrored")
    var isUpsideDown: Bool = UserDefaults.standard.bool(forKey: "isUpsideDown")
	var isBorderless: Bool = UserDefaults.standard.bool(forKey: "isBorderless")
	var isAspectRatioFixed: Bool = UserDefaults.standard.bool(forKey: "isAspectRatioFixed")
    
    // 0 = normal, 1 = 90' top to right, 2 = 180' top to bottom, 3 = 270' top to left
	var position = UserDefaults.standard.integer(forKey: "position")
	
    var defaultBorderStyle: NSWindow.StyleMask = NSWindow.StyleMask.closable
    var windowTitle = "Quick Camera"
    let defaultDeviceIndex: Int = 0
    var selectedDeviceIndex: Int = 0
    
    var devices: [AVCaptureDevice]!
    var captureSession: AVCaptureSession!
    var captureLayer: AVCaptureVideoPreviewLayer!
	var cachedSavePath: URL? = nil
    
    var input: AVCaptureDeviceInput!

    func errorMessage(message: String){
        let popup = NSAlert()
        popup.messageText = message
        popup.runModal()
    }
    
    func detectVideoDevices() {
        NSLog("Detecting video devices...")
        self.devices = AVCaptureDevice.devices(for: AVMediaType.video)
        
        if (devices?.count == 0) {
            let popup = NSAlert()
            popup.messageText = "Unfortunately, you don't appear to have any cameras connected. Goodbye for now!"
            popup.runModal()
            NSApp.terminate(nil)
        } else {
            NSLog("%d devices found", devices?.count ?? 0)
        }
        
        let deviceMenu = NSMenu()
        var deviceIndex = 0

        // Here we need to keep track of the current device (if selected) in order to keep it checked in the menu
        var currentDevice = self.devices[defaultDeviceIndex]
        if(self.captureSession != nil) {
            currentDevice = (self.captureSession.inputs[0] as! AVCaptureDeviceInput).device
        }
        self.selectedDeviceIndex = defaultDeviceIndex
        
        for device in self.devices {
            let deviceMenuItem = NSMenuItem(title: device.localizedName, action: #selector(deviceMenuChanged), keyEquivalent: "")
            deviceMenuItem.target = self
            deviceMenuItem.representedObject = deviceIndex
            if (device == currentDevice) {
                deviceMenuItem.state = NSControl.StateValue.on
                self.selectedDeviceIndex = deviceIndex
            }
            if (deviceIndex < 9) {
                deviceMenuItem.keyEquivalent = String(deviceIndex + 1)
            }
            deviceMenu.addItem(deviceMenuItem)
            deviceIndex += 1
        }
        selectSourceMenu.submenu = deviceMenu
    }
    
    func startCaptureWithVideoDevice(defaultDevice: Int) {
        NSLog("Starting capture with device index %d", defaultDevice)
        let device: AVCaptureDevice = self.devices[defaultDevice]
        
        if (captureSession != nil) {
            
            // if we are "restarting" a session but the device is the same exit early
            let currentDevice = (self.captureSession.inputs[0] as! AVCaptureDeviceInput).device
            guard currentDevice != device else { return }
            
            captureSession.stopRunning()
        }
        captureSession = AVCaptureSession()
        
        do {
            self.input = try AVCaptureDeviceInput(device: device)
            self.captureSession.addInput(input)
            self.captureSession.startRunning()
            self.captureLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            self.captureLayer.connection?.automaticallyAdjustsVideoMirroring = false
            self.captureLayer.connection?.isVideoMirrored = false
            
            self.playerView.layer = self.captureLayer
            self.playerView.layer?.backgroundColor = CGColor.black
            self.windowTitle = String(format: "Quick Camera: [%@]", device.localizedName)
            self.window.title = self.windowTitle
            fixAspectRatio()
        } catch {
            NSLog("Error while opening device")
            self.errorMessage(message: "Unfortunately, there was an error when trying to access the camera. Try again or select a different one.")
        }
    }
    
   
    
    @IBAction func mirrorHorizontally(_ sender: NSMenuItem) {
        NSLog("Mirror image menu item selected")
		isMirrored.toggle()
		UserDefaults.standard.set(isMirrored, forKey: "isMirrored")
        self.captureLayer.connection?.isVideoMirrored = isMirrored
    }
    
    func setRotation(_ position: Int){
        switch (position){
        case 1: if (!isUpsideDown){
            self.captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
        } else {
            self.captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight
        }
        break
        case 2: if (!isUpsideDown){
            self.captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portraitUpsideDown
        } else {
            self.captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        }
        break
        case 3: if (!isUpsideDown) {
            self.captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight
        } else {
            self.captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
        }
        break
        case 0: if (!isUpsideDown) {
            self.captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        } else {
            self.captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portraitUpsideDown
        }
        break
        default: break
        }
    }
    
    @IBAction func mirrorVertically(_ sender: NSMenuItem) {
        NSLog("Mirror image vertically menu item selected")
		isUpsideDown.toggle()
		UserDefaults.standard.set(isUpsideDown, forKey: "isUpsideDown")
        setRotation(position)
		isMirrored.toggle()
        self.captureLayer.connection?.isVideoMirrored = isMirrored
    }
    
    @IBAction func rotateLeft(_ sender: NSMenuItem) {
        NSLog("Rotate Left menu item selected with position %d", position)
        position = position - 1
        if (position == -1) { position = 3}
		UserDefaults.standard.set(position, forKey: "position")
        setRotation(position)
    }
    
    @IBAction func rotateRight(_ sender: NSMenuItem) {
        NSLog("Rotate Right menu item selected with position %d", position)
        position = position + 1
        if (position == 4) { position = 0}
		UserDefaults.standard.set(position, forKey: "position")
        setRotation(position)
    }
        
    private func addBorder(){
        window.styleMask = defaultBorderStyle
        window.title = self.windowTitle
        self.window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)))
        window.isMovableByWindowBackground = false
    }
    
    private func removeBorder() {
        defaultBorderStyle = window.styleMask
        self.window.styleMask = [NSWindow.StyleMask.borderless, NSWindow.StyleMask.resizable]
        self.window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        window.isMovableByWindowBackground = true
    }
    
    @IBAction func borderless(_ sender: NSMenuItem) {
        NSLog("Borderless menu item selected")
        if (self.window.styleMask.contains(.fullScreen)){
            NSLog("Ignoring borderless command as window is full screen")
            return
        }
		isBorderless.toggle()
		UserDefaults.standard.set(isBorderless, forKey: "isBorderless")
        sender.state = NSControl.StateValue(Int(isBorderless))
        if (isBorderless) {
            removeBorder()
        } else {
            addBorder()
        }
        fixAspectRatio()
        
    }
    
    @IBAction func enterFullScreen(_ sender: NSMenuItem) {
        NSLog("Enter full screen menu item selected")
        playerView.window?.toggleFullScreen(self)
    }
    
    @IBAction func toggleFixAspectRatio(_ sender: NSMenuItem) {
		isAspectRatioFixed.toggle()
		UserDefaults.standard.set(isAspectRatioFixed, forKey: "isAspectRatioFixed")
		sender.state = NSControl.StateValue(Int(isAspectRatioFixed))
        fixAspectRatio()
    }
    
    func fixAspectRatio() {
        if isAspectRatioFixed, #available(OSX 10.15, *) {
            let height = input.device.activeFormat.formatDescription.dimensions.height
            let width = input.device.activeFormat.formatDescription.dimensions.width
            let size = NSMakeSize(CGFloat(width), CGFloat(height))
            self.window.contentAspectRatio = size
            
            let ratio = CGFloat(Float(width)/Float(height))
            
            var currentSize = self.window.contentLayoutRect.size
            currentSize.height = currentSize.width / ratio
            self.window.setContentSize(currentSize)
        } else {
            self.window.contentResizeIncrements = NSMakeSize(1.0,1.0)
        }
    }
	
	func windowDidResize(_ notification: Notification) {
		fixAspectRatio()
	}

    @IBAction func saveImage(_ sender: NSMenuItem?) {
        if (self.window.styleMask.contains(.fullScreen)){
            NSLog("Save is not supported as window is full screen")
            return
        }
        
        if (captureSession != nil){
            if #available(OSX 10.12, *) {
                // turn borderless on, capture image, return border to previous state
                let borderlessState = self.isBorderless	
                if (borderlessState == false) {
                    NSLog("Removing border")
                    self.removeBorder()
                }

                /* Pause the RunLoop for 0.1 sec to let the window repaint after removing the border - I'm not a fan of this approach
                   but can't find another way to listen to an event for the window being updated. PRs welcome :) */
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))

                let cgImage = CGWindowListCreateImage(CGRect.null, .optionIncludingWindow, CGWindowID(self.window.windowNumber), [.boundsIgnoreFraming, .bestResolution])

                if (borderlessState == false){
                    self.addBorder()
                }
				
				let now = Date()
				let dateFormatter = DateFormatter()
				dateFormatter.dateFormat = "yyyy-MM-dd"
				let date = dateFormatter.string(from: now)
				dateFormatter.dateFormat = "h.mm.ss a"
				let time = dateFormatter.string(from: now)
				
                DispatchQueue.main.async {
					if self.cachedSavePath == nil{
						let panel = NSOpenPanel()
						panel.canChooseFiles = false
						panel.canChooseDirectories = true
						panel.beginSheetModal(for: self.window) { (result) in
							if (result == NSApplication.ModalResponse.OK){
								let filepath = panel.url!.appendingPathComponent(String(format: "QuickCamera_%@_ %@.png", date, time))
								NSLog(filepath.absoluteString)
								let destination = CGImageDestinationCreateWithURL(filepath as CFURL, kUTTypePNG, 1, nil)
								if (destination == nil)
								{
									NSLog("Could not write file - destination returned from CGImageDestinationCreateWithURL was nil")
									self.errorMessage(message: "Unfortunately, the image could not be saved to this location.")
								} else {
									self.cachedSavePath = panel.url!
									CGImageDestinationAddImage(destination!, cgImage!, nil)
									CGImageDestinationFinalize(destination!)
								}
							}
						}
					} else {
						let newPath = self.cachedSavePath!.appendingPathComponent(String(format: "QuickCamera_%@_ %@.png", date, time))
						let destination = CGImageDestinationCreateWithURL(newPath as CFURL, kUTTypePNG, 1, nil)
						CGImageDestinationAddImage(destination!, cgImage!, nil)
						CGImageDestinationFinalize(destination!)
					}
                }
				
            } else {
                let popup = NSAlert()
                popup.messageText = "Unfortunately, saving images is only supported in Mac OSX 10.12 (Sierra) and higher."
                popup.runModal()
            }
        }
    }
    
    @objc func deviceMenuChanged(_ sender: NSMenuItem) {
        NSLog("Device Menu changed")
        if (sender.state == NSControl.StateValue.on) {
            // selected the active device, so nothing to do here
            return
        }
        
        // set the checkbox on the currently selected device
        for menuItem: NSMenuItem in selectSourceMenu.submenu!.items {
            menuItem.state = NSControl.StateValue.off
        }
        sender.state = NSControl.StateValue.on
        
        self.startCaptureWithVideoDevice(defaultDevice: sender.representedObject as! Int)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        detectVideoDevices()
        startCaptureWithVideoDevice(defaultDevice: defaultDeviceIndex)
		window.delegate = self
        usb.delegate = self
		
		if (isBorderless) {
			removeBorder()
		}
		
		self.captureLayer.connection?.isVideoMirrored = isMirrored
		setRotation(position)
		aspectRatioItem.state = NSControl.StateValue(rawValue: Int(isAspectRatioFixed))
		borderlessItem.state = NSControl.StateValue(rawValue: Int(isBorderless))
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

class MyPlayerView : NSView {
	override func keyDown(with event: NSEvent) {
		if (event.keyCode == 49){
			print("SPACE")
			let l = NSApplication.shared.delegate as! QCAppDelegate
			l.saveImage(nil)
			self.window!.makeFirstResponder(self)
		}
	}
}

fileprivate extension Int {
	init(_ bool: Bool) {
		self = bool ? 1 : 0
	}
}
