//
//  OutputViewGenerator.swift
//  HotelChatBot
//  In this class the HTML code for the view is generated and the course is hold
//  Created by Jens Lünstedt on 23.02.23.
//

import Foundation
import AppKit

class OutputViewGenerator: NSObject {
    
    var preBody:  String   = ""
    var postBody: String   = ""
    var entries:  [String] = []
    var hotelBase64Image: String = ""
    var guestBase64Image: String = ""

    /**
        we initialize the variables which holds the html code til the body and to close the body / html from to text files from the app resources
     */
    override init() {
        super.init()
        
        // we load the html text with the header, the style information and the beginning of the body into the variable
        if let path = Bundle.main.path(forResource: "preBody", ofType: "txt") {
            do {
                try preBody = String(contentsOfFile: path)
            }
            catch  {
                print("error trying to load preBodyfile")
                return
            }
        }
        
        // we load the html text from the body end to the end of the html
        if let path = Bundle.main.path(forResource: "postBody", ofType: "txt") {
            do {
                try postBody = String(contentsOfFile: path)
            }
            catch  {
                print("error trying to load postBodyfile")
                return
            }
        }
        
        // In the HTML style code we have two placeholder for the pony and the guest image
        // we replace them with the base64 code of the images
        var image: NSImage? = NSImage(named:"Zum_taenzelnden_Pony_256")
        if image != nil {
            hotelBase64Image = image!.base64String!
            preBody = preBody.replacing("@HOTELBASE64DATA@", with: hotelBase64Image)
        }
        image = NSImage(named:"GuestSmiley")
        if image != nil {
            guestBase64Image = image!.base64String!
            preBody = preBody.replacing("@GUESTBASE64DATA@", with: guestBase64Image)
        }

    }
    
    
    /**
        A new chat from the hotel shall be created so we put that to the chat array and return the whole html code
        @Parameter String with the chat text
        @Return    String with the HTML
     */
    func newHotelChat(text: String) -> String {
        var html: String = "<div align=\"left\">\n"
        html = html + "<p class=\"from-hotel\">" + text + "</p>\n"
        html = html + "<img class=\"hotelimage\" id=\"base64-hotel-img\" alt=\"\"/>\n"
        html = html + "</div>\n"
        
        entries.append(html)
        return createHtml()
    }

    
    /**
        A new chat from the guest shall be created so we put that to the chat array and return the whole html code
        @Parameter String with the chat text
        @Return    String with the HTML
     */
    func newGuestChat(text: String) -> String {
        var html: String = "<div align=\"right\">\n"
        html = html + "<p class=\"from-guest\">" + text + "</p>\n"
        html = html + "<img class=\"guestimage\" id=\"base64-guest-img\" alt=\"\"/>\n"
        html = html + "</div>\n"

        entries.append(html)
        return createHtml()
    }

    /**
        create the whole html code from the beginning with all entries to the end
        @Parameter --
        @Return    String with the HTML
     */
    private func createHtml() -> String {
        var html: String = preBody;
        for text: String in entries {
            html = html + text
        }
        html = html + postBody
        return html
    }
    
    
}

/**
    This is a NSImage extension which makes it able to convert a bitmap image to the base64 code to include that into the HTML style code
 */
extension NSImage {
    var base64String:String? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: NSColorSpaceName.deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
            ) else {
                print("Couldn't create bitmap representation")
                return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = (NSGraphicsContext(bitmapImageRep: rep))
        draw(at: NSZeroPoint, from: NSZeroRect, operation: .sourceOver, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [NSBitmapImageRep.PropertyKey.compressionFactor: 1.0]) else {
            print("Couldn't create PNG")
            return nil
        }

        return data.base64EncodedString(options: [])
    }
}
