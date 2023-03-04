//
//  LanguageWindowController.swift
//  HotelChatBot
//
//  Created by Jens Lünstedt on 01.03.23.
//

import Cocoa

/// The delegate method definition for the event that the user wish to change the language.
protocol LanguageChangeDelegate {
    /// Delegate method with the information of the new language.
    func newLanguage(_ language: String)
}

/**
 A third ViewController. If the analyse of the text finds another language as the system language and if there are
 models available for this language the user will ask if he wants to switch the language.
 The Controller presents the question for the language and two buttons for switching and cancellation.
 If the language should change the delegate is informed about the new language.
 */
class LanguageWindowController: NSViewController {

    /// The NSTextField with the question
    @IBOutlet weak var questionlabel:  NSTextField!
    /// NSButton for just closing the window without an action
    @IBOutlet weak var cancelButton:   NSButton!
    /// NSButton for changing the language
    @IBOutlet weak var switchButton:   NSButton!

    /// Short String for the old language
    private var oldLanguage:     String = ""
    /// Short String for the new language
    private var newLanguage:     String = ""
    
    /// Long String for the old language
    private var oldLanguageName: String = ""
    /// Long String for the new language
    private var newLanguageName: String = ""
    
    /// The delegate variable which is informed when the language should change
    var delegate: LanguageChangeDelegate?

    /**
        A public function for getting the information about the old and the new language.
     */
    func setLanguages(oldLanguage: String, newLanguage: String) {
        self.oldLanguage = oldLanguage
        self.newLanguage = newLanguage
    }
    
    
    /**
        Default function when this view is loaded. Just the button texts are set.
     */
    override func viewDidLoad() {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        super.viewDidLoad()
        // Do view setup here.
        cancelButton.title = NSLocalizedString("cancel", comment: "")
        switchButton.title = NSLocalizedString("switch", comment: "")
        switchButton.isHighlighted = true

    }
    

    /**
        The view will be visible in the next step so we should make view changes like the set of the window title first.
        Here we translate the language shorts into long names.
     */
    override func viewWillAppear() {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        self.view.window?.title = NSLocalizedString("Would you like to change the app language?", comment: "")
        self.view.window?.setAccessibilityDefaultButton(switchButton)
        
        switchButton.keyEquivalent = "\r"
        
        switch oldLanguage {
        case "en": oldLanguageName = "English"
            break
        case "de": oldLanguageName = "Deutsch"
            break
        default:
            oldLanguageName = NSLocalizedString("unknown", comment: "")
        }

        switch newLanguage {
        case "en": newLanguageName = "English"
            break
        case "de": newLanguageName = "Deutsch"
            break
        default:
            newLanguageName = NSLocalizedString("unknown", comment: "")
            return
        }

        questionlabel.stringValue = NSLocalizedString("Your current language is ", comment: "") + oldLanguageName + NSLocalizedString(".\nDo you want to switch to ", comment: "") + newLanguageName + "?"
    }
    
    
    /**
        Just close the window because the user does not want to change the language.
     */
    @IBAction override func cancelOperation(_ sender: Any?) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        NSApplication.shared.stopModal()
    }
    
    
    /**
        Action function to switch the language. The delegate is informed.
     */
    @IBAction func switchPressed(_ sender: Any?) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        delegate?.newLanguage(newLanguage)
        NSApplication.shared.stopModal()
    }
}
