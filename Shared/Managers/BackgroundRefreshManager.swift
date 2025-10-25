//
//  BackgroundRefreshManager.swift
//  SugarWatch
//
//  CRITICAL: Менеджер фоновых задач для контроля диабета 1 типа
//  MUST ENSURE DATA UPDATES EVEN WHEN APP IS IN BACKGROUND!
//  IMPORTANT: iOS target only! DO NOT add to Watch App target!
//
//  
//  ✅ Task 6: Maximum aggressive widget update strategy every 5 minutes
//  ✅ Multiple backup mechanisms
//  ✅ Automatic restart on failures

import Foundation
#if os(iOS)
import BackgroundTasks
#endif
import WidgetKit
import UserNotifications

class BackgroundRefreshManager {
    static let shared = BackgroundRefreshManager()
    
    // ═══════════════════════════════════════════════════════════════
    // BACKGROUND TASKS CONFIGURATION
    // ═══════════════════════════════════════════════════════════════
    
    // ВАЖНО: These identifiers must be in Info.plist!
    // Add to Info.plist in iPhone target:
    // <key>BGTaskSchedulerPermittedIdentifiers</key>
    // <array>
    //     <string>com.devsugar.SugarWatch.refresh</string>
    //     <string>com.devsugar.SugarWatch.criticalCheck</string>
    //     <string>com.devsugar.SugarWatch.widgetForce</string>
    // </array>
    
    private let refreshTaskIdentifier = "com.devsugar.SugarWatch.refresh"
    private let criticalCheckIdentifier = "com.devsugar.SugarWatch.criticalCheck"
    private let widgetForceIdentifier = "com.devsugar.SugarWatch.widgetForce" 
    
    // ✅ Multiple timers for reliability
    private var primaryMonitorTimer: Timer?
    private var secondaryMonitorTimer: Timer?
    private var widgetForceTimer: Timer?
    
    // Scheduling errors counter
    private var schedulingErrors: Int = 0
    private let maxSchedulingErrors = 5
    
    // Last successful execution
    private var lastSuccessfulRefresh: Date?
    private var lastSuccessfulCriticalCheck: Date?
    private var lastWidgetReload: Date?
    
    // ✅ Refresh attempts counter
    private var refreshAttempts: Int = 0
    
    private init() {}
    
    // ═══════════════════════════════════════════════════════════════
    // BACKGROUND TASKS REGISTRATION
    // ═══════════════════════════════════════════════════════════════
    
    func registerBackgroundTasks() {
        #if os(iOS)
        print("\n📋 [BACKGROUND] ════════════════════════════════════════")
        print("📋 [BACKGROUND] Registering CRITICAL background tasks")
        print("📋 [BACKGROUND] 24/7 background operation depends on this!")
        print("📋 [BACKGROUND] ════════════════════════════════════════")
        
        // 1. REGULAR widget update
        let refreshRegistered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshTaskIdentifier,
            using: nil
        ) { task in
            self.handleWidgetRefresh(task: task as! BGAppRefreshTask)
        }
        
        print(refreshRegistered ? "✅ [1/3] Widget Refresh registered" : "❌ [1/3] ERROR Widget Refresh!")
        
