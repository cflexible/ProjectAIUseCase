//
//  ChatController.swift
//  HotelChatBot
//
//  Created by Jens Lünstedt on 24.02.23.
//

import Cocoa
import CoreML
import NaturalLanguage

class ChatController: NSObject {
    static var classifierModel: NLModel?
    static var taggerModel: NLModel?

    static var actStep: Int = 0
    static var newLearnTaggingWordString:  String = ""
    static var newLearnTaggingString:      String = ""
    static var taggingSentences:           [String] = []
    
    static var workBooking: Booking?

    
    static func nextStep() -> String {
        let nextworkflowObject: Workflow? = DatastoreController.shared.entityByName("Workflow", key: "orderNumber", value: NSNumber.init(value: actStep) as NSObject) as? Workflow
        
        if nextworkflowObject != nil {
            actStep += 1
            return Translations().getTranslation(text: (nextworkflowObject?.englishText) ?? "")
        }
        return ""
    }
    
    static private func initModels() {
        if classifierModel != nil && taggerModel != nil {
            return
        }
        if let classifierModelURL = Bundle.main.url(forResource: "HotelChatbotTextClassifier 4", withExtension: "mlmodelc") {
            do {
                classifierModel = try NLModel(contentsOf: classifierModelURL)
            }
            catch  {
                print("error trying to load classifier model")
                return
            }
        }
        if let taggerModelURL = Bundle.main.url(forResource: "HotelChatBotTagger 4", withExtension: "mlmodelc") {
            do {
                taggerModel = try NLModel(contentsOf: taggerModelURL)
            }
            catch  {
                print("error trying to load classifier model")
                return
            }
        }
    }


