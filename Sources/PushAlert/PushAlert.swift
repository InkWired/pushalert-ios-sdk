import SwiftUI
import SafariServices
import WebKit

@objc
public class PushAlert : NSObject {
    private static var app_id : String = ""
    private static var settings = Dictionary<String,Any>()
    private let application : UIApplication
    private static var token : String = ""
    private static var mInAppBehaviour : PAInAppBehaviour = PAInAppBehaviour.NOTIFICATION
    private static var mOpenURLBehaviour : PAOpenURLBehaviour = PAOpenURLBehaviour.WITHIN_APP_OVERLAY
    
    public static var onSubscribeListener : PushAlertSubscribeDelegate?
    public static var onNotificationOpened: PushAlertNotificationOpenerDelegate?
    public static var onForegroundNotificationReceived: PushAlertForegroundNotificationReceiverDelegate?
    
    static var osPermissionState:PAOSPermissionState = PAOSPermissionState.NOT_SET
    
    private static var analyticsData:[[String:String]] = [[String:String]]()
    private static var app_active_start_time = 0
    private static var conversionReceivedNotificationId:Int64 = -1;
    
    public init(application : UIApplication){
        self.application = application
    }
    
    @objc public static func initialize(app_id:String, application:UIApplication, settings:Dictionary<String, Any>){
        self.app_id = app_id
        self.settings = settings
        
        Helper.setAppId(appId: app_id)
        Helper.setBadgeCount(badgeCount: 0)
        application.applicationIconBadgeNumber = 0
        
        checkOSNotificationPermissionState()
        
        if(!settings.isEmpty){
            if(settings[Helper.PA_SETTINGS_IN_APP_BEHAVIOUR]! is PAInAppBehaviour){
                PushAlert.mInAppBehaviour = settings[Helper.PA_SETTINGS_IN_APP_BEHAVIOUR] as! PAInAppBehaviour
            }
        }
        
        let subscriptionStatus = Helper.getSubscriptionStatus()
        if(subscriptionStatus == Helper.PA_SUBS_STATUS_DEFAULT){
            if(!settings.isEmpty){
                
                let isAutoPromptEnabled:Bool = settings[Helper.PA_SETTINGS_AUTO_PROMPT_KEY]! is Bool ? settings[Helper.PA_SETTINGS_AUTO_PROMPT_KEY] as! Bool : true;
                let isProvisionalAuth:Bool = settings[Helper.PA_SETTINGS_PROVISIONAL_AUTHORIZATION]! is Bool ? settings[Helper.PA_SETTINGS_PROVISIONAL_AUTHORIZATION] as! Bool : false;
                
                let delay:Int = settings[Helper.PA_SETTINGS_DELAY]! is Int ? settings[Helper.PA_SETTINGS_DELAY] as! Int : 5
                
                if isAutoPromptEnabled {
                    //Request Permission
                    DispatchQueue.main.asyncAfter(deadline: .now() + DispatchTimeInterval.seconds(delay)) {
                        if(isProvisionalAuth){
                            registerForPushNotificationsProvisional()
                        }
                        else{
                            registerForPushNotifications()
                        }
                    }
                    
                }
            }
            else{
                //Request Permission
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    registerForPushNotifications()
                }
            }
        }
        else if(subscriptionStatus == Helper.PA_SUBS_STATUS_SUBSCRIBED){
            Helper.setAppVersionInit(syncVersion: true)
        }
        
