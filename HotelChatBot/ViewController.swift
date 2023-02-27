//
//  ViewController.swift
//  HotelChatBot
//  This is the central controller class which is used to control the view elements and the app main process
//  Created by Jens Lünstedt on 21.02.23.
//

import Cocoa
import WebKit

class ViewController: NSViewController, NSTextFieldDelegate, WKNavigationDelegate, NSWindowDelegate {

    @IBOutlet weak var webView:    WKWebView!
    @IBOutlet weak var editField:  NSTextField!
    @IBOutlet weak var botWorking: NSProgressIndicator!
    
    var outviewGenerator = OutputViewGenerator()
    
    var helpviewController: HelpViewController?

    /**
        Default function when this view is loaded
     */
    override func viewDidLoad() {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        DataLoad.loadBaseData()

        self.view.window?.delegate = self
        editField.delegate = self
        var html: String = outviewGenerator.newHotelChat(text: ChatController.nextStep())
        webView.navigationDelegate = self
        webView.loadHTMLString(html, baseURL: nil)
    }

    
    /**
        The view will be visible in the next step so we should make view changes like the set of the window title first.
     */
    override func viewWillAppear() {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        super.viewWillAppear()
        self.view.window?.title = NSLocalizedString("To the Prancing Pony booking chatbot", comment: "")
    }
    
    
    /**
        The view is now visible
     */
    override func viewDidAppear() {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        super.viewDidAppear()

        self.view.window?.delegate = self
        self.view.window?.minSize = NSSize(width: 320, height: 300) // We define a minimum size of the window before the HTML view gets broken
    }
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    
    /**
        Event when the user changed the text in the editing field. we then calculate a new high with the next function til a maximum so the user should not have to scroll
     */
    func controlTextDidChange(_ obj: Notification) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        calculateEditHeight()
    }
    
    
    /**
        The user presses return and we take that event for using his editing
     */
    func controlTextDidEndEditing(_ obj: Notification) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        let html: String = outviewGenerator.newGuestChat(text: editField.stringValue)
        webView.loadHTMLString(html, baseURL: nil)
        let text = editField.stringValue
        editField.stringValue = ""
        botWorking.isHidden = false
        var newHotelChatString: String? = ChatController.analyseText(text: text)
        if newHotelChatString != nil {
            let html: String = outviewGenerator.newHotelChat(text: newHotelChatString!)
            webView.navigationDelegate = self
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
    
    /**
        we calculate the height of the text and we grow the height of the text field until it reaches a maximum height of 128
        also we recalculate the height of the webview and set that
     */
    func calculateEditHeight() {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        let attrString: NSAttributedString = editField.attributedStringValue
        let bounds = attrString.boundingRect(with: CGSize(width: editField.frame.size.width, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil)
        let size = CGSize(width: bounds.width, height: bounds.height)
  
        if size.height > editField.frame.size.height && size.height < 128 {
            editField.frame.size.height = size.height + 10
            webView.frame.origin.y = editField.frame.size.height + 8
            webView.frame.size.height = self.view.frame.size.height - webView.frame.origin.y
        }
    }
    
    
    /**
        If the info button is pressed we show a little window with an informational text to the user.
     */
    @IBAction func infoPressed(_ sender: NSButton) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        helpviewController = Utilities.storyBoard.instantiateController(identifier: "HelpviewController")
        self.presentAsModalWindow(helpviewController!)
    }
    
    
    /**
        If the webview is loaded we scroll to the end because we reload the page with every new chat entry
     */
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        webView.scrollPageDown(self)
    }

    
    /**
        If the user pressed the close button the whole program terminates
     */
    func windowWillClose(_ notification: Notification) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        NSApplication.shared.terminate(self)
    }

}

