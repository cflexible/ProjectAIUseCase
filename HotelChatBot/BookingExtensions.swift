//
//  BookingExtensions.swift
//  HotelChatBot
//
//  Created by Jens Lünstedt on 28.02.23.
//

import Foundation
import CoreData


/**
    Extension for the Booking class
 */
public extension Booking {
    
    /**
        we try to book empty rooms and if this is successful we return true
     */
    func bookRooms(fromDate: Date, toDate: Date, countPersons: Int) -> Int {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        let bookingPredicate = NSPredicate.init(format: "startDate >= \(fromDate) and endDate <= \(toDate)")
        let bookingObjects: [Booking]? = DatastoreController.shared.allForEntity("Booking", with: bookingPredicate) as? [Booking]
        
        var bookedRooms: [Room] = []
        for bookingObject in bookingObjects ?? [] {
            for bookingRoom in bookingObject.rooms ?? [] {
                bookedRooms.append((bookingRoom as! Room))
            }
        }
        
        let roomPredicate = NSPredicate.init(format: "not room in \(bookedRooms)")
        var freeRooms: [Room]? = DatastoreController.shared.allForEntity("Room", with: roomPredicate) as? [Room]
        // we should add a sort with count of beds later but for now all rooms have two beds
        
        var possibleGuests = 0
        
        // We count the free beds
        for freeRoom: Room in freeRooms ?? [] {
            possibleGuests += Int(freeRoom.numberOfBeds)
        }
        
        // if there are not enough beds we return false
        if possibleGuests < countPersons { return 0 }
        
        // we book rooms
        var openGuests: Int = countPersons
        var roomCount = 0
        while openGuests > 0 {
            let freeRoom: Room = freeRooms![0]
            self.addToRooms(freeRoom)
            roomCount += 1
            freeRooms?.remove(at: 0)
            openGuests -= Int(freeRoom.numberOfBeds)
        }

        return roomCount
    }
    
    
    /**
        we look if there are free rooms available for the given time range
     */
    static func freeRooms(fromDate: Date, toDate: Date, countPersons: Int) -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        let bookingPredicate = NSPredicate.init(format: "startDate >= \(fromDate) and endDate <= \(toDate)")
        let bookingObjects: [Booking]? = DatastoreController.shared.allForEntity("Booking", with: bookingPredicate) as? [Booking]
        
        var bookedRooms: [Room] = []
        for bookingObject in bookingObjects ?? [] {
            for bookingRoom in bookingObject.rooms ?? [] {
                bookedRooms.append((bookingRoom as! Room))
            }
        }
        
        let roomPredicate = NSPredicate.init(format: "not room in \(bookedRooms)")
        var freeRooms: [Room]? = DatastoreController.shared.allForEntity("Room", with: roomPredicate) as? [Room]
        // we should add a sort with count of beds later but for now all rooms have two beds
        
        var possibleGuests = 0
        
        // We count the free beds
        for freeRoom: Room in freeRooms ?? [] {
            possibleGuests += Int(freeRoom.numberOfBeds)
        }
        
        return "There are \(freeRooms?.count ?? 0) for max \(possibleGuests) guests avaliable for that time range."
    }
    
 
    /**
        we look for the room prices
     */
    static func roomPrices() -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        let roomPredicate = NSPredicate.init(format: "")
        let orderBy       = NSSortDescriptor.init(key: "price", ascending: true)
        var freeRooms: [Room]? = DatastoreController.shared.allForEntity("Room", with: roomPredicate, orderBy: [orderBy]) as? [Room]
        let lowestPrice  = freeRooms?.first?.price ?? 0.00
        let highestPrice = freeRooms?.last?.price ?? 0.00
        
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.currencyCode = "€"

        if lowestPrice == highestPrice {
            return "Our rooms costs \(formatter.string(for: lowestPrice) ?? "unknown")."
        }
        else {
            return "Our rooms costs between \(formatter.string(for: lowestPrice) ?? "unknown") and \(formatter.string(for: highestPrice) ?? "unknown")."
        }

    }
    /**
        we try to book empty rooms and if this is successful we return true
     */
    func bookParking(fromDate: Date, toDate: Date) -> Bool {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        let parkingPredicate = NSPredicate.init(format: "blocked = NO")
        let parkingObjects: [Parkingplace]? = DatastoreController.shared.allForEntity("Parkingplace", with: parkingPredicate) as? [Parkingplace]
        
        if parkingObjects != nil && parkingObjects?.count ?? 0 > 0 {
            self.addToParkings(parkingObjects![0])
            return true
        }
        return false
    }
    
    
    /**
        Output of booking as HTML
     */
    func toHTML() -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

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


public extension NSManagedObject {
    func bookingComplete() -> Bool {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        let attributeKeys        = self.entity.attributeKeys
        let oneRelationshipKeys  = self.entity.toOneRelationshipKeys
        let manyRelationshipKeys = self.entity.toManyRelationshipKeys
        
        // we test the original attributes if they are not optional and have a value
        for key in attributeKeys {
            let attribute = self.entity.attributesByName[key]
            if attribute?.isOptional ?? true {
                continue
            }
            else if self.value(forKey: key) == nil {
                return false // We have a need object but no value, so the booking is not complete
            }
        }
        
        // we test the direct relationships if they are also exist if not optional
        for key in oneRelationshipKeys {
            let object = self.entity.relationshipsByName[key]
            if object?.isOptional ?? true {
                continue
            }
            else if object == nil {
                return false
            }
            else {
                return (self.entity.value(forKey: key) as! NSManagedObject).bookingComplete()
            }
        }

        // we test the direct relationships if they are also exist if not optional
        for key in manyRelationshipKeys {
            let object = self.entity.relationshipsByName[key]
            if object?.isOptional ?? true {
                continue
            }
            else if object == nil {
                return false
            }
            // we can spare the test of all subobjects. It is enough to know that they exist.
        }

        return false
    }


}
