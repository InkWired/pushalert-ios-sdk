//
//  SwiftUIView.swift
//  
//
//  Created by Mohit Kuldeep on 27/01/24.
//

public class PANotificationOpened {
    private var notification_id:Int64
    private var extraData:[String:String]
    private var url:String
    private var action_id:String
    private var category_id:String

    
    init(notification_id:Int64, url:String, category_id:String, action_id:String, extraData:[String:String]){
        self.notification_id = notification_id
        self.url = url
        self.extraData = extraData
        self.action_id = action_id
        self.category_id = category_id
    }

    public func getNotificationId() -> Int64 {
        return notification_id;
    }

    public func getExtraData() -> [String:String] {
        return extraData;
    }

    
    public func getUrl() -> String {
        return url;
    }
    
    public func getCategoryId() -> String {
        return category_id;
    }

    public func getActionId() -> String {
        let striped_action_id = action_id.replacingOccurrences(of: getCategoryId()+".", with: "")
        return striped_action_id;
    }
}
