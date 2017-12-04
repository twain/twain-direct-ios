//
//  MainTableTableViewController.swift
//  TWAIN Direct Sample
//
//  Created by Steve Tibbett on 2017-09-22.
//  Copyright © 2017 Visioneer, Inc. All rights reserved.
//

import UIKit
import WebKit

class MainTableTableViewController: UITableViewController {

    @IBOutlet var startButton: UIButton!
    @IBOutlet var pauseButton: UIButton!
    @IBOutlet var stopButton: UIButton!
    @IBOutlet weak var selectedScannerLabel: UILabel!
    @IBOutlet weak var selectedTaskLabel: UILabel!
    @IBOutlet weak var sessionStatusLabel: UILabel!
    @IBOutlet weak var scannedImagesLabel: UILabel!
    
    var session: Session?
    var imageReceiver: ImageReceiver?
    var lastImageNameReceived = ""

    // The discovered scanners on the network - used to tag the scanner
    // as "Offline" if we don't see it.
    var scannersDiscovered = [ScannerInfo]()
    
    var serviceDiscoverer: ServiceDiscoverer?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableViewAutomaticDimension
        
        NotificationCenter.default.addObserver(forName:.scannedImagesUpdatedNotification, object: nil, queue: OperationQueue.main) { notification in
            if let data = notification.object as? ImagesUpdatedNotificationData {
                self.lastImageNameReceived = data.url.lastPathComponent
                self.updateScannedImagesLabel()
            }
        }

        NotificationCenter.default.addObserver(forName:.sessionUpdatedNotification, object: nil, queue: OperationQueue.main) { (_) in
            self.updateUI()
        }

        NotificationCenter.default.addObserver(forName:.didFinishCapturingNotification, object: nil, queue: OperationQueue.main) { (_) in
            log.info("didFinishCapturingNotification")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        serviceDiscoverer = ServiceDiscoverer(delegate: self)
        serviceDiscoverer?.start()
        
        updateUI()
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        serviceDiscoverer?.stop()
        serviceDiscoverer = nil
    }
    
