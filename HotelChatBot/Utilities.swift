//
//  Utilities.swift
//  Some old helper functions. Just a few are used.
//
//  Created by Jens Lünstedt on 28.11.20.
//

import Foundation
import AppKit

class Utilities: NSObject {

    static let storyBoard: NSStoryboard = NSStoryboard.init(name:"Main", bundle:nil)
    static let tempValueFormatter = NumberFormatter()
    static let humValueFormatter  = NumberFormatter()

    static func tempFormatter() -> NumberFormatter {
        tempValueFormatter.numberStyle = .decimal
        tempValueFormatter.locale      = Locale.current
        tempValueFormatter.maximumFractionDigits = 1
        tempValueFormatter.minimumFractionDigits = 1

        return tempValueFormatter
    }
    
    static func humFormatter() -> NumberFormatter {
        humValueFormatter.numberStyle = .decimal
        humValueFormatter.locale      = Locale.current
        humValueFormatter.maximumFractionDigits = 1
        humValueFormatter.minimumFractionDigits = 1

        return humValueFormatter
    }
    
    class func getDefaultCountry()->String {
        let localeComponents = NSLocale.current.identifier.components(separatedBy: "_")
        var region:String = ""
        if localeComponents.count == 2 {
            region = localeComponents[1]
        }
        
        if region == "DE" {
            return NSLocalizedString("Germany", comment: "")
        }
        else if region == "CH" {
            return NSLocalizedString("Switzerland", comment:"")
        }
        else if region == "AT" {
            return NSLocalizedString("Austria", comment:"")
        }
        else if region == "GB" {
            return NSLocalizedString("Great Britain", comment:"")
        }
        else if region == "IE" {
            return NSLocalizedString("Ireland", comment: "")
        }
        else {
            return ""
        }
    }
    
    
    class func getCountry()->String {
        let localeComponents = NSLocale.current.identifier.components(separatedBy: "_")
        var region:String = ""
        if localeComponents.count == 2 {
            region = localeComponents[1]
        }
        
        return region
    }
    

    class func getLanguage()->String {
        let localeComponents = NSLocale.current.identifier.components(separatedBy: "_")
        //var region:String    = ""
        var language: String = ""
        if localeComponents.count == 2 {
            language = localeComponents[0].uppercased()
        //    region   = localeComponents[1].uppercased()
        }
        return language
    }
    
    
    
    class func getAnonymUserID()->String {
        // We have no user ID so for having an ID who has changed a value we use the last part of the directory of the App
        var path = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
        var components = path.components(separatedBy: "/")
        if components.count > 2 {
            path = components[components.count - 2]
            components = path.components(separatedBy: "-")
            if components.count >= 1 {
                path = components[components.count-1]
            }
        }
        return path
    }
    

