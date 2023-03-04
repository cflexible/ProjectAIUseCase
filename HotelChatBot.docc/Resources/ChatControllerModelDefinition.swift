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
    static let classifierVersion = "4"
    /// A variable to set the tagger model version when it is selected.
    static let taggerVersion     = "4"
    ...
