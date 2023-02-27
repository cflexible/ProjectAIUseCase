//
//  HelpViewController.swift
//  HotelChatBot
//  The controller for the help window. Here we just set the window title and the help content loaded from Localized.strings
//  Created by Jens Lünstedt on 23.02.23.
//

import Cocoa

class HelpViewController: NSViewController {

    @IBOutlet weak var helptextField: NSTextField!
    @IBOutlet weak var okButton:      NSButton!

    
    /**
        Default function when this view is loaded
     */
    override func viewDidLoad() {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        super.viewDidLoad()
        // Do view setup here.
        helptextField.stringValue = NSLocalizedString("Help text", comment: "An information text about the chatbot.")
        okButton.setAccessibilityTitle(NSLocalizedString("Ok", comment: ""))
    }
    
    
    /**
        The view will be visible in the next step so we should make view changes like the set of the window title first.
     */
    override func viewWillAppear() {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        super.viewWillAppear()
        self.view.window?.title = NSLocalizedString("Information about this chatbot", comment: "")
    }
    
    
}
