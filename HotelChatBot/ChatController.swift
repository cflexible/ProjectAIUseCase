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

    static var actStep: Int = -1
    static var newLearnTaggingWordString:  String = ""
    static var newLearnTaggingString:      String = ""
    static var taggingSentences:           [String] = []
    
    static var workBooking:   Booking?
    static var wantsBooking:  Bool?
    static var askedQuestion: Int = 0
    
    // We read all the workflows once from the database and sort them by questionNumber
    static var workflows: [Workflow] = DatastoreController.shared.allForEntity("Workflow", with: nil, orderBy: [NSSortDescriptor(key: "questionNumber", ascending: true)]) as! [Workflow]
    
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
    
    static private func initModels() {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

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
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

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
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

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
        fromDayString   = fromDayString.wordToIntegerString(language: languageRecog.dominantLanguage?.rawValue ?? "")   ?? ""
        toDayString     = toDayString.wordToIntegerString(language: languageRecog.dominantLanguage?.rawValue ?? "")     ?? ""
        
        let fromDate: Date? = Utilities.dateFromComponentStrings(day: fromDayString, month: fromMonthString, year: fromYearString, language: languageRecog.dominantLanguage?.rawValue)
        let toDate:   Date? = Utilities.dateFromComponentStrings(day: toDayString, month: toMonthString, year: toYearString, language: languageRecog.dominantLanguage?.rawValue)
        
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
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        // Initialize LanguageRecognizer
        let languageRecog = NLLanguageRecognizer()
        // find the dominant language
        languageRecog.processString(text)
        print("Dominant language is: \(languageRecog.dominantLanguage?.rawValue ?? "")")

        initModels()
        
        var guest: Guest? = ChatController.workBooking?.guest
        
        struct ValueHypotheseses {
            var text: String
            var hypotheses: Double
        }
        
        var testValue = workBooking?.value(forKeyPath: "guest")
        testValue     = workBooking?.value(forKeyPath: "startDate")
        
        if classifierModel != nil && taggerModel != nil {
            var classifierLabel = classifierModel!.predictedLabel(for: text)
            // We remember the text
            ClassifierHelper.addText(text: text, classifierString: classifierLabel)
            print("Found classifier: \(classifierLabel ?? "")")
            if ["hasEnglishDates", "hasGermanDates", "hasUSDates"].contains(classifierLabel) {
                classifierLabel = "hasDates"
            }
            switch classifierLabel {
                
            case "hasNames":
                if workBooking?.guest?.firstname?.count ?? 0 > 0 && workBooking?.guest?.lastname?.count ?? 0 > 0 {
                    return "We are sorry but I did not understand you right.<br>" + getNextQuestion()
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
                return "We are sorry but I did not understand you right.<br>" + getNextQuestion()
                
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
                    return String("I'm sorry but I could not understand you.<br>" + getNextQuestion())
                }
                if workBooking?.guest != nil {
                    let firstName: String = workBooking?.guest?.firstname ?? ""
                    let lastName:  String = workBooking?.guest?.lastname  ?? ""
                    return "Hallo " + "<strong>" + firstName + "</strong>" + " " + "<strong>" + lastName + "</strong>" + ". Welcome to our hotel. <br>" + getNextQuestion()
                }
                else {
                    return "I'm sorry but I could not find you in our System. Please give us your names. Thanks.<br>" + getNextQuestion()
                }

            case "numberOfGuests":
                let numberOfGuests = valueForNumbers(tagname: "number", text: text)
                if workBooking?.startDate != nil && workBooking?.endDate != nil && numberOfGuests > 0 {
                    let bookedRoomCount: Int = workBooking?.bookRooms(fromDate: (workBooking?.startDate)!, toDate: (workBooking?.endDate)!, countPersons: numberOfGuests) ?? 0
                    if bookedRoomCount > 0 {
                        return "We have booked \(String(bookedRoomCount)) rooms for you.<br>" + getNextQuestion()
                    }
                    else {
                        return "We are sorry but we have not enough free rooms available.<br>" + getNextQuestion()
                    }
                }
                return "We are sorry but we could not understand how many you are. Please try it again.<br>" + getNextQuestion()
                
            case "hasDates":
                let dates: [Date]? = valueForDates(text: text, language: languageRecog.dominantLanguage?.rawValue ?? "en")
                if workBooking != nil && dates?.count == 2 && dates?[0].compare((dates?[1])!) == .orderedAscending {
                    workBooking?.startDate = dates![0]
                    workBooking?.endDate   = dates![1]
                    return "Thank you for the dates.<br>" + getNextQuestion()
                }
                return "we are sorry but we could not recognize the dates. We prefere a format in yyyy-mm-dd.<br>" + getNextQuestion()
                
            case "positive-hasChildren":
                workBooking?.numberOfChildren = 1
                return "We have noticed a child.<br>" + getNextQuestion()
            case "negative-hasChildren":
                workBooking?.numberOfChildren = 0
                return "We have noticed no children.<br>" + getNextQuestion()
                
            case "privateVisit":
                workBooking?.guestType = "Private"
                return "We have noticed your visit as a private visit.<br>" + getNextQuestion()
            case "businessVisit":
                workBooking?.guestType = "Business"
                return "We have noticed your visit as a business visit.<br>" + getNextQuestion()
                
            case "hasPhonenumber":
                let phoneNumberString: String = valueForPhone(text: text)
                workBooking?.guest?.phonenumber = phoneNumberString
                return "Thank you for your phonenumber.<br>" + getNextQuestion()
                
            case "positive-breakfast":
                workBooking?.breakfast = true
                return "Breakfast is noticed.<br>" + getNextQuestion()
            case "negative-breakfast":
                workBooking?.breakfast = false
                return "It is noticed that you do not want to have breakfast.<br>" + getNextQuestion()
                
            case "positive-parking":
                if workBooking?.startDate != nil && workBooking?.endDate != nil {
                    if workBooking?.bookParking(fromDate: (workBooking?.startDate)!, toDate: (workBooking?.endDate)!) ?? false {
                        return "Parking is noticed.<br>" + getNextQuestion()
                    }
                    else {
                        return "We are sorry but we do not have a free parking place for you.<br>" + getNextQuestion()
                    }
                }
                return "Before we can book a parking place we need your arrival and departure dates.<br>" + getNextQuestion()
            case "negative-parking":
                return "It is noticed that you do not need a parking place.<br>" + getNextQuestion()
            
            case "number-answer":
                return "Thank you<br>" + getNextQuestion()
                
            case "room-price":
                return Booking.roomPrices() + "<br>" + getNextQuestion()
            case "free-room":
                if workBooking?.startDate != nil && workBooking?.endDate != nil && workBooking?.numberOfGuests != nil {
                    return Booking.freeRooms(fromDate: workBooking!.startDate!, toDate: workBooking!.endDate!, countPersons: Int(workBooking!.numberOfGuests)) + "<br>" + getNextQuestion()
                }
                return "Please give us your visit dates and how many you are.<br>" + getNextQuestion()
            default:
                break
            }
        }
        else {
            return String("I'm sorry but I miss a NLP model, please ask the developer.")
        }
        
        writeNewTraingsdataToFile()
        return String("I'm sorry but I could not understand you.<br>" + getNextQuestion())
    }
    
    
    /**
        We have a new trainings sentence and we remember it for generating a file later
     */
    static func addTraingsdata(classifierText: String!, taggingWords: String, taggingTags: String) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        if classifierText.isEmpty || taggingWords.isEmpty || taggingTags.isEmpty {
            return
        }
        taggingSentences.append("{\n    \"tokens\":[" + taggingWords + "],\n    \"labels\": [" + taggingTags + "]\n},\n")
    }
    
    
    /**
        Wir schreiben zwei Dateien mit zukünftigen Trainingsdaten als Basis
     */
    static func writeNewTraingsdataToFile() {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        let desktopPath = (NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true) as [String]).first
        if desktopPath == nil { return }

        let taggerFilename: String = desktopPath! + "/NewTaggerTrainingdata.json"
        if let trainingHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: taggerFilename)) {
            trainingHandle.seekToEndOfFile() // moving pointer to the end

            for theString in taggingSentences {
                trainingHandle.write(theString.data(using: .utf8)!)
            }
            trainingHandle.closeFile() // closing the file
        }
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

        let test = workBooking?.bookingComplete()

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
        return "I'm sorry but I did not understand you."
