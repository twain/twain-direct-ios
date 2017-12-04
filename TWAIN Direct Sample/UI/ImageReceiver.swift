//
//  ImageReceiver.swift
//  TWAIN Direct Sample
//
//  Created by Steve Tibbett on 2017-09-30.
//  Copyright © 2017 Visioneer, Inc. All rights reserved.
//

import Foundation
import UIKit

extension Notification.Name {
    static let scannedImagesUpdatedNotification = Notification.Name("scannedImagesUpdatedNotification")
    static let sessionUpdatedNotification = Notification.Name("sessionUpdatedNotification")
    static let didFinishCapturingNotification = Notification.Name("didFinishCapturingNotification")
}

struct ImagesUpdatedNotificationData {
    let session: Session
    let url: URL
}

/**
 Simple class that accepts images from SessionDelegate and stores them on disk, then
 broadcasts a notification to let the UI know to refresh.
 */
class ImageReceiver : SessionDelegate {
    let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
    
    func session(_ session: Session, didReceive url: URL, metadata: Data) {
        log.info("Moving to \(docsDir)")
        try? FileManager.default.moveItem(at: url, to: docsDir.appendingPathComponent(url.lastPathComponent))
        let info = ImagesUpdatedNotificationData(session: session, url: url)
        NotificationCenter.default.post(name: .scannedImagesUpdatedNotification, object: info)
    }
    
    func session(_ session: Session, didChangeState newState: Session.State) {
        log.info("sessionDidChangeState \(newState)")
        NotificationCenter.default.post(name: .sessionUpdatedNotification, object: self)
    }
    
    func session(_ session: Session, didChangeStatus newStatus: Session.StatusDetected?, success: Bool) {
        log.info("sessionDidChangeStatus \(String(describing:newStatus)) success=\(success)")
        NotificationCenter.default.post(name: .sessionUpdatedNotification, object: self)
    }
    
    func sessionDidFinishCapturing(_ session: Session) {
        log.info("sessionDidFinishCapturing")
        NotificationCenter.default.post(name: .didFinishCapturingNotification, object: self)
    }
    
    func session(_ session: Session, didEncounterError error: Error) {
        log.error("ImageReceiver didEncounterError \(error)")
        let title = NSLocalizedString("Error", comment: "")
        let message = error.localizedDescription
        
        OperationQueue.main.addOperation {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment:"OK Button"), style: .cancel))
            alert.modalPresentationStyle = .fullScreen
            
            // This should really be passed through to a proper view to present, but for this sample
            // we'll show an alert on the root window's rootViewController
            UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true, completion: nil)
        }
    }
}
