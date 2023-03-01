//
//  Extensions.swift
//  HotelChatBot
//
//  Created by Jens Lünstedt on 27.02.23.
//

import Foundation


public extension String {
    /**
        In this function we return a part of the string if it maches the given regex. We use this e.g. to extract an eMail from a text.
     */
    func matching(regex: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: regex)
        let results = regex.matches(in: self, range: NSRange(startIndex..., in: self))
        return results.map { String(self[Range($0.range, in: self)!]) }
    }
}


/**
    This method gives us a concrete number for a word. we use this to get number from word like first, second or ordinals like 1st
 */
public extension String {
    /**
        Transformation of a string if it is a named integer like first to a real Int which we can use easier
     */
    func wordToIntegerString(language: String) -> String? {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        let locale = Locale(identifier: language)
        
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = locale

        var resultNumber: Int? = nil
        // we test if the string is a normal number
        numberFormatter.numberStyle = .none
        resultNumber = numberFormatter.number(from: self) as? Int
        // if it was not a normal number, was it a word?
        if resultNumber == nil {
            numberFormatter.numberStyle = .spellOut
            resultNumber = numberFormatter.number(from: self) as? Int
        }
        // if it is still unknown it is perhaps an ordinal
        if resultNumber == nil {
            numberFormatter.numberStyle = .ordinal
            resultNumber = numberFormatter.number(from: self) as? Int
        }
        
        var resultString = self
        if resultNumber != nil {
            resultString = String(resultNumber!)
        }
        return resultString
    }
    
    
    /**
        Of a concatinated string we would like to have the part before a delimiter
     */
    func before(first delimiter: Character) -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        if let index = firstIndex(of: delimiter) {
            let before = prefix(upTo: index)
            return String(before)
        }
        return ""
    }
    
    
    /**
        Of a concatinated string we would like to have the part after a delimiter
     */
    func after(first delimiter: Character) -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        if let index = firstIndex(of: delimiter) {
            let after = suffix(from: index).dropFirst()
            return String(after)
        }
        return ""
    }
}


