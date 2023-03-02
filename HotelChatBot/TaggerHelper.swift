//
//  TaggerHelper.swift
//  HotelChatBot
//
//  Created by Jens Lünstedt on 02.03.23.
//

import Cocoa

class TaggerHelper: NSObject {

    /**
     we add a new text to the table
     */
    static func addTag(language: String, words: [String], tags: [String]) {
        #if DEBUG
                NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        if words.count != tags.count {
            print("ERROR we have \(words.count) words and \(tags.count) tags" )
            return
        }
        
        var sentence = ""
        for word in words {
            if sentence.count > 0 {
                sentence = sentence + ", "
            }
            sentence = sentence + "\"" + word + "\""
        }
        
        var wordTagging: Wordtaggingdefinitions? = DatastoreController.shared.entityByName("Wordtaggingdefinitions", key: "wordList", value: sentence as NSObject) as? Wordtaggingdefinitions
        if wordTagging != nil && wordTagging?.language == language {
            return
        }
        
        var taggings = ""
        for tag in tags {
            if taggings.count > 0 {
                taggings = taggings + ", "
            }
            taggings = taggings + "\"" + tag + "\""
        }
        
        wordTagging = DatastoreController.shared.createNewEntityByName("Wordtaggingdefinitions") as? Wordtaggingdefinitions
        wordTagging?.language = language
        wordTagging?.wordList = sentence
        wordTagging?.tagList  = taggings
        
        _ = DatastoreController.shared.saveToPersistentStore()
    }
    
    
    /**
      we look for the existing languages in the classifier table and create one file for each language
     */
    static func createMLFiles() {
        #if DEBUG
                NSLog("\(type(of: self)) \(#function)()")
        #endif

        let allTagger = DatastoreController.shared.allForEntity("Wordtaggingdefinitions") as? [Wordtaggingdefinitions] ?? []
        
        var languages: [String] = []
        
        // we first collect all existing languages
        for tagger in allTagger {
            if !languages.contains(tagger.language!) {
                languages.append(tagger.language!)
            }
        }
        
        for language in languages {
            createMLFiles(language: language)
        }
    }
    
    

    /**
     We write all the classifier data into two files, one for training and one for testing
     */
    private static func createMLFiles(language: String) {
        #if DEBUG
                NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        let desktopPath = (NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true) as [String]).first
        if desktopPath == nil { return }
        
        let taggerTrainingsFilename: String = desktopPath! + "/NewTaggerTrainingdata_" + language + ".json"
        let taggerTestsFilename:     String = desktopPath! + "/NewTaggerTestdata_" + language + ".json"

        let rowCount = DatastoreController.shared.rowCountForEntity(name: "Wordtaggingdefinitions")
        if rowCount == 0 { return } // nothing to do here
        
        let trainingsMax: Int = Int(Double(rowCount) * 0.75)
        
        var trainingNumberFoundArray: [Int] = []
        
        do {
            try "[\n".write(toFile: taggerTrainingsFilename, atomically: true, encoding: .utf8)
            try "[\n".write(toFile: taggerTestsFilename, atomically: true, encoding: .utf8)

            var firstRow: Bool = true
            var fileString: String! = ""

            if let trainingHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: taggerTrainingsFilename)) {
                trainingHandle.seekToEndOfFile() // moving pointer to the end
                
                // we find 75% random rows from the database and write them to the trainingsfile
                var randRowNum: Int!
                while trainingNumberFoundArray.count <= trainingsMax {
                    randRowNum = Int.random(in: 0..<rowCount)
                    
                    if trainingNumberFoundArray.contains(randRowNum) { continue } // If we already had the row number we search for another one
                    
                    trainingNumberFoundArray.append(randRowNum) // we remember the found row number
                    let taggings: Wordtaggingdefinitions? = DatastoreController.shared.entityByRownum(entityName: "Wordtaggingdefinitions", rownum: randRowNum) as? Wordtaggingdefinitions
                    if taggings == nil { return }
                    if taggings?.language != language { continue } // If the language is not correct we use the next one
                    
                    if !firstRow { // after the first row we separate the parts with a comma
                        trainingHandle.write(",".data(using: .utf8)!)
                    }
                    firstRow = false
                    fileString = "{\"tokens\": \"" + (taggings!.wordList ?? "") + "\", \"labels\": \"" + (taggings!.tagList ?? "") + "\"}\n"
                    trainingHandle.write(fileString.data(using: .utf8)!)
                }
                trainingHandle.write("]".data(using: .utf8)!)
                trainingHandle.closeFile() // closing the file
            }
                

            // we loop to all the rows and if we did not wrote it to the trainingsdata file we use it for the test data file
            if let testHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: taggerTestsFilename)) {
                testHandle.seekToEndOfFile() // moving pointer to the end
                firstRow = true
                for i in 0..<rowCount {
                    if !trainingNumberFoundArray.contains(i) {
                        let taggings: Wordtaggingdefinitions = DatastoreController.shared.entityByRownum(entityName: "Wordtaggingdefinitions", rownum: i) as! Wordtaggingdefinitions
                        if taggings.language != language { continue } // If the language is not correct we use the next one
                        
                        if !firstRow { // after the first row we separate the parts with a comma
                            testHandle.write(",".data(using: .utf8)!)
                        }
                        firstRow = false
                        fileString = "{\"tokens\": \"" + (taggings.wordList ?? "") + "\", \"labels\": \"" + (taggings.tagList ?? "") + "\"}\n"
                        testHandle.write(fileString.data(using: .utf8)!)
                    }
                }
                testHandle.write("]".data(using: .utf8)!)
                testHandle.closeFile() // closing the file
            }
        }
        catch {
            print("Could not write file: " + taggerTrainingsFilename)
            print("or")
            print("Could not write file: " + taggerTestsFilename)
        }
    }
}
