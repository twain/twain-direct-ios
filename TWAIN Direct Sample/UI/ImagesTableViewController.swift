//
//  ImagesTableViewController.swift
//  TWAIN Direct Sample
//
//  Created by Steve Tibbett on 2017-10-02.
//  Copyright © 2017 Visioneer, Inc. All rights reserved.
//

import UIKit
import QuickLook

class ImagesTableViewController: UITableViewController {

    @IBOutlet var deleteAllButton: UIBarButtonItem!

    let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last!
    var files = [String]()

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(forName:.scannedImagesUpdatedNotification, object: nil, queue: OperationQueue.main) { notification in
            self.refresh()
        }

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
 
        refresh();
    }

    func refresh() {
        if let files = try? FileManager.default.contentsOfDirectory(atPath: docsDir.path) {
            self.files = files.sorted().reversed()
            self.tableView.reloadData()
        }
        
        deleteAllButton.isEnabled = !files.isEmpty
    }
    
    @IBAction func didTapDeleteAll(_ sender: Any) {
        if let files = try? FileManager.default.contentsOfDirectory(atPath: docsDir.path) {
            for file in files {
                try? FileManager.default.removeItem(at: docsDir.appendingPathComponent(file))
            }
        }
        
        refresh()
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return files.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = files[indexPath.row]
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let preview = QLPreviewController()
        preview.dataSource = self
        self.navigationController?.pushViewController(preview, animated: true)
    }
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if let previewVC = segue.destination as? QLPreviewController {
            previewVC.dataSource = self
        }
    }

}

extension ImagesTableViewController : QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        if let selRow = tableView.indexPathForSelectedRow {
            return docsDir.appendingPathComponent(files[selRow.row]) as QLPreviewItem
        } else {
            return URL(string:"about:blank")! as QLPreviewItem
        }
    }
}
