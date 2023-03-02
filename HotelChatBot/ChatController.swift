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

    static var classifierVersion = "4"
    static var taggerVersion     = "4"

    static var actStep: Int = -1
    static var taggingSentences:           [String] = []
    
    static var workBooking:   Booking?
    static var wantsBooking:  Bool?
    static var askedQuestion: Int = 0
    
    // If the current language is changed we load the language model
    static var currentLanguage: String = "en" {
        didSet {
            if currentLanguage != oldValue && Bundle.main.url(forResource: "HotelChatbotTextClassifier_" + currentLanguage + " " + classifierVersion, withExtension: "mlmodelc") != nil {
                initModels()
                Translations.translationLanguage = currentLanguage
            }
            else {
                currentLanguage = "en"
                initModels()
                Translations.translationLanguage = currentLanguage
            }
        }
    }
    
    // We read all the workflows once from the database and sort them by questionNumber
    static var workflows: [Workflow] = DatastoreController.shared.allForEntity("Workflow", with: nil, orderBy: [NSSortDescriptor(key: "questionNumber", ascending: true)]) as! [Workflow]

    //MARK: Initialisation functions

    /**
        We load language specific models if possible. Otherwise we look for an english version or a version without a language
     */
    static private func initModels() {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        if classifierModel != nil && taggerModel != nil {
            return
        }
        if let classifierModelURL = Bundle.main.url(forResource: "HotelChatbotTextClassifier_" + currentLanguage + " " + classifierVersion, withExtension: "mlmodelc") {
            do {
                classifierModel = try NLModel(contentsOf: classifierModelURL)
            }
            catch  {
                print("error trying to load classifier model")
                return
            }
        }
        else if let classifierModelURL = Bundle.main.url(forResource: "HotelChatbotTextClassifier_en " + classifierVersion, withExtension: "mlmodelc") {
            do {
                classifierModel = try NLModel(contentsOf: classifierModelURL)
            }
            catch  {
                print("error trying to load classifier model")
                return
            }
        }
        else if let classifierModelURL = Bundle.main.url(forResource: "HotelChatbotTextClassifier " + classifierVersion, withExtension: "mlmodelc") {
            do {
                classifierModel = try NLModel(contentsOf: classifierModelURL)
            }
            catch  {
                print("error trying to load classifier model")
                return
            }
        }

        
        if let taggerModelURL = Bundle.main.url(forResource: "HotelChatBotTagger_" + currentLanguage + " " + taggerVersion, withExtension: "mlmodelc") {
            do {
                taggerModel = try NLModel(contentsOf: taggerModelURL)
            }
            catch  {
                print("error trying to load classifier model")
                return
            }
        }
        else if let taggerModelURL = Bundle.main.url(forResource: "HotelChatBotTagger_en " + taggerVersion, withExtension: "mlmodelc") {
            do {
                taggerModel = try NLModel(contentsOf: taggerModelURL)
            }
            catch  {
                print("error trying to load classifier model")
                return
            }
        }
        else if let taggerModelURL = Bundle.main.url(forResource: "HotelChatBotTagger " + taggerVersion, withExtension: "mlmodelc") {
            do {
                taggerModel = try NLModel(contentsOf: taggerModelURL)
            }
            catch  {
                print("error trying to load classifier model")
                return
            }
        }
    }


    /**
        we look for the current text language
     */
    static func currentTextLanguage(text: String) -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        // Initialize LanguageRecognizer
        let languageRecog = NLLanguageRecognizer()
        // find the dominant language
        languageRecog.processString(text)
        print("Dominant language is: \(languageRecog.dominantLanguage?.rawValue ?? "")")
        return languageRecog.dominantLanguage?.rawValue ?? ""
    }
    
    
    //MARK: Workflow functions

    static func nextStep() -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        let nextworkflowObject: Workflow? = DatastoreController.shared.entityByName("Workflow", key: "questionNumber", value: NSNumber.init(value: actStep) as NSObject) as? Workflow
        
        if nextworkflowObject != nil {
            actStep += 1
            if actStep <= 0 {
                return Translations().getTranslation(text: (nextworkflowObject?.englishText) ?? "") + nextStep()
            }
            return Translations().getTranslation(text: (nextworkflowObject?.englishText) ?? "")
        }
        return ""
    }
    
    
    /**
        Main function for analysing a text. Here we just splitt the text into sentences and analyse them separately
     */
    static func analyseText(text: String) -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        if currentLanguage.count == 0 {
            currentLanguage = currentTextLanguage(text: text)
        }

        initModels()
        
        struct ValueHypotheseses {
            var text: String
            var hypotheses: Double
        }
        
        let sentences = text.split(separator: ".")
        var fullResult = ""
        for sentence in sentences {
            let result: String = analyseSentence(text: String(sentence))
            if !fullResult.contains(result) {
                fullResult = fullResult + result
            }
        }
        fullResult = fullResult + getNextQuestion()
        return fullResult
        
    }
    
    
    static private func analyseSentence(text: String) -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        if currentLanguage.count == 0 {
            currentLanguage = currentTextLanguage(text: text)
        }

        initModels()
        
        var guest: Guest? = workBooking?.guest
        
        struct ValueHypotheseses {
            var text: String
            var hypotheses: Double
        }
        
        if classifierModel != nil && taggerModel != nil {
            var classifierLabel = classifierModel!.predictedLabel(for: text)
            // We remember the text
            ClassifierHelper.addText(language: currentLanguage, text: text, classifierString: classifierLabel)
            print("Found classifier: \(classifierLabel ?? "")")
            if ["hasEnglishDates", "hasGermanDates", "hasUSDates"].contains(classifierLabel) {
                classifierLabel = "hasDates"
            }
            switch classifierLabel {
                
            case "hasNames":
                if workBooking?.guest?.firstname?.count ?? 0 > 0 && workBooking?.guest?.lastname?.count ?? 0 > 0 {
                    return "We are sorry but I did not understand you.<br>"
                }
                let firstName: String = valueForNames(tagname: "first-name", text: text)
                let lastName:  String = valueForNames(tagname: "last-name", text: text)
                
                if firstName.count > 0 && lastName.count > 0 {
                    guest = DatastoreController.shared.createNewEntityByName("Guest") as? Guest
                    guest?.firstname = firstName
                    guest?.lastname  = lastName
                    addValueToBooking(data: guest!)
                    return "Hello <strong>" + firstName + "</strong> <strong>" + lastName + "</strong>. Welcome to our hotel. <br>"
                }
                return "We are sorry but I did not understand you.<br>"
                
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
                    return String("I'm sorry but I could not understand you.<br>")
                }
                if workBooking?.guest != nil {
                    let firstName: String = workBooking?.guest?.firstname ?? ""
                    let lastName:  String = workBooking?.guest?.lastname  ?? ""
                    return "Hallo " + "<strong>" + firstName + "</strong>" + " " + "<strong>" + lastName + "</strong>" + ". Welcome to our hotel. <br>"
                }
                else {
                    return "I'm sorry but I could not find you in our System. Please give us your names. Thanks.<br>"
                }

            case "numberOfGuests":
                let numberOfGuests = valueForNumbers(tagname: "number", text: text)
                if workBooking?.startDate != nil && workBooking?.endDate != nil && numberOfGuests > 0 {
                    let bookedRoomCount: Int = workBooking?.bookRooms(fromDate: (workBooking?.startDate)!, toDate: (workBooking?.endDate)!, countPersons: numberOfGuests) ?? 0
                    if bookedRoomCount > 0 {
                        return "We have booked \(String(bookedRoomCount)) rooms for you.<br>"
                    }
                    else {
                        return "We are sorry but we have not enough free rooms available.<br>"
                    }
                }
                return "We are sorry but we could not understand how many you are. Please try it again.<br>"
                
            case "hasDates":
                let dates: [Date]? = valueForDates(text: text, language: currentLanguage)
                if workBooking != nil && dates?.count == 2 && dates?[0].compare((dates?[1])!) == .orderedAscending {
                    workBooking?.startDate = dates![0]
                    workBooking?.endDate   = dates![1]
                    return "Thank you for the dates.<br>"
                }
                return "We are sorry but we could not recognize the dates. We prefere a format in yyyy-mm-dd.<br>"
                
            case "positive-hasChildren":
                workBooking?.numberOfChildren = 1
                return "We have noticed a child.<br>"
            case "negative-hasChildren":
                workBooking?.numberOfChildren = 0
                return "We have noticed no children.<br>"
                
            case "privateVisit":
                workBooking?.guestType = "Private"
                return "We have noticed your visit as a private visit.<br>"
            case "businessVisit":
                workBooking?.guestType = "Business"
                return "We have noticed your visit as a business visit.<br>"
                
            case "hasPhonenumber":
                let phoneNumberString: String = valueForPhone(text: text)
                workBooking?.guest?.phonenumber = phoneNumberString
                return "Thank you for your phonenumber.<br>"
                
            case "positive-breakfast":
                workBooking?.breakfast = true
                return "Breakfast is noticed.<br>"
            case "negative-breakfast":
                workBooking?.breakfast = false
                return "It is noticed that you do not want to have breakfast.<br>"
                
            case "positive-parking":
                if workBooking?.startDate != nil && workBooking?.endDate != nil {
                    if workBooking?.bookParking(fromDate: (workBooking?.startDate)!, toDate: (workBooking?.endDate)!) ?? false {
                        return "Parking is noticed.<br>" + getNextQuestion()
                    }
                    else {
                        return "We are sorry but we do not have a free parking place for you.<br>"
                    }
                }
                return "Before we can book a parking place we need your arrival and departure dates.<br>"
            case "negative-parking":
                return "It is noticed that you do not need a parking place.<br>"
            
            case "number-answer":
                return "Thank you<br>"
                
            case "room-price":
                return Booking.roomPrices() + "<br>"
            case "free-room":
                if workBooking?.startDate != nil && workBooking?.endDate != nil && workBooking?.numberOfGuests != nil {
                    return Booking.freeRooms(fromDate: workBooking!.startDate!, toDate: workBooking!.endDate!, countPersons: Int(workBooking!.numberOfGuests)) + "<br>" + getNextQuestion()
                }
                return "Please give us your visit dates and how many you are.<br>"
            default:
                break
            }
        }
        else {
            return String("I'm sorry but I miss a NLP model, please ask the developer.")
        }
        
        return String("I'm sorry but I could not understand you.<br>")
    }
    
    

    static func valueForTag(tagname: String, text: String) -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        struct ValueHypotheseses {
            var text: String
            var hypotheses: Double
        }

        var foundValues: [ValueHypotheseses] = []

        // We remember the text to get new classifier trainings data if neccessary
        var newLearnTaggingWordStrings: [String]  = []
        var newLearnTaggingStrings:     [String]  = []
        
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
                newLearnTaggingWordStrings.append(String(text[tokenRange]))
                newLearnTaggingStrings.append(tag.rawValue)
                
                if tag.rawValue == tagname {
                    let hypotheses =  tagger.tagHypotheses(at: tokenRange.lowerBound, unit: .word, scheme: chatTagScheme, maximumCount: 1)
                    let hypothesisValue = hypotheses.0.values
                    let pair: ValueHypotheseses = ValueHypotheseses(text: String(text[tokenRange]), hypotheses: hypothesisValue.first ?? 0)
                    foundValues.append(pair)
                }
            }
            return true
        }
        TaggerHelper.addTag(language: currentLanguage, words: newLearnTaggingWordStrings, tags: newLearnTaggingStrings)
        foundValues.sort(by: { $0.hypotheses > $1.hypotheses })
        return foundValues.first?.text ?? ""
    }

    
    static func valueForNames(tagname: String, text: String) -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        struct ValueHypotheseses {
            var text: String
            var hypotheses: Double
        }

        var foundValues: [ValueHypotheseses] = []

        // We remember the text to get new classifier trainings data if neccessary
        var newLearnTaggingWordStrings: [String]  = []
        var newLearnTaggingStrings:     [String]  = []

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
                newLearnTaggingWordStrings.append(String(text[tokenRange]))
                newLearnTaggingStrings.append(tag.rawValue)

                if tag.rawValue == tagname {
                    let hypotheses =  tagger.tagHypotheses(at: tokenRange.lowerBound, unit: .word, scheme: chatTagScheme, maximumCount: 1)
                    let hypothesisValue = hypotheses.0.values
                    let pair: ValueHypotheseses = ValueHypotheseses(text: String(text[tokenRange]), hypotheses: hypothesisValue.first ?? 0)
                    foundValues.append(pair)
                }
            }
            return true
        }
        TaggerHelper.addTag(language: currentLanguage, words: newLearnTaggingWordStrings, tags: newLearnTaggingStrings)
        foundValues.sort(by: { $0.hypotheses > $1.hypotheses })
        return foundValues.first?.text ?? ""
    }


    static func valueForDates(text: String, language: String) -> [Date]? {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

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
        var newLearnTaggingWordStrings: [String]  = []
        var newLearnTaggingStrings:     [String]  = []

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
                newLearnTaggingWordStrings.append(String(text[tokenRange]))
                newLearnTaggingStrings.append(tag.rawValue)

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
        TaggerHelper.addTag(language: currentLanguage, words: newLearnTaggingWordStrings, tags: newLearnTaggingStrings)

       if fromYearString.count == 0 {
            fromYearString = Utilities.actualYear()
        }
        if toYearString.count == 0 {
            toYearString = Utilities.actualYear()
        }
        fromDayString   = fromDayString.wordToIntegerString(language: currentLanguage)   ?? ""
        toDayString     = toDayString.wordToIntegerString(language: currentLanguage)     ?? ""
        
        let fromDate: Date? = Utilities.dateFromComponentStrings(day: fromDayString, month: fromMonthString, year: fromYearString, language: currentLanguage)
        let toDate:   Date? = Utilities.dateFromComponentStrings(day: toDayString, month: toMonthString, year: toYearString, language: currentLanguage)
        
        if fromDate == nil || toDate == nil { return nil }
        return [fromDate!, toDate!]
    }


    static func valueForNumbers(tagname: String, text: String) -> Int {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        struct ValueHypotheseses {
            var text: String
            var hypotheses: Double
        }

        let languageRecog = NLLanguageRecognizer()
        // find the dominant language
        languageRecog.processString(text)
        print("language for date is: \(languageRecog.dominantLanguage?.rawValue ?? "")")

        var foundValues: [ValueHypotheseses] = []

        // We remember the text to get new classifier trainings data if neccessary
        var newLearnTaggingWordStrings: [String]  = []
        var newLearnTaggingStrings:     [String]  = []

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
                newLearnTaggingWordStrings.append(String(text[tokenRange]))
                newLearnTaggingStrings.append(tag.rawValue)

                if tag.rawValue == tagname {
                    let hypotheses =  tagger.tagHypotheses(at: tokenRange.lowerBound, unit: .word, scheme: chatTagScheme, maximumCount: 1)
                    let hypothesisValue = hypotheses.0.values
                    let pair: ValueHypotheseses = ValueHypotheseses(text: String(text[tokenRange]), hypotheses: hypothesisValue.first ?? 0)
                    foundValues.append(pair)
                }
            }
            return true
        }
        TaggerHelper.addTag(language: currentLanguage, words: newLearnTaggingWordStrings, tags: newLearnTaggingStrings)
        foundValues.sort(by: { $0.hypotheses > $1.hypotheses })
        return Int(foundValues.first?.text.wordToIntegerString(language: languageRecog.dominantLanguage?.rawValue ?? "") ?? "") ?? 0
    }

    
    static func valueForPhone(text: String) -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        struct ValueHypotheseses {
            var text: String
            var hypotheses: Double
        }

        let tagname = "phone"
        var resultPhoneNumber = ""

        // We remember the text to get new classifier trainings data if neccessary
        var newLearnTaggingWordStrings: [String]  = []
        var newLearnTaggingStrings:     [String]  = []

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
                if tag.rawValue == tagname {
                    resultPhoneNumber += text[tokenRange]
                }
                newLearnTaggingWordStrings.append(String(text[tokenRange]))
                newLearnTaggingStrings.append(tag.rawValue)
            }
            return true
        }
        TaggerHelper.addTag(language: currentLanguage, words: newLearnTaggingWordStrings, tags: newLearnTaggingStrings)
        return resultPhoneNumber
    }


    static func addValueToBooking(data: NSObject) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        if data is Guest {
            if workBooking == nil {
                workBooking = DatastoreController.shared.createNewEntityByName("Booking") as? Booking
            }
            workBooking?.guest = (data as! Guest)

        }
    }
    
    
    static func getNextQuestion() -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        // let test = workBooking?.bookingComplete()

        for workflow in workflows {
            if workflow.questionNumber < actStep {
                continue
            }
            if workflow.checkAttributename == "workBooking" && workBooking == nil {
                return workflow.englishText ?? "Undefined Text"
            }
            else {
                let validateValue = workBooking?.value(forKeyPath: workflow.checkAttributename ?? "")
                if validateValue == nil {
                    askedQuestion = Int(workflow.questionNumber)
                    return workflow.englishText ?? "Undefined Text"
                }
            }
        }
        return Translations().getTranslation(text: workflows.last?.englishText ?? "We are sorry but we did not understand you.<br>")
    }
    
}