/*
        if workBooking == nil {
            askedQuestion = 0
            return "Please give me your firstname and lastname or your eMail address when you have already been a guest at our hotel."
        }
        if workBooking?.guest == nil {
            askedQuestion = 1
            return "Please name me your firstname and your lastname or your mail address if you don't stay the first time at our hotel, thanks."
        }
        if workBooking?.guest?.firstname == nil  {
            askedQuestion = 2
            return "Please name me your firstname and your lastname, thanks."
        }
        if workBooking?.startDate == nil && workBooking?.endDate == nil {
            askedQuestion = 3
            return "From when to when would you like to stay?"
        }
        if workBooking?.startDate == nil {
            askedQuestion = 4
            return "When will you arrive?"
        }
        if workBooking?.endDate == nil {
            askedQuestion = 5
            return "When will you leave?"
        }
        if workBooking?.numberOfGuests == nil || workBooking?.numberOfGuests == 0 {
            askedQuestion = 6
            return "How many persons want to overnight?"
        }
        if workBooking?.numberOfChildren == nil && workBooking?.numberOfGuests ?? 0 > 2 {
            askedQuestion = 7
            return "How many children are with you?"
        }
        if workBooking?.breakfast == nil {
            askedQuestion = 8
            return "Do you like to have breakfast in the mornings?"
        }
        if workBooking?.guestType == nil && (workBooking?.numberOfChildren == nil || workBooking?.numberOfChildren == 0) {
            askedQuestion = 9
            return "Is this a private or business visit?"
        }
        if workBooking?.paymentMethod == nil {
            askedQuestion = 10
            return "How do you like to pay (credit card or cash)?"
        }
        if workBooking?.parkings == nil {
            askedQuestion = 11
            return "Do you need a parking place?"
        }
        if workBooking?.guest?.phonenumber == nil {
            askedQuestion = 12
            return "Please give us your phonenumber where we can reach you if we have questions."
        }
        if workBooking?.guest?.mailaddress == nil {
            askedQuestion = 13
            return "Please give me your mail address where we can send the confirmation mail."
        }
        else if workBooking?.state == nil {
            askedQuestion = 14
            return "The booking is complete. Please verify your values and confirm them with yes, otherwise no.<br>" + (workBooking?.toHTML() ?? "")
        }
        else if workBooking?.state == "booked" {
            askedQuestion = 15
            return "Thank you for your booking. We send you a confirmation mail. Good bye."
        }
        else {
            askedQuestion = 16
            return "We are sorry but we did not understand you."
        }
 */
    }
    
}

