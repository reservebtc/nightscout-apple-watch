//
//  SugarWatch_Watch_AppApp.swift
//  SugarWatch Watch App Watch App
//
//  Created by 20/10/25.
//

import SwiftUI
import UserNotifications
import WatchKit

// ════════════════════════════════════════════════════════════════
// NOTIFICATION DELEGATE CLASS (SOLVES THE PROBLEM!)
// ════════════════════════════════════════════════════════════════

class WatchNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    
    static let shared = WatchNotificationDelegate()
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("📢 [WATCH] Notification arrived!")
        WKInterfaceDevice.current().play(.notification)  // ✅ VIBRATION!
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.actionIdentifier
        print("👆 [WATCH] Tap: \(identifier)")
        
        if identifier.starts(with: "SNOOZE_") {
            let minutes = Int(identifier.replacingOccurrences(of: "SNOOZE_", with: "")) ?? 5
            if let alarmId = response.notification.request.content.userInfo["alarmId"] as? String {
                snoozeAlarm(id: alarmId, minutes: minutes)
            }
            WKInterfaceDevice.current().play(.success)  // ✅ CONFIRMATION VIBRATION!
        }
        
        completionHandler()
    }
    
    private func snoozeAlarm(id: String, minutes: Int) {
        let defaults = UserDefaults(suiteName: "group.com.devsugar.SugarWatch")
        let snoozeUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        defaults?.set(snoozeUntil, forKey: "snooze_\(id)")
        defaults?.synchronize()
        print("⏰ [WATCH] Alarm \(id) snoozed for \(minutes) min")
    }
}

// ════════════════════════════════════════════════════════════════
// MAIN APP
// ════════════════════════════════════════════════════════════════

@main
struct SugarWatch_Watch_App_Watch_AppApp: App {
    
    // ✅ INITIALIZATION
    init() {
        print("🚀 [WATCH] App initialization...")
        setupWatchNotifications()
        print("✅ [WATCH] Ready")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    // ════════════════════════════════════════════════════════════
    // NOTIFICATIONS SETUP
    // ════════════════════════════════════════════════════════════
    
    func setupWatchNotifications() {
        print("🔔 [WATCH] Setting up notifications...")
        
        // ✅ USING DELEGATE CLASS
        UNUserNotificationCenter.current().delegate = WatchNotificationDelegate.shared
        
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .criticalAlert]
        
        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
            if granted {
                print("✅ [WATCH] Permission granted")
                self.setupWatchNotificationCategories()
            } else {
                print("❌ [WATCH] Permission denied!")
                if let error = error {
                    print("   Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func setupWatchNotificationCategories() {
        print("🔔 [WATCH] Setting up categories...")
        
        var categories: Set<UNNotificationCategory> = []
        
        // Buttons
        let snooze5 = UNNotificationAction(identifier: "SNOOZE_5", title: "⏰ 5 min", options: [])
        let snooze15 = UNNotificationAction(identifier: "SNOOZE_15", title: "⏰ 15 min", options: [])
        let snooze30 = UNNotificationAction(identifier: "SNOOZE_30", title: "⏰ 30 min", options: [])
        let dismiss = UNNotificationAction(identifier: "DISMISS", title: "✅ OK", options: [.destructive])
        
        // Category for critical notifications
        let critical = UNNotificationCategory(
            identifier: "CRITICAL_GLUCOSE",
            actions: [snooze5, snooze15, snooze30, dismiss],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        categories.insert(critical)
        
        // Category for high glucose
        let high = UNNotificationCategory(
            identifier: "HIGH_GLUCOSE",
            actions: [snooze15, snooze30, dismiss],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        categories.insert(high)
        
        // Category for low glucose
        let low = UNNotificationCategory(
            identifier: "LOW_GLUCOSE",
            actions: [snooze5, snooze15, dismiss],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        categories.insert(low)
        
        UNUserNotificationCenter.current().setNotificationCategories(categories)
        print("✅ [WATCH] Categories configured: \(categories.count) items")
    }
}
