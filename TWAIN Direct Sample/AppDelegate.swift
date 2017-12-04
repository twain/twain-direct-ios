//
//  AppDelegate.swift
//  TWAIN Direct Sample
//
//  Created by Steve Tibbett on 2017-09-21.
//  Copyright © 2017 Visioneer, Inc. All rights reserved.
//

import UIKit

let log = SwiftyBeaver.self

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    // SwiftyBeaver Log file destination, so we can find it from the log view
    var fileDestination = FileDestination()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        setupLogging()
        log.info("App started")
        
        return true
    }

    func setupLogging() {
        let console = ConsoleDestination()
        console.format = "$DHH:mm:ss$d $L $M"
        console.asynchronously = false
        log.addDestination(console)

        // Log to a file so we can view the log in the app
        let _ = fileDestination.deleteLogFile()
        fileDestination.format = "$DHH:mm:ss$d $L $M"
        log.addDestination(fileDestination)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {

        if url.pathExtension == "tdt" {
            log.info("Received task file: \(url.lastPathComponent)")
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                
                if let data = try? Data(contentsOf: url) {
                    UserDefaults.standard.setValue(data, forKey: "task")
                    UserDefaults.standard.setValue(url.lastPathComponent, forKey: "taskName")
                }

                // Post a notification that will trigger the main UI to update the task name
                NotificationCenter.default.post(name: .sessionUpdatedNotification, object: nil)
            }
        }
        
        return true
    }
}

