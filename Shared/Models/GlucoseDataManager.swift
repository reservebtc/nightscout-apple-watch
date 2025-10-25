//
//  GlucoseDataManager.swift
//  SugarWatch
//
//  CRITICAL: Data manager for Type 1 diabetes control
//  THE CHILD'S LIFE DEPENDS ON THE RELIABILITY OF THIS SERVICE!
//  MUST WORK 24/7 WITHOUT EXCEPTIONS OR FAILURES!
//
//  UPDATES:
//  ✅ Task 1: Show last data instead of 0, red time on delay
//  ✅ Task 3: Critical notifications for Apple Watch with haptics
//  ✅ Task 8: Complete notification system with snooze

import Foundation
import UserNotifications
import Combine
#if os(iOS)
import UIKit
#endif
import WidgetKit
#if os(watchOS)
import WatchKit
import ClockKit
#endif

// ═══════════════════════════════════════════════════════════════
// GLUCOSE DATA STRUCTURE (for compatibility)
// ═══════════════════════════════════════════════════════════════
struct GlucoseData {
    let glucose: Int
    let direction: String
    let date: Date
    let delta: Double?
}

class GlucoseDataManager: ObservableObject {
    static let shared = GlucoseDataManager()
    
    // ═══════════════════════════════════════════════════════════════
    // GLUCOSE DATA
    // ═══════════════════════════════════════════════════════════════
    @Published var currentGlucose: Int = 0
    @Published var direction: String = "Flat"
    @Published var lastUpdate: Date = Date()
    @Published var delta: Double? = nil
    @Published var minutesAgo: Int = 0
    
    // ✅ NEW: Last valid data (to show instead of 0)
    @Published var lastValidGlucose: Int = 0
    @Published var lastValidUpdate: Date = Date()
    @Published var isDataStale: Bool = false  // Red indicator on delay
    
    // PUMP DATA
    @Published var lastBolus: (amount: Double, time: Date)? = nil
    @Published var currentBasal: Double = 0.0
    @Published var pumpLastContact: Date? = nil
    @Published var isPumpConnected: Bool = true
    
    // LOOP DATA
    @Published var iob: Double = 0.0  // Insulin On Board
    @Published var cob: Double = 0.0  // Carbs On Board
    @Published var reservoir: Double = 0.0  // Insulin remaining in reservoir
    
    // ✅ NEW: History for tracking unchanging glucose
    private var glucoseHistory: [Int] = []
    private var glucoseHistoryDates: [Date] = []
    private let maxHistoryCount = 5  // Store last 5 values
    
    // Critical state flag
    @Published var isInCriticalState: Bool = false
    
    // ✅ TASK 3: Tracking critical notifications for Apple Watch
    private var lastWatchCriticalAlert: Date?
    private let watchAlertCooldown: TimeInterval = 300 // 5 minutes between critical alerts on watch
    
    // ═══════════════════════════════════════════════════════════════
    // THRESHOLD SETTINGS
    // ═══════════════════════════════════════════════════════════════
    var lowGlucoseThreshold: Int = UserDefaults.standard.integer(forKey: "lowThreshold") != 0
        ? UserDefaults.standard.integer(forKey: "lowThreshold") : 70
    var highGlucoseThreshold: Int = UserDefaults.standard.integer(forKey: "highThreshold") != 0
        ? UserDefaults.standard.integer(forKey: "highThreshold") : 180
    var criticalLowThreshold: Int = UserDefaults.standard.integer(forKey: "criticalLowThreshold") != 0
        ? UserDefaults.standard.integer(forKey: "criticalLowThreshold") : 55
    var criticalHighThreshold: Int = UserDefaults.standard.integer(forKey: "criticalHighThreshold") != 0
        ? UserDefaults.standard.integer(forKey: "criticalHighThreshold") : 250
    var updateInterval: TimeInterval = UserDefaults.standard.double(forKey: "updateInterval") != 0
        ? UserDefaults.standard.double(forKey: "updateInterval") : 300  // 5 minutes default
    
    // Interval for critical mode (more frequent updates)
    private let criticalUpdateInterval: TimeInterval = 60 // 1 minute
    
    // ✅ NEW: Snoozed alarms system with detailed settings
    private struct AlarmSnooze {
        var until: Date
        var count: Int  // How many times snoozed
    }
    private var snoozedAlarms: [String: AlarmSnooze] = [:]
    
