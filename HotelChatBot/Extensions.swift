//
//  Extensions.swift
//  HotelChatBot
//
//  Created by Jens Lünstedt on 27.02.23.
//

import Foundation


public extension String {
    func matching(regex: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: regex)
        let results = regex.matches(in: self, range: NSRange(startIndex..., in: self))
        return results.map { String(self[Range($0.range, in: self)!]) }
    }
}


public extension String {
    func wordToInteger() -> Int? {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .spellOut
        return  numberFormatter.number(from: self) as? Int
    }
}


public extension Booking {
    func toHTML() -> String {
        var boolString = ""
        var bookingStyle = ""
        
        if let path = Bundle.main.path(forResource: "BookingHtmlStyle", ofType: "txt") {
            do {
                try bookingStyle = String(contentsOfFile: path)
            }
            catch  {
                print("error trying to load preBodyfile")
                return ""
            }
        }

        var html: String = "<style>" + bookingStyle + "</style>"
        html = html + "<div>"
        html = html + "<div class=\"divTable blueTable\">"
        html = html + "<div class=\"divTableHeading\">"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableHead\">What</div>"
        html = html + "<div class=\"divTableHead\">Your value</div>"
        html = html + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableBody\">"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">Name</div>"
        html = html + "<div class=\"divTableCell\">" + (self.guest?.firstname)! + " " + (self.guest?.lastname)! + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">Stay from</div>"
        html = html + "<div class=\"divTableCell\">" + self.startDate!.description + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">Stay to</div>"
        html = html + "<div class=\"divTableCell\">" + self.endDate!.description + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">Number of guests</div>"
        html = html + "<div class=\"divTableCell\">" + String(self.numberOfGuests) + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">Number of children</div>"
        html = html + "<div class=\"divTableCell\">" + String(self.numberOfChildren) + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">With breakfast</div>"
        if breakfast {
            boolString = NSLocalizedString("YES", comment: "")
        }
        else {
            boolString = NSLocalizedString("NO", comment: "")
        }
        html = html + "<div class=\"divTableCell\">" + boolString + "</div>"
        html = html + "</div>"
        if parkings?.count ?? 0 > 0 {
            boolString = NSLocalizedString("YES", comment: "")
        }
        else {
            boolString = NSLocalizedString("NO", comment: "")
        }
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">Parkingplace</div>"
        html = html + "<div class=\"divTableCell\">" + boolString + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">Visit type</div>"
        html = html + "<div class=\"divTableCell\">" + self.guestType! + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">Payment type</div>"
        html = html + "<div class=\"divTableCell\">" + self.paymentMethod! + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">Phone</div>"
        html = html + "<div class=\"divTableCell\">" + (self.guest?.phonenumber)! + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">Mail</div>"
        html = html + "<div class=\"divTableCell\">" + (self.guest?.mailaddress)! + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">Booked rooms</div>"
        html = html + "<div class=\"divTableCell\">" + String(self.rooms!.count) + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">Comment</div>"
        html = html + "<div class=\"divTableCell\">" + (self.comment ?? "") + "</div>"
        html = html + "</div>"
        html = html + "</div>"
        html = html + "</div>"
        html = html + "</div>"
        html = html + "</div>"
        return html
    }
}
