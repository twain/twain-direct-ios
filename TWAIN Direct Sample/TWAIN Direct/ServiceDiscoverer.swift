//
//  ServiceDiscoverer.swift
//  TWAIN Direct Sample
//
//  Created by Steve Tibbett on 2017-09-21.
//  Copyright © 2017 Visioneer, Inc. All rights reserved.
//

import Foundation
import CFNetwork

protocol ServiceDiscovererDelegate: class {
    func discoverer(_ discoverer: ServiceDiscoverer, didDiscover scanners: [ScannerInfo])
}

class ServiceDiscoverer : NSObject {
    // Map if discovered scanners - the key is the URL of the host plus the
    // friendly name of the scanner.
    var discoveredScanners = [String:ScannerInfo]()

    weak var delegate: ServiceDiscovererDelegate?
    
    let browser = NetServiceBrowser()
    var services = [NetService]()
    
    init(delegate: ServiceDiscovererDelegate) {
        super.init()
        
        self.delegate = delegate
        browser.delegate = self

    }
    
    func start() {
        log.info("Bonjour search for scanners starting")
        browser.searchForServices(ofType: "_privet._tcp", inDomain: "")
    }
    
    func stop() {
        browser.stop()
    }
    
    func scannerInfoFrom(service:NetService) -> ScannerInfo? {
        guard let data = service.txtRecordData() else {
            log.error("No TXT record from service \(service.name)")
            return nil
        }
        
        let dict = NetService.dictionary(fromTXTRecord: data)
        
        guard var fqdn = service.hostName else {
            // We need the host name
            return nil
        }
        
        // Map the Data values to String values
        let txtDict = dict.mapValues { (data) -> String in
            if let str = String(data: data, encoding: .utf8) {
                return str
            } else {
                return ""
            }
        }
        
        var scheme = "http"
        if (txtDict["https"] ?? "") == "1" {
            scheme = "https"
        }
        
        if fqdn.hasSuffix(".") {
            fqdn = String(fqdn.dropLast())
        }
        
        guard let url = URL(string:"\(scheme)://\(fqdn):\(service.port)/") else {
            // Error building URL
            return nil
        }
        
        let scannerInfo = ScannerInfo(url: url, name: service.name, fqdn: fqdn, txtDict: txtDict)
        return scannerInfo
    }
}

extension ServiceDiscoverer : NetServiceBrowserDelegate {
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        log.info("Found service \(service.name), resolving.")
        services.append(service)
        service.delegate = self
        service.resolve(withTimeout: 3.0)
    }
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        discoveredScanners = discoveredScanners.filter { $0.value.name != service.name }
        delegate?.discoverer(self, didDiscover: Array(discoveredScanners.values))
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        log.info("Search ended")
    }
}

extension ServiceDiscoverer : NetServiceDelegate {
    func netServiceWillResolve(_ sender: NetService) {
        log.info("Will resolve")
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        log.info("did not resolve")
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        if let scannerInfo = scannerInfoFrom(service:sender) {
            let key = "\(scannerInfo.url.absoluteString)\(String(describing:scannerInfo.friendlyName))"
            
            log.info("Discovered \(scannerInfo.friendlyName ?? "") at \(scannerInfo.url)")
            discoveredScanners[key] = scannerInfo
            delegate?.discoverer(self, didDiscover: Array(discoveredScanners.values))
        }
    }
}