    // ✅ NEW: Alarm types according to requirements
    enum AlarmType {
        case lowGlucose              // Low glucose: 10/20/30 min
        case criticalLow             // Very low: only 10 min
        case highGlucose             // High: 10/20/30/45/60 min
        case criticalHigh            // Very high: 10/20/30 min
        case missedReadings          // Missed readings: auto 15 min
        case loopNotClosed           // Loop not closed: auto 15 min
        case glucoseNotChanging      // Glucose not changing: auto 15 min
    }
    
    // ═══════════════════════════════════════════════════════════════
    // 24/7 RELIABILITY MECHANISMS
    // ═══════════════════════════════════════════════════════════════
    
    // Main update timer
    private var timer: Timer?
    
    // Watchdog timer - monitors that main timer is not stuck
    private var watchdogTimer: Timer?
    private var lastSuccessfulFetch: Date = Date()
    
    // Heartbeat check - self-diagnostics every minute
    private var heartbeatTimer: Timer?
    
    // Consecutive errors counter
    private var consecutiveErrors: Int = 0
    private let maxConsecutiveErrors = 3
    
    // System activity flag
    private var isSystemActive: Bool = true
    
    #if os(iOS)
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    #endif
    
    // ═══════════════════════════════════════════════════════════════
    // INITIALIZATION
    // ═══════════════════════════════════════════════════════════════
    init() {
        print("\n🚀 [DATAMANAGER] ═══════════════════════════════════")
        print("🚀 [DATAMANAGER] Initializing CRITICAL module")
        print("🚀 [DATAMANAGER] LIFE depends on reliability!")
        print("🚀 [DATAMANAGER] ═══════════════════════════════════\n")
        
        // Load last saved data
        loadLastValidData()
        
        setupNotifications()
        startMonitoring()
        startWatchdog()
        startHeartbeat()
        
        #if os(iOS)
        setupBackgroundMode()
        setupAppLifecycleObservers()
        #endif
    }
    
    // ✅ NEW: Load last valid data
    private func loadLastValidData() {
        if let savedGlucose = UserDefaults.standard.object(forKey: "lastValidGlucose") as? Int,
           let savedDate = UserDefaults.standard.object(forKey: "lastValidUpdate") as? Date {
            lastValidGlucose = savedGlucose
            lastValidUpdate = savedDate
            currentGlucose = savedGlucose
            lastUpdate = savedDate
            print("📊 [DATAMANAGER] Loaded last data: \(savedGlucose) mg/dL from \(savedDate)")
        }
    }
    
