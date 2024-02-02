//
//  SwiftUIView.swift
//  
//
//  Created by Mohit Kuldeep on 01/02/24.
//

import Foundation

struct PANotificationCategory:Codable{
    let category_id:String
    let total_action_buttons:Int
    let action1_info:String
    let action2_info:String
    let action3_info:String
    
    init(category_id: String, total_action_buttons: Int, action1_info: NSDictionary, action2_info: NSDictionary, action3_info: NSDictionary) {
        self.category_id = category_id
        self.total_action_buttons = total_action_buttons
        
        var jsonData = try! JSONSerialization.data(withJSONObject: action1_info, options: [])
        var jsonString = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue)! as String
        self.action1_info = jsonString
        
        jsonData = try! JSONSerialization.data(withJSONObject: action2_info, options: [])
        jsonString = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue)! as String
        self.action2_info = jsonString
        
        jsonData = try! JSONSerialization.data(withJSONObject: action3_info, options: [])
        jsonString = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue)! as String
        self.action3_info = jsonString
    }
    
    init(category_id: String, total_action_buttons: Int, action1_info: String, action2_info: String, action3_info: String) {
        self.category_id = category_id
        self.total_action_buttons = total_action_buttons
        
        self.action1_info = action1_info
        self.action2_info = action2_info
        self.action3_info = action3_info
    }
    
    func getAction1() -> NSDictionary{
        var action1_ns:NSDictionary = NSDictionary();
        
        if let data = action1_info.data(using: String.Encoding.utf8) {
            do {
                action1_ns = try JSONSerialization.jsonObject(with: data, options: []) as! NSDictionary
            } catch {}
        }
        
        return action1_ns
    }
    
    func getAction2() -> NSDictionary{
        var action2_ns:NSDictionary = NSDictionary();
        
        if let data = action2_info.data(using: String.Encoding.utf8) {
            do {
                action2_ns = try JSONSerialization.jsonObject(with: data, options: []) as! NSDictionary
            } catch {}
        }
        
        return action2_ns
    }
    
    func getAction3() -> NSDictionary{
        var action3_ns:NSDictionary = NSDictionary();
        
        if let data = action3_info.data(using: String.Encoding.utf8) {
            do {
                action3_ns = try JSONSerialization.jsonObject(with: data, options: []) as! NSDictionary
            } catch {}
        }
        
        return action3_ns
    }
}

extension String {
    func matchingStrings(regex: String) throws -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: []) else { return [] }
        let nsString = self as NSString
        let results  = regex.matches(in: self, options: [], range: NSMakeRange(0, nsString.length))
        return results.map { result in
            (0..<result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound
                    ? nsString.substring(with: result.range(at: $0))
                    : ""
            }
        }
    }
}
