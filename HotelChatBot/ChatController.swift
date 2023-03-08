//
//  ChatController.swift
//  HotelChatBot
//
//  Created by Jens Lünstedt on 24.02.23.
//

import Cocoa
import CoreML
import NaturalLanguage

/** The ChatController class is the main function class of the application where the input of a hotel guest is analyzed.
 The most important thing is getting the questions to present to the guest which are dependend on the Booking
 object in which the data will be stored. Automaticcally dependend on open (unfilled) necessary attributes, the
 next question is selected.
*/
class ChatController: NSObject {
    /// The classifierModel holds the model for classifying the texts. It should use a language dependend model.
    static var classifierModel: NLModel?
    /// The taggerModel holds the model for tagging the text words. It should use a language dependend model.
    static var taggerModel: NLModel?

    /// A variable to set the classifier model version when it is selected.
    static let classifierVersion = "1"
    /// A variable to set the tagger model version when it is selected.
    static let taggerVersion     = "4"

    /// Variable to hold the sentences in from the text to analyse. The text is splitt with the . into sentences and each sentence is then analysed.
    static var taggingSentences:           [String] = []
    
    /// workBooking holds the DB object with which we save the guest information
    static var workBooking:   Booking = Booking.createBooking() // Here we initialize a booking object including a guest object
    
    /// In askedQuestion we memorize the actual presented question
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

    static let baseErrormessage = Translations().getTranslation(text: "We are sorry but I did not understand you.<br>")
    

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

        var text = text
        text = text.replacingOccurrences(of: "ü", with: "ue")
        text = text.replacingOccurrences(of: "ä", with: "ae")
        text = text.replacingOccurrences(of: "ö", with: "oe")
        text = text.replacingOccurrences(of: "Ü", with: "Ue")
        text = text.replacingOccurrences(of: "Ä", with: "Ae")
        text = text.replacingOccurrences(of: "Ö", with: "Oe")
        text = text.replacingOccurrences(of: "ß", with: "ss")
        // Split the text into sentences (this is actually simple but a fast way)
        let sentences = text.split(separator: ". ")
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

        var classifierLabel = classifierModel!.predictedLabel(for: text)
        // We remember the text
        ClassifierHelper.addText(language: currentLanguage, text: text, classifierString: classifierLabel)
        print("Found classifier: \(classifierLabel ?? "") for Question: \(askedQuestion) \(questionForAskedNumber(number: askedQuestion))")
        if ["hasEnglishDates", "hasGermanDates", "hasUSDates"].contains(classifierLabel) {
            classifierLabel = "hasDates"
        }
        
        if Utilities.getMailAddressFromText(text) != nil {
            return accessMail(text: text)
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
            return accessMail(text: text)

        case "numberOfGuests":
            let numberOfGuests = valueForNumbers(tagname: "number", text: text)
            workBooking.numberOfGuests = Int16(numberOfGuests)
            return bookRooms()
            
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

        case "payment":
            let paymenttypes: [String] = valueForTag(tagnames: ["cash", "card"], text: text)
            var paymentType: String?
            for type in paymenttypes {
                if paymentType != nil {
                    paymentType = paymentType ?? "" + " "
                }
                paymentType = paymentType ?? "" + type
            }
            if paymentType != nil {
                workBooking.paymentMethod = paymentType
                return Translations().getTranslation(text: "We have noticed you would like to pay \(paymentType ?? "unknown").<br>")
            }
            if text.contains("cash") {
                workBooking.paymentMethod = "cash"
                return Translations().getTranslation(text: "We have noticed you would like to pay cash.<br>")
            }
            if text.contains("card") {
                workBooking.paymentMethod = "credit card"
                return Translations().getTranslation(text: "We have noticed you would like to pay with credit card.<br>")
            }

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
            let foundValue = valueForNumbers(tagname: "number", text: text)
            if askedQuestion == 6 && foundValue != 0 {
                workBooking.numberOfGuests = Int16(foundValue)
                return bookRooms()
            }
            else if askedQuestion == 7 && foundValue != 0 {
                workBooking.numberOfChildren = Int16(foundValue)
                return Translations().getTranslation(text: "Ok, we noticed you have \(foundValue) children with you<br>")
            }
            return Translations().getTranslation(text: "Thank you for the number<br>")
            
            // we expect a yes or something like that
        case "simple-positive":
            if askedQuestion == 7 {
                workBooking.numberOfChildren = 0
                return Translations().getTranslation(text: workflows[askedQuestion].negativeAnswer ?? "")
            }
            else if askedQuestion == 8 {
                workBooking.breakfast = true
                return Translations().getTranslation(text: "Breakfast is noticed.<br>")
            }
            else if workBooking.finishBooking() {
                return "" // If the booking is finished we just return for the next question
            }
            return Translations().getTranslation(text: workflows[askedQuestion].negativeAnswer ?? "")
            
            // we expect a no or something like that
        case "simple-negative":
            if askedQuestion == 7 {
                workBooking.numberOfChildren = 0
                return Translations().getTranslation(text: workflows[askedQuestion].negativeAnswer ?? "")
            }
            else if askedQuestion == 8 {
                workBooking.breakfast = false
                return Translations().getTranslation(text: "It is noticed that you do not want to have breakfast.<br>")
            }
            return Translations().getTranslation(text: "Thank you. We have noticed that you do not want to book.<br>You can close the window.<br>")
            
        case "room-price":
            return Booking.roomPrices() + "<br>"
        case "free-room":
            if workBooking.startDate != nil && workBooking.endDate != nil && workBooking.numberOfGuests == 0 {
                return Booking.freeRoomsText(fromDate: workBooking.startDate!, toDate: workBooking.endDate!, countPersons: Int(workBooking.numberOfGuests)) + "<br>" //+ getNextQuestion()
            }
            return Translations().getTranslation(text: "Please give us your visit dates and how many you are.<br>")
        default:
            break
        }
        
