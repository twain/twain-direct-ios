//
//  ScannerPickerTableViewController.swift
//  TWAIN Direct Sample
//
//  Created by Steve Tibbett on 2017-09-25.
//  Copyright © 2017 Visioneer, Inc. All rights reserved.
//

import UIKit

class ScannerPickerTableViewController: UITableViewController {

    var serviceDiscoverer: ServiceDiscoverer?
    var scanners = [ScannerInfo]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        serviceDiscoverer = ServiceDiscoverer(delegate: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        serviceDiscoverer?.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        serviceDiscoverer?.stop()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return scanners.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "scannerCell", for: indexPath)
        let scannerInfo = scanners[indexPath.row]
        let titleLabel = cell.viewWithTag(1) as! UILabel
        let bodyLabel = cell.viewWithTag(2) as! UILabel
        
        titleLabel.text = scannerInfo.friendlyName
        
        var bodyText = "\(scannerInfo.url)"
        if let note = scannerInfo.note {
            bodyText = "\(bodyText)\n\(note)"
        }
        bodyLabel.text = bodyText
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let scannerInfo = scanners[indexPath.row]
        if let json = try? JSONEncoder().encode(scannerInfo) {
            if let jsonString = String(data: json, encoding: .utf8) {
                UserDefaults.standard.set(jsonString, forKey: "scanner")
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
}

extension ScannerPickerTableViewController : ServiceDiscovererDelegate {
    func discoverer(_ discoverer: ServiceDiscoverer, didDiscover scanners: [ScannerInfo]) {
        OperationQueue.main.addOperation {
            self.scanners = scanners
            self.tableView.reloadData()
        }
    }
}


