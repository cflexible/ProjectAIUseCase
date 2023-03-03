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
    
    static var workBooking:   Booking = Booking.createBooking() // Here we initialize a booking object including a guest object
    static var wantsBooking:  Bool?
    static var askedQuestion: Int = -10
    
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
        Load of language specific models if possible. Otherwise look for an english version or a version without a language
     */
    static private func initModels() {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        if classifierModel != nil && taggerModel != nil {
            return
        }
        
        // we try to load a classifier model for the actual language if that is not possible we use en or nothing
        var modelFilename = "HotelChatbotTextClassifier" + "_" + currentLanguage + " " + classifierVersion
        var classifierModelURL = Bundle.main.url(forResource: modelFilename, withExtension: "mlmodelc")
        if classifierModelURL == nil {
            modelFilename = "HotelChatbotTextClassifier" + "_en " + classifierVersion
            classifierModelURL = Bundle.main.url(forResource: modelFilename, withExtension: "mlmodelc")
        }
        if classifierModelURL == nil {
            classifierModelURL = Bundle.main.url(forResource: "HotelChatbotTextClassifier " + classifierVersion, withExtension: "mlmodelc")
        }
        if classifierModelURL == nil {
            return
        }
        do {
            classifierModel = try NLModel(contentsOf: classifierModelURL!)
        }
        catch  {
            print("error trying to load classifier model")
            return
        }

        // we try to load a tagger model for the actual language if that is not possible we use en or nothing
        modelFilename = "HotelChatBotTagger" + "_" + currentLanguage + " " + classifierVersion
        var taggerModelURL = Bundle.main.url(forResource: modelFilename, withExtension: "mlmodelc")
        if taggerModelURL == nil {
            modelFilename = "HotelChatBotTagger" + "_en " + classifierVersion
            taggerModelURL = Bundle.main.url(forResource: modelFilename, withExtension: "mlmodelc")
        }
        if taggerModelURL == nil {
            taggerModelURL = Bundle.main.url(forResource: "HotelChatBotTagger " + classifierVersion, withExtension: "mlmodelc")
        }
        if taggerModelURL == nil {
            return
        }
        do {
            taggerModel = try NLModel(contentsOf: taggerModelURL!)
        }
        catch  {
            print("error trying to load tagger model")
            return
        }
    }


    /**
        Look for the current text language
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
    /**
        Main function for analysing a text. Here we just splitt the text into sentences and analyse them separately
     */
    static func analyseText(text: String) -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        // if there is no language set (which is improbable) the langauge is set from the text
        if currentLanguage.count == 0 {
            currentLanguage = currentTextLanguage(text: text)
        }

        // Initialize the models
        initModels()

        // Split the text into sentences (this is actually simple but a fast way)
        let sentences = text.split(separator: ".")
        var fullResult = ""
        for sentence in sentences {
            let result: String = analyseSentence(text: String(sentence))
            if !fullResult.contains(result) {
                fullResult = fullResult + result
            }
        }
        // Return the result with the next question
        fullResult = fullResult + getNextQuestion()
        return fullResult
        
    }
    
    
    /**
        This is the main function of analysing the texts. Here we get one sentence. So we can first analyse the kind
        of the sentence before we analyse the content of the sentence.
     */
    static private func analyseSentence(text: String) -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        // If we miss a model we return
        if classifierModel == nil || taggerModel == nil {
            return String("I'm sorry but I miss a NLP model, please ask the developer.")
        }

        let baseErrormessage = Translations().getTranslation(text: "We are sorry but I did not understand you.<br>")
        
        var classifierLabel = classifierModel!.predictedLabel(for: text)
        // We remember the text
        ClassifierHelper.addText(language: currentLanguage, text: text, classifierString: classifierLabel)
        print("Found classifier: \(classifierLabel ?? "")")
        if ["hasEnglishDates", "hasGermanDates", "hasUSDates"].contains(classifierLabel) {
            classifierLabel = "hasDates"
        }
        
        switch classifierLabel {
        case "hasNames":
            if workBooking.guest?.firstname?.count ?? 0 > 0 && workBooking.guest?.lastname?.count ?? 0 > 0 {
                return baseErrormessage + Translations().getTranslation(text: workflows[askedQuestion].negativeAnswer ?? "")
            }
            let firstName: String = valueForNames(tagname: "first-name", text: text)
            let lastName:  String = valueForNames(tagname: "last-name", text: text)
            
            if firstName.count > 0 && lastName.count > 0 {
                workBooking.guest?.firstname = firstName
                workBooking.guest?.lastname  = lastName
                var positiveReturn = Translations().getTranslation(text: workflows[askedQuestion + 1].positiveAnswer ?? "")
                positiveReturn = positiveReturn.replacingOccurrences(of: "<firstName>", with: firstName)
                positiveReturn = positiveReturn.replacingOccurrences(of: "<lastName>", with: lastName)
                return positiveReturn
            }
            print(askedQuestion)
            return baseErrormessage + Translations().getTranslation(text: workflows[askedQuestion].negativeAnswer ?? "")
            
        case "hasMailaddress":
            let mail: String = Utilities.getMailAddressFromText(text) ?? ""
            
            if workBooking.guest != nil && workBooking.guest?.firstname?.count ?? 0 > 0 && workBooking.guest?.lastname?.count ?? 0 > 0 && mail.count > 0 {
                workBooking.guest?.mailaddress = mail
            }
            else if mail.count > 0 {
                let guestDB: Guest? = DatastoreController.shared.entityByName("Guest", key: "mailaddress", value: mail as NSObject) as? Guest
                if guestDB != nil {
                    workBooking.guest = guestDB!
                }
            }
            else {
                return baseErrormessage
            }
            if workBooking.guest != nil {
                let firstName: String = workBooking.guest?.firstname ?? ""
                let lastName:  String = workBooking.guest?.lastname  ?? ""
                var positiveReturn = Translations().getTranslation(text: workflows[askedQuestion + 1].positiveAnswer ?? "")
                positiveReturn = positiveReturn.replacingOccurrences(of: "<firstName>", with: firstName)
                positiveReturn = positiveReturn.replacingOccurrences(of: "<lastName>", with: lastName)
                return positiveReturn
            }
            else {
                return Translations().getTranslation(text: "I'm sorry but I could not find you in our System. Please give us your names. Thanks.<br>")
            }

        case "numberOfGuests":
            let numberOfGuests = valueForNumbers(tagname: "number", text: text)
            if workBooking.startDate != nil && workBooking.endDate != nil && numberOfGuests > 0 {
                let bookedRoomCount: Int = workBooking.bookRooms(fromDate: (workBooking.startDate)!, toDate: (workBooking.endDate)!, countPersons: numberOfGuests)
                if bookedRoomCount > 0 {
                    var bookedRoomResult = Translations().getTranslation(text: "We have booked <bookedRoomCount> rooms for you.<br>")
                    bookedRoomResult = bookedRoomResult.replacingOccurrences(of: "bookedRoomCount", with: String(bookedRoomCount))
                    return bookedRoomResult
                }
                else {
                    return Translations().getTranslation(text: "We are sorry but we have not enough free rooms available.<br>")
                }
            }
            return Translations().getTranslation(text: "We are sorry but we could not understand how many you are. Please try it again.<br>")
            
        case "hasDates":
            let dates: [Date]? = valueForDates(text: text, language: currentLanguage)
            if dates?.count == 2 && dates?[0].compare((dates?[1])!) == .orderedAscending {
                workBooking.startDate = dates![0]
                workBooking.endDate   = dates![1]
                return Translations().getTranslation(text: "Thank you for the dates.<br>")
            }
            return baseErrormessage + Translations().getTranslation(text: workflows[askedQuestion].negativeAnswer ?? "")
            
        case "positive-hasChildren":
            workBooking.numberOfChildren = 1
            return Translations().getTranslation(text: workflows[askedQuestion].positiveAnswer ?? "")
        case "negative-hasChildren":
            workBooking.numberOfChildren = 0
            return Translations().getTranslation(text: workflows[askedQuestion].negativeAnswer ?? "")
            
        case "privateVisit":
            workBooking.guestType = "Private"
            return Translations().getTranslation(text: "We have noticed your visit as a private visit.<br>")
        case "businessVisit":
            workBooking.guestType = "Business"
            return Translations().getTranslation(text: "We have noticed your visit as a business visit.<br>")
            
        case "hasPhonenumber":
            let phoneNumberString: String = valueForPhone(text: text)
            workBooking.guest?.phonenumber = phoneNumberString
            return Translations().getTranslation(text: "Thank you for your phonenumber.<br>")
            
        case "positive-breakfast":
            workBooking.breakfast = true
            return Translations().getTranslation(text: "Breakfast is noticed.<br>")
        case "negative-breakfast":
            workBooking.breakfast = false
            return Translations().getTranslation(text: "It is noticed that you do not want to have breakfast.<br>")
            
        case "positive-parking":
            if workBooking.startDate != nil && workBooking.endDate != nil {
                if workBooking.bookParking(fromDate: (workBooking.startDate)!, toDate: (workBooking.endDate)!) {
                    return Translations().getTranslation(text: "Parking is noticed.<br>")
                }
                else {
                    return Translations().getTranslation(text: "We are sorry but we do not have a free parking place for you.<br>")
                }
            }
            return Translations().getTranslation(text: "Before we can book a parking place we need your arrival and departure dates.<br>")
        case "negative-parking":
            return Translations().getTranslation(text: "It is noticed that you do not need a parking place.<br>")
        
        case "number-answer":
            return Translations().getTranslation(text: "Thank you for the number<br>")
            
            // we expect a yes or something like that
        case "simple-positiv":
            if workBooking.finishBooking() {
                return "" // If the booking is finished we just return for the next question
            }
            return Translations().getTranslation(text: workflows[askedQuestion].negativeAnswer ?? "")
            
            // we expect a no or something like that
        case "simple-negativ":
            return Translations().getTranslation(text: "Thank you. We have noticed that you do not want to book.<br>You can close the window.<br>")
            
        case "room-price":
            return Booking.roomPrices() + "<br>"
        case "free-room":
            if workBooking.startDate != nil && workBooking.endDate != nil && workBooking.numberOfGuests == 0 {
                return Booking.freeRooms(fromDate: workBooking.startDate!, toDate: workBooking.endDate!, countPersons: Int(workBooking.numberOfGuests)) + "<br>" //+ getNextQuestion()
            }
            return Translations().getTranslation(text: "Please give us your visit dates and how many you are.<br>")
        default:
            break
        }
        
        return baseErrormessage
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

