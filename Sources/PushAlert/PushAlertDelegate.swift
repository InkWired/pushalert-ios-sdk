//
//  SwiftUIView.swift
//  
//
//  Created by Mohit Kuldeep on 01/02/24.
//
import Foundation

public protocol PushAlertSubscribeDelegate : NSObjectProtocol
{
    func onSubscribe(subs_id:String)
}

public protocol PushAlertNotificationOpenerDelegate : NSObjectProtocol
{
    func notificationOpened(paNotificationOpened : PANotificationOpened)
}

public protocol PushAlertForegroundNotificationReceiverDelegate: NSObjectProtocol {
    func foregroundNotificationReceived(notification: PANotification) -> Bool
}

public protocol PushAlertBackgroundNotificationReceiverDelegate: NSObjectProtocol {
    func backgroundNotificationReceived(notification: PANotification) -> Bool
}
