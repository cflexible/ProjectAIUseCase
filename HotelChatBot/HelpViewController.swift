//
//  HelpViewController.swift
//  HotelChatBot
//  The controller for the help window. Here we just set the window title and the help content loaded from Localized.strings
//  Created by Jens Lünstedt on 23.02.23.
//

import Cocoa

/**
 This class is for controlling the help view. It has just two view parts, a NSTextField for the help text and an NSBotton for confirming the message and slosing the window.
 */
class HelpViewController: NSViewController {

    /// The textfield for visualizing the help text
    @IBOutlet weak var helptextField: NSTextField!
    /// The button for closing the window
    @IBOutlet weak var okButton:      NSButton!

    
    /**
        Default function when this view is loaded. Here the base text is set plus the help text from the actual question of the workflow.
     */
    override func viewDidLoad() {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        super.viewDidLoad()
        // Do view setup here.
        var helptext = NSLocalizedString("Help text", comment: "An information text about the chatbot.")
        if ChatController.askedQuestion > 0 {
            helptext = helptext + "\n\n" + Translations().getTranslation(text: ChatController.workflows[ChatController.askedQuestion + 1].helpText ?? "") // we need + 1 because of array
        }
        helptextField.stringValue = helptext
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
