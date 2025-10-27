// ContentView.swift for Watch App
// Put this file in: SugarWatch Watch App Watch App/ContentView.swift
// CRITICAL: App for Type 1 diabetes control
// Child's life depends on reliability!
//
// UPDATES:
// ✅ TASK 1: Long Press gesture (0.5 sec) for refresh
// ✅ TASK 2: Force refresh widget/complication
// ✅ Graph with points for last 1 hour
// ✅ Boluses display with time distribution
// ✅ Increased last update time font
// ✅ Auto-refresh every 5 minutes
// ✅ Refresh on wrist raise
//
// VERSION: Universal (works on ALL watches!)

import SwiftUI
import WidgetKit
import CommonCrypto
import WatchKit

struct ContentView: View {
    @StateObject private var dataManager = GlucoseDataManager.shared
    @State private var showDetails = false
    @AppStorage("useMMOL", store: UserDefaults(suiteName: "group.com.devsugar.SugarWatch"))
    private var useMMOL = false
    
    // Tracking watch state
    @Environment(\.scenePhase) private var scenePhase
    
    // ✅ IMPROVED: Timer for auto-refresh every 5 minutes
    @State private var updateTimer: Timer?
    @State private var updateCounter: Int = 0  // Update counter
    
    // Loading state
    @State private var isLoading = false
    
    // ✅ NEW: Glucose history for graph (1 hour = 12 points every 5 min)
    @State private var glucoseHistory: [(value: Int, date: Date)] = []
    
    // ✅ NEW: Bolus history for last 3 hours (Fiasp)
    @State private var bolusHistory: [(amount: Double, date: Date, type: String)] = []
    
    // ✅ NEW: Pump data
    @State private var pumpIOB: Double = 0.0
    @State private var pumpCOB: Double = 0.0
    
    // ✅ NEW: Indicator that data is stale
    @State private var isDataStale = false
    
    // ✅ NEW: Time of last Loop connection to Nightscout (in minutes)
    @State private var loopMinutesAgo: Int = 0
    @State private var isLoopStale = false  // >10 minutes - problem
    
    // ✅ NEW: Basal rate
    @State private var currentBasal: Double = 0.0
    
    // ✅ TASK 1: Tracking double tap gesture
    @State private var doubleTapCount: Int = 0
    @State private var lastDoubleTapTime: Date = Date()
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            if showDetails {
                detailsView
            } else {
                mainView
            }
            
