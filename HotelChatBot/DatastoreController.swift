//
//  DatastoreController.swift
//  The datastore controller class. With the modelBaseName all is set and we can use
//  use the methods to create, read, find, change or delete database entities
//
//  Created by Jens Lünstedt on 28.11.20.
//

import Foundation
import CoreData

/**
 An old class from many projects with some new functions. So the documentation is not complete and partial in German. 
 */
class DatastoreController: NSObject {
    private var modelNumberString: String { return "" }
    private var modelBaseName:     String { return "HotelChatbotModel" }
    
    private var persistentStoreCoordinator:NSPersistentStoreCoordinator? = nil
    private var managedObjectContext:NSManagedObjectContext? = nil
    private let batchsize = 50
    private var actBatchStart = 0
    private var batch = false
    private var actEntityName = ""
    
    /// The usable property to get the singleton DatastoreController instance. This is important because with this the methods get usable.
    static let shared = DatastoreController() // Usage: DatastoreController.shared
    
    private let dbPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
    
    /**
     *  @Method    init
     *  @Parameter --
     *     @Return    --
     *  Initializes a singleton and the database in the file system.
     */
    override init() {  //This prevents others from using the default '()' initializer for this class.
        // Ziel der Initialisierung ist es einen managed Object Context zu bekommen, denn den brauchen wir in allen anderen Funktionen
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
            NSLog("DB Path: %@", dbPath)
        #endif
        super.init()
        
        let modelName = modelBaseName.appending(modelNumberString)
        let subDirectory = (modelBaseName as NSString).appendingPathExtension("momd") // Wir haben vielleicht mehrere Modelle in Unterverzeichnissen
        var modelURL = Bundle.main.url(forResource: modelName, withExtension: "mom", subdirectory: subDirectory)
        if modelURL == nil {
            // Wir haben keine Untermodelle gefunden. Vielleicht klappt es ohne diese
            modelURL = Bundle.main.url(forResource: modelName, withExtension: "mom", subdirectory: "")
            if modelURL == nil {
                fatalError("Unable to Find Data Model")
            }
        }
        
        let managedObjectModel = NSManagedObjectModel.init(contentsOf: modelURL!) // Wir initialisieren das Modell

        let options = [NSMigratePersistentStoresAutomaticallyOption: true,
                       NSInferMappingModelAutomaticallyOption: true]

        let storeUrl = NSURL(fileURLWithPath: dbPath).appendingPathComponent(modelBaseName.appending(".sqlite"))

        // Zum Modell brauchen wir den Persistence Store Coordinator
        persistentStoreCoordinator = NSPersistentStoreCoordinator.init(managedObjectModel: managedObjectModel!)
        var part = 0
        let fileAttributes = [FileAttributeKey.protectionKey: FileProtectionType.complete] as [FileAttributeKey: Any]
        do {
            try persistentStoreCoordinator?.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeUrl, options: options)
            part = 1

            // Wir haben den Persistence Store Coordinator mit seiner Datei und schützen diese
            //try FileManager.default.setAttributes(fileAttributes, ofItemAtPath: (storeUrl?.absoluteString)!)
            
            managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            managedObjectContext?.persistentStoreCoordinator = persistentStoreCoordinator
        }
        catch {
            switch part {
            case 0:
                print("Error while adding PersistenceStore: ".appending((storeUrl?.absoluteString)!).appending("\n, ").appending(options.description))
                break
            case 1:
                print("Error while stting File attributes: ".appending(fileAttributes.description).appending("\n, ").appending((storeUrl?.absoluteString)!))
                break
            default:
                print("unbekannter Punkt")
            }
            
        }
    }

    //MARK: Base functions
    /**
     Bereich für die allgemeinen Funktionen
     */
    /**
     *  @Method    saveToPersistentStore
     *  @Parameter --
     *     @Return    Bool
     *  Tries to save the actual managed object context and returns true or false depending on the success.
     */
    func saveToPersistentStore() -> Bool {
    #if DEBUG
        NSLog("\(type(of: self)) \(#function)()")
    #endif

        var savedOK = false
        if managedObjectContext?.parent != nil && (managedObjectContext?.parent?.hasChanges)! {
            do {
                try managedObjectContext?.parent?.save()
            }
            catch let error {
                print("Could not save parent \(error)")
                //return false
                savedOK = false
            }
            
        }
        managedObjectContext?.performAndWait() {
            do {
                let insertedObjects = managedObjectContext?.insertedObjects
                for managedObject in insertedObjects! {
                    if managedObject.responds(to:Selector(("setModifyDate:"))) {
                        managedObject.setValue(NSDate(), forKey:"modifyDate");
                    }
                    if managedObject.responds(to:Selector(("setCreateDate:"))) {
                        managedObject.setValue(NSDate(), forKey:"createDate");
                    }
                    if managedObject.responds(to:Selector(("setModifiedBy:"))) {
                        managedObject.setValue(Utilities.getAnonymUserID(), forKey:"modifiedBy");
                    }
                    if managedObject.responds(to:Selector(("setCreatedBy:"))) {
                        managedObject.setValue(Utilities.getAnonymUserID(), forKey:"createdBy");
                    }
                    if managedObject.responds(to:#selector(NSObject.setVersion(_:))) {
                        let oldVersion = managedObject.value(forKey: "version")
                        if oldVersion == nil {
                            managedObject.setValue("1", forKey:"version");
                        }
                        else {
                            let oldVersionNumber = Int(oldVersion as! String)! + 1
                            managedObject.setValue(oldVersionNumber.description, forKey:"version");
                        }
                    }
                }
                
                let updatedObjects = managedObjectContext?.updatedObjects
                for managedObject in updatedObjects! {
                    if managedObject.responds(to:Selector(("setModifyDate:"))) {
                        managedObject.setValue(NSDate(), forKey:"modifyDate");
                    }
                    if managedObject.responds(to:Selector(("setModifyBy:"))) {
                        managedObject.setValue(Utilities.getAnonymUserID(), forKey:"modifyBy");
                    }
                    if managedObject.responds(to:#selector(NSObject.setVersion(_:))) {
                        let oldVersion:String = managedObject.value(forKey: "version") as! String
                        let oldVersionNumber = Int(oldVersion)! + 1
                        managedObject.setValue(oldVersionNumber.description, forKey:"version");
                    }
                }
                
                try managedObjectContext?.save()
                savedOK = true
            }
            catch let error {
                print("Could not save \(error)")
                savedOK =  false
            }
        }
        return savedOK
    }

    
    /**
     *  @Method    rollback
     *  @Parameter --
     *     @Return    --
     *  Rollsback to the last save.
     */
    func rollback() {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        managedObjectContext?.rollback()
    }
    
    
    //MARK: Entity functions
    /**
     *  @Method    allForEntity entityName predicate
     *  @Parameter String
     *     @Return    NSArray
     *  Fetches all entities for the given name.
     */
    func allForEntity(_ entityName: String, with predicate: NSPredicate?) -> NSArray {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
        if predicate != nil {
            request.predicate = predicate
        }
        if batch {
            request.fetchBatchSize = batchsize
            request.fetchOffset = 0
            actEntityName = entityName
        }
        var returnValue:NSArray? = nil
        do {
            let result = try managedObjectContext?.fetch(request)
            if result == nil {
                return NSArray()
            }
            if ((result?.count)! >= 1) {
                returnValue = NSArray(array: result!)
            }
            let requestCount = try managedObjectContext?.count(for: request)
            if batch && requestCount! >= batchsize {
                actBatchStart += batchsize
            }
        }
        catch let error {
            print("Could not fetch \(error)")
        }
        if returnValue != nil {
            return returnValue!
        }
        else {
            return NSArray()
        }
    }
    
    
    /**
     *  @Method    allForEntity entityName predicate orderBy
     *  @Parameter String NSPredicate NSSortDescriptor
     *     @Return    NSArray
     *  Fetches all entities for the given name.
     */
    func allForEntity(_ entityName: String, with predicate: NSPredicate?, orderBy order: [NSSortDescriptor]?) -> NSArray {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
        if predicate != nil {
            request.predicate = predicate
        }
        if batch {
            request.fetchBatchSize = batchsize
            request.fetchOffset = 0
            actEntityName = entityName
        }
        if order != nil {
            let sortDescriptors = order
            request.sortDescriptors = sortDescriptors
        }
        var returnValue:NSArray? = nil
        do {
            let result = try managedObjectContext?.fetch(request)
            if ((result?.count)! >= 1) {
                returnValue = NSArray(array: result!)
            }
            let requestCount = try managedObjectContext?.count(for: request)
            if batch && requestCount! >= batchsize {
                actBatchStart += batchsize
            }
        }
        catch let error {
            print("Could not fetch \(error)")
        }
        if returnValue != nil {
            return returnValue!
        }
        else {
            return NSArray()
        }
    }
    
    
    /**
     *  @Method    allForEntity entityName
     *  @Parameter String
     *     @Return    NSArray
     *  Fetches all entities for the given name.
     */
    func allForEntity(_ entityName: String ) -> NSArray {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        return allForEntity(entityName, with: nil)
        }


    /**
     *  @Method    entityByName entityName
     *  @Parameter String
     *     @Return    NSArray
     *  Fetches one / the first entity for the given name.
     */
    func entityByName(_ entityName: String) -> NSManagedObject? {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)

        // execute
        var values:Array<Any>!
        do {
            values = try managedObjectContext?.fetch(request)
        }
        catch let error {
            print("Could not fetch \(error)")
        }

        if (values?.count)! > 0 {
            // this method is designed for accessing a single object, but if there's more just give the first
            return values[0] as? NSManagedObject
        }
        // Hier kommen wir nur hin, wenn wir nichts gefunden haben
        return nil
    }


    /**
     *  @Method    entityByName entityName key value
     *  @Parameter String, String, NSObject
     *     @Return    NSArray
     *  Fetches one / the first entity for the given name and the given search criteria.
     */
    func entityByName(_ entityName: String, key: String, value: NSObject) -> NSManagedObject? {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)

        let predicate = NSPredicate(format:"%K == %@", key, value)
        request.predicate = predicate

        // execute
        var values:Array<Any>!
        do {
            values = try managedObjectContext?.fetch(request)
        }
        catch let error {
            print("Could not fetch \(error)")
        }

        if (values?.count)! > 0 {
            // this method is designed for accessing a single object, but if there's more just give the first
            return values[0] as? NSManagedObject
        }
        // Hier kommen wir nur hin, wenn wir nichts gefunden haben
        return nil

    }

    
    /**
     *  @Method    entityByName entityName key value
     *  @Parameter String, String, NSObject
     *     @Return    NSArray
     *  Fetches one / the first entity for the given name and the given search criteria.
     */
    func entityByRownum(entityName: String, rownum: Int) -> NSManagedObject? {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        var rownum = rownum
        let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)

        let checkNum: Int! = try! managedObjectContext?.count(for: request) ?? 0
        // If we do not have any rows we stop
        if checkNum == 0 {
            return nil
        } // If the given rownum is lower then 0 we return the first row
        else if rownum < 0 {
            rownum = 0
        } // if the given rownum is greater then the last rownum we return the last rownum
        else if rownum > checkNum {
            rownum = checkNum
        }
        
        request.fetchOffset = rownum
        request.fetchLimit  = 1

        // execute
        var value:Array<Any>!
        do {
            value = try (managedObjectContext?.fetch(request))
            let retval = value[0] as? NSManagedObject
            return retval
        }
        catch let error {
            print("Could not fetch \(error)")
        }

        // Hier kommen wir nur hin, wenn wir nichts gefunden haben
        return nil
    }

    
    /**
        Refetch an enity if it is changed.
     */
    func refetchEntity(_ entity: NSManagedObject) -> NSManagedObject {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        return (managedObjectContext?.object(with: entity.objectID))!
    }
    
    
    /**
     *  @Method    createNewEntityByName
     *  @Parameter String
     *     @Return    NSManagedObject
     *  Creates a new NSManagedObject for the given Entity
     */
    func createNewEntityByName(_ entityName: String) -> NSManagedObject? {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        if managedObjectContext == nil {
            return nil
        }
        let newEntity = NSEntityDescription.insertNewObject(forEntityName: entityName, into: managedObjectContext!)
        return newEntity
    }


    /**
     *  @Method    removeEntity
     *  @Parameter NSManagedObject
     *     @Return    --
     *  Deletes a NSManagedObject
     */
    func removeEntity(_ entity: NSManagedObject) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        managedObjectContext?.delete(entity)
    }


    /**
     *  @Method    removeAllEntitiesByName
     *  @Parameter String
     *     @Return    --
     *  Deletes all objects of a given entity name
     */
    func removeAllEntitiesByName(_ entityName: String) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        let objects = allForEntity(entityName)

        for iObject in objects {
            managedObjectContext?.delete(iObject as! NSManagedObject)
        }
    }


    /**
     *  @Method    removeEntityHirarchy
     *  @Parameter NSManagedObject
     *     @Return    --
     *  Deletes the entity and all of its children
     */
    func removeEntityHirarchy(_ entity: NSManagedObject, parent: NSManagedObject?) {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        let allproperties = entity.entity.propertiesByName
        for attribute in allproperties {
            let key = attribute.key
            let theProperty = entity.value(forKey: key) as! NSObject
            if theProperty.isKind(of: NSManagedObject.classForCoder()) && (!theProperty.isEqual(parent) || parent == nil) {
                removeEntityHirarchy(theProperty as! NSManagedObject, parent:entity)
            }
        }
        removeEntity(entity)
    }


    //MARK: Helper Funtions
    /**
     *  @Method    dbSize
     *  @Parameter --
     *     @Return    uint64_t
     *  Get the size of the database
     */
    func dbSize() -> NSNumber? {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif
        
        let dbFileName = NSURL(fileURLWithPath: dbPath).appendingPathComponent(modelBaseName.appending(".sqlite"))?.absoluteString
        do {
            let fileAttributes:[FileAttributeKey : Any] = try FileManager.default.attributesOfItem(atPath: dbFileName!)
            return fileAttributes[FileAttributeKey.size] as? NSNumber
        }
        catch {
            print("File not readable")
            return nil
        }
    }
    
    
    /**
        We count the numbers of records for an entity
     */
    func rowCountForEntity(name: String) -> Int {
        #if DEBUG
            NSLog("\(type(of: self)) \(#function)()")
        #endif

        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: name)
        do {
            let count = try managedObjectContext?.count(for: fetchRequest)
            return count ?? 0
        } catch {
            print(error.localizedDescription)
        }
        return 0
    }

}
