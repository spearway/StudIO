//
//  DetailViewController.swift
//  StudIO
//
//  Created by Arthur Guiot on 1/12/18.
//  Copyright © 2018 Arthur Guiot. All rights reserved.
//

import UIKit
import SwiftGit2

class WorkingDirDetailVC: UIViewController {

    @IBOutlet weak var bottomLine: BottomLine!
    @IBOutlet weak var editorView: Editor!
    
    var file: File?
    var repo: Repository?
    
    var secondWindow: UIWindow?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        updatedBar()
        configureView()
        // GitVC
        let image = #imageLiteral(resourceName: "Repo-white").scaleImage(toSize: CGSize(width: 10, height: 10))
        let gitButton = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(gitVC(_:)))
        // Git Panel
        let pimg = #imageLiteral(resourceName: "branch-icon").scaleImage(toSize: CGSize(width: 6.25, height: 10))
        let pButton = UIBarButtonItem(image: pimg, style: .plain, target: self, action: #selector(gitPanel(_:)))
        editorView?.gitPanel.isHidden = true
        if let r = repo {
            editorView?.gitPanel.repo = r
        }
        //        navigationItem.rightBarButtonItems = [gitButton, pButton] // Disabling Git functionnalities
        let undoButton = UIBarButtonItem(barButtonSystemItem: .undo, target: self, action: #selector(undo(_:)))
        let redoButton = UIBarButtonItem(barButtonSystemItem: .redo, target: self, action: #selector(redo(_:)))
        
        let simg = #imageLiteral(resourceName: "snippet").scaleImage(toSize: CGSize(width: 10, height: 10))
        snippetButton = UIBarButtonItem(image: simg, style: .plain, target: self, action: #selector(showSnippet(_:)))
        
        navigationItem.rightBarButtonItems = [
            gitButton, pButton,
            snippetButton, undoButton, redoButton].reversed()
        
        var saveIcon = #imageLiteral(resourceName: "save-icon")
        saveIcon = saveIcon.scaleImage(toSize: CGSize(width: 24 / 2, height: 24 / 2)) ?? saveIcon
        let saveButton = UIBarButtonItem(image: saveIcon, style: .plain, target: self, action: #selector(save(_:)))
        
        navigationItem.leftBarButtonItems?.append(contentsOf: [saveButton])
        
        
        // Listen for events
        NotificationCenter.default.addObserver(self, selector: #selector(insertSnippet(notification:)), name: .init("insertSnippet"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadInterface(_:)), name: .init("reloadEditorMenu"), object: nil)
        // Double screen
        observe()
    }
    override func viewWillDisappear(_ animated: Bool) {
        save()
    }
    
    func configureView() {
        // Update the user interface for the detail item.
        if let detail = detailItem {
            file = detail
            bottomView((file?.name)!)
            codeEditor((file?.name)!)
        }
    }
    @objc func save(_ sender: Any? = nil) {
        if let f = self.file {
            let hash = try? f.read()
            editorView?.getData({ data, error  in
                if error != nil {
//                    NSObject.alert(t: "Code wasn't saved", m: "For obscure reasons, the code you edited wasn't saved. Here is why: \(error!.localizedDescription)")
                    return
                }
                if let d = data {
                    if d != hash {
                        _ = try? f.write(data: d)
                        DispatchQueue.main.async {
                            self.editorView?.getLangName({ str in
                                self.bottomLine.language.text = str
                            })
                        }
                    }
                }
            })
        }
    }
    func codeEditor(_ str: String) {
        guard let c = editorView else { return }
        c.content = try! file?.read().base64EncodedString()
        c.fileName = str
        
        let arr = str.split(separator: ".")
        let ext = String(arr[arr.count - 1]).uppercased()
        
        let editorSplit = self.splitViewController as! EditorSplitVC
        editorSplit.accessory.extension = ext
        
        c.highlightExt = ext
        
        c.settings([
            "fontSize": UserDefaults.standard.string(forKey: "studio-font-size") ?? "26",
            "lineWrapping": UserDefaults.standard.string(forKey: "studio-line-wrapping") ?? "false",
            "theme": UserDefaults.standard.string(forKey: "studio-editor-theme") ?? "monokai"
            ])
        
        c.highlight(str, code: {
            self.bottomLine.setupLanguage(str)
        })
        
        // Second display
        if UIScreen.screens.count > 1 {
            handleScreenConnectNotification()
        }
    }
    func bottomView(_ str: String = "") {
        let b = bottomLine
        if let branch = ((try? repo?.localBranch(named: "master").get()) as Branch??) {
            let commit = (((try? repo?.commits(in: branch!).next()?.get()) as Commit??))!
            let msg = commit?.message
            b?.lastCommit.text = msg
        }
        DispatchQueue.global().async {
            let text = ((try? self.file?.readSize()) as String??)
            DispatchQueue.main.async {
                b?.sizeString.text = text as? String
            }
        }
    }
    
    @IBAction func updatedBar() {
        bottomView()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    var detailItem: File? {
        didSet {
            // Update the view.
            self.title = detailItem?.name
            configureView()
        }
    }

    @objc func null(_ sender: Any?) {
        // null code
    }
    
    @objc func gitVC(_ sender: Any?) {
        let storyBoard: UIStoryboard = UIStoryboard(name: "git", bundle: nil)
        let newViewController = storyBoard.instantiateViewController(withIdentifier: "GitVC") as! GitVC
        newViewController.repo = repo
        self.navigationController?.pushViewController(newViewController, animated: true)
    }
    
    @objc func gitPanel(_ sender: Any?) {
        save()
        
        guard let p = editorView?.gitPanel else { return }
        
        let screenSize = UIScreen.main.bounds
        if p.contentView.frame.width > screenSize.width {
            p.contentView.frame = CGRect(x: 400 - screenSize.width, y: p.bounds.minY, width: screenSize.width, height: p.bounds.height)
        }
        
        if p.isHidden == true {
            p.reloadProperties()
        }
        p.isHidden = !(p.isHidden)
        
        let split = self.splitViewController as! EditorSplitVC
        split.HideSmartKeyboard()
    }
    
    @objc func undo(_ sender: Any?) {
        editorView?.undo()
    }
    @objc func redo(_ sender: Any?) {
        editorView?.redo()
    }
    
    var snippetButton: UIBarButtonItem!
    weak var snippetVC: snippetController?
    @objc func showSnippet(_ sender: Any?) {
        snippetVC = storyboard?.instantiateViewController(withIdentifier: "snippetController") as? snippetController
        snippetVC?.preferredContentSize = CGSize(width: 320, height: 400)
        
        showPopover(snippetVC!, from: snippetButton)
    }
    
    func showPopover(_ vc: UIViewController, from barButtonItem: UIBarButtonItem) {
        
        vc.modalPresentationStyle = .popover
        vc.popoverPresentationController?.barButtonItem = barButtonItem
        
        present(vc, animated: true, completion: nil)
    }
    
    @objc func reloadInterface(_ notification: Notification) {
        updatedBar()
        configureView()
    }
}