            // SPINNER - shown during data loading
            if isLoading {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .red))
                            .scaleEffect(0.8)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                        Spacer()
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showDetails.toggle()
            }
        }
        // ✅ TASK 1: LONG PRESS GESTURE for data refresh
        // Press and hold screen for 0.5 seconds
        // WORKS ON ALL watches and ALL watchOS versions!
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    handleUpdateGesture()
                }
        )
        .onAppear {
            print("\n⌚ [WATCH] ════════════════════════════════")
            print("⌚ [WATCH] Screen activated")
            print("⌚ [WATCH] ════════════════════════════════\n")
            fetchAllData()
            startAutoUpdate()
        }
        .onDisappear {
            print("⌚ [WATCH] Screen deactivated")
            stopAutoUpdate()
        }
        // ✅ CRITICAL! Tracking watch lifecycle
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                print("✅ [WATCH] Watch ACTIVE - raised wrist / tapped screen")
                fetchAllData()
                WidgetCenter.shared.reloadAllTimelines()
                startAutoUpdate()
            case .inactive:
                print("⏸ [WATCH] Watch INACTIVE")
            case .background:
                print("🌙 [WATCH] Watch IN BACKGROUND")
                stopAutoUpdate()
            @unknown default:
                break
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ✅ IMPROVED: AUTO-REFRESH EVERY 5 MINUTES (TASK 7)
    // ═══════════════════════════════════════════════════════════════
    
    private func startAutoUpdate() {
        stopAutoUpdate() // Stop old one if exists
        
        print("▶️ [WATCH] Starting auto-refresh every 5 minutes")
        
        // ✅ IMPROVED: Using RunLoop.main for reliability
        updateTimer = Timer(timeInterval: 300, repeats: true) { [self] _ in
            updateCounter += 1
            print("\n⏰ [WATCH] ════════════════════════════════")
            print("⏰ [WATCH] Auto-refresh #\(updateCounter)")
            print("⏰ [WATCH] Time: \(Date())")
            print("⏰ [WATCH] ════════════════════════════════\n")
            
            fetchAllData()
        }
        
        // ✅ CRITICAL: Adding to .common RunLoop mode for reliable work
        if let timer = updateTimer {
            RunLoop.main.add(timer, forMode: .common)
            print("✅ [WATCH] Timer added to RunLoop.main (mode .common)")
        }
        
        // ✅ NEW: Additional check after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.updateTimer == nil || !(self.updateTimer?.isValid ?? false) {
                print("🚨 [WATCH] CRITICAL! Timer died after 10 sec! RESTART!")
                self.startAutoUpdate()
            } else {
                print("✅ [WATCH] Timer working normally (check after 10 sec)")
            }
        }
        
        print("✅ [WATCH] Auto-refresh started")
    }
    
    private func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
        print("⏹ [WATCH] Auto-refresh stopped")
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ✅ TASK 1: LONG PRESS GESTURE HANDLER
    // Press and hold screen for 0.5 seconds for data refresh
    // ═══════════════════════════════════════════════════════════════
    
    private func handleUpdateGesture() {
        doubleTapCount += 1
        lastDoubleTapTime = Date()
        
        print("\n👆 [WATCH GESTURE] ═══════════════════════════════════")
        print("👆 [WATCH GESTURE] LONG PRESS detected! (#\(doubleTapCount))")
        print("👆 [WATCH GESTURE] Current glucose: \(dataManager.currentGlucose) mg/dL")
        print("👆 [WATCH GESTURE] Starting data refresh...")
        print("👆 [WATCH GESTURE] ═══════════════════════════════════\n")
        
        // Save current value for check
        let oldGlucose = dataManager.currentGlucose
        let oldUpdate = dataManager.lastUpdate
        
        // ✅ Haptic feedback
        WKInterfaceDevice.current().play(.click)
        
        // ✅ Show spinner
        withAnimation {
            isLoading = true
        }
        
        // ✅ Load data
        print("📡 [WATCH GESTURE] Starting loading via dataManager.fetchData()...")
        dataManager.fetchData()
        
        // 2. Load history for graph
        fetchGlucoseHistory()
        
        // 3. Load boluses
        fetchBolusHistory()
        
        // 4. Load Loop status
        fetchLoopStatus()
        
        // ✅ TASK 2: Force refresh widget/complication
        WidgetCenter.shared.reloadAllTimelines()
        print("✅ [WATCH GESTURE] Widget force refreshed!")
        
        // ✅ Check data update after 2  seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let newGlucose = self.dataManager.currentGlucose
            let newUpdate = self.dataManager.lastUpdate
            
            if newGlucose != oldGlucose || newUpdate != oldUpdate {
                print("✅ [WATCH GESTURE] Data UPDATED!")
                print("   Old glucose: \(oldGlucose) mg/dL")
                print("   New glucose: \(newGlucose) mg/dL")
                
                // Check data freshness
                self.checkDataFreshness()
                
                // Hide spinner
                withAnimation {
                    self.isLoading = false
                }
                print("✅ [WATCH GESTURE] Refresh completed successfully!\n")
            } else {
                print("⚠️ [WATCH GESTURE] Data not updated yet, waiting 2 more sec...")
                
                // Wait more 2  seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    let finalGlucose = self.dataManager.currentGlucose
                    let finalUpdate = self.dataManager.lastUpdate
                    
                    if finalGlucose != oldGlucose || finalUpdate != oldUpdate {
                        print("✅ [WATCH GESTURE] Data updated (2nd attempt)!")
                        print("   New glucose: \(finalGlucose) mg/dL")
                    } else {
                        print("⚠️ [WATCH GESTURE] Data unchanged")
                        print("   Glucose may actually be unchanged on server")
                    }
                    
                    // Check data freshness
                    self.checkDataFreshness()
                    
                    // Hide spinner
                    withAnimation {
                        self.isLoading = false
                    }
                    print("✅ [WATCH GESTURE] Refresh completed!\n")
                }
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ✅ NEW: LOADING ALL DATA (TASKS 2, 3)
    // ═══════════════════════════════════════════════════════════════
    
    private func fetchAllData() {
        isLoading = true
        
        // 1. Load main glucose data
        dataManager.fetchData()
        
        // ✅ 2. TASK 2: Load history for graph (2  hours)
        fetchGlucoseHistory()
        
        // ✅ 3. TASK 3: Load boluses for last 3 hours
        fetchBolusHistory()
        
        // ✅ 4. NEW: Load last Loop connection time
        fetchLoopStatus()
        
        // Check data freshness
        checkDataFreshness()
        
        // Refresh widgets
        WidgetCenter.shared.reloadAllTimelines()
        
        // Hide spinner after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                self.isLoading = false
            }
        }
    }
    
    // ✅ TASK 2: Loading glucose history for 1 hour
    private func fetchGlucoseHistory() {
        NightscoutService.shared.fetchGlucoseHistory(hours: 1) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let history):
                    // ✅ Convert: Double timestamp -> Date
                    self.glucoseHistory = history.map { entry in
                        let date = Date(timeIntervalSince1970: entry.date / 1000)
                        return (value: entry.sgv, date: date)
                    }
                    print("✅ [WATCH] History loaded: \(self.glucoseHistory.count)  points for 1 hour")
                    
                case .failure(let error):
                    print("❌ [WATCH] History load error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // ✅ TASK 3: Loading boluses for last 3 hours (Fiasp)
    private func fetchBolusHistory() {
        print("\n💊 [WATCH BOLUS] ═══════════════════════════════")
        print("💊 [WATCH BOLUS] Requesting boluses for 3 hours")
        
        NightscoutService.shared.fetchTreatments(hours: 3) { result in
            switch result {
            case .success(let treatments):
                print("💊 [WATCH BOLUS] Received treatments: \(treatments.count)")
                
                // ✅ BOUNDARY: 3  hours  ago
                let threeHoursAgo = Date().addingTimeInterval(-3 * 60 * 60)
                print("💊 [WATCH BOLUS] Filtering from: \(threeHoursAgo)")
                
                // ✅ FILTER: Exclude Temp Basal + filter by time
                let boluses = treatments.compactMap { treatment -> (amount: Double, date: Date, type: String)? in
                    guard let insulin = treatment.insulin, insulin > 0 else {
                        return nil
                    }
                    
                    let type = treatment.eventType ?? "Bolus"
                    let typeLower = type.lowercased()
                    
                    // ❌ EXCLUDE: Temp Basal
                    if typeLower.contains("temp") || typeLower.contains("basal") {
                        print("   ⏭ Skip basal: \(type) (\(String(format: "%.2f", insulin))  U)")
                        return nil
                    }
                    
                    // Convert created_at to Date
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    
                    guard let date = formatter.date(from: treatment.created_at) ??
                                    ISO8601DateFormatter().date(from: treatment.created_at) else {
                        return nil
                    }
                    
                    // ❌ CRITICAL: EXCLUDE old boluses (older than 3 hours)
                    if date < threeHoursAgo {
                        let hoursAgo = Int(Date().timeIntervalSince(date) / 3600)
                        print("   ⏭ Skip old: \(String(format: "%.2f", insulin))  U (\(hoursAgo)  h ago)")
                        return nil
                    }
                    
                    // ✅ ACCEPT: Bolus for last 3 hours!
                    let minutesAgo = Int(Date().timeIntervalSince(date) / 60)
                    print("   ✅ Bolus: \(String(format: "%.2f", insulin))  U (\(minutesAgo)  min, \(type))")
                    return (amount: insulin, date: date, type: type)
                }
                
                print("💊 [WATCH BOLUS] Boluses for 3 hours: \(boluses.count)")
                
                DispatchQueue.main.async {
                    self.bolusHistory = boluses.sorted { $0.date > $1.date }
                    print("✅ [WATCH BOLUS] bolusHistory updated: \(self.bolusHistory.count)")
                    
                    if !self.bolusHistory.isEmpty {
                        let total = self.bolusHistory.reduce(0) { $0 + $1.amount }
                        print("✅ [WATCH BOLUS] Sum for 3 hours: \(String(format: "%.2f", total))  U")
                        
                        for (idx, bolus) in self.bolusHistory.enumerated() {
                            let minutesAgo = Int(Date().timeIntervalSince(bolus.date) / 60)
                            print("   \(idx + 1). \(String(format: "%.2f", bolus.amount))  U - \(minutesAgo)  min ago (\(bolus.type))")
                        }
                    } else {
                        print("💊 [WATCH BOLUS] No boluses for 3 hours")
                    }
                    print("💊 [WATCH BOLUS] ═══════════════════════════════\n")
                }
                
            case .failure(let error):
                print("❌ [WATCH BOLUS] Error: \(error.localizedDescription)")
                print("💊 [WATCH BOLUS] ═══════════════════════════════\n")
            }
        }
    }
    
    // ✅ NEW: Loading Loop status (time of last connection + basal)
    private func fetchLoopStatus() {
        // ✅ FIXED: Using filter by Loop device
        let baseURL = "https://alisahealthysugar.work"
        let apiSecret = "dF275hNNcji6845e21SSvh5723"
        
        let urlString = "\(baseURL)/api/v1/devicestatus.json?find[device]=loop://iPhone&count=1"
        
        guard let url = URL(string: urlString) else {
            print("❌ [WATCH] Invalid URL for Loop status")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        // ✅ KEY: using SHA1 hash in header (like in NightscoutService)
        let hashedSecret = sha1Hash(apiSecret)
        request.setValue(hashedSecret, forHTTPHeaderField: "api-secret")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ [WATCH] Loop status load error: \(error?.localizedDescription ?? "unknown")")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let first = json.first {
                    
                    // 1. Time of last Loop connection
                    if let createdAt = first["created_at"] as? String {
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        
                        if let loopDate = formatter.date(from: createdAt) ??
                                         ISO8601DateFormatter().date(from: createdAt) {
                            
                            let minutesAgo = Int(Date().timeIntervalSince(loopDate) / 60)
                            
                            DispatchQueue.main.async {
                                self.loopMinutesAgo = minutesAgo
                                self.isLoopStale = minutesAgo > 10
                                
                                print("✅ [WATCH] Loop status: \(minutesAgo)  min ago")
                                
                                if self.isLoopStale {
                                    print("🚨 [WATCH] WARNING! Loop not connected for more than 10 minutes!")
                                }
                            }
                        }
                    }
                    
                    // 2. IOB and COB from Loop data
                    if let loop = first["loop"] as? [String: Any] {
                        // IOB
                        if let iob = loop["iob"] as? [String: Any],
                           let iobValue = iob["iob"] as? Double {
                            DispatchQueue.main.async {
                                self.pumpIOB = iobValue
                                print("   💊 IOB: \(String(format: "%.2f", iobValue)) U")
                            }
                        }
                    }
                    
                    // ✅ NEW: COB load from treatments (sum for 3 hours)
                    self.fetchCarbsSum()
                    
                    // 3. Basal rate from loop.enacted
                    if let loop = first["loop"] as? [String: Any],
                       let enacted = loop["enacted"] as? [String: Any],
                       let rate = enacted["rate"] as? Double, rate > 0 {
                        // ✅ Has active temp basal
                        DispatchQueue.main.async {
                            self.currentBasal = rate
                            print("✅ [WATCH] Temp Basal: \(String(format: "%.2f", rate)) U/h")
                        }
                    } else {
                        // ✅ No temp basal (rate = 0 or nil) - load scheduled
                        print("⚠️ [WATCH] Temp Basal: not active (load scheduled)")
                        self.fetchScheduledBasal()
                    }
                }
            } catch {
                print("❌ [WATCH] Loop status parse error: \(error)")
            }
        }.resume()
    }
    
    // ✅ NEW: Loading scheduled basal from profile.json
    private func fetchScheduledBasal() {
        let baseURL = "https://alisahealthysugar.work"
        let apiSecret = "dF275hNNcji6845e21SSvh5723"
        
        let urlString = "\(baseURL)/api/v1/profile.json"
        
        guard let url = URL(string: urlString) else {
            print("❌ [WATCH] Invalid URL for profile")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let hashedSecret = sha1Hash(apiSecret)
        request.setValue(hashedSecret, forHTTPHeaderField: "api-secret")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ [WATCH] Profile load error: \(error?.localizedDescription ?? "unknown")")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let first = json.first,
                   let defaultProfile = first["defaultProfile"] as? String,
                   let store = first["store"] as? [String: Any],
                   let profileData = store[defaultProfile] as? [String: Any],
                   let basal = profileData["basal"] as? [[String: Any]] {
                    
                    // Get current scheduled basal
                    let calendar = Calendar.current
                    let now = Date()
                    let hour = calendar.component(.hour, from: now)
                    let minute = calendar.component(.minute, from: now)
                    let currentSeconds = hour * 3600 + minute * 60
                    
                    var scheduledBasal = 0.0
                    
                    for entry in basal {
                        if let time = entry["time"] as? String,
                           let value = entry["value"] as? Double {
                            
                            let components = time.split(separator: ":").compactMap { Int($0) }
                            if components.count == 2 {
                                let entrySeconds = components[0] * 3600 + components[1] * 60
                                
                                if currentSeconds >= entrySeconds {
                                    scheduledBasal = value
                                } else {
                                    break
                                }
                            }
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self.currentBasal = scheduledBasal
                        print("✅ [WATCH] Scheduled Basal: \(String(format: "%.2f", scheduledBasal)) U/h")
                    }
                }
            } catch {
                print("❌ [WATCH] Profile parse error: \(error)")
            }
        }.resume()
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ✅ NEW: LOADING CARBS SUM FOR 3 HOURS FOR COB
    // ═══════════════════════════════════════════════════════════════
    private func fetchCarbsSum() {
        print("\n🍞 [WATCH COB] ═══════════════════════════════")
        print("🍞 [WATCH COB] Requesting carbs for 3 hours for COB")
        
        NightscoutService.shared.fetchTreatments(hours: 3) { result in
            switch result {
            case .success(let treatments):
                print("🍞 [WATCH COB] Received treatments: \(treatments.count)")
                
                // ✅ BOUNDARY: 3  hours  ago
                let threeHoursAgo = Date().addingTimeInterval(-3 * 60 * 60)
                
                // ✅ SUM carbs for last 3 hours
                var totalCarbs: Double = 0
                var carbCount = 0
                
                for treatment in treatments {
                    guard let carbs = treatment.carbs, carbs > 0 else {
                        continue
                    }
                    
                    // Convert created_at to Date
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    
                    guard let date = formatter.date(from: treatment.created_at) ??
                                    ISO8601DateFormatter().date(from: treatment.created_at) else {
                        continue
                    }
                    
                    // ❌ Skip old
                    if date < threeHoursAgo {
                        continue
                    }
                    
                    totalCarbs += carbs
                    carbCount += 1
                    
                    let minutesAgo = Int(Date().timeIntervalSince(date) / 60)
                    print("   ✅ Carbs: \(Int(carbs)) g (\(minutesAgo)  min ago)")
                }
                
                print("🍞 [WATCH COB] Found carbs: \(carbCount)  entries")
                print("🍞 [WATCH COB] Sum for 3 hours: \(Int(totalCarbs)) g")
                
                DispatchQueue.main.async {
                    self.pumpCOB = totalCarbs
                    print("✅ [WATCH COB] pumpCOB updated: \(Int(totalCarbs)) g")
                }
                print("🍞 [WATCH COB] ═══════════════════════════════\n")
                
            case .failure(let error):
                print("❌ [WATCH COB] Error: \(error.localizedDescription)")
                print("🍞 [WATCH COB] ═══════════════════════════════\n")
            }
        }
    }
    
    // Helper function for SHA1 hash
    private func sha1Hash(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    // ✅ TASK 1: Data freshness check
    private func checkDataFreshness() {
        let minutesAgo = dataManager.minutesAgo
        isDataStale = minutesAgo > 10
        
        if isDataStale {
            print("🔴 [WATCH] WARNING! Data stale: \(minutesAgo)  minutes")
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MAIN SCREEN - COMPACT SINGLE SCREEN DESIGN
    // ═══════════════════════════════════════════════════════════════
    
    private var mainView: some View {
        VStack(spacing: 0) {
            // ✅ TOP PART: BIG NUMBER LEFT + COMPACT CARDS RIGHT
            HStack(alignment: .top, spacing: 6) {
                // LEFT PART: BIG glucose number (60pt!)
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatGlucose(dataManager.currentGlucose))
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundColor(glucoseColorForDayMode)
                    
                    // ARROW AND DELTA
                    HStack(spacing: 4) {
                        Text(directionToArrow(dataManager.direction))
                            .font(.system(size: 20))
                            .foregroundColor(glucoseColorForDayMode)
                        
                        if let delta = dataManager.delta {
                            Text(formatDelta(delta))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(deltaColorForNightMode(delta))
                        }
                    }
                }
                .padding(.leading, 2)
                
                Spacer()
                
                // ✅ RIGHT PART: 2 ROWS HORIZONTAL (COMPACT CARDS)
                VStack(alignment: .trailing, spacing: 3) {
                    // ════ РЯД 1: ВРЕМЯ + LOOP ════
                    HStack(spacing: 3) {
                        // UPDATE TIME
                        HStack(spacing: 2) {
                            Circle()
                                .fill(dataFreshnessColor)
                                .frame(width: 5, height: 5)
                            
                            Text(timeAgo(dataManager.lastUpdate))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(isDataStale ? .red : .white.opacity(0.9))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                        )
                        
                        // LOOP STATUS
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 7))
                                .foregroundColor(isLoopStale ? .red : .green)
                            
                            Text("\(loopMinutesAgo)m")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(isLoopStale ? .red : .white.opacity(0.9))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isLoopStale ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                        )
                    }
                    
                    // ════ РЯД 2: BASAL + IOB + COB + BOLUSES ════
                    VStack(spacing: 2) {
                        // ROW 1: BASAL + IOB
                        HStack(spacing: 3) {
                            // BASAL RATE - ✅ ALWAYS SHOWN
                            HStack(spacing: 2) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.system(size: 7))
                                    .foregroundColor(.purple)
                                
                                Text(String(format: "%.2f", currentBasal))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.purple)
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.purple.opacity(0.15))
                            )
                            
                            // ✅ NEW: IOB
                            if pumpIOB > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "syringe")
                                        .font(.system(size: 7))
                                        .foregroundColor(.blue)
                                    
                                    Text(String(format: "%.1f", pumpIOB))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal, 5)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.blue.opacity(0.15))
                                )
                            }
                        }
                        
                        // ROW 2: COB + BOLUSES
                        HStack(spacing: 3) {
                            // ✅ NEW: COB
                            if pumpCOB > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 7))
                                        .foregroundColor(.orange)
                                    
                                    Text("\(Int(pumpCOB))")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 5)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.orange.opacity(0.15))
                                )
                            }
                            
                            // BOLUSES
                            if !bolusHistory.isEmpty {
                                let totalBolus = bolusHistory.reduce(0) { $0 + $1.amount }
                                
                                HStack(spacing: 2) {
                                    Image(systemName: "drop.fill")
                                        .font(.system(size: 7))
                                        .foregroundColor(.cyan)
                                    
                                    Text(String(format: "%.2f", totalBolus))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.cyan)
                                }
                                .padding(.horizontal, 5)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.cyan.opacity(0.15))
                                )
                            }
                        }
                    }
                }
                .padding(.trailing, 2)
            }
            .padding(.top, 25)  // ✅ CRITICAL: Top padding so it does not overlap time  hours!
            .padding(.horizontal, 4)
            
            // ✅ TASK 2: GRAPH WITH POINTS (FULL WIDTH)
            if !glucoseHistory.isEmpty {
                GlucoseGraphWithDotsView(
                    history: glucoseHistory,
                    currentGlucose: dataManager.currentGlucose,
                    isNightMode: false
                )
                .frame(height: 70)
                .padding(.horizontal, 4)
                .padding(.top, 4)
            }
            
            Spacer()
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    private func formatBolusTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // ═══════════════════════════════════════════════════════════════
    // DETAIL SCREEN - FULL INFO
    // ═══════════════════════════════════════════════════════════════
    
    private var detailsView: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Current glucose
                HStack {
                    Text("Glucose:")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text(formatGlucose(dataManager.currentGlucose))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(glucoseColorForNightMode)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Direction
                HStack {
                    Text("Trend:")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    HStack(spacing: 4) {
                        Text(directionToArrow(dataManager.direction))
                            .font(.system(size: 20))
                        Text(dataManager.direction)
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.white)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Delta
                if let delta = dataManager.delta {
                    HStack {
                        Text("Change:")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(formatDelta(delta))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(deltaColor(delta))
                    }
                    .padding(.horizontal)
                    
                    Divider()
                }
                
                // ✅ INCREASED FONT: Last update
                HStack {
                    Text("Updated:")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        // ✅ INCREASED FONT: was 12, now 15
                        Text(timeAgo(dataManager.lastUpdate))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(isDataStale ? .red : .white)
                        
                        Text(formatTime(dataManager.lastUpdate))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // Pump
                if let pumpContact = dataManager.pumpLastContact {
                    HStack {
                        Text("Pump:")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(dataManager.isPumpConnected ? "Connected" : "Not responding")
                                .font(.system(size: 14))
                                .foregroundColor(dataManager.isPumpConnected ? .green : .red)
                            Text(timeAgo(pumpContact))
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                }
                
                // ✅ TASK 3: Last bolus
                if let lastBolus = dataManager.lastBolus {
                    HStack {
                        Text("Last bolus:")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.2f  U", lastBolus.amount))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.cyan)
                            Text(timeAgo(lastBolus.time))
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                }
                
                // Basal
                if dataManager.currentBasal > 0 {
                    HStack {
                        Text("Basal:")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(String(format: "%.2f  U/h", dataManager.currentBasal))
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                }
                
                // ✅ TASK 3: List of all boluses for last 3 hours
                if !bolusHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Boluses for 3 hours:")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal)
                        
                        ForEach(bolusHistory.prefix(5), id: \.date) { bolus in
                            HStack {
                                Circle()
                                    .fill(Color.cyan)
                                    .frame(width: 4, height: 4)
                                
                                Text(String(format: "%.2f  U", bolus.amount))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.cyan)
                                
                                Spacer()
                                
                                Text(formatTime(bolus.date))
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    // Glucose color
    private var glucoseColorForNightMode: Color {
        if dataManager.currentGlucose < dataManager.lowGlucoseThreshold { return .red }
        if dataManager.currentGlucose > dataManager.highGlucoseThreshold { return .orange }
        return .green
    }
    
    // ✅ NEW: Color for day mode (old logic)
    private var glucoseColorForDayMode: Color {
        if dataManager.currentGlucose < dataManager.lowGlucoseThreshold { return .red }
        if dataManager.currentGlucose > dataManager.highGlucoseThreshold { return .orange }
        return .green
    }
    
    // Delta color
    private func deltaColorForNightMode(_ delta: Double) -> Color {
        if delta < -10 { return .red }
        if delta > 10 { return .orange }
        return .white
    }
    
    private func deltaColor(_ delta: Double) -> Color {
        if delta < -10 { return .red }
        if delta > 10 { return .orange }
        return .white
    }
    
    // ✅ Data freshness indicator (dot color)
    private var dataFreshnessColor: Color {
        let minutes = dataManager.minutesAgo
        if minutes <= 5 { return .green }      // Fresh data
        if minutes <= 10 { return .yellow }    // Still ok
        return .red                             // ALARM!
    }
    
    // Convert direction to arrow
    private func directionToArrow(_ direction: String) -> String {
        switch direction.uppercased() {
        case "DOUBLEUP": return "⇈"
        case "SINGLEUP": return "↑"
        case "FORTYFIVEUP": return "↗"
        case "FLAT": return "→"
        case "FORTYFIVEDOWN": return "↘"
        case "SINGLEDOWN": return "↓"
        case "DOUBLEDOWN": return "⇊"
        default: return "→"
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 1 {
            return "just now"
        } else if minutes == 1 {
            return "1  min ago"
        } else if minutes < 60 {
            return "\(minutes)  min ago"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)  h ago"
            } else {
                return "\(hours)  h\(remainingMinutes)  min ago"
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Glucose conversion
    private func formatGlucose(_ mgdl: Int) -> String {
        if useMMOL {
            let mmol = Double(mgdl) * 0.0555
            return String(format: "%.1f", mmol)
        } else {
            return "\(mgdl)"
        }
    }
    
    // Delta conversion
    private func formatDelta(_ delta: Double) -> String {
        let sign = delta >= 0 ? "+" : ""
        if useMMOL {
            let mmolDelta = delta * 0.0555
            return "\(sign)\(String(format: "%.1f", mmolDelta))"
        } else {
            return "\(sign)\(String(format: "%.1f", delta))"
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// ✅ TASK 2: GRAPH WITH POINTS FOR 60 MINUTES
// RANGE: Up to 12 mmol/L (216 mg/dL) for clarity!
// ═══════════════════════════════════════════════════════════════

struct GlucoseGraphWithDotsView: View {
    let history: [(value: Int, date: Date)]
    let currentGlucose: Int
    let isNightMode: Bool
    
    private let lowThreshold = 70
    private let highThreshold = 180
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            // ✅ NEW: Filter only last 60 minutes (12 points every 5 min)
            let oneHourAgo = Date().addingTimeInterval(-60 * 60)
            let last60Minutes = history.filter { $0.date >= oneHourAgo }
            
            guard !last60Minutes.isEmpty else {
                return AnyView(
                    Text("No data")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                )
            }
            
            // ✅ NEW: Range up to 12 mmol/L (216 mg/dL) for clarity!
            let minValue = 40   // Minimum 40 mg/dL (2.2 mmol/L)
            let maxValue = 216  // Maximum 216 mg/dL (12.0 mmol/L) ← CHANGED!
            let range = maxValue - minValue
            
            return AnyView(
                ZStack {
                    // Background zones (danger ranges)
                    backgroundZones(width: width, height: height, minValue: minValue, maxValue: maxValue, range: range)
                    
                    // Threshold lines
                    thresholdLines(width: width, height: height, minValue: minValue, maxValue: maxValue, range: range)
                    
                    // ✅ POINTS for last 60 minutes
                    ForEach(Array(last60Minutes.enumerated()), id: \.offset) { index, point in
                        let x = CGFloat(index) * (width / CGFloat(max(last60Minutes.count - 1, 1)))
                        
                        // ✅ NEW: If glucose above 12 mmol - line at top!
                        let clampedValue = min(max(point.value, minValue), maxValue)
                        let normalizedY = CGFloat(clampedValue - minValue) / CGFloat(range)
                        let y = height - (normalizedY * height)
                        
                        // Point
                        Circle()
                            .fill(colorForGlucose(point.value))
                            .frame(width: 4, height: 4)
                            .position(x: x, y: y)
                    }
                    
                    // Last U point (enlarged with border)
                    if let lastPoint = last60Minutes.last {
                        let x = width
                        let clampedValue = min(max(lastPoint.value, minValue), maxValue)
                        let normalizedY = CGFloat(clampedValue - minValue) / CGFloat(range)
                        let y = height - (normalizedY * height)
                        
                        ZStack {
                            Circle()
                                .fill(colorForGlucose(lastPoint.value))
                                .frame(width: 7, height: 7)
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 7, height: 7)
                        }
                        .position(x: x, y: y)
                    }
                }
            )
        }
    }
    
    private func backgroundZones(width: CGFloat, height: CGFloat, minValue: Int, maxValue: Int, range: Int) -> some View {
        VStack(spacing: 0) {
            if maxValue > highThreshold {
                Rectangle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(height: height * CGFloat(maxValue - highThreshold) / CGFloat(range))
            }
            
            Rectangle()
                .fill(Color.green.opacity(0.1))
                .frame(height: height * CGFloat(min(highThreshold, maxValue) - max(lowThreshold, minValue)) / CGFloat(range))
            
            if minValue < lowThreshold {
                Rectangle()
                    .fill(Color.red.opacity(0.15))
                    .frame(height: height * CGFloat(lowThreshold - minValue) / CGFloat(range))
            }
        }
    }
    
    private func thresholdLines(width: CGFloat, height: CGFloat, minValue: Int, maxValue: Int, range: Int) -> some View {
        Path { path in
            if lowThreshold > minValue && lowThreshold < maxValue {
                let y = height - (height * CGFloat(lowThreshold - minValue) / CGFloat(range))
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
            
            if highThreshold > minValue && highThreshold < maxValue {
                let y = height - (height * CGFloat(highThreshold - minValue) / CGFloat(range))
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
            }
        }
        .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
    }
    
    private func colorForGlucose(_ value: Int) -> Color {
        if value < lowThreshold { return .red }
        if value > highThreshold { return .orange }
        return .green
    }
}

// ═══════════════════════════════════════════════════════════════
// ✅ TASK 3: BOLUSES DISPLAY WITH TIME DISTRIBUTION
// ═══════════════════════════════════════════════════════════════

struct BolusHistoryView: View {
    let bolusHistory: [(amount: Double, date: Date, type: String)]
    let isNightMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title
            Text("💉 Boluses for 3 hours")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 2)
            
            // ✅ Total bolus
            if !bolusHistory.isEmpty {
                let totalBolus = bolusHistory.reduce(0) { $0 + $1.amount }
                HStack(spacing: 4) {
                    Text("Total:")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(String(format: "%.2f  U", totalBolus))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.cyan)
                }
                .padding(.bottom, 4)
            }
            
            // ✅ Bolus list with time
            VStack(spacing: 3) {
                ForEach(bolusHistory.prefix(4), id: \.date) { bolus in
                    HStack(spacing: 6) {
                        // Icon
                        Image(systemName: "drop.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.cyan)
                        
                        // Amount
                        Text(String(format: "%.2f  U", bolus.amount))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.cyan)
                        
                        Spacer()
                        
                        // Time
                        Text(formatBolusTime(bolus.date))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                        
                        // How long  ago
                        Text("(\(timeAgo(bolus.date)))")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func formatBolusTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func timeAgo(_ date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            return "\(hours)h"
        }
    }
}
