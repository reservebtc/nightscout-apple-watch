import SwiftUI
import WidgetKit
import CommonCrypto

struct ContentView: View {
    @StateObject private var dataManager = GlucoseDataManager.shared
    @State private var showSettings = false
    @AppStorage("nightMode") private var nightMode = false
    @AppStorage("useMMOL", store: UserDefaults(suiteName: "group.com.devsugar.SugarWatch"))
    private var useMMOL = false
    
    // NEW: Tracking app state
    @Environment(\.scenePhase) private var scenePhase
    
    // NEW: Timer for auto-update every 5 minutes
    @State private var updateTimer: Timer?
    
    // ✅ TASK 5: Glucose history for graph (1 hour = 12 points)
    @State private var glucoseHistory: [(value: Int, date: Date)] = []
    
    // ✅ TASK 6: Bolus history for last 3 hours
    @State private var bolusHistory: [(amount: Double, date: Date, type: String)] = []
    
    // ✅ NEW: Pump data from devicestatus
    @State private var pumpIOB: Double = 0.0
    @State private var pumpCOB: Double = 0.0
    @State private var pumpReservoir: Double = 0.0
    @State private var pumpBasal: Double = 0.0
    @State private var pumpBattery: Int = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                (nightMode ? Color.black : Color(UIColor.systemBackground))
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 15) {
                        // MAIN BLOCK - GLUCOSE
                        mainGlucoseCard
                        
                        // ✅ TASK 5: GRAPH FOR 1 HOUR WITH POINTS
                        if !glucoseHistory.isEmpty {
                            glucoseGraphCard
                        }
                        
                        // STATUS AND CHANGES
                        statusCard
                        
                        // ✅ TASK 6: BOLUSES FOR 3 HOURS (ALWAYS SHOW!)
                        bolusCard
                        
                        // ✅ FIXED: PUMP DATA WITH BASAL
                        pumpDataCard
                        
                        // NIGHT MODE TOGGLE
                        nightModeToggle
                        
                        // REFRESH BUTTON
                        refreshButton
                        
                        // ALARM SETTINGS
                        alarmsCard
                    }
                    .padding()
                }
            }
            .navigationTitle("Sugar Watch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(nightMode ? .red : .blue)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(nightMode: nightMode)
            }
            .preferredColorScheme(nightMode ? .dark : nil)
        }
        .onAppear {
            print("📱 [iPhone] ContentView appeared - updating data")
            dataManager.fetchData()
            fetchGlucoseHistory()
            fetchBolusHistory()
            fetchPumpStatus()  // ✅ NEW: Loading pump data
            startAutoUpdate()
        }
        .onDisappear {
            print("📱 [iPhone] ContentView disappeared - stopping timer")
            stopAutoUpdate()
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                print("✅ [iPhone] App ACTIVE - updating data")
                dataManager.fetchData()
                fetchGlucoseHistory()
                fetchBolusHistory()
                fetchPumpStatus()  // ✅ NEW
                WidgetCenter.shared.reloadAllTimelines()
                startAutoUpdate()
            case .inactive:
                print("⏸ [iPhone] App INACTIVE")
            case .background:
                print("🌙 [iPhone] App IN BACKGROUND - stopping UI timer")
                stopAutoUpdate()
            @unknown default:
                break
            }
        }
    }
    
    // NEW: Starting auto-update every 5 minutes
    private func startAutoUpdate() {
        stopAutoUpdate()
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            print("⏰ [iPhone] Auto-update (every 5 minutes)")
            dataManager.fetchData()
            fetchGlucoseHistory()
            fetchBolusHistory()
            fetchPumpStatus()  // ✅ NEW
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        if let timer = updateTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
        
        print("✅ [iPhone] Auto-update started (every 5 minutes)")
    }
    
    private func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ✅ NEW: LOADING PUMP DATA FROM DEVICESTATUS
    // ═══════════════════════════════════════════════════════════════
    
    private func fetchPumpStatus() {
        print("\n🔋 [iPhone PUMP] ═══════════════════════════════")
        print("🔋 [iPhone PUMP] Requesting pump status")
        
        NightscoutService.shared.fetchDeviceStatus { result in
            switch result {
            case .success(let status):
                print("✅ [iPhone PUMP] Received pump status")
                
                DispatchQueue.main.async {
                    // ✅ FIXED: Check both places for reservoir
                    if let reservoir = status.reservoir ?? status.pump?.reservoir {
                        self.pumpReservoir = reservoir
                        print("   💧 Reservoir: \(String(format: "%.1f", reservoir)) U")
                    } else {
                        print("   ⚠️ Reservoir: not found (Loop does not send for Dash)")
                    }
                    
                    // ✅ FIXED: Check both places for battery
                    if let battery = status.battery?.percent ?? status.uploader?.battery {
                        self.pumpBattery = battery
                        print("   🔋 Battery: \(battery)%")
                    } else {
                        print("   ⚠️ Battery: not found")
                    }
                    
                    // IOB from Loop data
                    if let loop = status.loop {
                        if let iob = loop.iob?.iob {
                            self.pumpIOB = iob
                            print("   💊 IOB: \(String(format: "%.2f", iob)) U")
                        }
                    }
                    
                    // ✅ NEW: COB load from treatments (sum for 3 hours)
                    self.fetchCarbsSum()
                    
                    // Basal from Loop enacted
                    if let loop = status.loop {
                        // Basal from enacted
                        if let enacted = loop.enacted, let rate = enacted.rate, rate > 0 {
                            // ✅ Has active temp basal
                            self.pumpBasal = rate
                            print("   📊 Temp Basal: \(String(format: "%.2f", rate)) U/h")
                        } else {
                            // ✅ No temp basal (rate = 0 or nil) → load scheduled
                            print("   ⚠️ Temp Basal: not active (loading scheduled)")
                            self.fetchScheduledBasal()
                        }
                    } else {
                        print("   ⚠️ Loop data: absent")
                        
                        // ✅ NEW: Load scheduled basal from profile!
                        self.fetchScheduledBasal()
                    }
                    
                    print("✅ [iPhone PUMP] Data updated")
                    print("🔋 [iPhone PUMP] ═══════════════════════════════\n")
                }
                
            case .failure(let error):
                print("❌ [iPhone PUMP] Error: \(error.localizedDescription)")
                print("🔋 [iPhone PUMP] ═══════════════════════════════\n")
            }
        }
    }
    
    // ✅ NEW: Loading scheduled basal from profile
    private func fetchScheduledBasal() {
        print("   📊 Loading scheduled basal from profile...")
        
        NightscoutService.shared.fetchProfile { result in
            switch result {
            case .success(let profile):
                DispatchQueue.main.async {
                    if let defaultName = profile.defaultProfile,
                       let store = profile.store[defaultName],
                       let basalSchedule = store.basal {
                        
                        let scheduledBasal = NightscoutService.shared.getCurrentScheduledBasal(from: basalSchedule)
                        self.pumpBasal = scheduledBasal
                        print("   ✅ Scheduled Basal: \(String(format: "%.2f", scheduledBasal)) U/h")
                    } else {
                        print("   ⚠️ Scheduled Basal: not found  in profile")
                    }
                }
                
            case .failure(let error):
                print("   ❌ Profile error: \(error.localizedDescription)")
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ✅ NEW: LOADING CARBS SUM FOR 3 HOURS FOR COB
    // ═══════════════════════════════════════════════════════════════
    private func fetchCarbsSum() {
        print("\n🍞 [COB] ═══════════════════════════════")
        print("🍞 [COB] Requesting carbs for 3 hours for COB")
        
        NightscoutService.shared.fetchTreatments(hours: 3) { result in
            switch result {
            case .success(let treatments):
                print("🍞 [COB] Received treatments: \(treatments.count)")
                
                // ✅ BOUNDARY: 3 hours ago
                let threeHoursAgo = Date().addingTimeInterval(-3 * 60 * 60)
                
                // ✅ SUMMING carbs for last 3 hours
                var totalCarbs: Double = 0
                var carbCount = 0
                
                for treatment in treatments {
                    guard let carbs = treatment.carbs, carbs > 0 else {
                        continue
                    }
                    
                    // ❌ Skip old ones
                    if treatment.date < threeHoursAgo {
                        continue
                    }
                    
                    totalCarbs += carbs
                    carbCount += 1
                    
                    let minutesAgo = Int(Date().timeIntervalSince(treatment.date) / 60)
                    print("   ✅ Carbs: \(Int(carbs))  g(\(minutesAgo)  min ago)")
                }
                
                print("🍞 [COB] Found carbs: \(carbCount)  entries")
                print("🍞 [COB] Sum for 3 hours: \(Int(totalCarbs)) g")
                
                DispatchQueue.main.async {
                    self.pumpCOB = totalCarbs
                    print("✅ [COB] pumpCOB updated: \(Int(totalCarbs)) g")
                }
                print("🍞 [COB] ═══════════════════════════════\n")
                
            case .failure(let error):
                print("❌ [COB] Error: \(error.localizedDescription)")
                print("🍞 [COB] ═══════════════════════════════\n")
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ✅ TASK 5: LOADING GLUCOSE HISTORY (1 HOUR = 12 POINTS)
    // ═══════════════════════════════════════════════════════════════
    
    private func fetchGlucoseHistory() {
        let nightscoutURL = "https://alisahealthysugar.work"
        
        guard let url = URL(string: "\(nightscoutURL)/api/v1/entries.json?count=12") else {
            print("❌ [iPhone GRAPH] Invalid URL for history")
            return
        }
        
        print("\n📊 [iPhone GRAPH] ═══════════════════════════════")
        print("📊 [iPhone GRAPH] Requesting glucose history")
        print("📊 [iPhone GRAPH] URL: \(url)")
        print("📊 [iPhone GRAPH] Request WITHOUT api-secret (public read)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [iPhone GRAPH] History load error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 [iPhone GRAPH] HTTP Status: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("❌ [iPhone GRAPH] No history data")
                return
            }
            
            print("📊 [iPhone GRAPH] Received: \(data.count)  bytes")
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    print("📊 [iPhone GRAPH] Records in JSON: \(json.count)")
                    
                    if let first = json.first {
                        print("📊 [iPhone GRAPH] Example record:")
                        print("   sgv: \(first["sgv"] ?? "none")")
                        print("   dateString: \(first["dateString"] ?? "none")")
                    }
                    
                    let history = json.compactMap { entry -> (value: Int, date: Date)? in
                        guard let sgv = entry["sgv"] as? Int,
                              let dateString = entry["dateString"] as? String else {
                            print("⚠️ [iPhone GRAPH] Пропущена запись (none sgv или dateString)")
                            return nil
                        }
                        
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        
                        var date: Date?
                        date = formatter.date(from: dateString)
                        
                        if date == nil {
                            formatter.formatOptions = [.withInternetDateTime]
                            date = formatter.date(from: dateString)
                        }
                        
                        guard let parsedDate = date else {
                            print("⚠️ [iPhone GRAPH] Failed to parse date: \(dateString)")
                            return nil
                        }
                        
                        return (value: sgv, date: parsedDate)
                    }
                    
                    print("📊 [iPhone GRAPH] Parsed points: \(history.count)")
                    
                    DispatchQueue.main.async {
                        self.glucoseHistory = history.sorted { $0.date < $1.date }
                        print("✅ [iPhone GRAPH] glucoseHistory updated: \(self.glucoseHistory.count)  points")
                        print("📊 [iPhone GRAPH] isEmpty = \(self.glucoseHistory.isEmpty)")
                        
                        if !self.glucoseHistory.isEmpty {
                            print("✅ [iPhone GRAPH] GRAPH SHOULD APPEAR!")
                        } else {
                            print("❌ [iPhone GRAPH] No data - graph will not appear")
                        }
                        print("📊 [iPhone GRAPH] ═══════════════════════════════\n")
                    }
                }
            } catch {
                print("❌ [iPhone GRAPH] JSON parsing error: \(error)")
            }
        }.resume()
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ✅ TASK 6: LOADING BOLUSES FOR 3 HOURS
    // ═══════════════════════════════════════════════════════════════
    
    private func fetchBolusHistory() {
        print("\n💊 [iPhone BOLUS] ═══════════════════════════════")
        print("💊 [iPhone BOLUS] Requesting boluses for 3 hours")
        print("💊 [iPhone BOLUS] Using NightscoutService.shared.fetchTreatments()")
        
        NightscoutService.shared.fetchTreatments(hours: 3) { result in
            switch result {
            case .success(let treatments):
                print("💊 [iPhone BOLUS] Received treatments: \(treatments.count)")
                
                // ✅ CRITICAL: Time boundary - 3 hours ago
                let threeHoursAgo = Date().addingTimeInterval(-3 * 60 * 60)
                print("💊 [iPhone BOLUS] Filtering from: \(threeHoursAgo)")
                
                // ✅ FILTER: Exclude Temp Basal + filter by time
                let boluses = treatments.compactMap { treatment -> (amount: Double, date: Date, type: String)? in
                    guard let insulin = treatment.insulin, insulin > 0 else {
                        return nil
                    }
                    
                    let type = treatment.eventType ?? "Bolus"
                    let typeLower = type.lowercased()
                    
                    // ❌ EXCLUDE: Temp Basal
                    if typeLower.contains("temp") || typeLower.contains("basal") {
                        print("   ⏭ Пропуск базала: \(type) (\(String(format: "%.2f", insulin))  U)")
                        return nil
                    }
                    
                    // ❌ CRITICAL: EXCLUDE old boluses (older than 3 hours)
                    if treatment.date < threeHoursAgo {
                        let hoursAgo = Int(Date().timeIntervalSince(treatment.date) / 3600)
                        print("   ⏭ Skip old: \(String(format: "%.2f", insulin))  U (\(hoursAgo)  h ago)")
                        return nil
                    }
                    
                    // ✅ ACCEPT: Bolus for last Uние 3 hours!
                    let minutesAgo = Int(Date().timeIntervalSince(treatment.date) / 60)
                    print("   ✅ Bolus: \(String(format: "%.2f", insulin))  U (\(minutesAgo)  min, \(type))")
                    return (amount: insulin, date: treatment.date, type: type)
                }
                
                print("💊 [iPhone BOLUS] Болюсов за 3 hours: \(boluses.count)")
                
                DispatchQueue.main.async {
                    self.bolusHistory = boluses.sorted { $0.date > $1.date }
                    print("✅ [iPhone BOLUS] bolusHistory обновлен: \(self.bolusHistory.count)")
                    
                    if !self.bolusHistory.isEmpty {
                        let total = self.bolusHistory.reduce(0) { $0 + $1.amount }
                        print("✅ [iPhone BOLUS] Sum for 3 hours: \(String(format: "%.1f", total))  U")
                        
                        // Log each bolus
                        for (idx, bolus) in self.bolusHistory.enumerated() {
                            let minutesAgo = Int(Date().timeIntervalSince(bolus.date) / 60)
                            print("   \(idx + 1). \(String(format: "%.1f", bolus.amount))  U - \(minutesAgo)  min ago (\(bolus.type))")
                        }
                    } else {
                        print("💊 [iPhone BOLUS] Болюсов none за 3 hours")
                    }
                    print("💊 [iPhone BOLUS] ═══════════════════════════════\n")
                }
                
            case .failure(let error):
                print("❌ [iPhone BOLUS] Error: \(error.localizedDescription)")
                print("💊 [iPhone BOLUS] ═══════════════════════════════\n")
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ✅ TASK 5
    // ═══════════════════════════════════════════════════════════════
    
    private var glucoseGraphCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundColor(nightMode ? .red : .blue)
                    .font(.title2)
                Text("Graph for 1 hour")
                    .font(.headline)
                    .foregroundColor(nightMode ? .red : .primary)
                Spacer()
                
                if let first = glucoseHistory.first, let last = glucoseHistory.last {
                    Text("\(first.value) → \(last.value)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Graph
            glucoseGraph
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(nightMode ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
        )
    }
    
    private var bolusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(nightMode ? .red : .cyan)
                    .font(.title2)
                Text("Boluses for 3 hours")
                    .font(.headline)
                    .foregroundColor(nightMode ? .red : .primary)
                Spacer()
                
                // ✅ BOLUSES SUM
                if !bolusHistory.isEmpty {
                    let totalBolus = bolusHistory.reduce(0) { $0 + $1.amount }
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f  U", totalBolus))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.cyan)
                        Text("total")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("0.0  U")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // ✅ BOLUS LIST or "No boluses" message
            if bolusHistory.isEmpty {
                Text("No boluses in last 3 hours")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                // Bolus list
                ForEach(bolusHistory.prefix(5).indices, id: \.self) { index in
                    let bolus = bolusHistory[index]
                    HStack {
                        // Number
                        Text("\(index + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        
                        // Amount
                        HStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                                .font(.caption)
                                .foregroundColor(.cyan)
                            Text(String(format: "%.1f  U", bolus.amount))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        // Time
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatBolusTime(bolus.date))
                                .font(.subheadline)
                            Text(timeAgo(bolus.date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if index < min(4, bolusHistory.count - 1) {
                        Divider()
                    }
                }
                
                if bolusHistory.count > 5 {
                    Text("+ more \(bolusHistory.count - 5) boluses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(nightMode ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
        )
    }
    
    // MAIN GLUCOSE CARD
    private var mainGlucoseCard: some View {
        VStack(spacing: 8) {
            // Glucose + arrow
            HStack(alignment: .top, spacing: 10) {
                Text(formatGlucose(dataManager.currentGlucose))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(glucoseColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(NightscoutService.shared.directionToArrow(dataManager.direction))
                        .font(.system(size: 36))
                        .foregroundColor(nightMode ? .red : glucoseColor)
                    
                    if let delta = dataManager.delta {
                        Text(formatDelta(delta))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(deltaColor(delta))
                    }
                }
            }
            .padding(.bottom, 5)
            
            // Update time
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(dataManager.isDataStale ? .red : .secondary)
                Text(timeAgo(dataManager.lastUpdate))
                    .foregroundColor(dataManager.isDataStale ? .red : .secondary)
                Text("•")
                    .foregroundColor(.secondary)
                Text(formatTime(dataManager.lastUpdate))
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(nightMode ? Color.red.opacity(0.15) : glucoseColor.opacity(0.1))
        )
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ✅ FIXED: PUMP CARD WITH BASAL INSTEAD OF IOB
    // ═══════════════════════════════════════════════════════════════
    
    private var pumpDataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .foregroundColor(nightMode ? .red : .blue)
                    .font(.title2)
                Text("Pump and Insulin")
                    .font(.headline)
                    .foregroundColor(nightMode ? .red : .primary)
                Spacer()
                Circle()
                    .fill(dataManager.isPumpConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
            }
            
            Divider()
            
            // Last U bolus
            if let bolus = dataManager.lastBolus {
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text("Last U bolus")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.2f", bolus.amount)) U")
                            .font(.headline)
                    }
                    Spacer()
                    Text(timeAgo(bolus.time))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // ✅ FIXED: Basal instead of IOB
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.green)
                VStack(alignment: .leading) {
                    Text("Basal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f U/h", pumpBasal))
                        .font(.headline)
                }
            }
            
            Divider()
            
            // COB
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundColor(.orange)
                VStack(alignment: .leading) {
                    Text("Active carbs (COB)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(pumpCOB)) g")
                        .font(.headline)
                }
            }
            
            if pumpCOB > 0 {
                Divider()
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.red)
                    Text("Expected absorption: ~\(formatAbsorptionTime())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Reservoir
            HStack {
                Image(systemName: "syringe.fill")
                    .foregroundColor(.green)
                VStack(alignment: .leading) {
                    Text("Reservoir")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(pumpReservoir)) U")
                        .font(.headline)
                }
                Spacer()
                if pumpReservoir < 20 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(nightMode ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
        )
    }
    
    // NIGHT MODE
    private var nightModeToggle: some View {
        HStack {
            Image(systemName: nightMode ? "moon.fill" : "sun.max.fill")
                .foregroundColor(nightMode ? .red : .yellow)
                .font(.title2)
            Text("Night mode")
                .font(.headline)
            Spacer()
            Toggle("", isOn: $nightMode)
                .labelsHidden()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(nightMode ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
        )
    }
    
    // REFRESH BUTTON
    private var refreshButton: some View {
        Button(action: {
            print("🔄 [iPhone] Manual refresh")
            dataManager.fetchData()
            fetchGlucoseHistory()
            fetchBolusHistory()
            fetchPumpStatus()  // ✅ NEW
            WidgetCenter.shared.reloadAllTimelines()
        }) {
            HStack {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.title2)
                Text("Refresh data")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(nightMode ? Color.red : Color.blue)
            )
        }
    }
    
    // STATUS
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(nightMode ? .red : .blue)
                    .font(.title2)
                Text("Status")
                    .font(.headline)
                    .foregroundColor(nightMode ? .red : .primary)
            }
            
            Divider()
            
            StatusRow(icon: "📊", title: "Direction", value: dataManager.direction, nightMode: nightMode)
            
            if let delta = dataManager.delta {
                StatusRow(icon: "📈", title: "Change", value: formatDelta(delta), nightMode: nightMode)
            }
            
            StatusRow(icon: "⏰", title: "Last update", value: formatTime(dataManager.lastUpdate), nightMode: nightMode)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(nightMode ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
        )
    }
    
    // 
    private var alarmsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(nightMode ? .red : .orange)
                    .font(.title2)
                Text("Alarm settings")
                    .font(.headline)
                    .foregroundColor(nightMode ? .red : .primary)
            }
            
            Divider()
            
            AlarmRow(
                icon: "🔴",
                title: "Critically low",
                value: formatThreshold(dataManager.criticalLowThreshold),
                snooze: "10  min",
                nightMode: nightMode
            )
            
            AlarmRow(
                icon: "🟡",
                title: "Low glucose",
                value: formatThreshold(dataManager.lowGlucoseThreshold),
                snooze: "10/20/30  min",
                nightMode: nightMode
            )
            
            AlarmRow(
                icon: "🟠",
                title: "High glucose",
                value: formatThreshold(dataManager.highGlucoseThreshold),
                snooze: "10/20/30/45/60  min",
                nightMode: nightMode
            )
            
            AlarmRow(
                icon: "🔴",
                title: "Critically high",
                value: formatThreshold(dataManager.criticalHighThreshold),
                snooze: "10/20/30  min",
                nightMode: nightMode
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(nightMode ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
        )
    }
    
    // HELPER FUNCTIONS
    
    private func formatGlucose(_ mgdl: Int) -> String {
        if useMMOL {
            let mmol = Double(mgdl) * 0.0555
            return String(format: "%.1f", mmol)
        } else {
            return "\(mgdl)"
        }
    }
    
    private func formatThreshold(_ mgdl: Int) -> String {
        if useMMOL {
            let mmol = Double(mgdl) * 0.0555
            return String(format: "%.1f mmol/L", mmol)
        } else {
            return "\(mgdl) mg/dL"
        }
    }
    
    private func formatDelta(_ delta: Double) -> String {
        if useMMOL {
            let mmol = delta * 0.0555
            return String(format: "%+.1f", mmol)
        } else {
            return String(format: "%+.1f", delta)
        }
    }
    
    private var glucoseColor: Color {
        if nightMode { return .red }
        
        let glucose = dataManager.currentGlucose
        if glucose <= dataManager.criticalLowThreshold || glucose >= dataManager.criticalHighThreshold {
            return .red
        } else if glucose <= dataManager.lowGlucoseThreshold {
            return .orange
        } else if glucose >= dataManager.highGlucoseThreshold {
            return .orange
        } else {
            return .green
        }
    }
    
    private func deltaColor(_ delta: Double) -> Color {
        if nightMode { return .red.opacity(0.8) }
        
        if abs(delta) <= 1 {
            return .green
        } else if abs(delta) <= 3 {
            return .orange
        } else {
            return .red
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
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatBolusTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatAbsorptionTime() -> String {
        let hours = Int(pumpCOB / 10) // Approximately 10g/hour
        if hours <= 1 {
            return "1 hour"
        } else {
            return "\(hours) hours"
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ✅ GLUCOSE GRAPH WITH POINTS
    // ═══════════════════════════════════════════════════════════════
    
    private var lowThreshold: Int { dataManager.lowGlucoseThreshold }
    private var highThreshold: Int { dataManager.highGlucoseThreshold }
    
    private var glucoseGraph: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height: CGFloat = 180
            
            // ✅ CHANGED: Range 40-216 mg/dL instead of min-max
            let minValue = 40
            let maxValue = 216
            let range = maxValue - minValue
            
            let history = glucoseHistory
            
            ZStack(alignment: .topLeading) {
                // Background
                Rectangle()
                    .fill(nightMode ? Color.black.opacity(0.3) : Color.white)
                    .cornerRadius(10)
                
                // Threshold lines
                Path { path in
                    // High threshold
                    let highY = height - (CGFloat(highThreshold - minValue) / CGFloat(range)) * height
                    path.move(to: CGPoint(x: 0, y: highY))
                    path.addLine(to: CGPoint(x: width, y: highY))
                    
                    // Low threshold
                    let lowY = height - (CGFloat(lowThreshold - minValue) / CGFloat(range)) * height
                    path.move(to: CGPoint(x: 0, y: lowY))
                    path.addLine(to: CGPoint(x: width, y: lowY))
                }
                .stroke(nightMode ? Color.red.opacity(0.3) : Color.orange.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                
                // Graph line
                if history.count >= 2 {
                    Path { path in
                        for (index, point) in history.enumerated() {
                            let x = (width / CGFloat(history.count - 1)) * CGFloat(index)
                            
                            // ✅ CHANGED: Clamp high values to upper bound
                            let clampedValue = min(max(point.value, minValue), maxValue)
                            let normalizedY = CGFloat(clampedValue - minValue) / CGFloat(range)
                            let y = height - (normalizedY * height)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(nightMode ? Color.red : colorForGlucose(history.last?.value ?? 100), lineWidth: 2)
                }
                
                // Points on graph
                ForEach(Array(history.enumerated()), id: \.offset) { index, point in
                    let x = (width / CGFloat(history.count - 1)) * CGFloat(index)
                    
                    // ✅ CHANGED: Clamp value to range 40-216
                    let clampedValue = min(max(point.value, minValue), maxValue)
                    let normalizedY = CGFloat(clampedValue - minValue) / CGFloat(range)
                    let y = height - (normalizedY * height)
                    
                    Circle()
                        .fill(colorForGlucose(point.value))
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                        .position(x: x, y: y)
                }
                
                // Last point enlarged
                if let lastPoint = history.last {
                    let x = width
                    
                    // ✅ CHANGED: Lastеdays
                    let clampedValue = min(max(lastPoint.value, minValue), maxValue)
                    let normalizedY = CGFloat(clampedValue - minValue) / CGFloat(range)
                    let y = height - (normalizedY * height)
                    
                    ZStack {
                        Circle()
                            .fill(colorForGlucose(lastPoint.value))
                            .frame(width: 12, height: 12)
                        Circle()
                            .stroke(nightMode ? Color.red : Color.white, lineWidth: 2)
                            .frame(width: 12, height: 12)
                    }
                    .position(x: x, y: y)
                }
            }
        }
        .frame(height: 180)
    }
    
    private func colorForGlucose(_ value: Int) -> Color {
        if nightMode {
            if value < lowThreshold { return .red }
            if value > highThreshold { return .red.opacity(0.8) }
            return .red.opacity(0.9)
        } else {
            if value < lowThreshold { return .red }
            if value > highThreshold { return .orange }
            return .green
        }
    }
}

// COMPONENT FOR ALARM ROW
struct AlarmRow: View {
    let icon: String
    let title: String
    let value: String
    let snooze: String
    let nightMode: Bool
    
    var body: some View {
        HStack {
            Text(icon)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(nightMode ? .red : .primary)
                Text("snooze: \(snooze)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundColor(nightMode ? Color.red.opacity(0.8) : .primary)
        }
    }
}

// COMPONENT FOR STATUS ROW
struct StatusRow: View {
    let icon: String
    let title: String
    let value: String
    let nightMode: Bool
    
    var body: some View {
        HStack {
            Text(icon)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(nightMode ? .red.opacity(0.9) : .primary)
        }
    }
}

// SETTINGS SCREEN
struct SettingsView: View {
    @StateObject private var dataManager = GlucoseDataManager.shared
    @Environment(\.dismiss) var dismiss
    let nightMode: Bool
    
    @State private var lowThreshold: Double
    @State private var highThreshold: Double
    @State private var criticalLowThreshold: Double
    @State private var criticalHighThreshold: Double
    @State private var updateInterval: Double
    @AppStorage("useMMOL", store: UserDefaults(suiteName: "group.com.devsugar.SugarWatch"))
    private var useMMOL = false
    
    init(nightMode: Bool = false) {
        self.nightMode = nightMode
        let manager = GlucoseDataManager.shared
        _lowThreshold = State(initialValue: Double(manager.lowGlucoseThreshold))
        _highThreshold = State(initialValue: Double(manager.highGlucoseThreshold))
        _criticalLowThreshold = State(initialValue: Double(manager.criticalLowThreshold))
        _criticalHighThreshold = State(initialValue: Double(manager.criticalHighThreshold))
        _updateInterval = State(initialValue: manager.updateInterval)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("📊 Units of measurement") {
                    Toggle(isOn: $useMMOL) {
                        HStack {
                            Image(systemName: "gauge.medium")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(useMMOL ? "mmol/L (mmol/L)" : "mg/dL (mg/dL)")
                                    .font(.headline)
                                Text(useMMOL ? "Millimoles per liter" : "Milligrams per deciliter")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section("⏱ Update frequency") {
                    VStack(alignment: .leading) {
                        Text("Every: \(Int(updateInterval)) seconds")
                            .font(.headline)
                        Slider(value: $updateInterval, in: 30...300, step: 30)
                    }
                }
                
                Section("🔔 Alarm thresholds") {
                    VStack(alignment: .leading) {
                        Text("🔴 Critically low: \(formatThreshold(Int(criticalLowThreshold)))")
                        Slider(value: $criticalLowThreshold, in: 40...70, step: 5)
                    }
                    VStack(alignment: .leading) {
                        Text("🟡 Low: \(formatThreshold(Int(lowThreshold)))")
                        Slider(value: $lowThreshold, in: 60...90, step: 5)
                    }
                    VStack(alignment: .leading) {
                        Text("🟠 High: \(formatThreshold(Int(highThreshold)))")
                        Slider(value: $highThreshold, in: 140...200, step: 10)
                    }
                    VStack(alignment: .leading) {
                        Text("🔴 Critically high: \(formatThreshold(Int(criticalHighThreshold)))")
                        Slider(value: $criticalHighThreshold, in: 200...300, step: 10)
                    }
                }
                
                Section {
                    Button("💾 Save") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Close") { dismiss() })
            .preferredColorScheme(nightMode ? .dark : nil)
        }
    }
    
    private func saveSettings() {
        dataManager.lowGlucoseThreshold = Int(lowThreshold)
        dataManager.highGlucoseThreshold = Int(highThreshold)
        dataManager.criticalLowThreshold = Int(criticalLowThreshold)
        dataManager.criticalHighThreshold = Int(criticalHighThreshold)
        dataManager.updateInterval = updateInterval
        dataManager.restartMonitoring()
        
        UserDefaults.standard.set(Int(lowThreshold), forKey: "lowThreshold")
        UserDefaults.standard.set(Int(highThreshold), forKey: "highThreshold")
        UserDefaults.standard.set(Int(criticalLowThreshold), forKey: "criticalLowThreshold")
        UserDefaults.standard.set(Int(criticalHighThreshold), forKey: "criticalHighThreshold")
        UserDefaults.standard.set(updateInterval, forKey: "updateInterval")
        
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private func formatThreshold(_ mgdl: Int) -> String {
        if useMMOL {
            let mmol = Double(mgdl) * 0.0555
            return String(format: "%.1f mmol/L", mmol)
        } else {
            return "\(mgdl) mg/dL"
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// SHA1 EXTENSION FOR API SECRET
// ═══════════════════════════════════════════════════════════════

extension String {
    func sha1() -> String {
        let data = Data(self.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
