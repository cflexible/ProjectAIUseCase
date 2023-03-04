//
//  AppDelegate.swift
//  HotelChatBot
//  This is the class where the app begins and ends. For this app there is no need to implement anything here.
//  Created by Jens Lünstedt on 21.02.23.
//

import Cocoa

/**
 Start and end class of the app. Here it is possible to react on open or termination events.
 There are two functions used. One is to load some classifier trainingdata from a file into the database. This is just for building up a dataset for later use.
 When the app will be terminate we read all the classifier and tagging information we created from the user input and write them into language separated files on the desktop.
 */
@main
class AppDelegate: NSObject, NSApplicationDelegate {

    
    /**
        When the app is loaded and is visible.
        This is called after the ViewController.viewDidLoad. So we cannot use it to load our base data into the database
     */
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        ClassifierHelper.loadTrainingsdataOnce()
    }

    
    /**
        Before the app will terminate this is called. Here you could save a database.
     */
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        ClassifierHelper.createMLFiles()
        TaggerHelper.createMLFiles()
    }

    
    /**
        This defines if the app caches information about the state of the app. For example the size of the window so
        it will be shown the same way as the time before.
     */
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