        if Helper.isAppUIScene() {
            registerLifecycleObserverUIScene()
        } else {
            registerLifecycleObserverUIApp()
        }
    }
    
    static func registerLifecycleObserverUIScene(){
        if #available(iOS 13.0, *) {
            NotificationCenter.default.addObserver(self, selector: #selector(self.appBecomeActive), name: UIScene.didActivateNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.appEnteredBackground), name: UIScene.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.appWillResign), name: UIScene.willDeactivateNotification, object: nil)
        }
    }
    
    static func registerLifecycleObserverUIApp(){
        NotificationCenter.default.addObserver(self, selector: #selector(self.appBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.appEnteredBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.appWillResign), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    @objc static func appBecomeActive(){
        conversionReceivedNotificationId = Helper.getConversionReceivedNotificationId()
        app_active_start_time = Int(Helper.currentTimeInMilliSeconds()/1000)
        
        checkOSNotificationPermissionState { permissionState in
            let subscriptionStatus = Helper.getSubscriptionStatus()
            
            if(permissionState == PAOSPermissionState.DENIED){
                if (subscriptionStatus == Helper.PA_SUBS_STATUS_SUBSCRIBED) {
                    Helper.getSharedPreferences().set(Helper.PA_SUBS_STATUS_DENIED, forKey: Helper.SUBSCRIPTION_STATUS_PREF);
                }
            }
            else if(permissionState == PAOSPermissionState.ALLOWED){
                if (subscriptionStatus != Helper.PA_SUBS_STATUS_SUBSCRIBED) {
                    //Helper.getSharedPreferences().set(Helper.PA_SUBS_STATUS_SUBSCRIBED, forKey: Helper.SUBSCRIPTION_STATUS_PREF);
                    registerForPushNotifications()
                }
            }
        }
    }
    
    @objc static func appEnteredBackground(){
        Helper.reportAnalytics(analyticsData: analyticsData, conversionReceivedNotificationId: conversionReceivedNotificationId)
        analyticsData = [[String:String]]()
    }
    
    @objc static func appWillResign(){
        let time_spent:Int = Int(Helper.currentTimeInMilliSeconds()/1000) - app_active_start_time

        analyticsData.append([
            "url" : "",
            "title" : "",
            "time" : String(app_active_start_time),
            "time_spent": String(time_spent)
        ])

    }
    
    static func registerForPushNotificationsProvisional()
    {
        if #available(iOS 12.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .provisional]) {
                (allowed, error) in
                if allowed {
                    PushAlert.osPermissionState = PAOSPermissionState.ALLOWED
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                } else {
                    if(error == nil){
                        Helper.getSharedPreferences().set(Helper.PA_SUBS_STATUS_DENIED, forKey: Helper.SUBSCRIPTION_STATUS_PREF);
                    }
                    else{
                        LogM.error(message: "Error in registerForPushNotificationsProvisional: " + error.debugDescription)
                    }
                    return;
                }
            }
        }
    }
        
    public static func requestForPushNotificationPermission(){
        checkOSNotificationPermissionState { permissionState in
            
            if(permissionState == PAOSPermissionState.DENIED){
                PushAlert.openAppSettings(withAlert: true)
            }
            else{
                registerForPushNotifications()
            }
        }
    }
    
    static func registerForPushNotifications() {
        //UNUserNotificationCenter.current().delegate = UIApplication.shared.delegate! as? UNUserNotificationCenterDelegate
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (allowed, error) in
             //This callback does not trigger on main loop be careful
            if allowed {
                PushAlert.osPermissionState = PAOSPermissionState.ALLOWED
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                if(error == nil){
                    Helper.getSharedPreferences().set(Helper.PA_SUBS_STATUS_DENIED, forKey: Helper.SUBSCRIPTION_STATUS_PREF);
                }
                else{
                    LogM.error(message: "Error in registerForPushNotifications: " + error.debugDescription)
                }
                return;
            }
        }
        
    }
    
    public static func handleToken(token:Data){
        let tokenParts = token.map { data -> String in
            return String(format: "%02.2hhx", data)
        }
        let finalToken = tokenParts.joined()
        
        Helper.registerToken(token: finalToken)
        
    }
    
    static func currAppId() -> String{
        return app_id
    }
    
    public static func getAppId() -> String{
        return Helper.getAppId()
    }
    
    public static func handleNotificationClick(response:UNNotificationResponse) -> Void{
        
        let notification_info = response.notification.request.content.userInfo
        var clicked_on = 0
        var final_url = ""
        var action_id = "main"
        
        let actionIdentifier = response.actionIdentifier
        if actionIdentifier == UNNotificationDefaultActionIdentifier {
            clicked_on = 0;
            if(notification_info.index(forKey: "url") != nil){
                final_url = (notification_info["url"] as? String)!
            }
        } else {
            action_id = actionIdentifier
            //bestAttemptContent.badge = (5) as NSNumber
            var total_action_buttons = 0
            var action1_info:NSDictionary = NSDictionary();
            var action2_info:NSDictionary = NSDictionary();
            var action3_info:NSDictionary = NSDictionary();
            
            if(notification_info.index(forKey: "total_action_buttons") != nil){
                total_action_buttons = (notification_info["total_action_buttons"] as? Int)!
            }
            
            if(notification_info.index(forKey: "action1_info") != nil){
                action1_info = (notification_info["action1_info"] as? NSDictionary)!
            }
            
            if(notification_info.index(forKey: "action2_info") != nil){
                action2_info = (notification_info["action2_info"] as? NSDictionary)!
            }
            
            if(notification_info.index(forKey: "action3_info") != nil){
                action3_info = (notification_info["action3_info"] as? NSDictionary)!
            }
            
            let notificationCategory = PANotificationCategory(category_id: response.notification.request.content.categoryIdentifier, total_action_buttons: total_action_buttons, action1_info: action1_info, action2_info: action2_info, action3_info: action3_info)
            
            if(clicked_on == 0 && notificationCategory.total_action_buttons>=1){
                let action1 = notificationCategory.getAction1()
                var id1 = action1["id"] as! String
                id1 = notificationCategory.category_id + "." + id1
                
                if(id1 == actionIdentifier){
                    clicked_on = 1
                    final_url = (action1["url"] as? String)!
                }
            }
            
            if(clicked_on == 0 && notificationCategory.total_action_buttons>=2){
                let action2 = notificationCategory.getAction2()
                var id2 = action2["id"] as! String
                id2 = notificationCategory.category_id + "." + id2
                
                if(id2 == actionIdentifier){
                    clicked_on = 2
                    final_url = (action2["url"] as? String)!
                }
            }
            
            if(clicked_on == 0 && notificationCategory.total_action_buttons>=3){
                let action3 = notificationCategory.getAction3()
                var id3 = action3["id"] as! String
                id3 = notificationCategory.category_id + "." + id3
                
                if(id3 == actionIdentifier){
                    clicked_on = 3
                    final_url = (action3["url"] as? String)!
                }
            }
        }
        
        LogM.info(message: "Clicked Action - " + String(clicked_on))
        var notificationId = "";
        if let tempId = notification_info["id"] as? String {
            notificationId = tempId
        }
        else if let tempId = notification_info["id"] as? Int64 {
            notificationId = String(tempId)
        }
        
        var notification_type = "";
        if let tempId = notification_info["type"] as? String {
            notification_type = tempId
        }
        else if let tempId = notification_info["type"] as? Int {
            notification_type = String(tempId)
        }
        
        var uid = "";
        if let tempId = notification_info["uid"] as? String {
            uid = tempId
        }
        else if let tempId = notification_info["uid"] as? Int {
            uid = String(tempId)
        }
        
        var campaign = "";
        if let tempCampaign = notification_info["campaign"] as? String {
            campaign = tempCampaign
        }
        
        Helper.notificationClickedReport(uid: uid, notificationId: notificationId, clicked_on: clicked_on, type: notification_type, eid: "0")
        Helper.saveLastClickedNotificationInfo(notification_id: notificationId, campaign: campaign);
        
        if PushAlert.onNotificationOpened != nil {
            var reqExtraData = [String:String]()
            if let extra_data = notification_info["extraData"] as? String {
                let data = extra_data.data(using: .utf8)!
                do {
                    reqExtraData = try (JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: String])!
                }
                catch{}
            }
            
            let paNotificationOpened:PANotificationOpened = PANotificationOpened(notification_id: Int64(notificationId)!, url: final_url, category_id: response.notification.request.content.categoryIdentifier,action_id: action_id, extraData: reqExtraData)
            
            PushAlert.onNotificationOpened?.notificationOpened(paNotificationOpened: paNotificationOpened)
        }
        else{
            let urlRequired:String = final_url
            if let url = URL(string: urlRequired) {
                if let urlScheme:String = url.scheme, Helper.getUrlSchemes().contains(urlScheme), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                } else if UIApplication.shared.canOpenURL(url) {
                    if(PushAlert.mOpenURLBehaviour == PAOpenURLBehaviour.WITHIN_APP_OVERLAY){
                        WebViewPA.url2Open = urlRequired
                        UIApplication.shared.keyWindow!.rootViewController?.present(WebViewPA(), animated: true, completion: nil)
                    }
                    else if(PushAlert.mOpenURLBehaviour == PAOpenURLBehaviour.WITHIN_APP_FULL_BROWSER){
                        let safariVC = SFSafariViewController(url: url)
                        UIApplication.shared.keyWindow!.rootViewController?.present(safariVC, animated: true, completion: nil)
                    }
                    else{
                        UIApplication.shared.open(url)
                    }
                } else {
                    // Handle the case where the URL cannot be opened
                    LogM.error(message: "URL cannot be opened")
                }
            }
        }
    }
    
    public static func handleForegroundNotification(notification:UNNotification, completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) -> Void{
        
        var showNotification = true
        if PushAlert.onForegroundNotificationReceived != nil {
            let paNotification = getPANotification(content: notification.request.content)
            
            showNotification = !(PushAlert.onForegroundNotificationReceived?.foregroundNotificationReceived(notification: paNotification) ?? false)
        }
        
        if(showNotification && PushAlert.mInAppBehaviour == PAInAppBehaviour.NOTIFICATION){
            if #available(iOS 14.0, *) {
                completionHandler([.banner, .badge, .sound, .list])
            } else {
                // Fallback on earlier versions
                completionHandler([.alert, .badge, .sound])
            }
        }
    }
    
    @available(iOS 11.0, *)
    @objc public static func didReceiveNotificationRequestFromExtension(request:UNNotificationRequest, bestAttemptContent: UNMutableNotificationContent, contentHandler:((UNNotificationContent) -> Void)?) -> Void{
        
        //On Notification Delivery
        Helper.logEvent(log: request.content.userInfo.description)
        
        Helper.notificationDeliveredReport(notification_info: bestAttemptContent.userInfo)
        
        if(bestAttemptContent.userInfo.index(forKey: "badge_value") != nil){
            if let badge_value = bestAttemptContent.userInfo["badge_value"] as? String{
                if let intValue = Int(badge_value) {
                    if(intValue > 0){
                        let newBadgeCount = Helper.getBadgeCount() + intValue
                        bestAttemptContent.badge = newBadgeCount as NSNumber
                        Helper.setBadgeCount(badgeCount: newBadgeCount)
                    }
                    else{
                        Helper.setBadgeCount(badgeCount: 0)
                    }
                }
            }
        }
        
        //bestAttemptContent.badge = (5) as NSNumber
        var total_action_buttons = 0
        var action1_info:NSDictionary = NSDictionary();
        var action2_info:NSDictionary = NSDictionary();
        var action3_info:NSDictionary = NSDictionary();
        
        if(bestAttemptContent.userInfo.index(forKey: "total_action_buttons") != nil){
            total_action_buttons = (bestAttemptContent.userInfo["total_action_buttons"] as? Int)!
        }
        
        if(bestAttemptContent.userInfo.index(forKey: "action1_info") != nil){
            action1_info = (bestAttemptContent.userInfo["action1_info"] as? NSDictionary)!
        }
        
        if(bestAttemptContent.userInfo.index(forKey: "action2_info") != nil){
            action2_info = (bestAttemptContent.userInfo["action2_info"] as? NSDictionary)!
        }
        
        if(bestAttemptContent.userInfo.index(forKey: "action3_info") != nil){
            action3_info = (bestAttemptContent.userInfo["action3_info"] as? NSDictionary)!
        }
        
        var title_attr="", sub_title_attr="", message_attr=""
        var attr_text:[String:String] = [:], no_attr_text:[String:String] = [:]
        if(bestAttemptContent.userInfo.index(forKey: "title_attr") != nil){
            attr_text["title"] = (bestAttemptContent.userInfo["title_attr"] as? String)!
            title_attr = attr_text["title"]!
            no_attr_text["title"] = bestAttemptContent.title
        }
        if(bestAttemptContent.userInfo.index(forKey: "message_attr") != nil){
            attr_text["message"] = (bestAttemptContent.userInfo["message_attr"] as? String)!
            message_attr = attr_text["message"]!
            no_attr_text["message"] = bestAttemptContent.body
        }
        if(bestAttemptContent.userInfo.index(forKey: "sub_title_attr") != nil){
            attr_text["sub_title"] = (bestAttemptContent.userInfo["sub_title_attr"] as? String)!
            sub_title_attr = attr_text["sub_title"]!
            no_attr_text["sub_title"] = bestAttemptContent.subtitle
        }
        if(bestAttemptContent.userInfo.index(forKey: "url_attr") != nil){
            attr_text["url"] = (bestAttemptContent.userInfo["url_attr"] as? String)!
            if(bestAttemptContent.userInfo.index(forKey: "url") != nil){
                no_attr_text["url"] = (bestAttemptContent.userInfo["url"] as? String)!
            }
        }
        
        let converted = Helper.checkAndConvert2Attributes(attr_text: attr_text, no_attr_text: no_attr_text)
        
        for entry in converted {
            if (entry.key == "title"){
                bestAttemptContent.title = entry.value
            }
            else if (entry.key == "message"){
                bestAttemptContent.body = entry.value
            }
            else if (entry.key == "sub_title"){
                bestAttemptContent.subtitle = entry.value
            }
            else if (entry.key == "url"){
                bestAttemptContent.userInfo["url"] = entry.value
            }
        }
        
        if let notification_type:String = bestAttemptContent.userInfo["type"] as? String {
            if (notification_type=="501") {
                if let attributes_str:String = Helper.getCartAbandonedData() {
                    let data = attributes_str.data(using: .utf8)!
                    do{
                        if let attributes = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: String] {
                            let new_title = Helper.processAttributes(attr_text: title_attr, attributes: attributes)
                            let new_sub_title = Helper.processAttributes(attr_text: sub_title_attr, attributes: attributes)
                            let new_message = Helper.processAttributes(attr_text: message_attr, attributes: attributes)
                            
                            if(new_title != "-1" && new_sub_title != "-1" && new_message != "-1"){
                                bestAttemptContent.title = new_title
                                bestAttemptContent.subtitle = new_sub_title
                                bestAttemptContent.body = new_message;
                            }
                            
                            if(attributes.index(forKey: "cart_url") != nil){
                                bestAttemptContent.userInfo["url"] = attributes["cart_url"]!;
                            }
        
                            if(attributes.index(forKey: "checkout_url") != nil){
                                let temp_action1_info:NSMutableDictionary = action1_info.mutableCopy() as! NSMutableDictionary
                                temp_action1_info["url"] = attributes["checkout_url"]
                                action1_info = temp_action1_info
                                bestAttemptContent.userInfo["action1_info"] = action1_info
                            }
                        }
                    }
                    catch {
                        LogM.error(message: "Error while decoding JSON for abandoned cart extra info.")
                    }
                }
            }
            else if (notification_type=="32" || notification_type=="33"){
                if let ls_id:String = bestAttemptContent.userInfo["ls_id"] as? String {
                    do{
                        if let product_alert_data:String = Helper.getProductAlertData(key: ls_id){
                            let data = product_alert_data.data(using: .utf8)!
                            if let attributes = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: String] {
                                let new_title = Helper.processAttributes(attr_text: bestAttemptContent.title, attributes: attributes)
                                let new_sub_title = Helper.processAttributes(attr_text: bestAttemptContent.subtitle, attributes: attributes)
                                let new_message = Helper.processAttributes(attr_text: bestAttemptContent.body, attributes: attributes)
                                
                                if(new_title != "-1" && new_sub_title != "-1" && new_message != "-1"){
                                    bestAttemptContent.title = new_title
                                    bestAttemptContent.subtitle = new_sub_title
                                    bestAttemptContent.body = new_message;
                                }
                            }
                        }
                    }
                    catch {
                        LogM.error(message: "Error while decoding JSON for product alert extra info.")
                    }
                }
            }
            
        }
        
        let pa_notification_category = PANotificationCategory(category_id: bestAttemptContent.categoryIdentifier, total_action_buttons: total_action_buttons, action1_info: action1_info, action2_info: action2_info, action3_info: action3_info)
        addCTAButtons(newNotificationCategory: pa_notification_category)
        
        if let imgURL = bestAttemptContent.userInfo["large_image"] as? String, imgURL != "" {
            if(imgURL.contains("https://") || imgURL.contains("http://")){
                
                
                let mediaUrl = URL(string: imgURL)
                let LPSession = URLSession(configuration: .default)
                LPSession.downloadTask(with: mediaUrl!, completionHandler: { temporaryLocation, response, error in
                    if let err = error {
                        LogM.error(message: "Error with downloading rich push: \(String(describing: err.localizedDescription))")
                        contentHandler!(bestAttemptContent)
                        return;
                    }
                    
                    let fileType = determineType(fileType: (response?.mimeType)!)
                    let fileName = temporaryLocation?.lastPathComponent.appending(fileType)
                    
                    let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName!)
                    
                    do {
                        try FileManager.default.moveItem(at: temporaryLocation!, to: temporaryDirectory)
                        let attachment = try UNNotificationAttachment(identifier: "", url: temporaryDirectory, options: nil)
                        
                        bestAttemptContent.attachments = [attachment];
                        contentHandler!(bestAttemptContent)
                        // The file should be removed automatically from temp
                        // Delete it manually if it is not
                        if FileManager.default.fileExists(atPath: temporaryDirectory.path) {
                            try FileManager.default.removeItem(at: temporaryDirectory)
                        }
                    } catch {
                        LogM.error(message: "Error with the rich push attachment: \(error)")
                        contentHandler!(bestAttemptContent)
                        return;
                    }
                }).resume()
            }
