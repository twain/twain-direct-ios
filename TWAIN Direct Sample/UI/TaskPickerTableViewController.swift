//
//  TaskPickerTableViewController.swift
//  TWAIN Direct Sample
//
//  Created by Steve Tibbett on 2017-09-25.
//  Copyright © 2017 Visioneer, Inc. All rights reserved.
//

import UIKit

class TaskPickerTableViewController: UITableViewController {

    @IBOutlet weak var selectedTaskLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        refresh()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (indexPath.section == 1 && indexPath.row == 1) {
            // Select a task file
            let picker = UIDocumentPickerViewController(documentTypes: ["org.twaindirect.task"], in: UIDocumentPickerMode.open)
            picker.delegate = self
            present(picker, animated:true)
        }
    }

    func refresh() {
        let taskName = UserDefaults.standard.string(forKey: "taskName") ?? NSLocalizedString("No task selected", comment: "User has not picked a task yet")
        selectedTaskLabel.text = taskName
    }
}

extension TaskPickerTableViewController : UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let url = urls.first {
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
            
                if let data = try? Data(contentsOf: url) {
                    UserDefaults.standard.setValue(data, forKey: "task")
                    UserDefaults.standard.setValue(url.lastPathComponent, forKey: "taskName")
                    refresh()
                }
            }
        }
    }
}
