//
//  PushAlertProxyDelegate.swift
//  PushAlertSDK
//
//  Created by Mohit Kuldeep on 08/10/25.
//

import UIKit
import UserNotifications

/// Proxy delegate for PushAlert SDK.
/// Hooks into UNUserNotificationCenter only. Does NOT replace UIApplication.delegate,
/// making it fully UIScene-safe.
public final class PushAlertProxyDelegate: NSObject, UNUserNotificationCenterDelegate {

    // MARK: - Singleton
    public static let shared = PushAlertProxyDelegate()

    // MARK: - Stored references
    private weak var originalAppDelegate: UIApplicationDelegate?
    private weak var originalNotificationDelegate: UNUserNotificationCenterDelegate?
    private var isStarted = false
    private var delegateObservation: NSKeyValueObservation?

    private override init() { super.init() }

    // MARK: - Public API
    /// Start proxying notification delegate methods.
    /// Should be called as early as possible.
    public func start() {
        guard !isStarted else { return }
        isStarted = true

        // Hook UNUserNotificationCenter delegate
        let center = UNUserNotificationCenter.current()
        if let delegate = center.delegate {
            originalNotificationDelegate = delegate
        }
        center.delegate = self
        
        
        // Observe delegate changes
        delegateObservation = center.observe(\.delegate, options: [.new, .old]) { [weak self] center, _ in
            guard let self = self else { return }
            if !(center.delegate is PushAlertProxyDelegate) {
                self.originalNotificationDelegate = center.delegate
                center.delegate = self
            }
        }

    }
    
    // MARK: - UNUserNotificationCenterDelegate Methods
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        PushAlert.handleForegroundNotification(notification: notification,
                                               completionHandler: completionHandler)

        originalNotificationDelegate?.userNotificationCenter?(
            center,
            willPresent: notification,
            withCompletionHandler: completionHandler
        )
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
        PushAlert.handleNotificationClick(response: response, completionHandler: completionHandler)

        originalNotificationDelegate?.userNotificationCenter?(
            center,
            didReceive: response,
            withCompletionHandler: completionHandler
        )
    }

    deinit {
        delegateObservation?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}