    static func valueForTag(tagname: String, text: String) -> String {
        struct ValueHypotheseses {
            var text: String
            var hypotheses: Double
        }

        var foundValues: [ValueHypotheseses] = []

        // We remember the text to get new classifier trainings data if neccessary
        newLearnTaggingWordString  = ""
        newLearnTaggingString      = ""
        
        let chatTagScheme = NLTagScheme("ChatbotTagScheme")
        let tagger = NLTagger(tagSchemes: [chatTagScheme, .nameTypeOrLexicalClass])
        tagger.setModels([taggerModel!], forTagScheme: chatTagScheme)
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .word,
                             scheme: chatTagScheme,
                             options: [.omitWhitespace]) { tag, tokenRange in
            if let tag = tag {
                print("\(text[tokenRange]): \(tag.rawValue)")
                if newLearnTaggingWordString.count > 0 {
                    newLearnTaggingWordString = newLearnTaggingWordString + ", "
                    newLearnTaggingString     = newLearnTaggingString     + ", "
                }
                newLearnTaggingWordString = newLearnTaggingWordString + "\"" + text[tokenRange] + "\""
                newLearnTaggingString     = newLearnTaggingString     + "\"" + tag.rawValue + "\""
                
                if tag.rawValue == tagname {
                    let hypotheses =  tagger.tagHypotheses(at: tokenRange.lowerBound, unit: .word, scheme: chatTagScheme, maximumCount: 1)
                    let hypothesisValue = hypotheses.0.values
                    let pair: ValueHypotheseses = ValueHypotheseses(text: String(text[tokenRange]), hypotheses: hypothesisValue.first ?? 0)
                    foundValues.append(pair)
                }
            }
            return true
        }
        addTraingsdata(classifierText: text, taggingWords: newLearnTaggingWordString, taggingTags: newLearnTaggingString)
        foundValues.sort(by: { $0.hypotheses > $1.hypotheses })
        return foundValues.first?.text ?? ""
    }

    
    static func valueForNames(tagname: String, text: String) -> String {
        struct ValueHypotheseses {
            var text: String
            var hypotheses: Double
        }

        var foundValues: [ValueHypotheseses] = []

        // We remember the text to get new classifier trainings data if neccessary
        newLearnTaggingWordString  = ""
        newLearnTaggingString      = ""
        
        let chatTagScheme = NLTagScheme("ChatbotTagScheme")
        let tagger = NLTagger(tagSchemes: [chatTagScheme, .nameTypeOrLexicalClass])
        tagger.setModels([taggerModel!], forTagScheme: chatTagScheme)
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .word,
                             scheme: chatTagScheme,
                             options: [.omitWhitespace]) { tag, tokenRange in
            if let tag = tag {
                print("\(text[tokenRange]): \(tag.rawValue)")
                if newLearnTaggingWordString.count > 0 {
                    newLearnTaggingWordString = newLearnTaggingWordString + ", "
                    newLearnTaggingString     = newLearnTaggingString     + ", "
                }
                newLearnTaggingWordString = newLearnTaggingWordString + "\"" + text[tokenRange] + "\""
                newLearnTaggingString     = newLearnTaggingString     + "\"" + tag.rawValue + "\""
                
                if tag.rawValue == tagname {
                    let hypotheses =  tagger.tagHypotheses(at: tokenRange.lowerBound, unit: .word, scheme: chatTagScheme, maximumCount: 1)
                    let hypothesisValue = hypotheses.0.values
                    let pair: ValueHypotheseses = ValueHypotheseses(text: String(text[tokenRange]), hypotheses: hypothesisValue.first ?? 0)
                    foundValues.append(pair)
                }
            }
            return true
        }
        addTraingsdata(classifierText: text, taggingWords: newLearnTaggingWordString, taggingTags: newLearnTaggingString)
        foundValues.sort(by: { $0.hypotheses > $1.hypotheses })
        return foundValues.first?.text ?? ""
    }


    static func valueForDates(text: String) -> [Date]? {
        struct ValueHypotheseses {
            var text: String
            var hypotheses: Double
        }

        var fromDayString:   String = ""
        var fromMonthString: String = ""
        var fromYearString:  String = ""

        var toDayString:   String = ""
        var toMonthString: String = ""
        var toYearString:  String = ""

        // We remember the text to get new classifier trainings data if neccessary
        newLearnTaggingWordString  = ""
        newLearnTaggingString      = ""
        
        let chatTagScheme = NLTagScheme("ChatbotTagScheme")
        let tagger = NLTagger(tagSchemes: [chatTagScheme, .nameTypeOrLexicalClass])
        tagger.setModels([taggerModel!], forTagScheme: chatTagScheme)
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .word,
                             scheme: chatTagScheme,
                             options: [.omitWhitespace, .omitPunctuation]) { tag, tokenRange in
            if let tag = tag {
                print("\(text[tokenRange]): \(tag.rawValue)")
                if newLearnTaggingWordString.count > 0 {
                    newLearnTaggingWordString = newLearnTaggingWordString + ", "
                    newLearnTaggingString     = newLearnTaggingString     + ", "
                }
                newLearnTaggingWordString = newLearnTaggingWordString + "\"" + text[tokenRange] + "\""
                newLearnTaggingString     = newLearnTaggingString     + "\"" + tag.rawValue + "\""
                
                let value: String = String(text[tokenRange])
                switch tag.rawValue {
                case "from-month-day":
                    if fromMonthString.count == 0 {
                        fromMonthString = value
                    }
                    else if fromDayString.count == 0 {
                        fromDayString = value
                    }
                    break
                case "from-day":
                    if fromDayString.count == 0 {
                        fromDayString = value
                    }
                    break
                case "from-month":
                    if fromMonthString.count == 0 {
                        fromMonthString = value
                    }
                    break
                case "from-day-month":
                    if fromDayString.count == 0 {
                        fromDayString = value
                    }
                    else if fromMonthString.count == 0 {
                        fromMonthString = value
                    }
                    break
                case "from-year-month-day":
                    if fromYearString.count == 0 {
                        fromYearString = value
                    }
                    else if fromMonthString.count == 0 {
                        fromMonthString = value
                    }
                    else if fromDayString.count == 0 {
                        fromDayString = value
                    }
                    break
                case "from-day-month-year":
                    if fromDayString.count == 0 {
                        fromDayString = value
                    }
                    else if fromMonthString.count == 0 {
                        fromMonthString = value
                    }
                    else if fromYearString.count == 0 {
                        fromYearString = value
                    }
                    break
                case "from-month-day-year":
                    if fromMonthString.count == 0 {
                        fromMonthString = value
                    }
                    else if fromDayString.count == 0 {
                        fromDayString = value
                    }
                    else if fromYearString.count == 0 {
                        fromYearString = value
                    }
                    break
                case "to-month-day":
                    if toMonthString.count == 0 {
                        toMonthString = value
                    }
                    else if toDayString.count == 0 {
                        toDayString = value
                    }
                    break
                case "to-day":
                    if toDayString.count == 0 {
                        toDayString = value
                    }
                    break
                case "to-month":
                    if toMonthString.count == 0 {
                        toMonthString = value
                    }
                    break
                case "to-day-month":
                    if toDayString.count == 0 {
                        toDayString = value
                    }
                    else if toMonthString.count == 0 {
                        toMonthString = value
                    }
                   break
                case "to-year-month-day":
                    print(Int(value))
                    if toYearString.count == 0 && Int(value) == nil {
                        // we have a text here
                    }
                    else if toYearString.count == 0 {
                        toYearString = value
                    }
                    else if toMonthString.count == 0 {
                        toMonthString = value
                    }
                    else if toDayString.count == 0 {
                        toDayString = value
                    }
                    break
                case "to-day-month-year":
                    if toDayString.count == 0 {
                        toDayString = value
                    }
                    else if toMonthString.count == 0 {
                        toMonthString = value
                    }
                    else if toYearString.count == 0 {
                        toYearString = value
                    }
                    break
                case "to-month-day-year":
                    if toMonthString.count == 0 {
                        toMonthString = value
                    }
                    else if toDayString.count == 0 {
                        toDayString = value
                    }
                    else if toYearString.count == 0 {
                        toYearString = value
                    }
                    break
                case "NONE":
                    break
                default:
                    NSLog("Unknown tag value: \(tag.rawValue)")
                    break
                }
            }
            return true
        }
        addTraingsdata(classifierText: text, taggingWords: newLearnTaggingWordString, taggingTags: newLearnTaggingString)

        let languageRecog = NLLanguageRecognizer()
        // find the dominant language
        languageRecog.processString(text)
        print("language for date is: \(languageRecog.dominantLanguage?.rawValue ?? "")")

        if fromYearString.count == 0 {
            fromYearString = Utilities.actualYear()
        }
        if toYearString.count == 0 {
            toYearString = Utilities.actualYear()
        }
        let fromDate: Date? = Utilities.dateFromComponentStrings(day: fromDayString, month: fromMonthString, year: fromYearString, language: languageRecog.dominantLanguage?.rawValue)
        let toDate:   Date? = Utilities.dateFromComponentStrings(day: toDayString, month: toMonthString, year: toYearString, language: languageRecog.dominantLanguage?.rawValue)
        
        if fromDate == nil || toDate == nil { return nil }
        return [fromDate!, toDate!]
    }


    static func valueForNumbers(tagname: String, text: String) -> Int {
        struct ValueHypotheseses {
            var text: String
            var hypotheses: Double
        }

        var foundValues: [ValueHypotheseses] = []

        // We remember the text to get new classifier trainings data if neccessary
        newLearnTaggingWordString  = ""
        newLearnTaggingString      = ""
        
        let chatTagScheme = NLTagScheme("ChatbotTagScheme")
        let tagger = NLTagger(tagSchemes: [chatTagScheme, .nameTypeOrLexicalClass])
        tagger.setModels([taggerModel!], forTagScheme: chatTagScheme)
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .word,
                             scheme: chatTagScheme,
                             options: [.omitWhitespace]) { tag, tokenRange in
            if let tag = tag {
                print("\(text[tokenRange]): \(tag.rawValue)")
                if newLearnTaggingWordString.count > 0 {
                    newLearnTaggingWordString = newLearnTaggingWordString + ", "
                    newLearnTaggingString     = newLearnTaggingString     + ", "
                }
                newLearnTaggingWordString = newLearnTaggingWordString + "\"" + text[tokenRange] + "\""
                newLearnTaggingString     = newLearnTaggingString     + "\"" + tag.rawValue + "\""
                
                if tag.rawValue == tagname {
                    let hypotheses =  tagger.tagHypotheses(at: tokenRange.lowerBound, unit: .word, scheme: chatTagScheme, maximumCount: 1)
                    let hypothesisValue = hypotheses.0.values
                    let pair: ValueHypotheseses = ValueHypotheseses(text: String(text[tokenRange]), hypotheses: hypothesisValue.first ?? 0)
                    foundValues.append(pair)
                }
            }
            return true
        }
        addTraingsdata(classifierText: text, taggingWords: newLearnTaggingWordString, taggingTags: newLearnTaggingString)
        foundValues.sort(by: { $0.hypotheses > $1.hypotheses })
        return foundValues.first?.text.wordToInteger() ?? 0
    }

    
    static func valueForPhone(text: String) -> String {
        struct ValueHypotheseses {
            var text: String
            var hypotheses: Double
        }

        let tagname = "phone"
        var resultPhoneNumber = ""

        // We remember the text to get new classifier trainings data if neccessary
        newLearnTaggingWordString  = ""
        newLearnTaggingString      = ""
        
        let chatTagScheme = NLTagScheme("ChatbotTagScheme")
        let tagger = NLTagger(tagSchemes: [chatTagScheme, .nameTypeOrLexicalClass])
        tagger.setModels([taggerModel!], forTagScheme: chatTagScheme)
        tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .word,
                             scheme: chatTagScheme,
                             options: [.omitWhitespace]) { tag, tokenRange in
            if let tag = tag {
                print("\(text[tokenRange]): \(tag.rawValue)")
                if tag.rawValue == "phone" {
                    resultPhoneNumber += text[tokenRange]
                }
                if newLearnTaggingWordString.count > 0 {
                    newLearnTaggingWordString = newLearnTaggingWordString + ", "
                    newLearnTaggingString     = newLearnTaggingString     + ", "
                }
                newLearnTaggingWordString = newLearnTaggingWordString + "\"" + text[tokenRange] + "\""
                newLearnTaggingString     = newLearnTaggingString     + "\"" + tag.rawValue + "\""
            }
            return true
        }
        addTraingsdata(classifierText: text, taggingWords: newLearnTaggingWordString, taggingTags: newLearnTaggingString)
        return resultPhoneNumber
    }



    
    
    static func analyseText(text: String) -> String {
        initModels()
        
        var guest: Guest? = ChatController.workBooking?.guest
        
        struct ValueHypotheseses {
            var text: String
            var hypotheses: Double
        }
        
        if classifierModel != nil && taggerModel != nil {
            let classifierLabel = classifierModel!.predictedLabel(for: text)
            // We remember the text
            ClassifierHelper.addText(text: text, classifierString: classifierLabel)
            print("Found classifier: \(classifierLabel)")
            switch classifierLabel {
                
            case "hasNames":
                if workBooking?.guest?.firstname?.count ?? 0 > 0 && workBooking?.guest?.lastname?.count ?? 0 > 0 {
                    return "I'm sorry but I did not understand you right.<br>" + getNextQuestion()
                }
                let firstName: String = valueForNames(tagname: "first-name", text: text)
                let lastName:  String = valueForNames(tagname: "last-name", text: text)
                
                if firstName.count > 0 && lastName.count > 0 {
                    guest = DatastoreController.shared.createNewEntityByName("Guest") as? Guest
                    guest?.firstname = firstName
                    guest?.lastname  = lastName
                    addValueToBooking(data: guest!)
                    return "Hallo <strong>" + firstName + "</strong> <strong>" + lastName + "</strong>. Welcome to our hotel. <br>" + getNextQuestion()
                }
                
                break
            case "hasMailaddress":
                let mail: String = Utilities.getMailAddressFromText(text) ?? ""
                
                if guest != nil && guest?.firstname?.count ?? 0 > 0 && guest?.lastname?.count ?? 0 > 0 && mail.count > 0 {
                    guest?.mailaddress = mail
                }
                else if mail.count > 0 {
                    let guestDB: Guest? = DatastoreController.shared.entityByName("Guest", key: "mailaddress", value: mail as NSObject) as? Guest
                    if guestDB != nil {
                        addValueToBooking(data: guestDB!)
                    }
                }
                else {
                    writeNewTraingsdataToFile()
                    return String("I'm sorry but I could not understand you. Can you give me your answer again, please?")
                }
                if workBooking?.guest != nil {
                    let firstName: String = workBooking?.guest?.firstname ?? ""
                    let lastName:  String = workBooking?.guest?.lastname  ?? ""
                    return "Hallo " + "<strong>" + firstName + "</strong>" + " " + "<strong>" + lastName + "</strong>" + ". Welcome to our hotel. <br>" + getNextQuestion()
                }
                else {
                    return "I'm sorry but I could not find you in our System. Please give us your names. Thanks.<br>" + getNextQuestion()
                }
                break

            case "numberOfGuests":
                let numberOfGuests = valueForNumbers(tagname: "number", text: text)
                break
                
            case "hasDates":
                let dates: [Date]? = valueForDates(text: text)
                if workBooking != nil && dates?.count == 2 && dates?[0].compare((dates?[1])!) == .orderedAscending {
                    workBooking?.startDate = dates![0]
                    workBooking?.endDate   = dates![1]
                    return "Thank you for the dates.<br>" + getNextQuestion()
                }
                break
            case "positive-hasChildren":
                break
            case "negative-hasChildren":
                break
            case "hasPhonenumber":
                let phoneNumberString: String = valueForPhone(text: text)
                workBooking?.guest?.phonenumber = phoneNumberString
                return "Thank you for your phonenumber.<br>" + getNextQuestion()
            case "positive-breakfast":
                workBooking?.breakfast = true
                return "Breakfast is noticed.<br>" + getNextQuestion()
            case "negative-breakfast":
                workBooking?.breakfast = false
                return "It is noticed that you do not want to have breakfast<br>" + getNextQuestion()
            default:
                break
            }
        }
        else {
            return String("I'm sorry but I miss a NLP model, please ask the developer.")
        }
        
        // Initialize LanguageRecognizer
        let languageRecog = NLLanguageRecognizer()
        // find the dominant language
        languageRecog.processString(text)
        print("Dominant language is: \(languageRecog.dominantLanguage?.rawValue ?? "")")
        writeNewTraingsdataToFile()
        return String("I'm sorry but I could not understand you. Can you give me your answer again, please?")
    }
    
    
    /**
        We have a new trainings sentence and we remember it for generating a file later
     */
    static func addTraingsdata(classifierText: String!, taggingWords: String, taggingTags: String) {
        if classifierText.isEmpty || taggingWords.isEmpty || taggingTags.isEmpty {
            return
        }
        taggingSentences.append("{\n    \"tokens\":[" + taggingWords + "],\n    \"labels\": [" + taggingTags + "]\n},\n")
    }
    
    
    /**
        Wir schreiben zwei Dateien mit zukünftigen Trainingsdaten als Basis
     */
    static func writeNewTraingsdataToFile() {
        let desktopPath = (NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true) as [String]).first
        if desktopPath == nil { return }

        let taggerFilename: String = desktopPath! + "/NewTaggerTrainingdata.json"
        do {
            for theString in taggingSentences {
                try theString.write(toFile: taggerFilename, atomically: true, encoding: .utf8)
            }
        }
        catch {
            print("Could not write file: " + taggerFilename)
        }
    }
    
    
    static func addValueToBooking(data: NSObject) {
        if data is Guest {
            if workBooking == nil {
                workBooking = DatastoreController.shared.createNewEntityByName("Booking") as? Booking
            }
            workBooking?.guest = (data as! Guest)

        }
    }
    
    
    static func getNextQuestion() -> String {
        if workBooking == nil {
            return "Please name me your firstname and your lastname, thanks."
        }
        if workBooking?.guest == nil {
            return "Please name me your firstname and your lastname or your mail address if you don't stay the first time at our hotel, thanks."
        }
        if workBooking?.guest?.firstname == nil || workBooking?.guest?.lastname == nil {
            return "Please name me your firstname and your lastname, thanks."
        }
        if workBooking?.startDate == nil && workBooking?.endDate == nil {
            return "From when to when would you like to stay?"
        }
        if workBooking?.startDate == nil {
            return "When will you arrive?"
        }
        if workBooking?.endDate == nil {
            return "When will you leave?"
        }
        if workBooking?.numberOfGuests == nil || workBooking?.numberOfGuests == 0 {
            return "How many persons want to overnight?"
        }
        if workBooking?.numberOfChildren == nil && workBooking?.numberOfGuests ?? 0 > 2 {
            return "How many children are with you?"
        }
        if workBooking?.breakfast == nil {
            return "Do you like to have breakfast in the mornings?"
        }
        if workBooking?.guestType == nil && (workBooking?.numberOfChildren == nil || workBooking?.numberOfChildren == 0) {
            return "Is this a private or business visit?"
        }
        if workBooking?.paymentMethod == nil {
            return "How do you like to pay (credit card or cash)?"
        }
        if workBooking?.parkings == nil {
            return "Do you need a parking place?"
        }
        if workBooking?.guest?.phonenumber == nil {
            return "Please give us your phonenumber where we can reach you if we have questions."
        }
        if workBooking?.guest?.mailaddress == nil {
            return "Please give me your mail address where we can send the confirmation mail."
        }
        else {
            return "The booking is complete. Please verify your values.<br>" + (workBooking?.toHTML() ?? "")
        }
    }
}