    class func convertSpecialCharacters(_ string: String) -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        var newString = string
        let char_dictionary = [
            "&amp;" : "&",
            "&lt;" : "<",
            "&gt;" : ">",
            "&quot;" : "\"",
            "&apos;" : "'"
        ];
        for (escaped_char, unescaped_char) in char_dictionary {
            newString = newString.replacingOccurrences(of: unescaped_char, with: escaped_char, options: NSString.CompareOptions.literal, range: string.startIndex..<string.endIndex)
        }
        return newString
    }
    
    class func reConvertSpecialCharacters(_ string: String) -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        var newString = string
        let char_dictionary = [
            "&amp;" : "&",
            "&lt;" : "<",
            "&gt;" : ">",
            "&quot;" : "\"",
            "&apos;" : "'"
        ];
        for (escaped_char, unescaped_char) in char_dictionary {
            newString = newString.replacingOccurrences(of: escaped_char, with: unescaped_char, options: NSString.CompareOptions.literal, range: string.startIndex..<string.endIndex)
        }
        return newString
    }
    
    
    class func imageDegrees(orientation: Int) -> Int {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        switch orientation {
        case 0: return 0
        case 1: return 180
        case 2: return -90
        case 3: return 90
        default:
            return 0
        }
    }
    
    
    class func libPath() -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        return NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
    }
    
    class func docPath() -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    }
    
    class func isNewerFile(newFileURL: URL, existingFileURL: URL) -> Bool {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        do {
            let newFileAttributes = try FileManager.default.attributesOfItem(atPath: newFileURL.path)
            let newFileDate:Date = newFileAttributes[FileAttributeKey.modificationDate] as! Date

            let existingFileAttributes = try FileManager.default.attributesOfItem(atPath: existingFileURL.path)
            let existingFileDate:Date = existingFileAttributes[FileAttributeKey.modificationDate] as! Date
            
            if newFileDate.compare(existingFileDate) == .orderedDescending {
                return true
            }
        }
        catch {
            print(error)
        }
        return false
    }
    
    
    class func replaceItem(at dstURL: URL, with srcURL: URL) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        do {
            try FileManager.default.removeItem(at: dstURL)
            try FileManager.default.copyItem(at: srcURL, to: dstURL)
        } catch let error as NSError {
            print(error.localizedDescription)
        }
    }
    
    
    static func hasProperty(object: AnyObject, name: String) -> Bool {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        for c in Mirror(reflecting: object).children
        {
            if c.label == name {
                return true
            }
        }
        return false
    }
    
    
    /**
        Wir ermitteln das aktuelle Jahr als String
     */
    static func actualYear() -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        var actYearString: String = ""
        
        let yearComponent = Calendar.current.dateComponents([.year], from: Date())
        actYearString = String(yearComponent.year ?? 0)

        return actYearString
    }


    static func monthNameOf(monthNo: Int) -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        if monthNo < 1 || monthNo > 12 {
            return ""
        }
        
        var workDate = Date()
        workDate = Calendar.current.date(bySetting: .month, value: monthNo, of: workDate)!
        
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale.current
        monthFormatter.dateFormat = "MMMM"
 
        let result = monthFormatter.string(from: workDate)
        print(result)
        return monthFormatter.string(from: workDate)
    }
    
    
    /**
        This function checks if we have a network connection
    */
    class func isConnectedToNetwork() -> Bool {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        /*
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                NetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        
        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
        if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
            return false
        }
        
        // Working for Cellular and WIFI
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        let ret = (isReachable && !needsConnection)
        
        return ret
 */
        return true
        
    }

    
    static func calculateTendency(valuesInOrder: [Double]?) -> (Double, Double)? {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        var minX = 0.0;
        var maxX = 0.0;
        var a    = 0.0;
        var b    = 0.0;
        
        if valuesInOrder == nil || valuesInOrder?.count == 0 { return nil }
        
        let n       = Double(valuesInOrder?.count ?? 0)
        var sumX    = 0.0;
        var sumY    = 0.0;
        var sumXPow = 0.0;
        var sumYPow = 0.0;
        var sumXY   = 0.0;
        minX = 0;
        maxX = Double(valuesInOrder?.count ?? 0)
        
        for i in 0..<valuesInOrder!.count {
            let oneValue = valuesInOrder?[i] ?? 0.0
            sumX += Double(i);
            sumY += oneValue
            sumXPow += Double(i * i);
            sumYPow += oneValue * oneValue
            sumXY   += Double(i) * oneValue
            if minX > Double(i) { minX = Double(i) }
            if maxX < Double(i) { maxX = Double(i) }
        }
        
        let xm = sumX / n;
        let ym = sumY / n;
        
        let xv = sumXPow / n - xm * xm;
        let kv = sumXY / n - (xm * ym);
        if (xv > 0.0) {
            b = kv / xv;
            a = ym - b * xm;
        }
        
        return (a, b)
    }
    
    
    static func stringOfSeconds(_ seconds: Int) -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        var stringSeconds: Int = 0
        var stringMinutes: Int = 0
        var stringHours:   Int = 0
        var calcValue = seconds
        
        stringSeconds = calcValue % 60
        calcValue = (calcValue - stringSeconds) / 60
        
        if calcValue > 0 {
            stringMinutes = calcValue % 60
            calcValue = (calcValue - stringMinutes) / 60
        }
        
        if calcValue > 0 {
            stringHours = calcValue
        }
        
        var ergString = "\(stringSeconds) s"
        if stringMinutes > 0 {
            ergString = "\(stringMinutes) min"
        }
        if stringHours > 0 {
            ergString = "\(stringHours) h"
        }
        return ergString
    }
    
    
    /**
        This function is for generating a Date object from given values. That could be numbers or words
     */
    static func dateFromComponentStrings(day: String!, month: String!, year: String?, language: String?) -> Date? {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        var localeIdentifier: String = "en_GB"
        var dateString: String = ""
        var year = year ?? actualYear()
        var foundDate: Date?
        let dateFormats: [String] = ["yy-MM-dd", "yyyy-MM-dd", "yyyy-MMM-dd", "yyyy-MMMM-dd"]
        
        if language != nil {
            switch language! {
            case "en":
                localeIdentifier = "en_GB"
                dateString = year + "-" + month + "-" + day
                break
            case "de":
                localeIdentifier = "de_DE"
                dateString = day + "." + month + "." + year
                break
            default:
                localeIdentifier = "en_GB"
                dateString = year + "-" + month + "-" + day
                break
            }
        }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: localeIdentifier)
        for i in 0..<dateFormats.count {
            dateFormatter.dateFormat = dateFormats[i]
            foundDate = dateFormatter.date(from: dateString)
            if foundDate != nil  {
                return foundDate
            }
        }
        print("Invalid date format")
        return nil
    }
    
    
    /**
        We search the first mail address from a text and return it
     */
    static func getMailAddressFromText(_ text: String?) -> String? {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        if text == nil { return nil }
        do {
            let mails = try text!.matching(regex: "(?<name>[\\w.]+)\\@(?<domain>\\w+\\.\\w+)(\\.\\w+)?")
            if mails.count > 0 {
                return mails[0]
            }
        }
        catch {
            NSLog("Could not extract mail addresses from text")
        }
        return nil
    }
}