/*
    static func addValueToBooking(data: NSObject) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        if data is Guest {
            if workBooking == nil {
                workBooking = DatastoreController.shared.createNewEntityByName("Booking") as? Booking
            }
            workBooking.guest = (data as! Guest)

        }
    }
    */
    
    static func getNextQuestion() -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        // Loop through the workflow entries as defined in BaseData.plist
        for i in 0..<workflows.count {
            var workflow = workflows[i]
            if workflow.questionNumber < askedQuestion {
                continue
            }
            
            if askedQuestion < -1 {
                var text = Translations().getTranslation(text: workflow.englishText ?? "Undefined Text")
                workflow = workflows[i+1]
                text = text + Translations().getTranslation(text: (workflow.englishText ?? "Undefined Text"))
                askedQuestion = Int(workflow.questionNumber)
                return text
            }
             
            else {
                if workflow.checkAttributename?.count ?? 0 > 0 {
                    // Get the value from the workBooking object which is asked by the workflow question
                    /*
                    let validateValue = workBooking.value(forKeyPath: workflow.checkAttributename ?? "")
                    if workflow.checkFunction == "==" && workflow.checkValue != nil {
                        if String(describing: validateValue) == workflow.checkValue {
                            askedQuestion = Int(workflow.questionNumber)
                        }
                    }
                     */
                    // If the booking value is empty it is asked for
                    if !isValueCorrectFilled(booking: workBooking, workflow: workflow) {
                        askedQuestion = Int(workflow.questionNumber)
                        var newQuestion = Translations().getTranslation(text: workflow.englishText ?? "Undefined Text")
                        newQuestion = newQuestion.replacingOccurrences(of: "<Booking>", with: workBooking.toHTML())
                        return newQuestion
                    }
                }
            }
        }
        
        return Translations().getTranslation(text: workflows.last?.englishText ?? "We are sorry but we did not understand you.<br>")
    }
    
    
    static private func isValueCorrectFilled(booking: Booking, workflow: Workflow) -> Bool {
        var value = workBooking.value(forKeyPath: workflow.checkAttributename ?? "")
        
        if value == nil {
            return false
        }
        
        if value != nil && (workflow.checkFunction == nil || workflow.checkValue == nil || workflow.checkFunction?.count == 0 || workflow.checkValue?.count == 0) {
            return true // There is nothing to check
        }
        
        var compareFunction = workflow.checkFunction ?? ""
        var referenceAttributeName  = ""
        if compareFunction.contains(" ") &&  !compareFunction.contains("contains") {
            compareFunction = workflow.checkFunction?.after(first: " ") ?? ""
            referenceAttributeName = workflow.checkFunction?.before(first: " ") ?? ""
            if referenceAttributeName.count > 0 {
                if workBooking.value(forKeyPath: referenceAttributeName) is Int {
                    value = String(workBooking.value(forKeyPath: referenceAttributeName) as! Int)
                }
                else if workBooking.value(forKeyPath: referenceAttributeName) is String {
                    value = workBooking.value(forKeyPath: referenceAttributeName) as! String
                }
                else if workBooking.value(forKeyPath: referenceAttributeName) is Bool {
                    value = String(workBooking.value(forKeyPath: referenceAttributeName) as! Bool)
                }
            }
        }
        
        if value is Int {
            value = String(value as! Int)
        }
        else if value is Bool {
            value = String(value as! Bool)
        }
        
        let compareValue: String    = workflow.checkValue ?? ""
        
        switch compareFunction {
        case "":
            return false // the standard case
        case "<":
            if Int(value as! String) ?? 0 < Int(compareValue) ?? 0 {
                return true
            }
        case ">":
            if Int(value as! String) ?? 0 > Int(compareValue) ?? 0 {
                return true
            }
        case "=":
            if value as! String == compareValue {
                return true
            }
        case "!=":
            if value as! String != compareValue {
                return true
            }
        case "<=":
            if Int(value as! String) ?? 0 <= Int(compareValue) ?? 0 {
                return true
            }
        case ">=":
            if Int(value as! String) ?? 0 >= Int(compareValue) ?? 0 {
                return true
            }
        case "contains":
            let list: [String] = compareValue.components(separatedBy: ", ")
            if list.contains(value as! String) {
                return true
            }
        case "not contains":
            let list: [String] = compareValue.components(separatedBy: ", ")
            if !list.contains(value as! String) {
                return true
            }
        default:
            print("Unknown function: \(compareFunction)")
            return true
        }
        return false
    }
}

