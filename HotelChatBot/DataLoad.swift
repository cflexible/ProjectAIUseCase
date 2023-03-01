//
//  DataLoad.swift
//  HotelChatBot
//  This class is for loading base database values from a plist file into the database
//  Created by Jens Lünstedt on 24.02.23.
//

import Foundation

class DataLoad: NSObject {

    // definition of the structures of the plist files to get an interpretation of the content
    struct AppValues: Codable {
        var rooms: [RoomStruc]
        struct RoomStruc: Codable {
            let attributes: roomAttributes
        }
        struct roomAttributes: Codable {
            let roomNumber:      Int
            let name:            String
            let numberOfBeds:    Int
            let price:           Double
            let roomDescription: String
        }

        var parkingplaces: [ParkingplaceStruc]
        struct ParkingplaceStruc: Codable {
            let attributes: parkingplaceAttributes
        }
        struct parkingplaceAttributes: Codable {
            let id:          String
            let hasCharger:  Bool
            let price:       Double
        }

        var workflows: [WorkflowStruc]
        struct WorkflowStruc: Codable {
            let attributes: workflowAttributes
        }
        struct workflowAttributes: Codable {
            let questionNumber:     Int
            let englishText:        String
            let negativeAnswer:     String
            let positiveAnswer:     String
            let checkAttributename: String
            let checkFunction:      String
            let checkValue:         String
            let helpText:           String
        }

    }

    
    /**
        We load the plist file from the resources and update or create the database values
     */
    static func loadBaseData() {
        let url       = Bundle.main.url(forResource: "BaseData", withExtension: "plist")!
        let data      = try! Data(contentsOf: url)
        let decoder   = PropertyListDecoder()
        do {
            let appValues = try decoder.decode(AppValues.self, from: data)
            // if we have room values we edit them here
            for room in appValues.rooms {
                let roomObject: Room? = DatastoreController.shared.entityByName("Room", key: "roomNumber", value: room.attributes.roomNumber as NSObject) as? Room
                if roomObject != nil {
                    roomObject!.name            = room.attributes.name
                    roomObject!.numberOfBeds    = Int16(room.attributes.numberOfBeds)
                    roomObject!.price           = NSDecimalNumber(value: room.attributes.price)
                    roomObject!.roomDescription = room.attributes.roomDescription
                    _ = DatastoreController.shared.saveToPersistentStore()
                }
                else {
                    var newRoomObject: Room = DatastoreController.shared.createNewEntityByName("Room") as! Room
                    newRoomObject.roomNumber      = Int16(room.attributes.roomNumber)
                    newRoomObject.name            = room.attributes.name
                    newRoomObject.numberOfBeds    = Int16(room.attributes.numberOfBeds)
                    newRoomObject.price           = NSDecimalNumber(value: room.attributes.price)
                    newRoomObject.roomDescription = room.attributes.roomDescription
                    _ = DatastoreController.shared.saveToPersistentStore()
                }
            }
            
            // if we have parkingplace definitions we edit them here
            for parkingplace in appValues.parkingplaces {
                let parkingplaceObject: Parkingplace? = DatastoreController.shared.entityByName("Parkingplace", key: "id", value: parkingplace.attributes.id as NSObject) as? Parkingplace
                if parkingplaceObject != nil {
                    parkingplaceObject!.hasCharger      = parkingplace.attributes.hasCharger
                    parkingplaceObject!.price           = NSDecimalNumber(value: parkingplace.attributes.price)
                    _ = DatastoreController.shared.saveToPersistentStore()
                }
                else {
                    var newParkingplaceObject: Parkingplace = DatastoreController.shared.createNewEntityByName("Parkingplace") as! Parkingplace
                    newParkingplaceObject.id            = parkingplace.attributes.id
                    newParkingplaceObject.hasCharger    = parkingplace.attributes.hasCharger
                    newParkingplaceObject.price         = NSDecimalNumber(value: parkingplace.attributes.price)
                    newParkingplaceObject.blocked       = false
                    _ = DatastoreController.shared.saveToPersistentStore()
                }
            }
            
            // if we have workflow values we edit them here
            for workflow in appValues.workflows {
                let workflowObject: Workflow? = DatastoreController.shared.entityByName("Workflow", key: "questionNumber", value: workflow.attributes.questionNumber as NSObject) as? Workflow
                if workflowObject != nil {
                    workflowObject!.englishText        = workflow.attributes.englishText
                    workflowObject!.negativeAnswer     = workflow.attributes.negativeAnswer
                    workflowObject!.positiveAnswer     = workflow.attributes.positiveAnswer
                    workflowObject!.checkAttributename = workflow.attributes.checkAttributename
                    workflowObject!.checkFunction      = workflow.attributes.checkFunction
                    workflowObject!.checkValue         = workflow.attributes.checkValue
                    workflowObject!.helpText           = workflow.attributes.helpText
                    _ = DatastoreController.shared.saveToPersistentStore()
                }
                else {
                    var newWorkflowObject: Workflow = DatastoreController.shared.createNewEntityByName("Workflow") as! Workflow
                    newWorkflowObject.questionNumber      = Int16(workflow.attributes.questionNumber)
                    newWorkflowObject.englishText         = workflow.attributes.englishText
                    newWorkflowObject.negativeAnswer      = workflow.attributes.negativeAnswer
                    newWorkflowObject.positiveAnswer      = workflow.attributes.positiveAnswer
                    newWorkflowObject.checkAttributename  = workflow.attributes.checkAttributename
                    newWorkflowObject.checkFunction       = workflow.attributes.checkFunction
                    newWorkflowObject.checkValue          = workflow.attributes.checkValue
                    newWorkflowObject.helpText            = workflow.attributes.helpText
                    _ = DatastoreController.shared.saveToPersistentStore()
                }
            }
        }
        catch let error as NSError {
            print(error)
        }
    }
    
}
