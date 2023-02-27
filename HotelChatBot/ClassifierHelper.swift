//
//  ClassifierHelper.swift
//  HotelChatBot
//
//  Created by Jens Lünstedt on 27.02.23.
//

import Cocoa

class ClassifierHelper: NSObject {
    
    /**
     we add a new text to the table
     */
    static func addText(text: String, classifierString: String?) {
#if DEBUG
        NSLog("\(type(of: self)) \(#function)()")
#endif
        
        var classifier: Classifierdefinitions? = DatastoreController.shared.entityByName("Classifierdefinitions", key: "text", value: text as NSObject) as? Classifierdefinitions
        if classifier != nil {
            return
        }
        
        classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = text
        classifier?.theClassifier = classifierString ?? "other"
        
        _ = DatastoreController.shared.saveToPersistentStore()
    }
    
    
    /**
     We write all the classifier data into two files, one for training and one for testing
     */
    static func createMLFiles() {
#if DEBUG
        NSLog("\(type(of: self)) \(#function)()")
#endif
        
        let desktopPath = (NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true) as [String]).first
        if desktopPath == nil { return }
        let classifierTrainingsFilename: String = desktopPath! + "/NewClassifierTrainingdata.json"
        let classifierTestsFilename:     String = desktopPath! + "/NewClassifierTestdata.json"
        
        let rowCount = DatastoreController.shared.rowCountForEntity(name: "Classifierdefinitions")
        if rowCount == 0 { return } // nothing to do here
        
        let trainingsMax: Int = Int(Double(rowCount) * 0.75)
        
        var trainingNumberFoundArray: [Int] = []
        
