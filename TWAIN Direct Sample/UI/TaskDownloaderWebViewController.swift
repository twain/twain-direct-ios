//
//  TaskDownloaderWebViewController.swift
//  TWAIN Direct Sample
//
//  Created by Steve Tibbett on 2017-10-01.
//  Copyright © 2017 Visioneer, Inc. All rights reserved.
//

import UIKit
import WebKit

class TaskDownloaderWebViewController: UIViewController {

    @IBOutlet weak var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let url = URL(string: "https://www.dynamsoft.com/Demo/TwainDirectTaskGeneratorOnline/Basic.html") {
            let request = URLRequest(url:url)
            webView.load(request)
        }

        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension TaskDownloaderWebViewController : WKUIDelegate {
    
}

extension TaskDownloaderWebViewController : WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse {
            if let disposition = response.allHeaderFields["Content-Disposition"] as? String {
                if (disposition.lowercased().starts(with: "attachment")) {
                    
                    // Extract the filename from the Content-Disposition header
                    let fileName = (disposition.split(separator: ";").reduce(nil) { prev, value in
                        let parts = String(value).split(separator:"=")
                        if (parts.count == 2 && parts[0] == "attachment") {
                            return String(parts[1])
                        }
                        return nil
                    } as String?) ?? "Downloaded Task.tdt"
                    
                    guard let url = response.url else {
                        // No URL?
                        decisionHandler(.cancel)
                        return
                    }
                    
                    let session = URLSession.shared
                    let task = session.dataTask(with: url) { data, response, error -> Void in
                        if let data = data {
                            // Ensure it parses
                            if let data = try? JSONSerialization.jsonObject(with: data, options: []) {
                                // We're good .. save it
                                UserDefaults.standard.setValue(data, forKey: "task")
                                UserDefaults.standard.setValue(fileName, forKey: "taskName")
                            } else {
                                OperationQueue.main.addOperation {
                                    let title = NSLocalizedString("Invalid JSON", comment:"Alert title")
                                    let message = NSLocalizedString("Invalid JSON received", comment: "Alert body")
                                    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
                                    self.present(alert, animated: true)
                                    
                                }
                            }
                        }
                        
                        decisionHandler(.cancel)
                        OperationQueue.main.addOperation {
                            self.navigationController?.popViewController(animated: true)
                        }
                    }
                    
                    task.resume()
                    return
                }
            }
        }
        
        decisionHandler(.allow)
    }
}