    // ✅ NEW: Save last valid data
    private func saveLastValidData() {
        UserDefaults.standard.set(lastValidGlucose, forKey: "lastValidGlucose")
        UserDefaults.standard.set(lastValidUpdate, forKey: "lastValidUpdate")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // APP LIFECYCLE OBSERVERS
    // ═══════════════════════════════════════════════════════════════
    #if os(iOS)
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    @objc private func appWillEnterForeground() {
        print("✅ [LIFECYCLE] App returning - checking system")
        isSystemActive = true
        
        // CRITICAL: Check data immediately
        fetchData()
        
        // Make sure all timers are working
        if timer == nil || !(timer?.isValid ?? false) {
            print("⚠️ [LIFECYCLE] Main timer dead - RESTARTING!")
            startMonitoring()
        }
        
        if watchdogTimer == nil || !(watchdogTimer?.isValid ?? false) {
            print("⚠️ [LIFECYCLE] Watchdog dead - RESTARTING!")
            startWatchdog()
        }
        
        if heartbeatTimer == nil || !(heartbeatTimer?.isValid ?? false) {
            print("⚠️ [LIFECYCLE] Heartbeat dead - RESTARTING!")
            startHeartbeat()
        }
    }
    
    @objc private func appDidBecomeActive() {
        print("✅ [LIFECYCLE] App active")
        isSystemActive = true
        fetchData()
    }
    
    @objc private func appWillResignActive() {
        print("⏸ [LIFECYCLE] App losing activity")
        isSystemActive = false
    }
    
    @objc private func appDidEnterBackground() {
        print("🌙 [LIFECYCLE] App in background - saving data")
        saveLastValidData()
        
        #if os(iOS)
        beginBackgroundTask()
        
        // Schedule background tasks
        BackgroundRefreshManager.shared.scheduleWidgetRefresh()
        if isInCriticalState {
            BackgroundRefreshManager.shared.scheduleCriticalCheck()
        }
        #endif
    }
    
    @objc private func appWillTerminate() {
        print("🛑 [LIFECYCLE] WARNING! App terminating!")
        print("🛑 [LIFECYCLE] Saving last data...")
        saveLastValidData()
        
        #if os(iOS)
        BackgroundRefreshManager.shared.scheduleWidgetRefresh()
        if isInCriticalState {
            BackgroundRefreshManager.shared.scheduleCriticalCheck()
        }
        #endif
    }
    #endif
    
    // ═══════════════════════════════════════════════════════════════
    // WATCHDOG - WATCHDOG TIMER
    // ═══════════════════════════════════════════════════════════════
    private func startWatchdog() {
        watchdogTimer?.invalidate()
        
        // Check every 2 minutes
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let timeSinceLastFetch = Date().timeIntervalSince(self.lastSuccessfulFetch)
            
            print("🐕 [WATCHDOG] System check...")
            print("🐕 [WATCHDOG] Time since last successful fetch: \(Int(timeSinceLastFetch / 60)) minutes")
            
            // If no successful fetch for more than 10 minutes
            if timeSinceLastFetch > 600 {
                print("🚨 [WATCHDOG] CRITICAL! System frozen! Restarting...")
                self.emergencyRestart()
            }
            
            // Check that main timer is alive
            if self.timer == nil || !(self.timer?.isValid ?? false) {
                print("⚠️ [WATCHDOG] Main timer dead! Restarting...")
                self.startMonitoring()
            }
        }
        
        print("🐕 [WATCHDOG] Watchdog timer started")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // HEARTBEAT - SYSTEM HEALTH CHECK
    // ═══════════════════════════════════════════════════════════════
    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        
        // Self-diagnostics every minute
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            print("💓 [HEARTBEAT] ═══════════════════════════")
            print("💓 [HEARTBEAT] System health check")
            print("💓 [HEARTBEAT] Current glucose: \(self.currentGlucose) mg/dL")
            print("💓 [HEARTBEAT] Minutes ago: \(self.minutesAgo)")
            print("💓 [HEARTBEAT] Critical state: \(self.isInCriticalState)")
            print("💓 [HEARTBEAT] Active: \(self.isSystemActive)")
            print("💓 [HEARTBEAT] Consecutive errors: \(self.consecutiveErrors)")
            
            // Check that data is fresh
            self.updateMinutesAgo()
            
            // If data is stale for 15+ minutes - critical situation
            if self.minutesAgo >= 15 {
                print("🚨 [HEARTBEAT] CRITICAL! Data not updating for \(self.minutesAgo) minutes!")
                self.sendSystemAlarm(
                    title: "🚨 System not working!",
                    body: "Data not updating for \(self.minutesAgo) minutes! Check connection!"
                )
            }
            
            print("💓 [HEARTBEAT] ═══════════════════════════\n")
        }
        
        print("💓 [HEARTBEAT] Heartbeat timer started")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // EMERGENCY RESTART
    // ═══════════════════════════════════════════════════════════════
    private func emergencyRestart() {
        print("🚨 [EMERGENCY] ════════════════════════════")
        print("🚨 [EMERGENCY] EMERGENCY SYSTEM RESTART!")
        print("🚨 [EMERGENCY] ════════════════════════════")
        
        // Stop everything
        stopMonitoring()
        watchdogTimer?.invalidate()
        heartbeatTimer?.invalidate()
        
        // Reset error counter
        consecutiveErrors = 0
        
        // Send critical notification
        sendSystemAlarm(
            title: "🚨 System restarted",
            body: "Failure detected. System automatically restarted."
        )
        
        // Wait 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Start everything again
            self.startMonitoring()
            self.startWatchdog()
            self.startHeartbeat()
            
            // Try to fetch data immediately
            self.fetchData()
            
            print("✅ [EMERGENCY] System restarted successfully")
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // BACKGROUND MODE (iOS)
    // ═══════════════════════════════════════════════════════════════
    #if os(iOS)
    private func setupBackgroundMode() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBackgroundRefresh),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func handleBackgroundRefresh() {
        print("🌙 [BACKGROUND] Entering background mode")
        beginBackgroundTask()
        
        // Save current data
        saveLastValidData()
        
        // Schedule background task
        BackgroundRefreshManager.shared.scheduleWidgetRefresh()
    }
    
