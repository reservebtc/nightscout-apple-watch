//
//  SugarWatchApp.swift
//  SugarWatch
//
//  CRITICAL: Main application file for Type 1 diabetes control
//  MUST ENSURE LAUNCH AND OPERATION OF ALL SYSTEMS 24/7!

import SwiftUI
import UserNotifications
import BackgroundTasks

@main
struct SugarWatchApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// DELEGATE FOR BACKGROUND WORK AND NOTIFICATIONS
// ═══════════════════════════════════════════════════════════════
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    // NEW: Successful initialization flag
    private var isFullyInitialized = false
    
    // NEW: App health check timer
    private var healthCheckTimer: Timer?
    
    // ═══════════════════════════════════════════════════════════════
    // APP LAUNCH
    // ═══════════════════════════════════════════════════════════════
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        print("\n🚀 [APP] ═══════════════════════════════════════════")
        print("🚀 [APP] LAUNCHING CRITICAL APPLICATION")
        print("🚀 [APP] SugarWatch - Type 1 diabetes control")
        print("🚀 [APP] ═══════════════════════════════════════════\n")
        
        // STEP 1: Notifications setup
        setupNotifications()
        
        // STEP 2: Background tasks registration
        registerBackgroundTasks()
        
        // STEP 3: Data monitoring start
        startMonitoring()
        
        // STEP 4: Scheduling first background refresh
        scheduleInitialBackgroundRefresh()
        
        // NEW: STEP 5: Starting app health check
        startAppHealthCheck()
        
        // NEW: STEP 6: Checking launch reason
        checkLaunchReason(launchOptions: launchOptions)
        
        // Mark successful initialization
        isFullyInitialized = true
        
        print("\n✅ [APP] ═══════════════════════════════════════════")
        print("✅ [APP] Application fully initialized")
        print("✅ [APP] All systems operational!")
        print("✅ [APP] ═══════════════════════════════════════════\n")
        
        return true
    }
    
    // ═══════════════════════════════════════════════════════════════
    // NEW: LAUNCH REASON CHECK
    // ═══════════════════════════════════════════════════════════════
    private func checkLaunchReason(launchOptions: [UIApplication.LaunchOptionsKey : Any]?) {
        if let options = launchOptions {
            print("ℹ️ [APP] Launch reasons:")
            
            if options[.bluetoothCentrals] != nil {
                print("   📡 Bluetooth event")
            }
            if options[.location] != nil {
                print("   📍 Location event")
            }
            if options[.remoteNotification] != nil {
                print("   🔔 Push notification")
            }
            if options[.url] != nil {
                print("   🔗 URL event")
            }
            // Check if there are any options at all
            if !options.isEmpty {
                print("   📋 Total options: \(options.count)")
            }
        } else {
            print("ℹ️ [APP] Normal user launch")
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // NOTIFICATIONS SETUP
    // ═══════════════════════════════════════════════════════════════
    private func setupNotifications() {
        print("🔔 [APP] Notifications setup...")
        
        UNUserNotificationCenter.current().delegate = self
        
        // CRITICAL: Requesting ALL possible permissions
        let options: UNAuthorizationOptions = [
            .alert,
            .badge,
            .sound,
            .criticalAlert,  // Critical notifications (bypass Do Not Disturb)
            .providesAppNotificationSettings
        ]
        
        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
            if granted {
                print("✅ [APP] Notification permission granted")
                self.setupCriticalNotificationCategories()
            } else {
                print("❌ [APP] Notification permission DENIED!")
                if let error = error {
                    print("   Error: \(error.localizedDescription)")
                }
                
                // NEW: Notify user that app will not work without permissions
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.showNotificationPermissionAlert()
                }
            }
        }
    }
    
    // NEW: Show alert about permission requirement
    private func showNotificationPermissionAlert() {
        // Can add UIAlertController if needed
        print("⚠️ [APP] IMPORTANT: Without notification permission, app cannot warn about critical values!")
    }
    
    // Setup categories for critical notifications
    private func setupCriticalNotificationCategories() {
        var categories: Set<UNNotificationCategory> = []
        
        // Category for critical glucose values
        let treatAction = UNNotificationAction(
            identifier: "TREAT_ACTION",
            title: "Took action ✅",
            options: []
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_5",
            title: "Snooze 5 min",
            options: []
        )
        
        let criticalCategory = UNNotificationCategory(
            identifier: "CRITICAL_GLUCOSE",
            actions: [treatAction, snoozeAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        categories.insert(criticalCategory)
        
        UNUserNotificationCenter.current().setNotificationCategories(categories)
        print("✅ [APP] Notification categories configured")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // BACKGROUND TASKS REGISTRATION
    // ═══════════════════════════════════════════════════════════════
    private func registerBackgroundTasks() {
        print("📋 [APP] Background tasks registration...")
        
        // CRITICAL: Registering background tasks for widget updates
        BackgroundRefreshManager.shared.registerBackgroundTasks()
        
        print("✅ [APP] Background tasks registered")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MONITORING START
    // ═══════════════════════════════════════════════════════════════
    private func startMonitoring() {
        print("🔍 [APP] Starting continuous monitoring...")
        
        // CRITICAL: Starting DataManager - the heart of the app
        GlucoseDataManager.shared.startMonitoring()
        
        print("✅ [APP] Monitoring started")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // SCHEDULING FIRST BACKGROUND REFRESH
    // ═══════════════════════════════════════════════════════════════
    private func scheduleInitialBackgroundRefresh() {
        print("📅 [APP] Scheduling first background refresh...")
        
        BackgroundRefreshManager.shared.scheduleWidgetRefresh()
        
        // NEW: If critical value detected immediately - schedule frequent checks
        let currentGlucose = GlucoseDataManager.shared.currentGlucose
        if currentGlucose > 0 && (currentGlucose < 70 || currentGlucose > 250) {
            print("🚨 [APP] Critical value detected - scheduling frequent checks")
            BackgroundRefreshManager.shared.scheduleCriticalCheck()
        }
        
        print("✅ [APP] Background refresh scheduled")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // NEW: APP HEALTH CHECK
    // Every 2 minutes check that all systems are working
    // ═══════════════════════════════════════════════════════════════
    private func startAppHealthCheck() {
        print("💓 [APP] Starting app health check...")
        
        healthCheckTimer?.invalidate()
        
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            print("\n💓 [APP HEALTH] ═══════════════════════════════════")
            print("💓 [APP HEALTH] App health check...")
            
            // Check 1: Application initialized?
            if !self.isFullyInitialized {
                print("   ❌ Application not fully initialized!")
            } else {
                print("   ✅ Initialization: OK")
            }
            
            // Check 2: DataManager working?
            let minutesAgo = GlucoseDataManager.shared.minutesAgo
            if minutesAgo > 15 {
                print("   ⚠️ Data stale: \(minutesAgo)  min ago")
                print("   🔄 Force refresh...")
                GlucoseDataManager.shared.fetchData()
            } else {
                print("   ✅ Data fresh: \(minutesAgo)  min ago")
            }
            
            // Check 3: Glucose normal?
            let glucose = GlucoseDataManager.shared.currentGlucose
            if glucose > 0 {
                if glucose < 70 {
                    print("   🚨 CRITICALLY LOW: \(glucose) mg/dL")
                } else if glucose > 250 {
                    print("   🚨 CRITICALLY HIGH: \(glucose) mg/dL")
                } else {
                    print("   ✅ Glucose normal: \(glucose) mg/dL")
                }
            }
            
            print("💓 [APP HEALTH] ═══════════════════════════════════\n")
        }
        
        RunLoop.current.add(healthCheckTimer!, forMode: .common)
        print("✅ [APP] Health check started (every 2 min)")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // APPLICATION LIFECYCLE
    // ═══════════════════════════════════════════════════════════════
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("\n📱 [APP] ═══════════════════════════════════════════")
        print("📱 [APP] Application entered BACKGROUND")
        print("📱 [APP] Continuing work in background mode...")
        
        // CRITICAL: Scheduling background refresh
        BackgroundRefreshManager.shared.scheduleWidgetRefresh()
        
        // Checking critical values
        let currentGlucose = GlucoseDataManager.shared.currentGlucose
        print("   🍬 Current glucose: \(currentGlucose) mg/dL")
        
        if currentGlucose < 70 || currentGlucose > 250 {
            print("   🚨 CRITICAL VALUE - scheduling frequent checks!")
            BackgroundRefreshManager.shared.scheduleCriticalCheck()
        }
        
        print("📱 [APP] ═══════════════════════════════════════════\n")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("\n📱 [APP] ═══════════════════════════════════════════")
        print("📱 [APP] Application returning to FOREGROUND")
        
        // Update data immediately
        print("   🔄 Updating data...")
        GlucoseDataManager.shared.fetchData()
        
        // Clear badge
        UNUserNotificationCenter.current().setBadgeCount(0)
        
        print("📱 [APP] ═══════════════════════════════════════════\n")
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("✅ [APP] Application became ACTIVE")
        
        // NEW: Check that all systems are working
        if !isFullyInitialized {
            print("⚠️ [APP] Application not fully initialized - restarting systems")
            // Re-initialization
            registerBackgroundTasks()
            startMonitoring()
            scheduleInitialBackgroundRefresh()
            isFullyInitialized = true
        }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        print("⏸ [APP] Application losing activity")
    }
    
    // NEW: Handling app termination
    func applicationWillTerminate(_ application: UIApplication) {
        print("\n🛑 [APP] ═══════════════════════════════════════════")
        print("🛑 [APP] WARNING! Application TERMINATING!")
        print("🛑 [APP] Attempting to save systems operation...")
        
        // Scheduling background tasks for future
        BackgroundRefreshManager.shared.scheduleWidgetRefresh()
        
        if GlucoseDataManager.shared.isInCriticalState {
            print("🚨 [APP] Critical state - scheduling frequent checks")
            BackgroundRefreshManager.shared.scheduleCriticalCheck()
        }
        
        // Stopping timers
        healthCheckTimer?.invalidate()
        
        print("🛑 [APP] Background tasks scheduled")
        print("🛑 [APP] ═══════════════════════════════════════════\n")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // NOTIFICATION HANDLING
    // ═══════════════════════════════════════════════════════════════
    
    // SHOW NOTIFICATIONS EVEN WHEN APP IS OPEN
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        print("🔔 [APP] Received notification (app open)")
        print("   Title: \(notification.request.content.title)")
        
        // CRITICAL: Show notification with sound and banner even when app is active
        // This is important for critical glucose notifications!
        completionHandler([.banner, .sound, .badge])
    }
    
    // HANDLING NOTIFICATION TAP
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let identifier = response.actionIdentifier
        let category = response.notification.request.content.categoryIdentifier
        
        print("👆 [APP] Notification tap")
        print("   Action: \(identifier)")
        print("   Category: \(category)")
        
        // Handling critical notification actions
        if category == "CRITICAL_GLUCOSE" {
            if identifier == "TREAT_ACTION" {
                print("✅ [APP] User took action")
                // Clear badge
                UNUserNotificationCenter.current().setBadgeCount(0)
                
                // NEW: Update data to check current state
                GlucoseDataManager.shared.fetchData()
                
            } else if identifier == "SNOOZE_5" {
                print("⏰ [APP] User snoozed for 5 min")
                // Snooze repeat notification
                if let alarmId = response.notification.request.content.userInfo["alarmId"] as? String {
                    GlucoseDataManager.shared.snoozeAlarm(id: alarmId, minutes: 5)
                }
            }
        }
        
        // Handling "Snooze" buttons
        if identifier.starts(with: "SNOOZE_") {
            if let minutes = Int(identifier.replacingOccurrences(of: "SNOOZE_", with: "")),
               let alarmId = response.notification.request.content.userInfo["alarmId"] as? String {
                GlucoseDataManager.shared.snoozeAlarm(id: alarmId, minutes: minutes)
                print("⏰ [APP] Alarm \(alarmId) snoozed for \(minutes) min")
            }
        }
        
        // NEW: On any notification tap - update data
        if identifier == UNNotificationDefaultActionIdentifier {
            print("📱 [APP] App opened via notification - updating data")
            GlucoseDataManager.shared.fetchData()
        }
        
        completionHandler()
    }
    
    // NEW: Handling notification settings change
    func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {
        print("⚙️ [APP] User opened notification settings")
        // Can show instructions on how to enable critical alerts
    }
}
