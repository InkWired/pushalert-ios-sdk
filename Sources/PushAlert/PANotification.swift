//
//  SwiftUIView.swift
//  
//
//  Created by Mohit Kuldeep on 28/01/24.
//

import Foundation

@objc public class PANotification: NSObject {
    private var id: Int64 = 0
    private var title: String, sub_title: String, message: String, url: String, image: String, category: String
    private var action1: NSDictionary
    private var action2: NSDictionary
    private var action3: NSDictionary
    private var extraData: [String: String]?
    
    init(id: Int64, title: String, sub_title: String, message: String, url: String, largeImage: String, category: String,
         action1: NSDictionary,
         action2: NSDictionary,
         action3: NSDictionary,
         extraData: String) {
        
        self.id = id
        self.title = title
        self.sub_title = sub_title
        self.message = message
        self.url = url
        self.image = largeImage
        self.category = category
        
        self.action1 = action1
        self.action2 = action2
        self.action3 = action3
        
        if let data = extraData.data(using: .utf8) {
            self.extraData = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String]
        }
    }
    
    public func getTitle() -> String {
        return title
    }
    
    func setTitle(title: String) {
        self.title = title
    }
    
    public func getSubTitle() -> String {
        return sub_title
    }
    
    func setSubTitle(sub_title: String) {
        self.sub_title = sub_title
    }
    
    public func getMessage() -> String {
        return message
    }
    
    func setMessage(message: String) {
        self.message = message
    }
    
    public func getUrl() -> String {
        return url
    }
    
    func setUrl(url: String) {
        self.url = url
    }
    
    public func getImage() -> String {
        return image
    }
    
    func setImage(image: String) {
        self.image = image
    }
    
    public func getId() -> Int64 {
        return id
    }
    
    public func getAction1() -> NSDictionary {
        return action1
    }
    
    func setAction1(action1: NSDictionary) {
        self.action1 = action1
    }
    
    public func getAction2() -> NSDictionary {
        return action2
    }
    
    func setAction2(action2: NSDictionary) {
        self.action2 = action2
    }
    
    public func getAction3() -> NSDictionary {
        return action3
    }
    
    func setAction3(action3: NSDictionary) {
        self.action3 = action3
    }
    
    public func getCategory() -> String {
        return category
    }
    
    func setCategory(category: String) {
        self.category = category
    }
    
    
    public func getExtraData() -> [String: String]? {
        return extraData
    }
    
    func setExtraData(extraData: [String: String]) {
        self.extraData = extraData
    }
}
