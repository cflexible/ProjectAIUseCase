//
//  LanguageWindowController.swift
//  HotelChatBot
//
//  Created by Jens Lünstedt on 01.03.23.
//

import Cocoa

class LanguageWindowController: NSViewController {

    @IBOutlet weak var questionlabel:  NSTextField!
    @IBOutlet weak var cancelButton:   NSButton!
    @IBOutlet weak var switchButton:   NSButton!

    var oldLanguage:     String = ""
    var newLanguage:     String = ""
    var oldLanguageName: String = ""
    var newLanguageName: String = ""

    func setLanguages(oldLanguage: String, newLanguage: String) {
        self.oldLanguage = oldLanguage
        self.newLanguage = newLanguage
    }
    
    
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
    
    @IBAction override func cancelOperation(_ sender: Any?) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        NSApplication.shared.stopModal()
    }
    
    
    @IBAction func switchPressed(_ sender: Any?) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        ChatController.currentLanguage = newLanguage
        NSApplication.shared.stopModal()
    }
}