        do {
            try "[\n".write(toFile: classifierTrainingsFilename, atomically: true, encoding: .utf8)
            try "[\n".write(toFile: classifierTestsFilename, atomically: true, encoding: .utf8)

            var firstRow: Bool = true
            var fileString: String! = ""

            if let trainingHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: classifierTrainingsFilename)) {
                trainingHandle.seekToEndOfFile() // moving pointer to the end
                
                // we find 75% random rows from the database and write them to the trainingsfile
                var randRowNum: Int!
                while trainingNumberFoundArray.count <= trainingsMax {
                    randRowNum = Int.random(in: 0..<rowCount)
                    
                    if trainingNumberFoundArray.contains(randRowNum) { continue } // If we already had the row number we search for another one
                    
                    trainingNumberFoundArray.append(randRowNum) // we remember the found row number
                    let classifier: Classifierdefinitions? = DatastoreController.shared.entityByRownum(entityName: "Classifierdefinitions", rownum: randRowNum) as? Classifierdefinitions
                    if classifier == nil { return }
                    
                    if !firstRow { // after the first row we separate the parts with a comma
                        trainingHandle.write(",".data(using: .utf8)!)
                    }
                    firstRow = false
                    fileString = "{\"text\": \"" + (classifier!.text ?? "") + "\", \"label\": \"" + (classifier!.theClassifier ?? "") + "\"}\n"
                    trainingHandle.write(fileString.data(using: .utf8)!)
                }
                trainingHandle.write("]".data(using: .utf8)!)
                trainingHandle.closeFile() // closing the file
            }
                

            // we loop to all the rows and if we did not wrote it to the trainingsdata file we use it for the test data file
            if let testHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: classifierTestsFilename)) {
                testHandle.seekToEndOfFile() // moving pointer to the end
                firstRow = true
                for i in 0..<rowCount {
                    if !trainingNumberFoundArray.contains(i) {
                        let classifier: Classifierdefinitions = DatastoreController.shared.entityByRownum(entityName: "Classifierdefinitions", rownum: i) as! Classifierdefinitions
                        
                        if !firstRow { // after the first row we separate the parts with a comma
                            testHandle.write(",".data(using: .utf8)!)
                        }
                        firstRow = false
                        fileString = "{\"text\": \"" + (classifier.text ?? "") + "\", \"label\": \"" + (classifier.theClassifier ?? "") + "\"}\n"
                        testHandle.write(fileString.data(using: .utf8)!)
                    }
                }
                testHandle.write("]".data(using: .utf8)!)
                testHandle.closeFile() // closing the file
            }
        }
        catch {
            print("Could not write file: " + classifierTrainingsFilename)
            print("or")
            print("Could not write file: " + classifierTestsFilename)
        }
    }
    
    static func loadTrainingsdataOnce() {
        var classifier: Classifierdefinitions? = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "My first name is David and my last name is Johnson."
        classifier?.theClassifier = "hasNames"
        _ = DatastoreController.shared.saveToPersistentStore()

        classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I am proud of my first name, Emily, and my last name, Martinez."
        classifier?.theClassifier  = "hasNames"
        _ = DatastoreController.shared.saveToPersistentStore()

        classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "My first name is Sarah and my last name is Davis."
        classifier?.theClassifier  = "hasNames"
        _ = DatastoreController.shared.saveToPersistentStore()

        classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "My last name is Nguyen, but my first name is a bit difficult to pronounce."
        classifier?.theClassifier  = "hasNames"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "My first name is Alex and my last name is Brown."
        classifier?.theClassifier  = "hasNames"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I go by my middle name, Marie, instead of my first name, which is Rebecca, and my last name is Hernandez."
        classifier?.theClassifier  = "hasNames"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "My first name is Jack and my last name is Smith, but I prefer to be called by my nickname, Jax."
        classifier?.theClassifier  = "hasNames"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "My first name is Sophia and my last name is Lee, and I'm proud of my heritage."
        classifier?.theClassifier  = "hasNames"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "My first name is Michael and my last name is Johnson, but everyone calls me Mike."
        classifier?.theClassifier  = "hasNames"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "My first name is Lauren and my last name is Thompson, and I'm a proud member of the Thompson family."
        classifier?.theClassifier  = "hasNames"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "Hello, I, am Lauren Thompson"
        classifier?.theClassifier  = "hasNames"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "Please email me at jane.doe@example.com if you have any questions."
        classifier?.theClassifier  = "hasMailaddress"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "My email address is john.smith@gmail.com if you want to get in touch with me."
        classifier?.theClassifier  = "hasMailaddress"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "You can reach me at samuel.johnson@yahoo.com for more information."
        classifier?.theClassifier  = "hasMailaddress"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "The email I received from jennifer.lee@hotmail.com was very helpful."
        classifier?.theClassifier  = "hasMailaddress"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "Please send your resume to career.opportunities@companyname.com."
        classifier?.theClassifier  = "hasMailaddress"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "The email I sent to support@techcompany.com bounced back."
        classifier?.theClassifier  = "hasMailaddress"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "We can discuss the details over email at alexander.brown@example.com."
        classifier?.theClassifier  = "hasMailaddress"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "You can contact me at roberta.nguyen@domainname.org for further inquiries."
        classifier?.theClassifier  = "hasMailaddress"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "The email I received last night from max.wilson@companyname.net contained important information."
        classifier?.theClassifier  = "hasMailaddress"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "Please send your payment to billing@mycompany.com as soon as possible."
        classifier?.theClassifier  = "hasMailaddress"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "My phone number is +44 7911 123456."
        classifier?.theClassifier  = "hasPhonenumber"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "Please call me at (555) 555-1212"
        classifier?.theClassifier  = "hasPhonenumber"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I can be reached at +49 123 456789"
        classifier?.theClassifier  = "hasPhonenumber"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "If you have any questions, you can reach us at +44 1234 567890."
        classifier?.theClassifier  = "hasPhonenumber"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "The phone number for customer service is (800) 123-4567."
        classifier?.theClassifier  = "hasPhonenumber"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "You can contact me at +49 30 1234567."
        classifier?.theClassifier  = "hasPhonenumber"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "The phone number for the hotel is +44 20 1234 5678."
        classifier?.theClassifier  = "hasPhonenumber"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "Please call us at (555) 123-4567."
        classifier?.theClassifier  = "hasPhonenumber"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "The number to call for support is +49 800 1234567."
        classifier?.theClassifier  = "hasPhonenumber"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "If you have any questions, you can contact us at +44 123 456 7890."
        classifier?.theClassifier  = "hasPhonenumber"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "Yes, I would like to have breakfast included in my booking."
        classifier?.theClassifier  = "positive-breakfast"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "No, I won't need breakfast during my stay."
        classifier?.theClassifier  = "negative-breakfast"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I would like to have breakfast on the first morning of my stay."
        classifier?.theClassifier  = "positive-breakfast"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I prefer to have breakfast outside the hotel."
        classifier?.theClassifier  = "negative-breakfast"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I would like to have breakfast served in my room every morning."
        classifier?.theClassifier  = "positive-breakfast"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I don't usually eat breakfast, so I won't need it during my stay."
        classifier?.theClassifier  = "negative-breakfast"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I would like to have breakfast at the hotel's restaurant."
        classifier?.theClassifier  = "positive-breakfast"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I have specific dietary restrictions, so I won't be having breakfast at the hotel."
        classifier?.theClassifier  = "negative-breakfast"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I would like to have breakfast included in my booking, but only on certain days of my stay."
        classifier?.theClassifier  = "positive-breakfast"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I'm on a tight schedule, so I won't have time for breakfast during my stay."
        classifier?.theClassifier  = "negative-breakfast"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "It will be just me staying in the room."
        classifier?.theClassifier  = "numberOfGuests"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "There will be two of us staying in the room."
        classifier?.theClassifier  = "numberOfGuests"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I am traveling with my family, so there will be four of us staying in the room."
        classifier?.theClassifier  = "numberOfGuests"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I am part of a group of ten, so we'll need five rooms in total."
        classifier?.theClassifier  = "numberOfGuests"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I am traveling with my partner, but we will need separate rooms."
        classifier?.theClassifier  = "numberOfGuests"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I am traveling with my partner and our two children, so there will be four of us staying in the room."
        classifier?.theClassifier  = "numberOfGuests"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "It will be three of us staying in the room - myself, my partner, and a friend."
        classifier?.theClassifier  = "numberOfGuests"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I am part of a business trip and we need three rooms for three people."
        classifier?.theClassifier  = "numberOfGuests"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I am traveling with a friend and we would like two separate rooms."
        classifier?.theClassifier  = "numberOfGuests"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I am traveling with my colleagues and we need four rooms for a total of eight people."
        classifier?.theClassifier  = "numberOfGuests"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I am traveling with my partner and our two children, so there will be four of us staying in the room."
        classifier?.theClassifier  = "positive-hasChildren"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I am traveling with my family, so there will be four of us staying in the room."
        classifier?.theClassifier  = "positive-hasChildren"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "No, we do not have children."
        classifier?.theClassifier  = "negative-hasChildren"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "There are no children with us."
        classifier?.theClassifier  = "negative-hasChildren"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I would like to stay from 5.4. until 7.4."
        classifier?.theClassifier  = "hasDates"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I'd like to book a room from June 15th to June 20th"
        classifier?.theClassifier  = "hasDates"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I'd like to book a room from 15/06 to 20/06"
        classifier?.theClassifier  = "hasDates"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I'd like to book a room from 2023-08-01 to June 20th"
        classifier?.theClassifier  = "hasDates"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I'd like to book a room from 07.09.23 to 12.09.23."
        classifier?.theClassifier  = "hasDates"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I'd like to book a room from 2023-10-15 to 2023-10-20"
        classifier?.theClassifier  = "hasDates"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I'd like to book a room from 08/21 to 08/26"
        classifier?.theClassifier  = "hasDates"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I'd like to book a room from 27.12.23 to 01.01.24."
        classifier?.theClassifier  = "hasDates"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I'd like to book a room from November 2nd to November 7th"
        classifier?.theClassifier  = "hasDates"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I'd like to book a room from 2023-05-12 to 2023-05-16"
        classifier?.theClassifier  = "hasDates"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I'd like to book a room from 06/01/23 to 06/05/23"
        classifier?.theClassifier  = "hasDates"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I would like to stay from 5th April until 7th April"
        classifier?.theClassifier  = "hasDates"
        _ = DatastoreController.shared.saveToPersistentStore()

    classifier = DatastoreController.shared.createNewEntityByName("Classifierdefinitions") as? Classifierdefinitions
        classifier?.text = "I would like to stay from 3.5. until 8.5"
        classifier?.theClassifier  = "hasDates"
        _ = DatastoreController.shared.saveToPersistentStore()

    }
}
