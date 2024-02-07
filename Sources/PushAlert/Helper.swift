//
//  Helper.swift
//  
//
//  Created by Mohit Kuldeep on 04/02/23.
//

import SwiftUI
import WebKit

class Helper {
    static let PA_SETTINGS_AUTO_PROMPT_KEY = "auto_prompt"
    static let PA_SETTINGS_DELAY = "delay"
    static let PA_SETTINGS_PROVISIONAL_AUTHORIZATION = "provisional_auth"
    static let PA_SETTINGS_IN_APP_BEHAVIOUR = "in_app_behaviour"
    
    static var sendingSubsID = false;
    static let APP_ID_PREF = "PA_APP_ID";
    static let SUBSCRIBER_ID_PREF = "PA_SUBSCRIBER_ID";
    static let CURRENT_TOKEN_PREF = "PA_CURRENT_TOKEN";
    static let SUBSCRIPTION_STATUS_PREF = "PA_SUBSCRIPTION_STATUS";
    static let EXPLICITLY_PERMISSION_DENIED = "PA_EXPLICITLY_PERMISSION_DENIED";
    static let PA_ALL_NOTIFICATION_CATEGORIES = "pa_notification_categories_data"
    static let PA_CURRENT_BADGE_COUNT = "pa_notf_badge_count"
    
    static let ABANDONED_CART_DATA = "_pa_abandoned_cart";
    static let PRODUCT_ALERT_DATA = "_pa_product_alert_";
    private static let APP_VERSION = "_pa_app_version";
    
    static let PREFERENCE_LAST_NOTIFICATION_RECEIVED = "PA_LAST_NOTIFICATION_RECEIVED";
    static let PREFERENCE_LAST_NOTIFICATION_CLICKED = "PA_LAST_NOTIFICATION_CLICKED";
    static let PREFERENCE_ATTRIBUTION_TIME = "PA_PREFERENCE_ATTRIBUTION_TIME";
    static let EVENT_NOTIFICATION_RECEIVED = "pa_notification_received";
    static let EVENT_NOTIFICATION_CLICKED = "pa_notification_clicked";
    static let EVENT_NOTIFICATION_IMPACT = "pa_notification_impact";
    
    static let NOT_COMPLETED_TASKS = "PA_NOT_COMPLETED_TASKS";
    
    //private static let USER_SUBSCRIPTION_STATE = "PA_USER_SUBSCRIPTION_STATE";
    private static let USER_PRIVACY_CONSENT = "PA_USER_PRIVACY_CONSENT";
    private static let USER_PRIVACY_CONSENT_REQUIRED = "PA_USER_PRIVACY_CONSENT_REQUIRED";
    static let APP_NOTIFICATION_PERMISSION_STATE = "PA_APP_NOTIFICATION_PERMISSION_STATE";
    static let ENABLE_FIREBASE_ANALYTICS = "PA_ENABLE_FIREBASE_ANALYTICS";
    
    static let PUSHALERT_API_DOMAIN = "https://iosapi.pushalert.co/";
    static let PUSHALERT_APPS_DOMAIN = "https://iosapps.pushalert.co/";
    
    static let PA_SUBS_STATUS_SUBSCRIBED = 1;
    static let PA_SUBS_STATUS_UNSUBSCRIBED = -1;
    static let PA_SUBS_STATUS_DEFAULT = 0;
    static let PA_SUBS_STATUS_DENIED = -2;
    static let PA_SUBS_STATUS_UNSUBSCRIBED_NOTIFICATION_DISABLED = -3;
    