    private func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    #endif
    
    // ═══════════════════════════════════════════════════════════════
    // MONITORING
    // ═══════════════════════════════════════════════════════════════
    
    func startMonitoring() {
        stopMonitoring()
        
        // Determine update interval
        let interval = isInCriticalState ? criticalUpdateInterval : updateInterval
        
        print("▶️ [MONITORING] Starting monitoring with \(interval) sec interval")
        
        // Load data immediately
        fetchData()
        
        // Start timer
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.fetchData()
        }
        
        // Add to RunLoop for reliability
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        print("⏸ [MONITORING] Monitoring stopped")
    }
    
    // ✅ NEW: Restart monitoring (for ContentView)
    func restartMonitoring() {
        print("\n🔄 [MONITORING] ══════════════════════════")
        print("🔄 [MONITORING] RESTARTING monitoring")
        
        stopMonitoring()
        
        // Small delay before restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startMonitoring()
        }
        
        print("🔄 [MONITORING] ══════════════════════════\n")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // DATA FETCH
    // ═══════════════════════════════════════════════════════════════
    
    func fetchData() {
        print("\n📡 [FETCH] ════════════════════════════════")
        print("📡 [FETCH] Fetching glucose data...")
        
        #if os(iOS)
        beginBackgroundTask()
        #endif
        
        NightscoutService.shared.fetchLatestGlucose { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let data):
                print("✅ [FETCH] Data received successfully")
                self.handleSuccessfulFetch(data)
                
            case .failure(let error):
                print("❌ [FETCH] Error: \(error.localizedDescription)")
                self.handleFailedFetch(error)
            }
            
            #if os(iOS)
            self.endBackgroundTask()
            #endif
            
            print("📡 [FETCH] ════════════════════════════════\n")
        }
    }
    
    // ✅ IMPROVED: Handle successful fetch
    private func handleSuccessfulFetch(_ data: GlucoseData) {
        DispatchQueue.main.async {
            // Reset error counter
            self.consecutiveErrors = 0
            self.lastSuccessfulFetch = Date()
            
            // ✅ Check: if data is valid (not 0), save as last valid
            if data.glucose > 0 {
                self.currentGlucose = data.glucose
                self.lastValidGlucose = data.glucose
                self.lastValidUpdate = data.date
                self.saveLastValidData()
                
                // Add to history
                self.addToGlucoseHistory(data.glucose, date: data.date)
                
                print("✅ [DATA] New data: \(data.glucose) mg/dL")
            } else {
                // ✅ If received 0, show last valid data
                print("⚠️ [DATA] Received 0, showing last data: \(self.lastValidGlucose) mg/dL")
                self.currentGlucose = self.lastValidGlucose
            }
            
            self.direction = data.direction
            self.delta = data.delta
            self.lastUpdate = data.date
            
            // Update time
            self.updateMinutesAgo()
            
            // ✅ Check: is data stale?
            self.checkIfDataIsStale()
            
            // Update critical state
            self.updateCriticalState()
            
            // Check all alarm conditions
            self.checkAllAlarmConditions()
            
            // Update widgets
            WidgetKit.WidgetCenter.shared.reloadAllTimelines()
            
            print("✅ [FETCH] Processing complete: \(self.currentGlucose) mg/dL, \(self.minutesAgo) min ago")
        }
    }
    
    // ✅ NEW: Check if data is stale
    private func checkIfDataIsStale() {
        // Data is stale if more than 10 minutes passed
        isDataStale = minutesAgo > 10
        
        if isDataStale {
            print("🔴 [DATA] Data is stale! \(minutesAgo) minutes without update")
        }
    }
    
    // ✅ NEW: Add to history for tracking unchanging glucose
    private func addToGlucoseHistory(_ glucose: Int, date: Date) {
        glucoseHistory.append(glucose)
        glucoseHistoryDates.append(date)
        
        // Keep only last 5 values
        if glucoseHistory.count > maxHistoryCount {
            glucoseHistory.removeFirst()
            glucoseHistoryDates.removeFirst()
        }
    }
    
    private func handleFailedFetch(_ error: Error) {
        DispatchQueue.main.async {
            self.consecutiveErrors += 1
            
            print("❌ [FETCH] Error #\(self.consecutiveErrors): \(error.localizedDescription)")
            
            // ✅ On error show last valid data
            if self.lastValidGlucose > 0 {
                self.currentGlucose = self.lastValidGlucose
                print("ℹ️ [FETCH] Showing last data: \(self.lastValidGlucose) mg/dL")
            }
            
            // Update time since last update
            self.updateMinutesAgo()
            self.checkIfDataIsStale()
            
            // If many errors in a row - critical situation
            if self.consecutiveErrors >= self.maxConsecutiveErrors {
                print("🚨 [FETCH] CRITICAL! \(self.consecutiveErrors) consecutive errors!")
                
                self.sendSystemAlarm(
                    title: "🚨 Server problem!",
                    body: "Cannot get data. Check connection!"
                )
                
                // Try emergency restart
                if self.consecutiveErrors >= 5 {
                    self.emergencyRestart()
                }
            }
        }
    }
    
    // Update time since last update
    private func updateMinutesAgo() {
        let timeInterval = Date().timeIntervalSince(lastUpdate)
        minutesAgo = Int(timeInterval / 60)
    }
    
    // Update critical state
    private func updateCriticalState() {
        let wasCritical = isInCriticalState
        
        isInCriticalState = currentGlucose <= criticalLowThreshold ||
                           currentGlucose >= criticalHighThreshold ||
                           minutesAgo > 15 ||
                           !isPumpConnected
        
        // If entered critical state - speed up updates
        if !wasCritical && isInCriticalState {
            print("🚨 [CRITICAL] Entering critical mode!")
            startMonitoring() // Restart with short interval
        }
        
        // If exited critical state
        if wasCritical && !isInCriticalState {
            print("✅ [CRITICAL] Exiting critical mode")
            startMonitoring() // Return to normal interval
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ✅ NEW: EXTENDED ALARM CHECK SYSTEM (TASK 8)
    // ═══════════════════════════════════════════════════════════════
    
    private func checkAllAlarmConditions() {
        // 1. Check glucose levels
        checkGlucoseLevels()
        
        // 2. ✅ Check missed readings (10 minutes without updates)
        checkMissedReadings()
        
        // 3. ✅ Check loop connection (pump not responding >10 minutes)
        checkLoopConnection()
        
        // 4. ✅ Check frozen glucose (3 same readings in 15 minutes)
        checkGlucoseNotChanging()
    }
    
    // ✅ NEW: Check missed readings
    private func checkMissedReadings() {
        if minutesAgo >= 10 {
            // Check: is this alarm already snoozed
            if !isAlarmSnoozed("missed_readings") {
                sendAlarm(
                    type: .missedReadings,
                    id: "missed_readings",
                    title: "⚠️ No new data",
                    body: "Glucose readings not updating for \(minutesAgo) minutes!",
                    critical: false
                )
                
                // Auto-snooze for 15 minutes
                snoozeAlarm(id: "missed_readings", minutes: 15)
            }
        }
    }
    
    // ✅ NEW: Check loop connection
    private func checkLoopConnection() {
        if let lastContact = pumpLastContact {
            let minutesSinceContact = Int(Date().timeIntervalSince(lastContact) / 60)
            
            if minutesSinceContact >= 10 {
                isPumpConnected = false
                
                if !isAlarmSnoozed("loop_not_closed") {
                    sendAlarm(
                        type: .loopNotClosed,
                        id: "loop_not_closed",
                        title: "⚠️ Loop not closed!",
                        body: "Pump not responding for \(minutesSinceContact) minutes!",
                        critical: false
                    )
                    
                    // Auto-snooze for 15 minutes
                    snoozeAlarm(id: "loop_not_closed", minutes: 15)
                }
            } else {
                isPumpConnected = true
            }
        }
    }
    
    // ✅ NEW: Check frozen glucose
    private func checkGlucoseNotChanging() {
        // Need minimum 3 values
        guard glucoseHistory.count >= 3 else { return }
        
        // Take last 3 values
        let lastThree = Array(glucoseHistory.suffix(3))
        let lastThreeDates = Array(glucoseHistoryDates.suffix(3))
        
        // Check: are all 3 the same?
        let allSame = lastThree.allSatisfy { $0 == lastThree[0] }
        
        if allSame {
            // Check: has 15 minutes passed between first and last
            if let firstDate = lastThreeDates.first,
               let lastDate = lastThreeDates.last {
                let minutesDiff = Int(lastDate.timeIntervalSince(firstDate) / 60)
                
                if minutesDiff >= 15 {
                    if !isAlarmSnoozed("glucose_not_changing") {
                        sendAlarm(
                            type: .glucoseNotChanging,
                            id: "glucose_not_changing",
                            title: "⚠️ Glucose not changing!",
                            body: "Reading \(lastThree[0]) mg/dL holding for \(minutesDiff) minutes. Possible sensor glitch!",
                            critical: false
                        )
                        
                        // Auto-snooze for 15 minutes
                        snoozeAlarm(id: "glucose_not_changing", minutes: 15)
                    }
                }
            }
        }
    }
    
    // Check glucose levels
    private func checkGlucoseLevels() {
        // ✅ Very low glucose (critical)
        if currentGlucose <= criticalLowThreshold {
            if !isAlarmSnoozed("critical_low") {
                sendAlarm(
                    type: .criticalLow,
                    id: "critical_low",
                    title: "🚨 CRITICALLY LOW!",
                    body: "Glucose: \(currentGlucose) mg/dL. TAKE ACTION IMMEDIATELY!",
                    critical: true
                )
            }
        }
        // ✅ Low glucose
        else if currentGlucose < lowGlucoseThreshold {
            if !isAlarmSnoozed("low") {
                sendAlarm(
                    type: .lowGlucose,
                    id: "low",
                    title: "⚠️ Low glucose",
                    body: "Glucose: \(currentGlucose) mg/dL",
                    critical: false
                )
            }
        }
        // ✅ Very high glucose (critical)
        else if currentGlucose >= criticalHighThreshold {
            if !isAlarmSnoozed("critical_high") {
                sendAlarm(
                    type: .criticalHigh,
                    id: "critical_high",
                    title: "🚨 CRITICALLY HIGH!",
                    body: "Glucose: \(currentGlucose) mg/dL. TAKE ACTION!",
                    critical: true
                )
            }
        }
        // ✅ High glucose
        else if currentGlucose > highGlucoseThreshold {
            if !isAlarmSnoozed("high") {
                sendAlarm(
                    type: .highGlucose,
                    id: "high",
                    title: "⚠️ High glucose",
                    body: "Glucose: \(currentGlucose) mg/dL",
                    critical: false
                )
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ✅ NEW: NOTIFICATION SYSTEM WITH SNOOZE (TASK 8)
    // ═══════════════════════════════════════════════════════════════
    
    private func sendAlarm(type: AlarmType, id: String, title: String, body: String, critical: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = critical ? .defaultCritical : .default
        content.userInfo = ["alarmId": id, "alarmType": getAlarmTypeName(type), "glucose": currentGlucose]
        content.badge = 1
        
        if critical {
            content.interruptionLevel = .critical
        }
        
        // ✅ Determine category based on alarm type
        content.categoryIdentifier = getAlarmCategory(for: type)
        
        let request = UNNotificationRequest(
            identifier: id + "_\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [ALARM] Send error \(id): \(error)")
            } else {
                print("✅ [ALARM] Sent: \(title)")
            }
        }
        
        // ═══════════════════════════════════════════════════════════════
        // ✅ TASK 3: CRITICAL NOTIFICATIONS FOR APPLE WATCH
        // ═══════════════════════════════════════════════════════════════
        #if os(watchOS)
        if critical {
            sendWatchCriticalAlert(title: title, body: body, type: type)
        }
        #endif
    }
    
    // ✅ NEW: Determine alarm category (for snooze buttons)
    private func getAlarmCategory(for type: AlarmType) -> String {
        switch type {
        case .lowGlucose:
            return "ALARM_LOW"              // 10/20/30 minutes
        case .criticalLow:
            return "ALARM_CRITICAL_LOW"     // only 10 minutes
        case .highGlucose:
            return "ALARM_HIGH"             // 10/20/30/45/60 minutes
        case .criticalHigh:
            return "ALARM_CRITICAL_HIGH"    // 10/20/30 minutes
        case .missedReadings:
            return "ALARM_AUTO"             // automatic (show for info)
        case .loopNotClosed:
            return "ALARM_AUTO"             // automatic
        case .glucoseNotChanging:
            return "ALARM_AUTO"             // automatic
        }
    }
    
    private func getAlarmTypeName(_ type: AlarmType) -> String {
        switch type {
        case .lowGlucose: return "low"
        case .criticalLow: return "critical_low"
        case .highGlucose: return "high"
        case .criticalHigh: return "critical_high"
        case .missedReadings: return "missed_readings"
        case .loopNotClosed: return "loop_not_closed"
        case .glucoseNotChanging: return "glucose_not_changing"
        }
    }
    
    // System notification (for critical system errors)
    private func sendSystemAlarm(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .defaultCritical
        content.interruptionLevel = .critical
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "system_alarm_\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [SYSTEM_ALARM] Error: \(error)")
            } else {
                print("✅ [SYSTEM_ALARM] Sent: \(title)")
            }
        }
    }
    
    // ✅ IMPROVED: Alarm snooze with repeat tracking
    func snoozeAlarm(id: String, minutes: Int) {
        let snoozeUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        
        // Increase snooze counter
        if let existing = snoozedAlarms[id] {
            snoozedAlarms[id] = AlarmSnooze(until: snoozeUntil, count: existing.count + 1)
        } else {
            snoozedAlarms[id] = AlarmSnooze(until: snoozeUntil, count: 1)
        }
        
        print("⏰ [ALARM] \(id) snoozed for \(minutes) min until \(snoozeUntil)")
        
        // Schedule check when snooze time expires
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(minutes * 60)) { [weak self] in
            guard let self = self else { return }
            
            // Remove from snoozed
            self.snoozedAlarms.removeValue(forKey: id)
            
            print("⏰ [ALARM] \(id) - snooze time expired, checking condition...")
            
            // Check: is this alarm still needed?
            self.checkAllAlarmConditions()
        }
    }
    
    // Check: is alarm snoozed
    private func isAlarmSnoozed(_ id: String) -> Bool {
        if let snooze = snoozedAlarms[id] {
            if Date() < snooze.until {
                return true
            } else {
                // Time expired - remove
                snoozedAlarms.removeValue(forKey: id)
                return false
            }
        }
        return false
    }
    
    // ═══════════════════════════════════════════════════════════════
    // NOTIFICATION CATEGORIES SETUP
    // ═══════════════════════════════════════════════════════════════
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .criticalAlert]
        ) { granted, error in
            if granted {
                print("✅ [NOTIFICATIONS] Permission granted")
                self.setupNotificationCategories()
            } else {
                print("❌ [NOTIFICATIONS] Permission denied: \(error?.localizedDescription ?? "")")
            }
        }
    }
    
    private func setupNotificationCategories() {
        var categories: Set<UNNotificationCategory> = []
        
        // ✅ 1. Low glucose: 10/20/30 minutes
        let lowActions = [
            UNNotificationAction(identifier: "SNOOZE_10", title: "Snooze 10 min", options: []),
            UNNotificationAction(identifier: "SNOOZE_20", title: "Snooze 20 min", options: []),
            UNNotificationAction(identifier: "SNOOZE_30", title: "Snooze 30 min", options: [])
        ]
        categories.insert(UNNotificationCategory(
            identifier: "ALARM_LOW",
            actions: lowActions,
            intentIdentifiers: [],
            options: []
        ))
        
        // ✅ 2. Critical low: only 10 minutes
        let criticalLowActions = [
            UNNotificationAction(identifier: "SNOOZE_10", title: "Snooze 10 min", options: [])
        ]
        categories.insert(UNNotificationCategory(
            identifier: "ALARM_CRITICAL_LOW",
            actions: criticalLowActions,
            intentIdentifiers: [],
            options: []
        ))
        
        // ✅ 3. High glucose: 10/20/30/45/60 minutes
        let highActions = [
            UNNotificationAction(identifier: "SNOOZE_10", title: "10 min", options: []),
            UNNotificationAction(identifier: "SNOOZE_20", title: "20 min", options: []),
            UNNotificationAction(identifier: "SNOOZE_30", title: "30 min", options: []),
            UNNotificationAction(identifier: "SNOOZE_45", title: "45 min", options: []),
            UNNotificationAction(identifier: "SNOOZE_60", title: "60 min", options: [])
        ]
        categories.insert(UNNotificationCategory(
            identifier: "ALARM_HIGH",
            actions: Array(highActions.prefix(3)), // iOS shows max 3-4 buttons
            intentIdentifiers: [],
            options: []
        ))
        
        // ✅ 4. Critical high: 10/20/30 minutes
        let criticalHighActions = [
            UNNotificationAction(identifier: "SNOOZE_10", title: "Snooze 10 min", options: []),
            UNNotificationAction(identifier: "SNOOZE_20", title: "Snooze 20 min", options: []),
            UNNotificationAction(identifier: "SNOOZE_30", title: "Snooze 30 min", options: [])
        ]
        categories.insert(UNNotificationCategory(
            identifier: "ALARM_CRITICAL_HIGH",
            actions: criticalHighActions,
            intentIdentifiers: [],
            options: []
        ))
        
        // ✅ 5. Auto alarms (missed readings, loop, frozen glucose)
        // Show for info only, auto-snoozed
        let autoActions = [
            UNNotificationAction(identifier: "DISMISS", title: "OK", options: [])
        ]
        categories.insert(UNNotificationCategory(
            identifier: "ALARM_AUTO",
            actions: autoActions,
            intentIdentifiers: [],
            options: []
        ))
        
        UNUserNotificationCenter.current().setNotificationCategories(categories)
        print("✅ [NOTIFICATIONS] Categories configured (\(categories.count) total)")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ✅ TASK 3: CRITICAL NOTIFICATIONS FOR APPLE WATCH
    // ═══════════════════════════════════════════════════════════════
    
    #if os(watchOS)
    private func sendWatchCriticalAlert(title: String, body: String, type: AlarmType) {
        // Check: didn't send recently (spam protection)
        if let lastAlert = lastWatchCriticalAlert,
           Date().timeIntervalSince(lastAlert) < watchAlertCooldown {
            print("⏰ [WATCH ALERT] Skipping - too soon after last alert")
            return
        }
        
        lastWatchCriticalAlert = Date()
        
        print("⌚️ [WATCH ALERT] 🚨 SENDING CRITICAL ALERT")
        print("⌚️ [WATCH ALERT] Title: \(title)")
        print("⌚️ [WATCH ALERT] Body: \(body)")
        
        // Create CRITICAL notification with max priority
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .defaultCritical  // Critical sound
        content.interruptionLevel = .critical  // Breaks through Do Not Disturb
        content.badge = 1
        content.userInfo = [
            "critical": true,
            "glucose": currentGlucose,
            "direction": direction,
            "alarmType": getAlarmTypeName(type)
        ]
        
        // Category with action buttons
        content.categoryIdentifier = getAlarmCategory(for: type)
        
        let request = UNNotificationRequest(
            identifier: "watch_critical_\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil  // Show immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [WATCH ALERT] Send error: \(error)")
            } else {
                print("✅ [WATCH ALERT] Critical alert sent!")
            }
        }
        
        // HAPTICS on watch
        triggerWatchHaptics(type: type)
        
        // Update complication on watch
        let server = CLKComplicationServer.sharedInstance()
        for complication in server.activeComplications ?? [] {
            server.reloadTimeline(for: complication)
        }
        print("⌚️ [WATCH ALERT] Complication updated")
    }
    
    // ✅ TASK 3: Haptic feedback (vibration) on Apple Watch
    private func triggerWatchHaptics(type: AlarmType) {
        // Determine vibration type based on criticality
        let hapticType: WKHapticType
        let hapticCount: Int
        
        switch type {
        case .criticalLow:
            hapticType = .failure  // Strongest vibration
            hapticCount = 3  // Repeat 3 times
            print("⌚️ [HAPTIC] 🚨 Critical vibration (VERY LOW)")
            
        case .criticalHigh:
            hapticType = .failure
            hapticCount = 3
            print("⌚️ [HAPTIC] 🚨 Critical vibration (VERY HIGH)")
            
        case .lowGlucose:
            hapticType = .notification  // Medium vibration
            hapticCount = 2
            print("⌚️ [HAPTIC] ⚠️ Warning vibration (LOW)")
            
        case .highGlucose:
            hapticType = .notification
            hapticCount = 2
            print("⌚️ [HAPTIC] ⚠️ Warning vibration (HIGH)")
            
        default:
            hapticType = .notification
            hapticCount = 1
            print("⌚️ [HAPTIC] ℹ️ Regular vibration")
        }
        
        // Trigger vibration needed number of times
        for i in 0..<hapticCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) {
                WKInterfaceDevice.current().play(hapticType)
            }
        }
        
        print("✅ [HAPTIC] Vibration triggered (\(hapticCount)x)")
    }
    #endif
}