//            else{
//                Helper.logEvent(log: "Local Image is " + imgURL)
//                if let url = Bundle.main.url(forResource: imgURL, withExtension: "png"){
//                    Helper.logEvent(log: "URL Local Image")
//                    if let attachment = try? UNNotificationAttachment(identifier: "image", url: url, options: nil){
//                        bestAttemptContent.attachments = [attachment]
//                        Helper.logEvent(log: "Attaching Local Image")
//                    }
//                }
//
//                contentHandler!(bestAttemptContent)
//            }

        }
        else{
            contentHandler!(bestAttemptContent)
        }
        
        
        //contentHandler!(bestAttemptContent)
    }
    
    static func determineType(fileType: String) -> String {
        // Determines the file type of the attachment to append to URL.
        if fileType == "image/jpeg" {
            return ".jpg";
        }
        if fileType == "image/gif" {
            return ".gif";
        }
        if fileType == "image/png" {
            return ".png";
        } else {
            return ".tmp";
        }
    }
    
    static func addCTAButtons(newNotificationCategory:PANotificationCategory){
        
        if(newNotificationCategory.total_action_buttons == 0 || newNotificationCategory.category_id == ""){
            return;
        }
        
        let allNotificationCategories = Helper.saveNotificationCategories(notificationCategory: newNotificationCategory)
        var notificationCategories: Set<UNNotificationCategory> = []
        
        var notificationCategoriesMap: [String:UNNotificationCategory] = [String:UNNotificationCategory]()
        
        let center: UNUserNotificationCenter = UNUserNotificationCenter.current()
        var count = 0
        for i in 0..<allNotificationCategories.count {
            let notificationCategory = allNotificationCategories[i]
            count = count + 1
            
            let categoryId = notificationCategory.category_id
            
            var allActions:[UNNotificationAction] = []
            
            //let categoryId = "actionBtnCategory"
            let action1 = notificationCategory.getAction1()
            var id1 = action1["id"] as! String
            id1 = categoryId + "." + id1
            
            if let name1 = action1["title"] as? String {
                
                var firstAction:UNNotificationAction
                if #available(iOS 15.0, *), let icon1 = action1["icon"] as? String {
                    let icon_system1 = action1["icon_system"] as! Int
                    if(icon_system1 == 1){
                        firstAction = UNNotificationAction( identifier: id1, title: "\(name1)", options: .foreground, icon: UNNotificationActionIcon(systemImageName: icon1))
                    }
                    else{
                        firstAction = UNNotificationAction( identifier: id1, title: "\(name1)", options: .foreground, icon: UNNotificationActionIcon(templateImageName: icon1))
                    }
                } else {
                    firstAction = UNNotificationAction( identifier: id1, title: "\(name1)", options: .foreground)
                }
                allActions.append(firstAction)
                
                if(notificationCategory.total_action_buttons>=2){
                    let action2 = notificationCategory.getAction2()
                    var id2 = action2["id"] as! String
                    id2 = categoryId + "." + id2
                    
                    if let name2 = action2["title"] as? String {
                        var secondAction:UNNotificationAction
                        if #available(iOS 15.0, *), let icon2 = action2["icon"] as? String {
                            let icon_system2 = action2["icon_system"] as! Int
                            if(icon_system2 == 1){
                                secondAction = UNNotificationAction( identifier: id2, title: "\(name2)", options: .foreground, icon: UNNotificationActionIcon(systemImageName: icon2))
                            }
                            else{
                                secondAction = UNNotificationAction( identifier: id2, title: "\(name2)", options: .foreground, icon: UNNotificationActionIcon(templateImageName: icon2))
                            }
                        } else {
                            secondAction = UNNotificationAction( identifier: id2, title: "\(name2)", options: .foreground)
                        }
                        allActions.append(secondAction)
                    }
                    
                }
                
                if(notificationCategory.total_action_buttons>=3){
                    let action3 = notificationCategory.getAction3()
                    var id3 = action3["id"] as! String
                    id3 = categoryId + "." + id3
                    
                    if let name3 = action3["title"] as? String {
                        var thirdAction:UNNotificationAction
                        if #available(iOS 15.0, *), let icon3 = action3["icon"] as? String {
                            let icon_system3 = action3["icon_system"] as! Int
                            if(icon_system3 == 1){
                                thirdAction = UNNotificationAction( identifier: id3, title: "\(name3)", options: .foreground, icon: UNNotificationActionIcon(systemImageName: icon3))
                            }
                            else{
                                thirdAction = UNNotificationAction( identifier: id3, title: "\(name3)", options: .foreground, icon: UNNotificationActionIcon(templateImageName: icon3))
                            }
                        } else {
                            thirdAction = UNNotificationAction( identifier: id3, title: "\(name3)", options: .foreground)
                        }
                        allActions.append(thirdAction)
                    }
                    
                }
            }
            let category = UNNotificationCategory( identifier: categoryId, actions: allActions, intentIdentifiers: [], options: [])
              
            notificationCategoriesMap[categoryId] = category
            //notificationCategories.insert(category)
        }
        for (_, value) in notificationCategoriesMap {
            notificationCategories.insert(value)
        }
        
        center.setNotificationCategories(notificationCategories)
        
    }
    
    static func logEvent(log:String){
        Helper.logEvent(log: log)
    }
    
    public static func getBadgeCount() -> Int{
        return Helper.getBadgeCount()
    }
    
    public static func getSubscriberID() -> String?{
        var subsId:String?
        if let savedSubsId = Helper.getSharedPreferences().string(forKey: Helper.SUBSCRIBER_ID_PREF) {
            subsId = savedSubsId
        }
        
        return subsId
    }
    
    public static func enableDebug(enable:Bool){
        LogM.enableDebug(enable: enable)
    }
    
    public static func addAttributes(attributes: [String: String]){
        
        if Helper.isSubscribed(), let subs_id:String = getSubscriberID() {
            
            do {
                let jsonEncoder = JSONEncoder()
                let json = try jsonEncoder.encode(attributes)
                let jsonString = String(data: json, encoding: .utf8)
                
                let queryItems:[URLQueryItem] = [
                    URLQueryItem(name: "subscriber", value: subs_id),
                    URLQueryItem(name: "attributes", value: jsonString)
                ]
               
                Helper.postRequest(url: Helper.PUSHALERT_API_DOMAIN + "app/v1/attribute/put", queryParams: queryItems, authorization: true){ (jsonOutput, success) in
                    
                    if (jsonOutput.index(forKey: "success") != nil && jsonOutput["success"] as? Bool == true) {
                        LogM.info(message: "Added attributes successfully")
                        
                        for attribute in attributes {
                            Helper.setAttribute(key: attribute.key, value: attribute.value)
                        }
                        
                    } else {
                        LogM.info(message: "Issue while adding attributes")
                    }
                }
            }
            catch{}
        }
        
    }
    
    public static func addUserToSegment(seg_id:Int){
        if Helper.isSubscribed(), let subs_id:String = getSubscriberID() {
            let queryItems:[URLQueryItem] = [
                URLQueryItem(name: "subscribers", value: "[\"" + subs_id + "\"]")
            ]
            
            Helper.postRequest(url: Helper.PUSHALERT_API_DOMAIN + "app/v1/segment/" + String(seg_id) + "/add", queryParams: queryItems, authorization: true){ (jsonOutput, success) in
                
                if (jsonOutput.index(forKey: "success") != nil && jsonOutput["success"] as? Bool == true) {
                    LogM.info(message: "User added to segment successfully")
                } else {
                    LogM.info(message: "Issue while adding subscriber to segment")
                }
            }
        }
    }
    
    public static func removeUserFromSegment(seg_id:Int){
        if Helper.isSubscribed(), let subs_id:String = getSubscriberID() {
            let queryItems:[URLQueryItem] = [
                URLQueryItem(name: "subscribers", value: "[\"" + subs_id + "\"]")
            ]
            
            Helper.postRequest(url: Helper.PUSHALERT_API_DOMAIN + "app/v1/segment/" + String(seg_id) + "/remove", queryParams: queryItems, authorization: true){ (jsonOutput, success) in
                
                if (jsonOutput.index(forKey: "success") != nil && jsonOutput["success"] as? Bool == true) {
                    LogM.info(message: "Subscriber removed from the segment.")
                } else {
                    LogM.info(message: "Issue while removing subscriber from segment")
                }
            }
        }
    }
    
    static func processTriggerEvent(eventCategory:String, eventAction:String, eventLabel:String, eventValue:Int){
        if Helper.isSubscribed(), let subs_id:String = getSubscriberID() {
            let queryItems:[URLQueryItem] = [
                URLQueryItem(name: "subscriber", value: subs_id),
                URLQueryItem(name: "eventCategory", value: eventCategory),
                URLQueryItem(name: "eventAction", value: eventAction),
                URLQueryItem(name: "eventLabel", value: eventLabel),
                URLQueryItem(name: "eventValue", value: String(eventValue))
            ]
            
            Helper.postRequest(url: Helper.PUSHALERT_API_DOMAIN + "app/v1/track/event", queryParams: queryItems, authorization: true){ (jsonOutput, success) in
                
                if (jsonOutput.index(forKey: "success") != nil && jsonOutput["success"] as? Bool == true) {
                    LogM.info(message: "Event registered successfully")
                } else {
                    LogM.info(message: "There was some issue while registering event")
                }
            }
        }
    }
    
    public static func triggerEvent(eventCategory:String, eventAction:String, eventLabel:String, eventValue:Int){
        processTriggerEvent(eventCategory: eventCategory, eventAction: eventAction, eventLabel: eventLabel, eventValue: eventValue)
    }

    public static func triggerEvent(eventCategory:String, eventAction:String, eventLabel:String){
        processTriggerEvent(eventCategory: eventCategory, eventAction: eventAction, eventLabel: eventLabel, eventValue: 0)
    }

    public static func ttriggerEvent(eventCategory:String, eventAction:String){
        processTriggerEvent(eventCategory: eventCategory, eventAction: eventAction, eventLabel: "", eventValue: 0)
    }
    
    public static func associateID(id:String){
        PushAlert.addAttributes(attributes: [
            "_assoc_id": id
        ])
    }
    
    public static func setEmail(email:String){
        PushAlert.addAttributes(attributes: [
            "pa_email": email
        ])
    }
    
    public static func setAge(age:Int){
        PushAlert.addAttributes(attributes: [
            "pa_age": String(age)
        ])
    }
    
    public static func setGender(gender:String){
        PushAlert.addAttributes(attributes: [
            "pa_gender": String(gender)
        ])
    }
    
    public static func setFirstName(firstName:String){
        PushAlert.addAttributes(attributes: [
            "pa_first_name": String(firstName)
        ])
    }
    
    public static func setLastName(lastName:String){
        PushAlert.addAttributes(attributes: [
            "pa_last_name": String(lastName)
        ])
    }
    
    public static func setPhoneNum(phoneNum:String){
        PushAlert.addAttributes(attributes: [
            "pa_phone_num": String(phoneNum)
        ])
    }
    
    public static func processAbandonedCart(action:AbandonedCartAction, data:[String:String]?){
        if Helper.isSubscribed(), let subs_id:String = getSubscriberID() {
            var queryItems:[URLQueryItem] = [
                URLQueryItem(name: "subscriber", value: subs_id)
            ]
            
            var jsonData = ""
            
            if(data != nil){
                do {
                    let jsonEncoder = JSONEncoder()
                    let json = try jsonEncoder.encode(data)
                    jsonData = String(data: json, encoding: .utf8)!
                    queryItems.append(URLQueryItem(name: "extra_info", value: jsonData))
                }
                catch {}
            }
            
            var uri = Helper.PUSHALERT_API_DOMAIN + "app/v1/abandonedCart";
            if(action==AbandonedCartAction.DELETE){
                uri = Helper.PUSHALERT_API_DOMAIN + "app/v1/abandonedCart/delete";
            }
            
            Helper.postRequest(url: uri, queryParams: queryItems, authorization: true){ (jsonOutput, success) in
                
                if (jsonOutput.index(forKey: "success") != nil && jsonOutput["success"] as? Bool == true) {
                    LogM.info(message: "AbandonedCart action performed successfully: " + "\(action)")
                    Helper.setCartAbandonedData(data: jsonData)
                } else {
                    LogM.info(message: "There was some issue while processing abandoned cart.")
                }
            }
        }
    }
    
    static func productAlert(type:String, action:String, product_id:Int, variant_id:Int, price:Double, extras:[String:String]?){
        if Helper.isSubscribed(), let subs_id:String = getSubscriberID() {
            var queryItems:[URLQueryItem] = [
                URLQueryItem(name: "subscriber", value: subs_id),
                URLQueryItem(name: "product_id", value: String(product_id)),
                URLQueryItem(name: "variant_id", value: String(variant_id)),
                URLQueryItem(name: "price", value: String(price)),
                URLQueryItem(name: "type", value: type),
                URLQueryItem(name: "alert_action", value: action)
            ]
            
            var jsonData = ""
            
            if(extras != nil){
                do {
                    let jsonEncoder = JSONEncoder()
                    let json = try jsonEncoder.encode(extras)
                    jsonData = String(data: json, encoding: .utf8)!
                    queryItems.append(URLQueryItem(name: "extras", value: jsonData))
                }
                catch {}
            }
            
            let url = Helper.PUSHALERT_API_DOMAIN + "app/v1/productAlert";
            
            Helper.postRequest(url: url, queryParams: queryItems, authorization: true){ (jsonOutput, success) in
                
                if (jsonOutput.index(forKey: "success") != nil && jsonOutput["success"] as? Bool == true) {
                    if(type == "oos"){
                        if(action=="add"){
                            LogM.info(message: "Product out of stock alert successfully added.")
                            Helper.setProductAlertData(key: "pushalert_oos_" + String(product_id) + "_" + String(variant_id), value: jsonData)
                        }
                        else{
                            LogM.info(message: "Product out of stock alert successfully removed.")
                            Helper.removeProductAlertData(key: "pushalert_oos_" + String(product_id) + "_" + String(variant_id))
                        }
                    }
                    else if(type == "price_drop"){
                        if(action=="add"){
                            LogM.info(message: "Product price drop alert successfully added.")
                            Helper.setProductAlertData(key: "pushalert_price_drop_" + String(product_id) + "_" + String(variant_id), value: jsonData)
                        }
                        else{
                            LogM.info(message: "Product price drop alert successfully removed.")
                            Helper.removeProductAlertData(key: "pushalert_price_drop_" + String(product_id) + "_" + String(variant_id))
                        }
                    }
                } else {
                    LogM.info(message: "There was some issue while processing product alerts")
                }
            }
        }
    }
    
    public static func addOutOfStockAlert(product_id:Int, variant_id:Int, price:Double, extras:[String:String]?){
        productAlert(type: "oos", action: "add", product_id: product_id, variant_id: variant_id, price: price, extras: extras)
    }
    
    public static func removedOutOfStockAlert(product_id:Int, variant_id:Int){
        productAlert(type: "oos", action: "remove", product_id: product_id, variant_id: variant_id, price: 0, extras: nil)
    }
    
    public static func isOutOfStockEnabled(product_id:Int, variant_id:Int) -> Bool {
        return Helper.getSharedPreferences().bool(forKey: "pushalert_oos_" + String(product_id) + "_" + String(variant_id))
    }
    
    public static func addPriceDropAlert(product_id:Int, variant_id:Int, price:Double, extras:[String:String]?){
        productAlert(type: "price_drop", action: "add", product_id: product_id, variant_id: variant_id, price: price, extras: extras)
    }
    
    public static func removePriceDropAlert(product_id:Int, variant_id:Int){
        productAlert(type: "price_drop", action: "remove", product_id: product_id, variant_id: variant_id, price: 0, extras: nil)
    }
    
    public static func isPriceDropEnabled(product_id:Int, variant_id:Int) -> Bool {
        return Helper.getSharedPreferences().bool(forKey: "pushalert_price_drop_" + String(product_id) + "_" + String(variant_id))
    }
    
    public static func isUserSubscribed() -> Bool {
        return Helper.isSubscribed()
    }
    
    @available(iOS 13.0.0, *)
    public static func hasOSNotificationPermission() async -> Bool {
        return (await Helper.getOSNotificationPermissionState())
        
    }
    
    public static func disableNotification(disable:Bool) {
        Helper.setAppNotificationPermissionStateTask(subscriptionState: !disable)
    }
    
    public static func isNotificationDisabled() -> Bool {
        let sharedPref = Helper.getSharedPreferences()
        if(sharedPref.object(forKey: Helper.APP_NOTIFICATION_PERMISSION_STATE) != nil){
            return !sharedPref.bool(forKey: Helper.APP_NOTIFICATION_PERMISSION_STATE)
        }
        else{
            return false
        }
    }
    
    public static func reportConversionWithValue(conversion_name:String, conversion_value:Double){
        var conversionNotificationId:Int64 = -1;

        let conversionReceivedNotificationId:Int64 = Helper.getConversionReceivedNotificationId();
        let conversionClickedNotificationId:Int64 = Helper.getConversionClickedNotificationId();

        var direct = 0;
        if(conversionClickedNotificationId != -1){
            conversionNotificationId = conversionClickedNotificationId;
            direct = 1;
        }
        else if(conversionReceivedNotificationId != -1){
            conversionNotificationId = conversionReceivedNotificationId;
        }

        if(conversionNotificationId>0 || conversion_name == "purchase") {
            Helper.processReportConversion(notification_id: conversionNotificationId, conversion_name: conversion_name, conversion_value: conversion_value, direct: direct);
        }
    }

    public static func reportConversion(conversion_name:String){
        reportConversionWithValue(conversion_name: conversion_name, conversion_value: 0.0);
    }
    
    public static func setInAppNotificationBehaviour(inAppBehaviour:PAInAppBehaviour){
        PushAlert.mInAppBehaviour = inAppBehaviour
    }
    
    public static func setOpenURLBehaviour(openURLBehaviour:PAOpenURLBehaviour){
        PushAlert.mOpenURLBehaviour = openURLBehaviour
    }
    
    public static func getPANotification(content: UNNotificationContent) -> PANotification{
        let notification_info = content.userInfo

        var notificationId = "";
        if let tempId = notification_info["id"] as? String {
            notificationId = tempId
        }
        else if let tempId = notification_info["id"] as? Int64 {
            notificationId = String(tempId)
        }
                
        var action1_info:NSDictionary = NSDictionary();
        var action2_info:NSDictionary = NSDictionary();
        var action3_info:NSDictionary = NSDictionary();

        if(notification_info.index(forKey: "action1_info") != nil){
            action1_info = (notification_info["action1_info"] as? NSDictionary)!
        }

        if(notification_info.index(forKey: "action2_info") != nil){
            action2_info = (notification_info["action2_info"] as? NSDictionary)!
        }

        if(notification_info.index(forKey: "action3_info") != nil){
            action3_info = (notification_info["action3_info"] as? NSDictionary)!
        }
        
        var final_url = ""
        if(notification_info.index(forKey: "url") != nil){
            final_url = (notification_info["url"] as? String)!
        }
        
        var largeImage = ""
        if let imgURL = notification_info["large_image"] as? String {
            largeImage = imgURL
        }
        
        var reqExtraData = "[]"
        if let extra_data = notification_info["extraData"] as? String {
            reqExtraData = extra_data
        }
        
        let paNotification:PANotification = PANotification(id: Int64(notificationId) ?? 0, title: content.title, sub_title: content.subtitle, message: content.body, url: final_url, largeImage: largeImage, category: content.categoryIdentifier, action1: action1_info, action2: action2_info, action3: action3_info, extraData: reqExtraData)
        
        return paNotification
    }
    
    public static func getPANotification(notification_info: [AnyHashable : Any]) -> PANotification{

        var notificationId = "";
        if let tempId = notification_info["id"] as? String {
            notificationId = tempId
        }
        else if let tempId = notification_info["id"] as? Int64 {
            notificationId = String(tempId)
        }
                
        var action1_info:NSDictionary = NSDictionary();
        var action2_info:NSDictionary = NSDictionary();
        var action3_info:NSDictionary = NSDictionary();

        if(notification_info.index(forKey: "action1_info") != nil){
            action1_info = (notification_info["action1_info"] as? NSDictionary)!
        }

        if(notification_info.index(forKey: "action2_info") != nil){
            action2_info = (notification_info["action2_info"] as? NSDictionary)!
        }

        if(notification_info.index(forKey: "action3_info") != nil){
            action3_info = (notification_info["action3_info"] as? NSDictionary)!
        }
        
        var final_url = ""
        if(notification_info.index(forKey: "url") != nil){
            final_url = (notification_info["url"] as? String)!
        }
        
        var largeImage = ""
        if let imgURL = notification_info["large_image"] as? String {
            largeImage = imgURL
        }
        
        var reqExtraData = "[]"
        if let extra_data = notification_info["extraData"] as? String {
            reqExtraData = extra_data
        }
        
        var title="", message="", sub_title="", category=""
        if let aps = notification_info["aps"] as? NSDictionary {
            if let alert = aps["alert"] as? NSDictionary {
                if alert.object(forKey: "title") != nil {
                    title = alert["title"] as! String
                }
                
                if alert.object(forKey: "subtitle") != nil {
                    sub_title = alert["subtitle"] as! String
                }
                
                if alert.object(forKey: "body") != nil {
                    message = alert["body"] as! String
                }
            }
            
            if aps.object(forKey: "category") != nil {
                category = aps["category"] as! String
            }
        }
        
        let paNotification:PANotification = PANotification(id: Int64(notificationId) ?? 0, title: title, sub_title: sub_title, message: message, url: final_url, largeImage: largeImage, category: category, action1: action1_info, action2: action2_info, action3: action3_info, extraData: reqExtraData)
        
        return paNotification
    }
    
    public static func checkOSNotificationPermissionState(completion: ((PAOSPermissionState)->())? = nil){
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
            
            completion?(PushAlert.osPermissionState)
        })
    }
    
    public static func openAppSettings(withAlert: Bool) {
        if(withAlert){
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Enable notifications for \(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") ?? "APP Name")", message: "To receive real time updates, please turn on \"Allow Notifications\" from Notifications section of \(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") ?? "APP Name") app settings.", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: " Not Now", style: UIAlertAction.Style.default, handler: nil))
                alert.addAction(UIAlertAction(title: "Go to Settings", style: .default, handler: { (action: UIAlertAction!) in
                    
                    DispatchQueue.main.async {
                        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                            return
                        }
                        if UIApplication.shared.canOpenURL(settingsUrl) {
                            UIApplication.shared.open(settingsUrl, options: [:], completionHandler: { (success) in
                                LogM.info(message: "Settings opened: \(success)")
                            })
                        }
                    }
                }))
                UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
            }
        }
        else{
            DispatchQueue.main.async {
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl, options: [:], completionHandler: { (success) in
                        LogM.info(message: "Settings opened: \(success)")
                    })
                }
            }
        }
    }
}