    func reportError(_ error: Error?) {
        log.error("MainTableViewController reporting error  \(String(describing:error))")
        
        let title = NSLocalizedString("Error", comment: "")
        let message = error?.localizedDescription ?? "\(String(describing:error))"
        
        OperationQueue.main.addOperation {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment:"OK Button"), style: .cancel))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @IBAction func didTapStart(_ sender: Any) {
        guard let scannerJSON = UserDefaults.standard.string(forKey: "scanner") else {
            return
        }
        
        // Disable until the next transition to avoid double-taps
        startButton.isEnabled = false
        
        var scannerInfo: ScannerInfo!
        do {
            scannerInfo = try JSONDecoder().decode(ScannerInfo.self, from: (scannerJSON.data(using: .utf8))!)
        } catch {
            log.error("Failed deserializing scannerInfo: \(error)")
            return
        }
        
        let scanner = ScannerInfo(url: scannerInfo.url, name: scannerInfo.name, fqdn: scannerInfo.fqdn, txtDict: [String:String]())
        session = Session(scanner: scanner)
        
        imageReceiver = ImageReceiver()
        session?.delegate = imageReceiver
        
        session?.open { result in
            switch (result) {
            case .Success:
                log.info("didTapStart openSession success")
                self.sendTask()
            case .Failure(let error):
                self.reportError(error)
                self.resetSession()
            }
        }
    }
    
    @IBAction func didTapPause(_ sender: Any) {
        session?.stopCapturing(completion: { (result) in
            switch (result) {
            case .Success:
                log.info("stopCapturing succeeded")
            case .Failure(let error):
                log.error("stopCapturing failed, error=\(String(describing:error))")
                self.resetSession()
            }
        })
    }
    
    @IBAction func didTapStop(_ sender: Any) {
        session?.closeSession(completion: { (result) in
            switch (result) {
            case .Success:
                log.info("closeSession succeeded")
            case .Failure(let error):
                log.error("closeSession failed, error=\(String(describing:error))")
            }
        })
    }
    
    @IBAction func didTapAction(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alert.popoverPresentationController?.barButtonItem = sender
        
        alert.addAction(UIAlertAction(title: "Show Log", style: .default, handler: { _ in
            // Show a WebView with the log file
            let webView = WKWebView()
            let vc = UIViewController()
            if let url = (UIApplication.shared.delegate as! AppDelegate).fileDestination.logFileURL {
                let request = URLRequest(url: url)
                webView.load(request)
                vc.view = webView
         
                vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.action, target: self, action: #selector(self.didTapShareLog))
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }))
        
        alert.addAction(UIAlertAction(title: "Reset Session", style: .default, handler: { _ in
            self.session = nil
            self.updateUI()
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alert, animated: true)
    }
    
    @objc func didTapShareLog() {
        if let url = (UIApplication.shared.delegate as! AppDelegate).fileDestination.logFileURL {
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            present(activityVC, animated:true)
        }
    }
    
    // Called from didTapStart when the session open succeeds
    func sendTask() {
        let data = "{\"actions\": [ { \"action\": \"configure\" } ] }".data(using: .utf8)
        let taskObj = try? JSONSerialization.jsonObject(with: data!, options: []) as! [String:Any]
        
        session?.sendTask(taskObj!) { result in
            switch (result) {
            case .Success:
                log.info("sendTask completed successfully")
                self.startCapturing()
                break;
            case .Failure(let error):
                log.info("sendTask Failure: \(String(describing:error))")
                break;
            }
        }
    }

    // Called from sendTask when the task has been successfully sent
    func startCapturing() {
        session?.startCapturing(completion: { (response) in
            switch (response) {
            case .Success(let result):
                log.info("startCapture succeeded: \(result)")
                
            case .Failure(let error):
                log.info("startCapture failed; \(String(describing:error))")
            }
        })
    }

    // If there's a session that's not closed, close it.
    // If there is a session, and it's closed, reset it.
    func resetSession() {
        if let session = session {
            if session.sessionState != .closed && session.sessionState != .noSession {
                session.closeSession(completion: { (result) in
                    switch (result) {
                    case .Success:
                        log.info("Session closed")
                    case .Failure(let error):
                        log.error("Close failed, error=\(String(describing:error))")
                        self.session = nil
                    }
                })
            } else {
                self.session = nil
            }
        }
        
        updateUI()
    }
    
    func updateUI() {
        OperationQueue.main.addOperation {
            self.updateLabels()
            self.updateButtons()
            self.updateScannedImagesLabel()
        }
    }
    
    func updateButtons() {
        var enablePlay = false
        var enablePause = false
        var enableStop = false
        
        if let session = session {
            let state = session.sessionState ?? .noSession
            // There is a session .. buttons state depends on session state
            switch (state) {
            case .noSession:
                enablePlay = true
                break;
            case .ready:
                enablePlay = true
                enableStop = true
                break;
            case .capturing:
                enablePause = true
                enableStop = true
                break;
            case .draining:
                enableStop = true
                break;
            case .closed:
                // Waiting for close to complete, no buttons enabled
                break;
            }
        } else {
            // No session .. enable the Play button if there is a scanner and task configured
            enablePlay = canScan()
        }
        
        startButton.isEnabled = enablePlay
        pauseButton.isEnabled = enablePause
        stopButton.isEnabled = enableStop
    }
    
    // We can scan if:
    // - There is a scanner selected
    // - There is a task selected
    // - The scanner is not offline
    func canScan() -> Bool {
        guard let scannerJSON = UserDefaults.standard.string(forKey: "scanner") else {
            return false
        }
        
        do {
            let scannerInfo = try JSONDecoder().decode(ScannerInfo.self, from:scannerJSON.data(using: .utf8)!)
            
            if (!scannersDiscovered.contains { $0.friendlyName == scannerInfo.friendlyName }) {
                // Scanner is not in the mDNS discovery list
                return false
            }

        } catch {
            log.error("Error deserializing selected scanner JSON")
            return false
        }
        
        guard let _ = UserDefaults.standard.value(forKey: "task") else {
            return false
        }

        return true
    }
    
    func updateLabels() {
        updateScannerInfoLabel()
        updateTaskLabel()
        updateStatusLabel()
        updateScannedImagesLabel()
    }
    
    func updateScannerInfoLabel() {
        var label = "No scanner selected."
        defer {
            selectedScannerLabel.text = label
        }
        
        if let scannerJSON = UserDefaults.standard.string(forKey: "scanner") {
            do {
                let scannerInfo = try JSONDecoder().decode(ScannerInfo.self, from: (scannerJSON.data(using: .utf8))!)
                if let scannerName = scannerInfo.friendlyName {
                    label = scannerName
                    
                    if (!scannersDiscovered.contains { $0.friendlyName == scannerName }) {
                        label = label + " (Offline)"
                    }
                }
            } catch {
                log.error("Error deserializing scannerInfo: \(String(describing:error))")
            }
        }
    }
    
    func updateTaskLabel() {
        var label = "No task selected."
        defer {
            selectedTaskLabel.text = label
        }
        
        if let taskName = UserDefaults.standard.string(forKey: "taskName") {
            label = taskName
        }
    }
    
    func updateScannedImagesLabel() {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
        let files = try? FileManager.default.contentsOfDirectory(atPath: docsURL.path)
        let count = files?.count ?? 0

        if (count == 1) {
            scannedImagesLabel.text = "1 scanned image"
        } else {
            scannedImagesLabel.text = "\(count) scanned images"
        }
    }
    
    func updateStatusLabel() {
        let state = self.session?.sessionState?.rawValue
        
        var text = (state ?? "no session")
        if let statusDetected = self.session?.sessionStatus?.detected {
            text += "(" + statusDetected.rawValue + ")"
        }

        text = text + "\n\(lastImageNameReceived)"
        self.sessionStatusLabel.text = text
    }
}

extension MainTableTableViewController : ServiceDiscovererDelegate {
    func discoverer(_ discoverer: ServiceDiscoverer, didDiscover scanners: [ScannerInfo]) {
        OperationQueue.main.addOperation {
            self.scannersDiscovered = scanners
            self.updateUI()
        }
    }
}
