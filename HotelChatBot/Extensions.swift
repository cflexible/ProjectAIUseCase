//
//  Extensions.swift
//  HotelChatBot
//
//  Created by Jens Lünstedt on 27.02.23.
//

import Foundation

/**
 Useful extensions for String
 */
public extension String {
    /**
        In this function we return a part of the string if it maches the given regex. We use this e.g. to extract an eMail from a text.
     */
    func matching(regex: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: regex)
        let results = regex.matches(in: self, range: NSRange(startIndex..., in: self))
        return results.map { String(self[Range($0.range, in: self)!]) }
    }

    /**
     This method gives us a concrete number for a word. we use this to get number from word like first, second or ordinals like 1st.
     A String is returned because if the transformation was not able the given String can be used for other editing.
     The transformation is language dependend. That is the reason for the parameter.
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
        
        var resultString: String? = self
        if resultNumber != nil {
            resultString = String(resultNumber!)
        }
        if resultNumber == nil {
            if translateNumberWords(word: self) != nil {
                resultString = String(translateNumberWords(word: self) ?? 0)
            }
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
    
    
    private func translateNumberWords(word: String) -> Int? {
        switch word.lowercased() {
        case "alone":
            return 1
        case "1":
            return 1
        case "one":
            return 1
        case "two":
            return 2
        case "three":
            return 3
        case "four":
            return 4
        case "five":
            return 5
        case "six":
            return 6
        case "seven":
            return 7
        case "eight":
            return 8
        case "nine":
            return 9
        case "ten":
            return 10
        case "eleven":
            return 11
        case "twelve":
            return 12
        case "thirteen":
            return 13
        case "2":
            return 2
        case "3":
            return 3
        case "4":
            return 4
        case "5":
            return 5
        case "6":
            return 6
        case "7":
            return 7
        case "8":
            return 8
        case "9":
            return 9
        case "10":
            return 10
        case "11":
            return 11
        case "12":
            return 12
        case "13":
            return 13
        case "first":
            return 1
        case "second":
            return 2
        case "third":
            return 3
        case "fourth":
            return 4
        case "fifth":
            return 5
        case "sixth":
            return 6
        case "seventh":
            return 7
        case "eighth":
            return 8
        case "ninth":
            return 9
        case "tenth":
            return 10
        case "eleventh":
            return 11
        case "twelvth":
            return 12

        default:
            return nil
        }
    }
}


