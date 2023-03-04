//
//  ViewController.swift
//  HotelChatBot
//  Created by Jens Lünstedt on 21.02.23.
//

import Cocoa
import WebKit

/**
 This is the central controller class which is used to control the view elements and the app main process.
 VievController is called after the AppDelegate. It is used in the storyboard for the main window content.
 On this there are three view elements which are controlled from this controller:
 - the output in a WKWebView with a HTML content
 - the users input in a NSTextField where we need the delegates of this field
 - a progress indicator which is visible while the chatbot analyses the text
 */
class ViewController: NSViewController, NSTextFieldDelegate, WKNavigationDelegate, NSWindowDelegate, LanguageChangeDelegate {

    /// The central element to visualize the chat
    @IBOutlet weak var webView:    WKWebView!
    /// The text input field for the user content
    @IBOutlet weak var editField:  NSTextField!
    /// The indicator for that the chat is working
    @IBOutlet weak var botWorking: NSProgressIndicator!
    
    /// Sub class for generating the webViews HTML content
    var outviewGenerator = OutputViewGenerator()
    
    /// A second ViewController to visualize help to the user if he presses the help button.
    /// The content of the help view depends on the actual state of the booking workflow.
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
        ChatController.currentLanguage = Utilities.getLanguage().lowercased()
        let html: String = outviewGenerator.newHotelChat(text: ChatController.getNextQuestion())
        webView.navigationDelegate = self
        webView.loadHTMLString(html, baseURL: nil)
        
    }

    
    /**
        The view will be visible in the next step so it should make view changes like the set of the window title first.
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
        editField.becomeFirstResponder()
    }
    
    
    /**
        Event when the user changed the text in the editing field. A new high is calculated with the next function til a maximum so the user should not have to scroll
     */
    func controlTextDidChange(_ obj: Notification) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        calculateEditHeight()
    }
    
    
    /**
        The user presses return and take that event for using his editing
     */
    func controlTextDidEndEditing(_ obj: Notification) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        if editField.stringValue.count == 0 { return }
        
        // We test the text language and compare it with the actual user language
        let textLanguage = ChatController.currentTextLanguage(text: editField.stringValue)
        if textLanguage.count > 0 && textLanguage != ChatController.currentLanguage {
            let languageWindowController = Utilities.storyBoard.instantiateController(withIdentifier: "LanguageQuestionWindow") as! NSWindowController
            let languageController: LanguageWindowController = languageWindowController.contentViewController as! LanguageWindowController
            languageController.setLanguages(oldLanguage: ChatController.currentLanguage, newLanguage: textLanguage)
            languageController.delegate = self
            let application = NSApplication.shared
            application.runModal(for: languageWindowController.window!)
            languageWindowController.close()
        }
        
        let html: String = outviewGenerator.newGuestChat(text: editField.stringValue)
        webView.loadHTMLString(html, baseURL: nil)
        let text = editField.stringValue
        editField.stringValue = ""
        botWorking.isHidden = false
        let newHotelChatString: String? = ChatController.analyseText(text: text)
        if newHotelChatString != nil {
            let html: String = outviewGenerator.newHotelChat(text: newHotelChatString!)
            webView.navigationDelegate = self
            webView.loadHTMLString(html, baseURL: nil)
        }
        if ((newHotelChatString ?? "").contains(NSLocalizedString("Good bye", comment: ""))) {
            editField.isEditable = false
            let html: String = outviewGenerator.newHotelChat(text: NSLocalizedString("You can close the window now.", comment: ""))
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
    
    
    /**
        Delegate function from LanguageWindowController if the language should change
     */
    func newLanguage(_ language: String) {
        ChatController.currentLanguage = language
    }
    
    
    /**
        Ccalculate the height of the text to grow the height of the text field until it reaches a maximum height of 128
        also recalculate the height of the webview and set that
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
        If the info button is pressed show a little window with an informational text to the user.
     */
    @IBAction func infoPressed(_ sender: NSButton) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        helpviewController = Utilities.storyBoard.instantiateController(identifier: "HelpviewController")
        self.presentAsModalWindow(helpviewController!)
    }
    
    
    /**
        If the webview is loaded scroll to the end because the page is reloaded with every new chat entry
     */
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        webView.scrollPageDown(self)
        // Scrolling til end of page
        webView.evaluateJavaScript("var scrollingElement = (document.scrollingElement || document.body); scrollingElement.scrollTop = scrollingElement.scrollHeight;")
        // prevent mouse actions
        webView.evaluateJavaScript("window.addEventListener('contextmenu', (event) => event.preventDefault());")
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