    static var pa_subs_id = ""
    
    
    public static func postRequest(url:String, queryParams:[URLQueryItem], authorization: Bool, completionBlock: @escaping ([String: Any], Bool) -> Void){
        
        let url = URL(string: url)!
        
        // create the session object
        let session = URLSession.shared
        
        // now create the URLRequest object using the url object
        var request = URLRequest(url: url)
        request.httpMethod = "POST" //set http method as POST
        
        // add headers for the request
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type") // change as per server requirements
        request.addValue("utf8", forHTTPHeaderField: "charset")
        //request.addValue("application/json", forHTTPHeaderField: "Accept")
        if (authorization) {
            request.addValue("pushalert_id=" + Helper.getAppId(), forHTTPHeaderField: "Authorization");
        }
        
        var requestBodyContent = URLComponents();
        requestBodyContent.queryItems = queryParams;
        
        request.httpBody = requestBodyContent.query?.data(using: .utf8)
        
        // create dataTask using the session object to send data to the server
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                LogM.error(message: "Post Request Error: \(error.localizedDescription)")
                return
            }
            // ensure there is valid response code returned from this HTTP response
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode)
            else {
                LogM.error(message: "Invalid Response received from the server - " + response!.description)
                return
            }
            // ensure there is data returned
            guard let responseData = data else {
                LogM.error(message: "nil Data received from the server")
                return
            }
            
            let dataString = String(data: responseData, encoding: .utf8)
            let data = dataString!.data(using: .utf8)!
            do {
                // create json object from data or use JSONDecoder to convert to Model stuct
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                    completionBlock(jsonResponse, true)
                } else {
                    LogM.error(message: "data maybe corrupted or in wrong format")
                    throw URLError(.badServerResponse)
                }
            } catch let error {
                LogM.error(message: error.localizedDescription)
            }
        }
        
        task.resume()
    }
    
    public static func getRequest(url:String, queryParams:[URLQueryItem]){
        
        let urlComponents = NSURLComponents(string: url)!
        urlComponents.queryItems = queryParams
        
        let finalUrl = urlComponents.url!
        
        // create the session object
        let session = URLSession.shared
        
        // now create the URLRequest object using the url object
        var request = URLRequest(url: finalUrl)
        request.httpMethod = "GET" //set http method as POST
        
        // create dataTask using the session object to send data to the server
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                LogM.error(message: "Get Request Error: \(error.localizedDescription)")
                return
            }
            // ensure there is valid response code returned from this HTTP response
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode)
            else {
                LogM.error(message: "Invalid Response received from the server - " + response!.description)
                return
            }
            // ensure there is data returned
            guard data != nil else {
                LogM.error(message: "nil Data received from the server")
                return
            }
        }
        
        task.resume()
    }
    
    static func checkAndConvert2Attributes(attr_text:[String : String], no_attr_text:[String : String]) -> [String : String]{
        var output:[String : String] = [:]
        
        for entry in attr_text {
            let msg = attr_text[entry.key];
            let msg_no_attr = no_attr_text[entry.key]!;
            
            output[entry.key] = processAttributes(attr_text: msg!, no_attr_text: msg_no_attr)
        }
        
        return output
    }
    
    static func processAttributes(attr_text:String, no_attr_text:String) -> String{
        if(attr_text==""){
            return no_attr_text;
        }
        
        var output = attr_text;
        var completed = true
        
        if let matches = try? output.matchingStrings(regex: "\\{\\{(.*?)\\}\\}"), matches.count>0 {
            for i in 0..<matches.count {
                if let attr_value = Helper.getAttribute(key: matches[i][1]) {
                    output = output.replacingOccurrences(of: matches[i][0], with: attr_value)
                }
                else{
                    completed = false
                    break;
                }
            }
        }
        
        if(completed) {
            return output;
        }
        else{
            return  no_attr_text;
        }
    }
    
    static func processAttributes(attr_text:String, attributes:[String:String]) -> String{
        if(attr_text==""){
            return attr_text
        }
        
        var output = attr_text;
        var completed = true
        
        if let matches = try? output.matchingStrings(regex: "\\{\\{(.*?)\\}\\}"), matches.count>0 {
            for i in 0..<matches.count {
                if attributes.index(forKey: matches[i][1]) != nil {
                    output = output.replacingOccurrences(of: matches[i][0], with: attributes[matches[i][1]]!)
                }
                else{
                    completed = false
                    break;
                }
            }
        }
        
        if(completed) {
            return output;
        }
        else{
            return  "-1";
        }
    }
    
    public static func logEvent(log:String){
        let queryItems = [
            URLQueryItem(name: "package_name", value: "com.inkwired.PhoneBunch"),
            URLQueryItem(name: "http_user_agent", value: ""),
            URLQueryItem(name: "log", value: log)
        ]
        
        getRequest(url: "https://api.pushalert.co/android-logs.php", queryParams: queryItems)
        
        
    }
    
    public static func registerToken(token:String){
        while (sendingSubsID) {
            usleep(500)
        }
        sendingSubsID = true;
        
        var queryItems:[URLQueryItem] = []
        
        let sharedPreference = getSharedPreferences();
        if let prevToken = sharedPreference.string(forKey: CURRENT_TOKEN_PREF) {
            if(prevToken == token){
                sharedPreference.set(PA_SUBS_STATUS_SUBSCRIBED, forKey: SUBSCRIPTION_STATUS_PREF);
                return
            }
            else{
                queryItems.append(URLQueryItem(name: "existing_id", value: prevToken))
            }
        }
        else{
            //New Subscription
        }
        
        let pushalert_info = Helper.getAppId().split(separator: "-")
        
        let screenSize: CGRect = UIScreen.main.bounds
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
        let userAgent = WKWebView().value(forKey: "userAgent");
        
        queryItems.append(URLQueryItem(name: "action", value: "subscribe"))
        queryItems.append(URLQueryItem(name: "pa_id", value: String(pushalert_info[1])))
        queryItems.append(URLQueryItem(name: "domain_id", value: String(pushalert_info[2])))
        queryItems.append(URLQueryItem(name: "host", value: String(pushalert_info[0])))
        queryItems.append(URLQueryItem(name: "packageName", value: getBundleIdentifier()))
        queryItems.append(URLQueryItem(name: "endpoint", value: token))
        queryItems.append(URLQueryItem(name: "type", value: isTablet() ? "tablet" : "mobile"));
        queryItems.append(URLQueryItem(name: "browser", value: "safari"))
        queryItems.append(URLQueryItem(name: "browserVer", value: "1"))
        queryItems.append(URLQueryItem(name: "browserMajor", value: "1.0"))
        queryItems.append(URLQueryItem(name: "os", value: "ios"))
        queryItems.append(URLQueryItem(name: "osVer", value: getOSInfo()))
        queryItems.append(URLQueryItem(name: "resoln_width", value: screenWidth.description))
        queryItems.append(URLQueryItem(name: "resoln_height", value: screenHeight.description))
        queryItems.append(URLQueryItem(name: "color_depth", value: "-1"))
        queryItems.append(URLQueryItem(name: "language", value: Locale.current.languageCode))
        queryItems.append(URLQueryItem(name: "engine", value: "na"))
        queryItems.append(URLQueryItem(name: "userAgent", value: userAgent as? String))
        queryItems.append(URLQueryItem(name: "endpoint_url", value: "safari"))
        queryItems.append(URLQueryItem(name: "subs_info", value: "{}"))
        queryItems.append(URLQueryItem(name: "referrer", value: "na"))
        queryItems.append(URLQueryItem(name: "subscription_url", value: "na"))
        queryItems.append(URLQueryItem(name: "app_type", value: "ios"))
        queryItems.append(URLQueryItem(name: "app_version", value: String(getAppVersionInt())))
        
        postRequest(url: Helper.PUSHALERT_APPS_DOMAIN + "subscribe/" + token, queryParams: queryItems, authorization: false){ (jsonOutput, success) in
            
            guard success else {
                sendingSubsID = false
                return
            }
            sharedPreference.set(jsonOutput["subs_id"] as! String, forKey: SUBSCRIBER_ID_PREF);
            sharedPreference.set(PA_SUBS_STATUS_SUBSCRIBED, forKey: SUBSCRIPTION_STATUS_PREF);
            sharedPreference.set(jsonOutput["attribution_time"] as! Int, forKey: PREFERENCE_ATTRIBUTION_TIME);
            sharedPreference.set(token, forKey: CURRENT_TOKEN_PREF);
            setAppVersionInit(syncVersion: false)
            
            if(jsonOutput.index(forKey: "updated_token")==nil || (jsonOutput["updated_token"] as! Bool)==false){
                if(jsonOutput["subs_id"] != nil) {
                    PushAlert.onSubscribeListener?.onSubscribe(subs_id: jsonOutput["subs_id"] as! String);
                }
                
                if((jsonOutput["welcome_enable"] as! Bool)==true){
                    if let data = (jsonOutput["welcome_data"] as! String).data(using: String.Encoding.utf8) {
                        do {
                            let welcome_data = try JSONSerialization.jsonObject(with: data, options: []) as! NSDictionary
                            Helper.processWelcomeNotification(welcome_data: welcome_data, sendReceivedReport: false)
                        } catch {
                        }
                    }
                }
                
                if let data = jsonOutput["attribution_time"] as? String {
                    Helper.setAttributionTime(attribution_time: data)
                }
            }
            sendingSubsID = false
            
        }
    }
    
    public static func processWelcomeNotification(welcome_data:NSDictionary, sendReceivedReport:Bool){
        let content = UNMutableNotificationContent()
        
        
        //adding title, subtitle, body and badge
        content.title = welcome_data["title"] as! String
        if(welcome_data.object(forKey: "sub_title") != nil){
            content.subtitle = welcome_data["sub_title"] as! String
        }
        //content.subtitle = "iOS Development is fun"
        content.body = welcome_data["body"] as! String
        content.badge = 1
        
        content.userInfo["url"] = welcome_data["url"] as! String
        content.userInfo["id"] = welcome_data["id"] as! Int
        content.userInfo["uid"] = "-1"
        content.userInfo["type"] = welcome_data["type"] as! Int
        
        if(welcome_data.object(forKey: "category_id") != nil){
            content.categoryIdentifier = welcome_data["category_id"] as! String
        }
        else{
            content.categoryIdentifier = "cat" + String(welcome_data["id"] as! Int)
        }
        
        //bestAttemptContent.badge = (5) as NSNumber
        var total_action_buttons = 0
        var action1_info:NSDictionary = NSDictionary()
        var action2_info:NSDictionary = NSDictionary()
        var action3_info:NSDictionary = NSDictionary()
        
        
        if(welcome_data.object(forKey: "total_action_buttons") != nil){
            total_action_buttons = (welcome_data["total_action_buttons"] as? Int)!
            content.userInfo["total_action_buttons"] = total_action_buttons
        }
        
        if(welcome_data.object(forKey: "action1_info") != nil){
            if let data = (welcome_data["action1_info"] as! String).data(using: String.Encoding.utf8) {
                do {
                    action1_info = try JSONSerialization.jsonObject(with: data, options: []) as! NSDictionary
                    content.userInfo["action1_info"] = action1_info
                    
                } catch {}
            }
        }
        
        if(welcome_data.object(forKey: "action2_info") != nil){
            if let data = (welcome_data["action2_info"] as! String).data(using: String.Encoding.utf8) {
                do {
                    action2_info = try JSONSerialization.jsonObject(with: data, options: []) as! NSDictionary
                    content.userInfo["action2_info"] = action2_info
                } catch {}
            }
        }
        
        if(welcome_data.object(forKey: "action3_info") != nil){
            if let data = (welcome_data["action3_info"] as! String).data(using: String.Encoding.utf8) {
                do {
                    action3_info = try JSONSerialization.jsonObject(with: data, options: []) as! NSDictionary
                    content.userInfo["action3_info"] = action3_info
                } catch {}
            }
        }
        
        
        let pa_notification_category = PANotificationCategory(category_id: content.categoryIdentifier, total_action_buttons: total_action_buttons, action1_info: action1_info, action2_info: action2_info, action3_info: action3_info)
        PushAlert.addCTAButtons(newNotificationCategory: pa_notification_category)
        
        if let imgURL = welcome_data["image"] as? String, imgURL != "" {
            if ((imgURL.contains("https://") || imgURL.contains("http://"))){
                
                let mediaUrl = URL(string: imgURL)
                let LPSession = URLSession(configuration: .default)
                LPSession.downloadTask(with: mediaUrl!, completionHandler: { temporaryLocation, response, error in
                    if let err = error {
                        LogM.error(message: "Error with downloading rich push: \(String(describing: err.localizedDescription))")
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                        
                        //getting the notification request
                        let request = UNNotificationRequest(identifier: "welcome_notification", content: content, trigger: trigger)
                        
                        //adding the notification to notification center
                        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                        
                        return;
                    }
                    
                    do {
                        let identifier = ProcessInfo.processInfo.globallyUniqueString
                        let target = FileManager.default.temporaryDirectory.appendingPathComponent(identifier).appendingPathExtension(mediaUrl!.pathExtension)
                        
                        try FileManager.default.moveItem(at: temporaryLocation!, to: target)
                        
                        let attachment = try UNNotificationAttachment(identifier: identifier, url: target, options: nil)
                        content.attachments.append(attachment)
                        
                        //trigger
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                        
                        //getting the notification request
                        let request = UNNotificationRequest(identifier: "welcome_notification", content: content, trigger: trigger)
                        
                        //adding the notification to notification center
                        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                    } catch {
                        LogM.error(message: "Error with the rich push attachment: \(error)")
                        //getting the notification trigger
                        //it will be called after 5 seconds
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                        
                        //getting the notification request
                        let request = UNNotificationRequest(identifier: "welcome_notification", content: content, trigger: trigger)
                        
                        //adding the notification to notification center
                        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                        
                        return;
                    }
                }).resume()
            }
            else {
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                
                //getting the notification request
                let request = UNNotificationRequest(identifier: "welcome_notification", content: content, trigger: trigger)
                
                //adding the notification to notification center
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            }
        }
        else {
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            
            //getting the notification request
            let request = UNNotificationRequest(identifier: "welcome_notification", content: content, trigger: trigger)
            
            //adding the notification to notification center
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
        
    }
    
    public static func notificationDeliveredReport(notification_info:[AnyHashable : Any]){
        let appId = Helper.getAppId();
        if(appId == ""){
            return
        }
        
        var queryItems:[URLQueryItem] = []
        
        let pushalert_info = appId.split(separator: "-")
        let sharedPreference = getSharedPreferences()
        
        queryItems.append(URLQueryItem(name: "user_id", value: String(pushalert_info[1])))
        queryItems.append(URLQueryItem(name: "domain_id", value: String(pushalert_info[2])))
        queryItems.append(URLQueryItem(name: "host", value: String(pushalert_info[0])))
        queryItems.append(URLQueryItem(name: "subs_id", value: sharedPreference.string(forKey: SUBSCRIBER_ID_PREF)))
        queryItems.append(URLQueryItem(name: "sent_time", value: notification_info["sent_time"] as? String))
        queryItems.append(URLQueryItem(name: "delivered_time", value: String(currentTimeInMilliSeconds()/1000)))
        //        queryItems.append(URLQueryItem(name: "http_user_agent", value: userAgent as? String))
        queryItems.append(URLQueryItem(name: "notification_id", value: notification_info["id"] as? String))
        queryItems.append(URLQueryItem(name: "type", value: notification_info["type"] as? String))
        queryItems.append(URLQueryItem(name: "device", value: isTablet() ? "tablet" : "mobile"))
        queryItems.append(URLQueryItem(name: "os", value: "ios"))
        queryItems.append(URLQueryItem(name: "osVer", value: getOSInfo()))
        queryItems.append(URLQueryItem(name: "nref_id", value: notification_info["nref_id"] as? String))
        
        
        //Helper.saveLastReceivedNotificationInfo(map.get("id"), map.containsKey("template_id") ? (map.get("template") + " (" + map.get("template_id") + ")") : "None");
        
        getRequest(url: PUSHALERT_API_DOMAIN + "deliveredApp.php", queryParams: queryItems);
        
        var campaign = "";
        if let tempCampaign = notification_info["campaign"] as? String {
            campaign = tempCampaign
        }
        Helper.saveLastReceivedNotificationInfo(notification_id: (notification_info["id"] as? String)!, campaign: campaign)
    }
    
    public static func notificationClickedReport(uid:String, notificationId:String, clicked_on:Int, type:String, eid:String){
        let appId = Helper.getAppId();
        if(appId == ""){
            return
        }
        
        var queryItems:[URLQueryItem] = []
        
        let pushalert_info = appId.split(separator: "-")
        let sharedPreference = getSharedPreferences()
        
        queryItems.append(URLQueryItem(name: "user_id", value: String(pushalert_info[1])));
        queryItems.append(URLQueryItem(name: "domain_id", value: String(pushalert_info[2])))
        queryItems.append(URLQueryItem(name: "host", value: String(pushalert_info[0])))
        queryItems.append(URLQueryItem(name: "subs_id", value: sharedPreference.string(forKey: SUBSCRIBER_ID_PREF)))
        queryItems.append(URLQueryItem(name: "uid", value: String(uid)))
        queryItems.append(URLQueryItem(name: "clicked_on", value: String(clicked_on)))
        queryItems.append(URLQueryItem(name: "clicked_time", value: String(currentTimeInMilliSeconds()/1000)))
        //        queryItems.append(URLQueryItem(name: "http_user_agent", value: userAgent as? String))
        queryItems.append(URLQueryItem(name: "notification_id", value: notificationId))
        queryItems.append(URLQueryItem(name: "type", value: type))
        queryItems.append(URLQueryItem(name: "eid", value: eid))
        queryItems.append(URLQueryItem(name: "device", value: isTablet() ? "tablet" : "mobile"))
        queryItems.append(URLQueryItem(name: "os", value: "ios"))
        queryItems.append(URLQueryItem(name: "browser", value: "safari"))
        queryItems.append(URLQueryItem(name: "osVer", value: getOSInfo()))
        
        
        getRequest(url: PUSHALERT_API_DOMAIN + "trackClickedApp.php", queryParams: queryItems);
    }
    
    public static func saveNotificationCategories(notificationCategory:PANotificationCategory) -> [PANotificationCategory] {
        
        var allCategories: [PANotificationCategory] = getNotificationCategories()
        let categoryLimit = 50
        allCategories.append(notificationCategory)
        if allCategories.count >= categoryLimit{
            allCategories.removeFirst()
        }
        //UserDefaults.standard.set(allCategories, forKey: PA_ALL_NOTIFICATION_CATEGORIES)
        do{
            let allCategoriesData = try JSONEncoder().encode(allCategories)
            UserDefaults.standard.set(allCategoriesData, forKey: PA_ALL_NOTIFICATION_CATEGORIES)
        }catch{}
        
        return allCategories
    }
    
    public static func getNotificationCategories() -> [PANotificationCategory] {
        var allCategories: [PANotificationCategory] = []
        if UserDefaults.standard.value(forKey: PA_ALL_NOTIFICATION_CATEGORIES) != nil {
            let allCategoriesData = UserDefaults.standard.data(forKey: PA_ALL_NOTIFICATION_CATEGORIES)
            do{
                allCategories = try JSONDecoder().decode([PANotificationCategory].self, from: allCategoriesData!)
            }
            catch {}
        }
        return allCategories
    }
    
    public static func getAppId() -> String{
        var appId = PushAlert.currAppId()
        if(appId==""){
            if let storedAppId = getSharedPreferences().string(forKey: APP_ID_PREF) {
                appId = storedAppId
            }
        }
        
        return appId
    }
    
    public static func getSystemVersion()->String{
        let systemVersion = UIDevice.current.systemVersion
        return systemVersion
    }
    
    public static func getDeviceName()->String{
        let deviceName = UIDevice.current.name
        return deviceName
    }
    
    static func getAppName()->String {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as! String
        return appName
    }
    
    static func getOSInfo()->String {
        let os = ProcessInfo().operatingSystemVersion
        return String(os.majorVersion) + "." + String(os.minorVersion) + "." + String(os.patchVersion)
    }
    
    static func getAppVersion() -> String {
        let dictionary = Bundle.main.infoDictionary!
        let version = dictionary["CFBundleShortVersionString"] as! String
        return "\(version)"
    }
    
    static func getAppVersionInt() -> Int {
        let version = getAppVersion()
        let versions_int = version.components(separatedBy: ".")
        
        let major:Int = Int(versions_int[0]) ?? 0
        let minor:Int = Int(versions_int[1]) ?? 0
        let patch:Int = Int(versions_int[2]) ?? 0
        
        return major * 1000000 + minor * 1000 + patch
    }
    
    static func currentTimeInMilliSeconds()-> Int64
    {
        let currentDate = Date()
        let since1970 = currentDate.timeIntervalSince1970
        return Int64(since1970 * 1000)
    }
    
    static func getUUID()->String
    {
        let device_id = UIDevice.current.identifierForVendor!.uuidString
        return device_id
    }
    
    static func getBundleIdentifier() -> String{
        let bundleIdentifier =  Bundle.main.bundleIdentifier
        return bundleIdentifier!.replacingOccurrences(of: ".PushAlertNotificationServiceExtension", with: "")
    }
    
    static func isTablet() -> Bool{
        if UIDevice.current.userInterfaceIdiom == .pad {
            return true
        } else {
            return false
        }
    }
    
    static func getSharedPreferences() -> UserDefaults{
        return UserDefaults(suiteName: "group." + getBundleIdentifier() + ".iwpa")!
    }
    
    static func isSubscribed() -> Bool{
        return getSharedPreferences().integer(forKey: SUBSCRIPTION_STATUS_PREF)==PA_SUBS_STATUS_SUBSCRIBED
    }
    
    static func getSubscriptionStatus() -> Int{
        return getSharedPreferences().integer(forKey: SUBSCRIPTION_STATUS_PREF)
    }
    
    static func setBadgeCount(badgeCount: Int) -> Void{
        //getSharedPreferences().setValue(badgeCount, forKey: PA_CURRENT_BADGE_COUNT)
        getSharedPreferences().set(badgeCount, forKey: PA_CURRENT_BADGE_COUNT)
        getSharedPreferences().synchronize()
    }
    
    static func setAppId(appId: String) -> Void{
        getSharedPreferences().set(appId, forKey: APP_ID_PREF)
        getSharedPreferences().synchronize()
    }
    
    static func getBadgeCount() -> Int{
        //return getSharedPreferences().integer(forKey: PA_CURRENT_BADGE_COUNT);
        return getSharedPreferences().integer(forKey: PA_CURRENT_BADGE_COUNT);
    }
    
    static func setAttribute(key:String, value:String){
        getSharedPreferences().set(value, forKey: "pa_attr_" + key)
    }
    
    static func getAttribute(key:String) -> String? {
        return getSharedPreferences().string(forKey: "pa_attr_" + key)
    }
    
    static func setCartAbandonedData(data:String) {
        getSharedPreferences().set(data, forKey: ABANDONED_CART_DATA)
    }
    
    static func getCartAbandonedData() -> String? {
        return getSharedPreferences().string(forKey: ABANDONED_CART_DATA)
    }
    
    static func setProductAlertData(key:String, value:String){
        getSharedPreferences().set(true, forKey: key)
        getSharedPreferences().set(value, forKey: PRODUCT_ALERT_DATA + key)
    }
    
    static func removeProductAlertData(key:String) {
        getSharedPreferences().removeObject(forKey: key)
        getSharedPreferences().removeObject(forKey: PRODUCT_ALERT_DATA + key)
    }
    
    static func getProductAlertData(key:String) -> String? {
        return getSharedPreferences().string(forKey: PRODUCT_ALERT_DATA + key)
    }
    
    @available(iOS 13.0.0, *)
    static func getOSNotificationPermissionState() async -> Bool{
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return (settings.authorizationStatus == .authorized)
    }
    
    static func syncOSNotificationPermissionState() {
        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { permission in
            if (permission.authorizationStatus == .authorized) {
                PushAlert.osPermissionState = PAOSPermissionState.ALLOWED
            }
            else if (permission.authorizationStatus == .denied) {
                PushAlert.osPermissionState = PAOSPermissionState.DENIED
            }
            else if (permission.authorizationStatus == .notDetermined) {
                PushAlert.osPermissionState = PAOSPermissionState.DEFAULT
            }
            else if (permission.authorizationStatus == .provisional) {
                PushAlert.osPermissionState = PAOSPermissionState.PROVISIONAL
            }
        })
    }
    
    static func setAppNotificationPermissionStateTask(subscriptionState: Bool){
        if Helper.isSubscribed(), let subs_id:String = PushAlert.getSubscriberID() {
            let queryItems:[URLQueryItem] = [
                URLQueryItem(name: "subscriber", value: subs_id),
                URLQueryItem(name: "is_active", value: subscriptionState ? "1" : "0")
            ]
            
            Helper.postRequest(url: PUSHALERT_API_DOMAIN + "app/v1/subscriptionState", queryParams: queryItems, authorization: true){ (jsonOutput, success) in
                
                if (jsonOutput.index(forKey: "success") != nil && jsonOutput["success"] as? Bool == true) {
                    getSharedPreferences().set(subscriptionState, forKey: APP_NOTIFICATION_PERMISSION_STATE)
                    
                    LogM.info(message: "Subscription state updated successfully to \(subscriptionState).")
                } else {
                    LogM.info(message: "Issue while updating user subscription state.")
                }
            }
        }
    }
    
    static func processReportConversion(notification_id:Int64, conversion_name:String, conversion_value:Double, direct:Int){
        if Helper.isSubscribed(), let subs_id:String = PushAlert.getSubscriberID() {
            
            let queryItems:[URLQueryItem] = [
                URLQueryItem(name: "subscriber", value: subs_id),
                URLQueryItem(name: "conversion_name", value: conversion_name),
                URLQueryItem(name: "notification_id", value: String(notification_id)),
                URLQueryItem(name: "conversion_value", value: String(format: "%.2f", conversion_value)),
                URLQueryItem(name: "conversion_direct", value: String(direct)),
            ]
            
            Helper.postRequest(url: PUSHALERT_API_DOMAIN + "app/v1/conversion", queryParams: queryItems, authorization: true){ (jsonOutput, success) in
                
                if (jsonOutput.index(forKey: "success") != nil && jsonOutput["success"] as? Bool == true) {
                    LogM.info(message: "Conversion reported successfully")
                } else {
                    LogM.info(message: "There was some issue while updating info.")
                }
            }
        }
    }
    
    static func saveLastClickedNotificationInfo(notification_id:String, campaign:String){
        var jsonObject:[String: String] = [:]
        jsonObject["notification_id"] = notification_id
        jsonObject["campaign"] = campaign
        jsonObject["time"] = String(currentTimeInMilliSeconds())
        let jsonData = try! JSONSerialization.data(withJSONObject: jsonObject, options: [])
        let jsonString = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue)! as String
        
        getSharedPreferences().setValue(jsonString, forKey: PREFERENCE_LAST_NOTIFICATION_CLICKED)
    }

    static func getLastClickedNotificationInfo() -> [String:String]? {

        do {
            if getSharedPreferences().object(forKey: PREFERENCE_LAST_NOTIFICATION_CLICKED) != nil {
                let last_notification_info = getSharedPreferences().string(forKey: PREFERENCE_LAST_NOTIFICATION_CLICKED)
                let data = last_notification_info!.data(using: .utf8)!
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: String] {
                    return jsonResponse
                } else {
                    return nil
                }
            }
            else{
                return nil
            }
        } catch {
        }

        return  nil
    }
    
    static func removeLastClickedNotificationInfo(){
        getSharedPreferences().removeObject(forKey: PREFERENCE_LAST_NOTIFICATION_CLICKED)
    }
    
    static func saveLastReceivedNotificationInfo(notification_id:String, campaign:String){
        var jsonObject:[String: String] = [:]
        jsonObject["notification_id"] = notification_id
        jsonObject["campaign"] = campaign
        jsonObject["time"] = String(currentTimeInMilliSeconds())
        let jsonData = try! JSONSerialization.data(withJSONObject: jsonObject, options: [])
        let jsonString = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue)! as String
        
        getSharedPreferences().setValue(jsonString, forKey: PREFERENCE_LAST_NOTIFICATION_RECEIVED)
    }

    static func getLastReceivedNotificationInfo() -> [String:String]? {

        do {
            if getSharedPreferences().object(forKey: PREFERENCE_LAST_NOTIFICATION_RECEIVED) != nil {
                let last_notification_info = getSharedPreferences().string(forKey: PREFERENCE_LAST_NOTIFICATION_RECEIVED)
                let data = last_notification_info!.data(using: .utf8)!
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: String] {
                    return jsonResponse
                } else {
                    return nil
                }
            }
            else{
                return nil
            }
        } catch {
        }

        return  nil
    }
    
    static func setAttributionTime(attribution_time:String){
        getSharedPreferences().setValue(attribution_time, forKey: PREFERENCE_ATTRIBUTION_TIME)
    }

    static func getAttributionTime() -> Int64 {
        if getSharedPreferences().object(forKey: PREFERENCE_ATTRIBUTION_TIME) != nil {
            return Int64(getSharedPreferences().string(forKey: PREFERENCE_ATTRIBUTION_TIME)!) ?? 86400000
        }
        else{
            return 86400000
        }
    }
    
    static func getConversionReceivedNotificationId() -> Int64{
        if let lastNotificationInfo:[String:String] = Helper.getLastReceivedNotificationInfo() {
            if(lastNotificationInfo.index(forKey: "notification_id") != nil){
                let lastNotificationTime = Int64(lastNotificationInfo["time"]!) ?? 0
                let attribution_time = Helper.getAttributionTime()
                if (lastNotificationTime >= currentTimeInMilliSeconds() - attribution_time) {
                    return Int64(lastNotificationInfo["notification_id"]!) ?? -1;
                }
            }
        }

        return  -1;
    }

    static func getConversionClickedNotificationId() -> Int64 {
        if let lastNotificationInfo:[String:String] = Helper.getLastClickedNotificationInfo() {
            if(lastNotificationInfo.index(forKey: "notification_id") != nil){
                return Int64(lastNotificationInfo["notification_id"]!) ?? -1;
            }
        }

        return  -1;
    }
    
    static func reportAnalytics(analyticsData:[[String:String]], conversionReceivedNotificationId:Int64){
        if Helper.isSubscribed(), let subs_id:String = PushAlert.getSubscriberID() {
            let analyticsJSONStr:String
            do{
                let data = try JSONEncoder().encode(analyticsData)
                analyticsJSONStr = String(data: data, encoding: .utf8)!
            }
            catch {return}
            
            var conversionNotificationId:Int64 = -1;
            let conversionClickedNotificationId = getConversionClickedNotificationId();
            
            var direct:Int = 0
            if(conversionClickedNotificationId != -1){
                conversionNotificationId = conversionClickedNotificationId;
                direct = 1;
            }
            else if(conversionReceivedNotificationId != -1){
                conversionNotificationId = conversionReceivedNotificationId;
            }
            
            //Reset
            Helper.removeLastClickedNotificationInfo();
            
            let finalConversionNotificationId = conversionNotificationId;
            let finalDirect = direct;
            
            
            let queryItems:[URLQueryItem] = [
                URLQueryItem(name: "subscriber", value: subs_id),
                URLQueryItem(name: "analytics", value: analyticsJSONStr),
                URLQueryItem(name: "conversion_notification_id", value: String(finalConversionNotificationId)),
                URLQueryItem(name: "conversion_direct", value: String(finalDirect)),
            ]
            
            Helper.postRequest(url: PUSHALERT_API_DOMAIN + "analyticsApp", queryParams: queryItems, authorization: true){ (jsonOutput, success) in
                
                if (jsonOutput.index(forKey: "success") != nil && jsonOutput["success"] as? Bool == true) {
                    LogM.info(message: "App analytics updated successfully");
                } else {
                    LogM.info(message: "There was some issue while updating app analytics");
                }
            }
        }
    }
    
    static func isAppUIScene() -> Bool {
        if #available(iOS 13.0, *) {
            return Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest") != nil
        }
        return false
    }
    
    static func getUrlSchemes() -> [String]{
        if let bundleURLTypes = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]],
           let appURLSchemes = bundleURLTypes.first?["CFBundleURLSchemes"] as? [String] {

            return appURLSchemes
        } else {
            return []
        }

    }
    
    static func setAppVersionInit(syncVersion:Bool){
        let version_stored = Helper.getSharedPreferences().integer(forKey: APP_VERSION);
        let current_version = getAppVersionInt()
        if (version_stored != current_version) {
            Helper.getSharedPreferences().set(current_version, forKey: APP_VERSION)

            if(syncVersion) {
                setAppVersion(appVersion: String(current_version));
            }
        }
    }

    static func setAppVersion(appVersion:String){
        PushAlert.addAttributes(attributes: [
            "pa_app_version": appVersion
        ])
    }
}

public enum AbandonedCartAction{
    case UPDATE, DELETE
}

public enum PAInAppBehaviour{
    case NONE, NOTIFICATION
}

public enum PAOSPermissionState{
    case ALLOWED, DENIED, DEFAULT, PROVISIONAL, NOT_SET
}

public enum PAOpenURLBehaviour{
    case WITHIN_APP_OVERLAY, WITHIN_APP_FULL_BROWSER, EXTERNAL_BROWSER
}
