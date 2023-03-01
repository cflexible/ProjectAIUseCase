//
//  BookingController.swift
//  HotelChatBot
//
//  Created by Jens Lünstedt on 25.02.23.
//

import Cocoa

class BookingController: NSObject {

    var bookingWorkObject: BookingWorkObject!
    var baseStatus:        [BookingStatus]   = []
    
    struct BookingWorkObject {
        var booking: Booking!
        var status:  [BookingStatus]
    }
    
    struct BookingStatus {
        var objectName:    String!
        var attributeName: String!
        var tagnames:      String! // a list of tags
        var priority:      Int!
        var answered:      Bool = false
    }
    
    override init() {
        super.init()
    }
    
    init(booking: Booking) {
        super.init()
        
        loadStatus()
        bookingWorkObject.status  = baseStatus
        checkBooking(booking)
    }

    
    func checkBooking(_ booking: Booking) {
        bookingWorkObject.booking = booking
        for attribut in booking.attributeKeys {
            let value = booking.value(forKey: attribut)
        }
    }
    
    
    
    func loadStatus() {
        var status:BookingStatus = BookingStatus(objectName: "Booking", attributeName: "guest", priority: 1, answered: false)
        baseStatus.append(status)
        status = BookingStatus(objectName: "Guest", attributeName: "firstname", tagnames: "first-name", priority: 5, answered: false)
        baseStatus.append(status)
        status = BookingStatus(objectName: "Guest", attributeName: "lastname", tagnames: "last-name", priority: 10, answered: false)
        baseStatus.append(status)
        status = BookingStatus(objectName: "Booking", attributeName: "startDate", priority: 15, answered: false)
        baseStatus.append(status)
        status = BookingStatus(objectName: "Booking", attributeName: "endDate", priority: 15, answered: false)
        baseStatus.append(status)
        status = BookingStatus(objectName: "Booking", attributeName: "numberOfGuests", priority: 20, answered: false)
        baseStatus.append(status)
        status = BookingStatus(objectName: "Booking", attributeName: "numberOfChildren", priority: 25, answered: false)
        baseStatus.append(status)
        status = BookingStatus(objectName: "Booking", attributeName: "rooms", priority: 30, answered: false)
        baseStatus.append(status)
        status = BookingStatus(objectName: "Booking", attributeName: "breakfast", priority: 32, answered: false)
        baseStatus.append(status)
        status = BookingStatus(objectName: "Booking", attributeName: "guestType", priority: 35, answered: false)
        baseStatus.append(status)
        status = BookingStatus(objectName: "Booking", attributeName: "paymentMethod", priority: 40, answered: false)
        baseStatus.append(status)
        status = BookingStatus(objectName: "Guest", attributeName: "mailaddress", tagnames: "mail", priority: 45, answered: false)
        baseStatus.append(status)
        status = BookingStatus(objectName: "Guest", attributeName: "phonenumber", priority: 50, answered: false)
        baseStatus.append(status)
        status = BookingStatus(objectName: "Booking", attributeName: "parkings", priority: 60, answered: false)
        baseStatus.append(status)
    }
}