        // 2. CRITICAL check
        let criticalRegistered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: criticalCheckIdentifier,
            using: nil
        ) { task in
            self.handleCriticalCheck(task: task as! BGAppRefreshTask)
        }
        
        print(criticalRegistered ? "✅ [2/3] Critical Check registered" : "❌ [2/3] ERROR Critical Check!")
        
        // ✅ 3. FORCED widget refresh (backup)
        let forceRegistered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: widgetForceIdentifier,
            using: nil
        ) { task in
            self.handleWidgetForceRefresh(task: task as! BGAppRefreshTask)
        }
        
        print(forceRegistered ? "✅ [3/3] Widget Force registered" : "❌ [3/3] ERROR Widget Force!")
        
        // ✅ Start MULTIPLE monitoring systems
        startPrimaryMonitoring()      // Primary (every 3 minutes)
        startSecondaryMonitoring()    // Backup (every 7 minutes)
        startWidgetForceMonitoring()  // Forced (every 5 minutes)
        
        // Schedule first tasks immediately
        scheduleWidgetRefresh()
        scheduleWidgetForceRefresh()
        
        print("📋 [BACKGROUND] ════════════════════════════════════════\n")
        #else
        print("⚠️ [BACKGROUND] Available for iOS only")
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ✅ TASK 6: MULTIPLE MONITORING SYSTEMS FOR 24/7 GUARANTEE
    // ═══════════════════════════════════════════════════════════════
    
    // 1️⃣ PRIMARY MONITORING - every 3 minуты
    private func startPrimaryMonitoring() {
        #if os(iOS)
        primaryMonitorTimer?.invalidate()
        
        primaryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            print("\n🔍 [PRIMARY] ═══════════════════════════════")
            print("🔍 [PRIMARY] Primary monitoring (every 3 min)")
            
            self.refreshAttempts += 1
            
            // 
            if let lastRefresh = self.lastSuccessfulRefresh {
                let timeSince = Date().timeIntervalSince(lastRefresh)
                let minutesSince = Int(timeSince / 60)
                print("   ⏰ Last update: \(minutesSince)  min ago")
                
                // ✅ 
                if timeSince > 600 {
                    print("   🚨 EMERGENCY MODE! Long time without updates!")
                    self.emergencyRefresh()
                }
            }
            
            // Reschedule all tasks
            self.scheduleWidgetRefresh()
            self.scheduleWidgetForceRefresh()
            
            // Force reload widgets
            WidgetCenter.shared.reloadAllTimelines()
            self.lastWidgetReload = Date()
            
            print("   ✅ Attempt #\(self.refreshAttempts)")
            print("🔍 [PRIMARY] ═══════════════════════════════\n")
        }
        
        RunLoop.current.add(primaryMonitorTimer!, forMode: .common)
        print("✅ [PRIMARY] Primary monitoring запущен (every 3 min)")
        #endif
    }
    
    // 2️⃣ BACKUP MONITORING - every 7 
    private func startSecondaryMonitoring() {
        #if os(iOS)
        secondaryMonitorTimer?.invalidate()
        
        secondaryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 420, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            print("\n🔍 [SECONDARY] ══════════════════════════")
            print("🔍 [SECONDARY] Backup monitoring (every 7 min)")
            
            // Duplicate task scheduling
            self.scheduleWidgetRefresh()
            self.scheduleCriticalCheck()
            
            // Check critical state
            if GlucoseDataManager.shared.isInCriticalState {
                print("   🚨 Critical state - enhanced refresh!")
                self.scheduleCriticalCheck()
                self.emergencyRefresh()
            }
            
            print("🔍 [SECONDARY] ══════════════════════════\n")
        }
        
        RunLoop.current.add(secondaryMonitorTimer!, forMode: .common)
        print("✅ [SECONDARY] Backup monitoring запущен (every 7 min)")
        #endif
    }
    
    // 3️⃣ ✅ FORCED WIDGET MONITORING - every 5 
    private func startWidgetForceMonitoring() {
        #if os(iOS)
        widgetForceTimer?.invalidate()
        
        widgetForceTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            print("\n⚡ [WIDGET FORCE] ══════════════════════")
            print("⚡ [WIDGET FORCE] Forced update (every 5 min)")
            
            // Force widget reload
            WidgetCenter.shared.reloadAllTimelines()
            self.lastWidgetReload = Date()
            
            // Schedule forced background task
            self.scheduleWidgetForceRefresh()
            
            // Check: time since last widget reload
            if let lastReload = self.lastWidgetReload {
                let timeSince = Date().timeIntervalSince(lastReload)
                print("   ⏰ Last widget reload: \(Int(timeSince))  sec ago")
            }
            
            print("   ✅ Widget force reloaded")
            print("⚡ [WIDGET FORCE] ══════════════════════\n")
        }
        
        RunLoop.current.add(widgetForceTimer!, forMode: .common)
        print("✅ [WIDGET FORCE] Forced monitoring started (every 5 min)")
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // REGULAR WIDGET REFRESH SCHEDULING
    // ═══════════════════════════════════════════════════════════════
    
    func scheduleWidgetRefresh() {
        #if os(iOS)
        // Cancel old task
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: refreshTaskIdentifier)
        
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        
        // ✅ AGGRESSIVE: Every 5 minutes (iOS may give more, but requesting minimum)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            schedulingErrors = 0
            print("✅ [REFRESH] Scheduled for \(request.earliestBeginDate!)")
            
            // Backup scheduling
            scheduleBackupRefresh()
            
        } catch {
            schedulingErrors += 1
            print("❌ [REFRESH] Error (\(schedulingErrors)/\(maxSchedulingErrors)): \(error)")
            
            if schedulingErrors >= maxSchedulingErrors {
                sendSystemAlert(
                    title: "⚠️ Background tasks problem",
                    body: "Cannot schedule updates. Restart app."
                )
            }
            
            // Retry in 30 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                self.scheduleWidgetRefresh()
            }
        }
        #endif
    }
    
    // ✅ FORCED widget refresh (separate task)
    func scheduleWidgetForceRefresh() {
        #if os(iOS)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: widgetForceIdentifier)
        
        let request = BGAppRefreshTaskRequest(identifier: widgetForceIdentifier)
        
        // ✅ CRITICAL: Every 5 minutes (alternative mechanism)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ [WIDGET FORCE] Scheduled for \(request.earliestBeginDate!)")
        } catch {
            print("❌ [WIDGET FORCE] Error: \(error)")
            
            // Retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                self.scheduleWidgetForceRefresh()
            }
        }
        #endif
    }
    
    // Backup scheduling
    private func scheduleBackupRefresh() {
        #if os(iOS)
        DispatchQueue.main.asyncAfter(deadline: .now() + 8 * 60) {
            print("🔄 [BACKUP] Backup scheduling")
            self.scheduleWidgetRefresh()
        }
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CRITICAL CHECK SCHEDULING
    // ═══════════════════════════════════════════════════════════════
    
    func scheduleCriticalCheck() {
        #if os(iOS)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: criticalCheckIdentifier)
        
        let request = BGAppRefreshTaskRequest(identifier: criticalCheckIdentifier)
        
        // Every 2 minutes for dangerous values
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("🚨 [CRITICAL] Scheduled for \(request.earliestBeginDate!)")
            
            scheduleBackupCriticalCheck()
            
        } catch {
            print("❌ [CRITICAL] Error: \(error)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                self.scheduleCriticalCheck()
            }
        }
        #endif
    }
    
    private func scheduleBackupCriticalCheck() {
        #if os(iOS)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4 * 60) {
            print("🔄 [BACKUP] Backup critical check")
            self.scheduleCriticalCheck()
        }
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ✅ EMERGENCY REFRESH
    // ═══════════════════════════════════════════════════════════════
    
    private func emergencyRefresh() {
        print("\n🚨 [EMERGENCY] ════════════════════════════")
        print("🚨 [EMERGENCY] EMERGENCY REFRESH!")
        
        // 1. Force reload widgets
        WidgetCenter.shared.reloadAllTimelines()
        
        // 2. Requesting data
        GlucoseDataManager.shared.fetchData()
        
        // 3. Reschedule all tasks
        scheduleWidgetRefresh()
        scheduleWidgetForceRefresh()
        scheduleCriticalCheck()
        
        // 4. Send notification
        sendSystemAlert(
            title: "⚠️ Emergency refresh",
            body: "System detected long absence of updates and performed emergency refresh."
        )
        
        print("🚨 [EMERGENCY] Complete")
        print("🚨 [EMERGENCY] ════════════════════════════\n")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // BACKGROUND TASK HANDLERS
    // ═══════════════════════════════════════════════════════════════
    
    #if os(iOS)
    // 1. WIDGET REFRESH
    private func handleWidgetRefresh(task: BGAppRefreshTask) {
        print("\n🔄 [WIDGET REFRESH] ═══════════════════════")
        print("🔄 [WIDGET REFRESH] Task started in background")
        let startTime = Date()
        
        // Schedule next refresh
        scheduleWidgetRefresh()
        
        task.expirationHandler = {
            print("⏰ [WIDGET REFRESH] Time expired")
            task.setTaskCompleted(success: false)
            self.scheduleWidgetRefresh()
        }
        
        var taskCompleted = false
        let timeoutWorkItem = DispatchWorkItem {
            guard !taskCompleted else { return }
            taskCompleted = true
            print("⏰ [WIDGET REFRESH] Timeout")
            task.setTaskCompleted(success: false)
            self.scheduleWidgetRefresh()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 25, execute: timeoutWorkItem)
        
        // Fetching data
        NightscoutService.shared.fetchLatestGlucose { result in
            guard !taskCompleted else { return }
            taskCompleted = true
            timeoutWorkItem.cancel()
            
            let duration = Date().timeIntervalSince(startTime)
            
            switch result {
            case .success(let data):
                print("✅ [WIDGET REFRESH] Data received in \(String(format: "%.1f", duration))с")
                print("   🍬 Glucose: \(data.glucose) mg/dL")
                
                // Update widgets
                WidgetCenter.shared.reloadAllTimelines()
                
                // Update DataManager
                DispatchQueue.main.async {
                    GlucoseDataManager.shared.fetchData()
                }
                
                self.lastSuccessfulRefresh = Date()
                
                // 
                if data.glucose < 70 || data.glucose > 250 {
                    print("   🚨 CRITICAL! Schedule frequent checks")
                    self.scheduleCriticalCheck()
                }
                
                task.setTaskCompleted(success: true)
                
            case .failure(let error):
                print("❌ [WIDGET REFRESH] Error: \(error)")
                
                // Update widgets 
                WidgetCenter.shared.reloadAllTimelines()
                
                task.setTaskCompleted(success: false)
                self.scheduleWidgetRefresh()
            }
            
            print("🔄 [WIDGET REFRESH] ═══════════════════════\n")
        }
    }
    
    // 2. ✅ FORCED WIDGET REFRESH
    private func handleWidgetForceRefresh(task: BGAppRefreshTask) {
        print("\n⚡ [WIDGET FORCE] ════════════════════════")
        print("⚡ [WIDGET FORCE] Forced update")
        
        // Schedule next
        scheduleWidgetForceRefresh()
        
        task.expirationHandler = {
            print("⏰ [WIDGET FORCE] Time expired")
            WidgetCenter.shared.reloadAllTimelines()
            task.setTaskCompleted(success: true)
        }
        
        // Force widget reload 
        WidgetCenter.shared.reloadAllTimelines()
        self.lastWidgetReload = Date()
        
        // Try to get fresh data
        NightscoutService.shared.fetchLatestGlucose { result in
            if case .success(let data) = result {
                print("✅ [WIDGET FORCE] Got data: \(data.glucose) mg/dL")
                DispatchQueue.main.async {
                    GlucoseDataManager.shared.fetchData()
                }
            } else {
                print("⚠️ [WIDGET FORCE] Data unavailable, using cache")
            }
            
            // Reload widget again
            WidgetCenter.shared.reloadAllTimelines()
            task.setTaskCompleted(success: true)
        }
        
        print("⚡ [WIDGET FORCE] ════════════════════════\n")
    }
    
    // 3. CRITICAL CHECK
    private func handleCriticalCheck(task: BGAppRefreshTask) {
        print("\n🚨 [CRITICAL CHECK] ═══════════════════════")
        print("🚨 [CRITICAL CHECK] Started")
        let startTime = Date()
        
        scheduleCriticalCheck()
        
        task.expirationHandler = {
            print("⏰ [CRITICAL CHECK] Time expired")
            task.setTaskCompleted(success: false)
            self.scheduleCriticalCheck()
        }
        
        var taskCompleted = false
        let timeoutWorkItem = DispatchWorkItem {
            guard !taskCompleted else { return }
            taskCompleted = true
            print("⏰ [CRITICAL CHECK] Timeout")
            task.setTaskCompleted(success: false)
            self.scheduleCriticalCheck()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 25, execute: timeoutWorkItem)
        
        NightscoutService.shared.fetchLatestGlucose { result in
            guard !taskCompleted else { return }
            taskCompleted = true
            timeoutWorkItem.cancel()
            
            let duration = Date().timeIntervalSince(startTime)
            
            switch result {
            case .success(let data):
                print("✅ [CRITICAL CHECK] За \(String(format: "%.1f", duration))с")
                print("   🍬 Glucose: \(data.glucose) mg/dL")
                
                // Check dangerous values
                if data.glucose < 70 {
                    print("   🚨 CRITICALLY LOW!")
                    self.sendCriticalNotification(
                        title: "🚨 CRITICALLY LOW!",
                        body: "Glucose: \(data.glucose) mg/dL. URGENT!",
                        glucose: data.glucose
                    )
                } else if data.glucose > 250 {
                    print("   🚨 CRITICALLY HIGH!")
                    self.sendCriticalNotification(
                        title: "🚨 CRITICALLY HIGH!",
                        body: "Glucose: \(data.glucose) mg/dL. TAKE ACTION!",
                        glucose: data.glucose
                    )
                } else {
                    print("   ✅ Normal")
                }
                
                WidgetCenter.shared.reloadAllTimelines()
                
                DispatchQueue.main.async {
                    GlucoseDataManager.shared.fetchData()
                }
                
                self.lastSuccessfulCriticalCheck = Date()
                task.setTaskCompleted(success: true)
                
            case .failure(let error):
                print("❌ [CRITICAL CHECK] Error: \(error)")
                
                self.sendSystemAlert(
                    title: "⚠️ Error критической проверки",
                    body: "Cannot get background data!"
                )
                
                task.setTaskCompleted(success: false)
                self.scheduleCriticalCheck()
            }
            
            print("🚨 [CRITICAL CHECK] ═══════════════════════\n")
        }
    }
    #endif
    
    // ═══════════════════════════════════════════════════════════════
    // NOTIFICATIONS
    // ═══════════════════════════════════════════════════════════════
    
    private func sendCriticalNotification(title: String, body: String, glucose: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .defaultCritical
        content.interruptionLevel = .critical
        content.badge = 1
        
        content.categoryIdentifier = "CRITICAL_GLUCOSE"
        content.userInfo = [
            "glucose": glucose,
            "timestamp": Date().timeIntervalSince1970,
            "source": "background"
        ]
        
        let request = UNNotificationRequest(
            identifier: "bg_critical_\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error уведомления: \(error)")
            } else {
                print("✅ Critical notification sent")
            }
        }
    }
    
    private func sendSystemAlert(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "bg_system_\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error системного уведомления: \(error)")
            } else {
                print("✅ System notification sent")
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MANAGEMENT
    // ═══════════════════════════════════════════════════════════════
    
    func cancelAllTasks() {
        #if os(iOS)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: refreshTaskIdentifier)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: criticalCheckIdentifier)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: widgetForceIdentifier)
        
        primaryMonitorTimer?.invalidate()
        secondaryMonitorTimer?.invalidate()
        widgetForceTimer?.invalidate()
        
        primaryMonitorTimer = nil
        secondaryMonitorTimer = nil
        widgetForceTimer = nil
        
        print("🛑 [BACKGROUND] All tasks cancelled")
        #endif
    }
    
    // ✅ Forced update 
    func forceRefreshNow() {
        print("\n⚡ [FORCE] ═══════════════════════════════")
        print("⚡ [FORCE] FORCED refresh")
        
        // Schedule all tasks
        scheduleWidgetRefresh()
        scheduleWidgetForceRefresh()
        
        // Update immediately
        DispatchQueue.main.async {
            GlucoseDataManager.shared.fetchData()
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        print("⚡ [FORCE] Complete")
        print("⚡ [FORCE] ═══════════════════════════════\n")
    }
}
