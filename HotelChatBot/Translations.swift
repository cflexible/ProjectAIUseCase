//
//  Translations.swift
//  HotelChatBot
//  Class for getting text translations. But we only look for translations if the user uses a known other language as the defautl en
//  Created by Jens Lünstedt on 24.02.23.
//

import Cocoa

/**
 This class is for translating text into a wished language. The default Localized.strings file is not used but the Translation table from the database.
 */
class Translations: NSObject {
    
    /// The destination language for the translation. If no is defined "en" is used.
    public static var translationLanguage: String = NSLocale.current.language.languageCode?.identifier ?? "en"
    
    /**
        In init we check if we have translations for the app language. Otherwise we use the default english
     */
    override init() {
        super.init()
    }
    
    
    /**
        For a given text we look if the translation language is different from english. Then we look if we have a translation available and we return it. Otherwise we return the original text.
     */
    func getTranslation(text: String) -> String {
        if Translations.translationLanguage == "en" {
            return text
        }
        
        let predicate = NSPredicate.init(format: "language = \(Translations.translationLanguage) and sourceString = \(text)")
        let translationObjects: [Translation]? = DatastoreController.shared.allForEntity("Translation", with: predicate) as? [Translation]
        if translationObjects != nil && translationObjects?.count ?? 0 > 0 {
            return translationObjects![0].translation ?? text // if the translatioon is empty we return the text
        }
        return text
    }
}
