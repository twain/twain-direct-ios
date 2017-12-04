//
//  ScannerInfo.swift
//  TWAIN Direct Sample
//
//  Created by Steve Tibbett on 2017-09-21.
//  Copyright © 2017 Visioneer, Inc. All rights reserved.
//

import Foundation

struct ScannerInfo : Codable {
    let url: URL
    let name: String
    let fqdn: String
    let txtDict: Dictionary<String, String>

    var friendlyName: String? {
        get {
            return txtDict["ty"]
        }
    }

    var note: String? {
        get {
            return txtDict["note"]
        }
    }
    
    var type: String? {
        get {
            return txtDict["type"]
        }
    }
}