        return baseErrormessage
    }
    
    
    static private func bookRooms() -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        if workBooking.startDate != nil && workBooking.endDate != nil && workBooking.numberOfGuests > 0 {
            let bookedRoomCount: Int = workBooking.bookRooms(fromDate: (workBooking.startDate)!, toDate: (workBooking.endDate)!, countPersons: Int(workBooking.numberOfGuests))
            if bookedRoomCount > 0 {
                var bookedRoomResult = Translations().getTranslation(text: "We have booked <bookedRoomCount> rooms for you.<br>")
                bookedRoomResult = bookedRoomResult.replacingOccurrences(of: "<bookedRoomCount>", with: String(bookedRoomCount))
                return bookedRoomResult
            }
            else {
                return Translations().getTranslation(text: "We are sorry but we have not enough free rooms available.<br>")
            }
        }
        return Translations().getTranslation(text: "We are sorry but we could not understand how many you are. Please try it again.<br>")
    }
    
    
    static private func accessMail(text: String) -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        let mail: String = Utilities.getMailAddressFromText(text) ?? ""
        
        if workBooking.guest != nil && workBooking.guest?.firstname?.count ?? 0 > 0 && workBooking.guest?.lastname?.count ?? 0 > 0 && mail.count > 0 {
            workBooking.guest?.mailaddress = mail
            return Translations().getTranslation(text: "Thank you for your mail address.<br>")
        }
        else if mail.count > 0 && workBooking.guest == nil {
            let guestDB: Guest? = DatastoreController.shared.entityByName("Guest", key: "mailaddress", value: mail as NSObject) as? Guest
            if guestDB != nil {
                workBooking.guest = guestDB!
                let firstName: String = workBooking.guest?.firstname ?? ""
                let lastName:  String = workBooking.guest?.lastname  ?? ""
                var positiveReturn = Translations().getTranslation(text: workflows[askedQuestion + 1].positiveAnswer ?? "")
                positiveReturn = positiveReturn.replacingOccurrences(of: "<firstName>", with: firstName)
                positiveReturn = positiveReturn.replacingOccurrences(of: "<lastName>", with: lastName)
                return positiveReturn
            }
        }
        else if mail.count == 0 {
            return baseErrormessage
        }
        if workBooking.guest != nil {
            return Translations().getTranslation(text: "Thank you for your information.<br>") // We should not come to here
        }
        else {
            return Translations().getTranslation(text: "I'm sorry but I could not find you in our System. Please give us your names. Thanks.<br>")
        }
    }
    
    
    /**
     This function is for analysing the word of the text and uses the most appropriate result.
     */
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

    
    /**
     This function is for analysing the word of the text and uses the most appropriate result.
     */
    static func valueForTag(tagnames: [String], text: String) -> [String] {
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
                
                if tagnames.contains(tag.rawValue) {
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
        var returnStrings: [String] = []
        for value in foundValues {
            returnStrings.append(String(value.text))
        }
        return returnStrings
    }

    
    /**
     In this function we know we have names in the text and now we want to know which word of a text is a firstname and which one is a lastname.
     Later on it should also be possible to get the gender from the firstname.
     */
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
                             options: [.omitWhitespace, .omitPunctuation]) { tag, tokenRange in
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


    /**
        This function is just for test purposes
     */
    private static func questionForAskedNumber(number: Int) -> String {
        for workflow in workflows {
            if workflow.questionNumber == number {
                return workflow.englishText ?? "unknown"
            }
        }
        return "unknown"
    }
    /**
     This function analyses the text and tries to figgure out which words include a from date and which one include a to date.
     */
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


    /**
     This function is for analysing numbers which can also be words. Therefore the words must be analyzed to get the number.
     */
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
        var manualFoundValues:             [Int]  = []

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
                else {
                    // From unknown reason this does not work properly so we try it by ourself
                    let testVal = Int(String(text[tokenRange]).wordToIntegerString(language: languageRecog.dominantLanguage?.rawValue ?? "") ?? "") ?? 0
                    if testVal > 0 {
                        manualFoundValues.append(testVal)
                    }
                }
            }
            return true
        }
        TaggerHelper.addTag(language: currentLanguage, words: newLearnTaggingWordStrings, tags: newLearnTaggingStrings)
        foundValues.sort(by: { $0.hypotheses > $1.hypotheses })
        if foundValues.count == 0 && manualFoundValues.count > 0 {
            return manualFoundValues[0]
        }
        return Int(foundValues.first?.text.wordToIntegerString(language: languageRecog.dominantLanguage?.rawValue ?? "") ?? "") ?? 0
    }

    
    /**
     In this function we know that there is a phone number in the text (sentence) but it is splitt into peaces. Therefore the tagger is used to get the single peaces and they are put together to one number.
     */
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

    
    /**
     This is the central function of the class. Here we look at the steps of the workflow and check if the values we want to have in our booking object are allready given by the guest.
     Otherwise the guest will asked for the next open information. At the end, when the booking information is complete the summary is presented to the user. But in this class only the texts
     are created. For the text creation also the Translation class is used.
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

