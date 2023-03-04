//
//  BookingExtensions.swift
//  HotelChatBot
//
//  Created by Jens Lünstedt on 28.02.23.
//

import Foundation
import CoreData


/**
    Extension for the Booking class. The Booking class comes from the CoreData model. Therefor we do not have a real class file we use this extensions.
 */
public extension Booking {
    
    /**
        If creating a booking object also a guest object is created because it is needed and with this there is a central position of creating the objects.
     */
    static func createBooking() -> Booking {
        let booking: Booking = (DatastoreController.shared.createNewEntityByName("Booking") as? Booking)!
        booking.guest = DatastoreController.shared.createNewEntityByName("Guest") as? Guest
        booking.state = "created"
        
        // Finish simulation
        /*
        booking.guest?.firstname = "Max"
        booking.guest?.lastname  = "Mustermann"
        booking.guest?.phonenumber = "0123456789"
        booking.guest?.mailaddress = "max@mustermann.de"
        booking.startDate = Date()
        booking.endDate   = Date()
        booking.breakfast = true
        booking.paymentMethod = "credit card"
        booking.numberOfGuests = 2
        booking.numberOfChildren = 0
        booking.addToRooms(DatastoreController.shared.entityByRownum(entityName: "Room", rownum: 0) as! Room)
        booking.addToParkings(DatastoreController.shared.entityByRownum(entityName: "Parkingplace", rownum: 0) as! Parkingplace)
         */
        return booking
    }
    
    
    /**
        If the Booking is complete it is set to the last state and store that into the database.
     */
    func finishBooking() -> Bool {
        if bookingComplete() {
            self.state = "booked"
            return DatastoreController.shared.saveToPersistentStore()
        }
        return false
    }
    
    
    /**
        Try to book empty rooms and if this is successful return true.
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
        A text with the information if free rooms are available is returned.
     */
    static func freeRoomsText(fromDate: Date, toDate: Date, countPersons: Int) -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        let freeRooms: [Room]? = freeRooms(fromDate: fromDate, toDate: toDate, countPersons: countPersons)
        
        return Translations().getTranslation(text: "There are ") + String(freeRooms?.count ?? 0) +
            Translations().getTranslation(text: "for max ") + String(possibleGuests(rooms: freeRooms)) +
            Translations().getTranslation(text: " guests avaliable for that time range.")
    }
    
    /**
        Look for free rooms and return a list of them
     */
    static func freeRooms(fromDate: Date, toDate: Date, countPersons: Int) -> [Room]? {
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
        let freeRooms: [Room]? = DatastoreController.shared.allForEntity("Room", with: roomPredicate) as? [Room]
        // we should add a sort with count of beds later but for now all rooms have two beds
        
        return freeRooms
    }


    /**
        Return the possible numbers of guests for the rooms
     */
    static func possibleGuests(rooms: [Room]?) -> Int {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        if rooms == nil {
            return 0
        }
        
        var possibleGuests = 0
        
        // We count the free beds
        for freeRoom: Room in rooms ?? [] {
            possibleGuests += Int(freeRoom.numberOfBeds)
        }
        
        return possibleGuests
    }
    
 
    /**
        Look for the room prices and return a text for the user.
     */
    static func roomPrices() -> String {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        let roomPredicate = NSPredicate.init(format: "")
        let orderBy       = NSSortDescriptor.init(key: "price", ascending: true)
        let freeRooms: [Room]? = DatastoreController.shared.allForEntity("Room", with: roomPredicate, orderBy: [orderBy]) as? [Room]
        let lowestPrice  = freeRooms?.first?.price ?? 0.00
        let highestPrice = freeRooms?.last?.price ?? 0.00
        
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.currencyCode = "€"

        if lowestPrice == highestPrice {
            return Translations().getTranslation(text:"Our rooms costs ") + (formatter.string(for: lowestPrice) ?? Translations().getTranslation(text:"unknown")) + "."
        }
        else {
            return Translations().getTranslation(text:"Our rooms costs between ") + (formatter.string(for: lowestPrice) ?? Translations().getTranslation(text:"unknown")) +
            Translations().getTranslation(text:" and ") + (formatter.string(for: highestPrice) ?? Translations().getTranslation(text:"unknown")) + "."
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

        if !bookingComplete() {
            return ""
        }
        
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
        html = html + "<div class=\"divTable blueTable\">"
        html = html + "<div class=\"divTableHeading\">"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableHead\">" + Translations().getTranslation(text:"What") + "</div>"
        html = html + "<div class=\"divTableHead\">Your value</div>"
        html = html + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableBody\">"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">" + Translations().getTranslation(text:"Name") + "</div>"
        html = html + "<div class=\"divTableCell\">" + (self.guest?.firstname)! + " " + (self.guest?.lastname)! + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">" + Translations().getTranslation(text:"Stay from") + "</div>"
        html = html + "<div class=\"divTableCell\">" + self.startDate!.description + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">" + Translations().getTranslation(text:"Stay to") + "</div>"
        html = html + "<div class=\"divTableCell\">" + self.endDate!.description + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">" + Translations().getTranslation(text:"Number of guests") + "</div>"
        html = html + "<div class=\"divTableCell\">" + String(self.numberOfGuests) + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">" + Translations().getTranslation(text:"Number of children") + "</div>"
        html = html + "<div class=\"divTableCell\">" + String(self.numberOfChildren) + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">" + Translations().getTranslation(text:"With breakfast") + "</div>"
        if breakfast {
            boolString = Translations().getTranslation(text:"YES")
        }
        else {
            boolString = Translations().getTranslation(text:"NO")
        }
        html = html + "<div class=\"divTableCell\">" + boolString + "</div>"
        html = html + "</div>"
        if parkings?.count ?? 0 > 0 {
            boolString = Translations().getTranslation(text:"YES")
        }
        else {
            boolString = Translations().getTranslation(text:"NO")
        }
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">" + Translations().getTranslation(text:"Parkingplace") + "</div>"
        html = html + "<div class=\"divTableCell\">" + boolString + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">" + Translations().getTranslation(text:"Visit type") + "</div>"
        html = html + "<div class=\"divTableCell\">" + self.guestType! + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">" + Translations().getTranslation(text:"Payment type") + "</div>"
        html = html + "<div class=\"divTableCell\">" + self.paymentMethod! + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">" + Translations().getTranslation(text:"Phone") + "</div>"
        html = html + "<div class=\"divTableCell\">" + (self.guest?.phonenumber)! + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">" + Translations().getTranslation(text:"Mail") + "</div>"
        html = html + "<div class=\"divTableCell\">" + (self.guest?.mailaddress)! + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">" + Translations().getTranslation(text:"Booked rooms") + "</div>"
        html = html + "<div class=\"divTableCell\">" + String(self.rooms!.count) + "</div>"
        html = html + "</div>"
        html = html + "<div class=\"divTableRow\">"
        html = html + "<div class=\"divTableCell\">" + Translations().getTranslation(text:"Comment") + "</div>"
        html = html + "<div class=\"divTableCell\">" + (self.comment ?? "") + "</div>"
        html = html + "</div>"
        html = html + "</div>"
        html = html + "</div>"
        return html
    }


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
                return (self.value(forKey: key) as! Booking).bookingComplete()
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

        return true
    }


}
