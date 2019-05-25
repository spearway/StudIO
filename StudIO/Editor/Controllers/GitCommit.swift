//
//  GitCommit.swift
//  StudIO
//
//  Created by Arthur Guiot on 1/1/19.
//  Copyright © 2019 Arthur Guiot. All rights reserved.
//

import UIKit
import SwiftGit2

class GitCommit: UIView {
    @IBOutlet var contentView: UIView!
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var commitStrip: UITextView!
    
    var repo: Repository?
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    
    private func commonInit() {
        Bundle.main.loadNibNamed("GitCommit", owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        
        initialisation()
        
    }
    func initialisation() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 89
        tableView.backgroundColor = #colorLiteral(red: 0.1674376428, green: 0.1674425602, blue: 0.167439878, alpha: 1)
        tableView.backgroundView?.backgroundColor = #colorLiteral(red: 0.1674376428, green: 0.1674425602, blue: 0.167439878, alpha: 1)
        reloadProperties()
    }
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if self.frame.origin.y == 0 {
                self.frame.origin.y -= keyboardSize.height
            }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if self.frame.origin.y != 0 {
            self.frame.origin.y = 0
        }
    }
    
    @IBAction func commit(_ sender: Any) {
        DispatchQueue.global().sync {
            let name = UserDefaults.standard.string(forKey: "name") ?? "StudIO User"
            let email = UserDefaults.standard.string(forKey: "email") ?? "studio@exemple.com"
            let sig = GTSignature(name: name, email: email, time: Date())
            
            // branches
            do {
                let r = try GTRepository(url: (repo?.directoryURL)!)
                let b = try r.currentBranch().name
                if (b == nil) {
                    let branch = repo?.localBranch(named: "master").value
                    let oid = branch?.oid
                    repo?.checkout(oid!, strategy: .Safe)
                }
                // commit
                let branch = try r.currentBranch()
                let last = try branch.targetCommit()
                
                let builder = try GTTreeBuilder(tree: last.tree, repository: r)
                
                for entry in self.status {
                    var a = entry.keys.first ?? "ERROR"
                    if a == "diff" {
                        a = Array(entry.keys)[entry.keys.count - 1]
                    }
                    if entry[a] == "true" {
                        let url = URL(fileURLWithPath: a, relativeTo: repo?.directoryURL)
                        let data = try Data(contentsOf: url)
                        try builder.addEntry(with: data, fileName: a, fileMode: .blob)
                    }
                }
                
                let subtree = try builder.writeTree()
                
                builder.clear()
                
                let name = branch.reference.name
                
                let commit = try r.createCommit(with: subtree, message: commitStrip.text, author: sig!, committer: sig!, parents: [last], updatingReferenceNamed: name)
                
                self.commitStrip.text = ""
                self.status = []
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.reloadProperties()
                }
            } catch {
                NSObject.alert(t: "Commit error", m: error.localizedDescription)
            }
            
        }
        
    }
    
    func reloadProperties() {
        DispatchQueue.global().async {
            self.status = []
            
            guard let rsg2 = self.repo?.directoryURL else { return }
            
            guard let r = try? GTRepository(url: rsg2) else { return }
            
            guard nil != r.fileURL else { return }
            do {
                try r.enumerateFileStatus(options: nil, usingBlock: { (delta1, delta2, val) in
                    if delta2?.status != .unmodified || delta1?.status != .unmodified {
                        if delta2?.newFile?.path != nil {
                            self.status.append([
                                delta2?.newFile?.path ?? "ERROR": "true",
                                "diff": String(delta2?.similarity ?? 0)
                            ])
                        } else {
                            self.status.append([
                                delta1?.newFile?.path ?? "ERROR": "true",
                                "diff": String(delta1?.similarity ?? 0)
                            ])
                        }
                    }
                })
            } catch {
                NSObject.alert(t: "Status error", m: error.localizedDescription)
            }
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.checkButton()
            }
        }
    }
    
    // properties
    var status: [[String: String]] = []
    
    @IBOutlet weak var commitButton: UIButton!
    func checkButton() {
        if status.count == 0 {
            commitButton.isEnabled = false
            commitButton.backgroundColor = #colorLiteral(red: 0.01993954368, green: 0.2427439988, blue: 0.5180901885, alpha: 1)
        } else {
            commitButton.isEnabled = true
            commitButton.backgroundColor = #colorLiteral(red: 0, green: 0.4784313725, blue: 1, alpha: 1)
        }
    }

}

extension GitCommit: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return status.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "cell") else {
                return UITableViewCell(style: .default, reuseIdentifier: "cell")
            }
            return cell
        }()
        cell.backgroundColor = #colorLiteral(red: 0.1674376428, green: 0.1674425602, blue: 0.167439878, alpha: 1)
        cell.contentView.backgroundColor = #colorLiteral(red: 0.1674376428, green: 0.1674425602, blue: 0.167439878, alpha: 1)
        let s = status
        let row = indexPath.row
        let path = s[row]
        
//        self.repo?.add(path: path ?? "Error")
        var title = path.keys.first ?? "ERROR"
        if title == "diff" {
            title = Array(path.keys)[path.keys.count - 1]
        }
        cell.textLabel?.text = title
        cell.textLabel?.textColor = #colorLiteral(red: 0.6666666865, green: 0.6666666865, blue: 0.6666666865, alpha: 1)
        cell.accessoryType = .checkmark
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        cell?.accessoryType = .none
        
        let row = indexPath.row
        let path = status[row]
        var title = path.keys.first ?? "ERROR"
        if title == "diff" {
            title = Array(path.keys)[path.keys.count - 1]
        }
        status[row] = [
            title: "false"
        ]
        
        checkButton()
    }
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        cell?.accessoryType = .checkmark
//        repo?.add(path: cell?.textLabel?.text ?? "")
        
        let row = indexPath.row
        let path = status[row]
        var title = path.keys.first ?? "ERROR"
        if title == "diff" {
            title = Array(path.keys)[path.keys.count - 1]
        }
        status[row] = [
            title: "true"
        ]
        
        checkButton()
    }
    
    
    // Options
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let row = status[indexPath.row]
        let diff = Double(row["diff"] ?? "0")
        
        let changes = UITableViewRowAction(style: .normal, title: "Similarity: \((diff ?? 0) * 100)%") { (action, indexPath) in
            // Do nothing
        }
        let discardChanges = UITableViewRowAction(style: .destructive, title: "Discard changes") { (action, indexPath) in
            do {
                let row = indexPath.row
                let path = self.status[row]
                var title = path.keys.first ?? "ERROR"
                if title == "diff" {
                    title = Array(path.keys)[path.keys.count - 1]
                }
                
                let r = try GTRepository(url: (self.repo?.directoryURL)!)

                let index = try r.index()
                try index.addFile(title)
                let HEAD = try r.lookUpObject(byRevParse: "HEAD") as! GTCommit
                let entry = try HEAD.tree?.entry(withPath: title)
                let blob = try GTBlob(treeEntry: entry!)
                let data = blob.data()
                
                let url = URL(fileURLWithPath: title, relativeTo: self.repo?.directoryURL)
                let file = try File(path: url.path)
                try file.write(data: data)
                self.status = []
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.reloadProperties()
                }
            } catch {
                NSObject.alert(t: "Couldn't discard changes", m: error.localizedDescription)
            }
            
        }
        return [changes, discardChanges]
    }
}
