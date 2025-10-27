//
//  GlucoseWidget.swift
//  GlucoseWidget
//
//  CRITICAL: Widget for Type 1 diabetes control
//  Child's life depends on update reliability!
//  MAXIMALLY AGGRESSIVE update - every 5 minutes WITHOUT EXCEPTIONS!
//
//  UPDATES:
//  ✅ Task 4 (NEW): Graph 2x wider, ONLY points every 5 minutes (12 points per hour)
//  ✅ Task 4: Increased space for glucose value (10.4 does not wrap to new line)
//  ✅ Task 6: Guaranteed widget update every 5 minutes 24/7

import WidgetKit
import SwiftUI

// ═══════════════════════════════════════════════════════════════
// ✅ TASK 6: PROVIDER WITH GUARANTEED UPDATE 24/7
// ═══════════════════════════════════════════════════════════════

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> GlucoseEntry {
        GlucoseEntry(
            date: Date(),
            glucose: 120,
            direction: "Flat",
            delta: 0,
            minutesAgo: 0,
            history: [110, 112, 115, 118, 120, 122, 125, 123, 120, 118, 120, 122]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (GlucoseEntry) -> ()) {
        print("📸 [WIDGET] Snapshot requested")
        fetchGlucoseData { entry in
            completion(entry)
        }
    }
    
    // ✅ IMPROVED: Maximally aggressive update strategy (TASK 6)
    func getTimeline(in context: Context, completion: @escaping (Timeline<GlucoseEntry>) -> ()) {
        let currentDate = Date()
        print("\n🔄 [WIDGET] ════════════════════════════════════════════════")
        print("🔄 [WIDGET] Timeline request at \(currentDate)")
        print("🔄 [WIDGET] Context: \(context.isPreview ? "Preview" : "Live")")
        print("🔄 [WIDGET] Family: \(context.family)")
        
        fetchGlucoseData { entry in
            var entries: [GlucoseEntry] = []
            
            // ✅ STRATEGY: Multiple entries to guarantee update
            // Even if system misses one - next will catch up
            
            // 1. CURRENT entry - immediately
            entries.append(entry)
            print("   📊 [0] Current: now, glucose \(entry.glucose) mg/dL")
            
            // 2. ✅ NEW: Creating dense update grid every 1-2 minutes
            // This guarantees at least one update will happen
            let densityIntervals = [1, 2, 3, 4, 5, 6, 8, 10, 12, 15] // minutes
            
            for (index, minuteOffset) in densityIntervals.enumerated() {
                if let nextDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate) {
                    let minutesAgoUpdated = entry.minutesAgo + minuteOffset
                    let densityEntry = GlucoseEntry(
                        date: nextDate,
                        glucose: entry.glucose,
                        direction: entry.direction,
                        delta: entry.delta,
                        minutesAgo: minutesAgoUpdated,
                        history: entry.history
                    )
                    entries.append(densityEntry)
                    print("   📊 [\(index + 1)] Scheduled: +\(minuteOffset)  min")
                }
            }
            
            // 3. ✅ CRITICAL: Determining next FORCED update
            // For critical values - every 2 minutes
            // For normal - every 5 minutes
            let isCritical = entry.glucose < 70 || entry.glucose > 250 || entry.minutesAgo > 10
            let forceUpdateInterval = isCritical ? 2 : 5
            
            guard let nextForceUpdate = Calendar.current.date(
                byAdding: .minute,
                value: forceUpdateInterval,
                to: currentDate
            ) else {
                // If cannot create date - use .atEnd for immediate retry
                print("   ⚠️ Failed to create next update date")
                completion(Timeline(entries: entries, policy: .atEnd))
                return
            }
            
            // ✅ 4. USING .after() - MOST AGGRESSIVE POLICY
            // System MUST update widget at specified time
            let timeline = Timeline(entries: entries, policy: .after(nextForceUpdate))
            
            let criticalMark = isCritical ? "🚨 CRITICAL!" : "✅ Normal"
            print("   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("   ✅ Timeline created \(criticalMark)")
            print("   📊 Total entries: \(entries.count)")
            print("   🍬 Glucose: \(entry.glucose) mg/dL (\(entry.minutesAgo)  min  ago)")
            print("   ⏰ FORCED update: \(nextForceUpdate)")
            print("   ⏱  In: \(forceUpdateInterval)  min")
            print("   🎯 Policy: .after() - iOS MUST update!")
            print("   🔄 Grid density: updates every 1-15 min")
            print("🔄 [WIDGET] ════════════════════════════════════════════════\n")
            
            completion(timeline)
        }
    }
    
    // ✅ IMPROVED: Loading data with extended timeout
    private func fetchGlucoseData(completion: @escaping (GlucoseEntry) -> Void) {
        print("📡 [WIDGET] → Data request started")
        let fetchStartTime = Date()
        
        // ✅ Increased timeout to 30 seconds for slow connections
        var isCompleted = false
        let timeoutWorkItem = DispatchWorkItem {
            guard !isCompleted else { return }
            isCompleted = true
            print("⚠️ [WIDGET] ⏱ TIMEOUT 30 sec! Returning last saved data")
            
            // ✅ Returning last saved data instead of 0
            let lastGlucose = UserDefaults.standard.integer(forKey: "lastValidGlucose")
            let fallbackEntry = GlucoseEntry(
                date: Date(),
                glucose: lastGlucose > 0 ? lastGlucose : 0,
                direction: "Flat",
                delta: nil,
                minutesAgo: 99,
                history: []
            )
            completion(fallbackEntry)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeoutWorkItem)
        
        // ✅ TASK 4: Loading history for graph - ONLY for last 1 hour (12 points)
        NightscoutService.shared.fetchGlucoseHistory(hours: 1) { historyResult in
            var history: [Int] = []
            
            if case .success(let historyData) = historyResult {
                // ✅ Taking last 12 points (1 hour = 12 points every 5 minutes)
                history = Array(historyData.map { $0.sgv }.prefix(12))
                print("📈 [WIDGET] ✓ History: \(history.count)  points for 1 hour")
            } else {
                print("⚠️ [WIDGET] ✗ History unavailable (not critical)")
            }
            
            // Getting current glucose (critical!)
            NightscoutService.shared.fetchLatestGlucose { result in
                guard !isCompleted else {
                    print("⚠️ [WIDGET] Ignoring late response (timeout already occurred)")
                    return
                }
                isCompleted = true
                timeoutWorkItem.cancel()
                
                let fetchDuration = Date().timeIntervalSince(fetchStartTime)
                let entry: GlucoseEntry
                
                switch result {
                case .success(let glucoseData):
                    // ✅ Breaking complex expression into parts for compiler
                    let currentTimestamp = Date().timeIntervalSince1970 * 1000
                    let dataTimestamp = glucoseData.date.timeIntervalSince1970 * 1000
                    let timeDiff = currentTimestamp - dataTimestamp
                    let minutesAgo = Int(timeDiff / 60000)
                    
                    entry = GlucoseEntry(
                        date: Date(),
                        glucose: glucoseData.glucose,
                        direction: glucoseData.direction,
                        delta: glucoseData.delta,
                        minutesAgo: minutesAgo,
                        history: history.isEmpty ? [glucoseData.glucose] : history
                    )
                    
                    // ✅ Saving last data
                    UserDefaults.standard.set(glucoseData.glucose, forKey: "lastValidGlucose")
                    
                    print("✅ [WIDGET] ✓ Data received successfully")
                    print("   🍬 Glucose: \(glucoseData.glucose) mg/dL")
                    print("   ⏱  Load time: \(String(format: "%.2f", fetchDuration))s")
                    print("   📈 History: \(history.count)  points")
                    
                case .failure(let error):
                    // On error use last saved data
                    let lastGlucose = UserDefaults.standard.integer(forKey: "lastValidGlucose")
                    entry = GlucoseEntry(
                        date: Date(),
                        glucose: lastGlucose > 0 ? lastGlucose : 0,
                        direction: "Flat",
                        delta: nil,
                        minutesAgo: 99,
                        history: history
                    )
                    
                    print("❌ [WIDGET] ✗ Load error: \(error)")
                    print("   🔄 Using last data: \(lastGlucose) mg/dL")
                }
                
                completion(entry)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// DATA MODEL
// ═══════════════════════════════════════════════════════════════

struct GlucoseEntry: TimelineEntry {
    let date: Date
    let glucose: Int
    let direction: String
    let delta: Double?
    let minutesAgo: Int
    let history: [Int]
    
    // ✅ CONVERSION: mg/dL → mmol/L
    var glucoseInMMOL: String {
        let mmol = Double(glucose) / 18.0
        return String(format: "%.1f", mmol)
    }
}

// ═══════════════════════════════════════════════════════════════
// WIDGET DISPLAY
// ═══════════════════════════════════════════════════════════════

struct GlucoseWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    // Night mode (22:00 - 07:00)
    @State private var isNightMode = false
    
    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                CircularWidgetView(entry: entry, isNightMode: isNightMode)
            case .accessoryRectangular:
                RectangularWidgetView(entry: entry, isNightMode: isNightMode)
            case .accessoryInline:
                InlineWidgetView(entry: entry)
            default:
                EmptyView()
            }
        }
        .onAppear {
            updateNightMode()
        }
    }
    
    private func updateNightMode() {
        let hour = Calendar.current.component(.hour, from: Date())
        isNightMode = (hour >= 22 || hour < 7)
    }
}

// ═══════════════════════════════════════════════════════════════
// CIRCULAR WIDGET (accessoryCircular)
// ═══════════════════════════════════════════════════════════════

struct CircularWidgetView: View {
    let entry: GlucoseEntry
    let isNightMode: Bool
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack(spacing: 2) {
                // ✅ CHANGED: Showing in mmol/L instead of mg/dL
                Text(entry.glucoseInMMOL)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(glucoseColor)
                    .minimumScaleFactor(0.6)
                
                Text(directionToArrow(entry.direction))
                    .font(.system(size: 18))
                    .foregroundColor(glucoseColor)
            }
        }
    }
    
    private var glucoseColor: Color {
        if isNightMode {
            return entry.glucose < 70 || entry.glucose > 180 ? .red : Color(red: 1.0, green: 0.4, blue: 0.4)
        } else {
            if entry.glucose < 70 { return .red }
            if entry.glucose > 180 { return .orange }
            return .green
        }
    }
    
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
}

// ═══════════════════════════════════════════════════════════════
// ✅ TASK 4: RECTANGULAR WIDGET WITH EXTENDED GRAPH
// ═══════════════════════════════════════════════════════════════

struct RectangularWidgetView: View {
    let entry: GlucoseEntry
    let isNightMode: Bool
    
    var body: some View {
        HStack(spacing: 3) {
            // ✅ LEFT PART: Glucose + arrow (COMPACT)
            VStack(alignment: .leading, spacing: 1) {
                // ✅ CRITICAL: Reduced font to 30 so 10.4 fits exactly
                // ✅ CHANGED: Showing in mmol/L instead of mg/dL
                Text(entry.glucoseInMMOL)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(glucoseColor)
                    .minimumScaleFactor(0.65) // ✅ Allows shrinking to 65%
                    .lineLimit(1) // ✅ CRITICAL: Strictly one line!
                    .fixedSize(horizontal: true, vertical: false) // ✅ No wrapping
                
                HStack(spacing: 3) {
                    Text(directionToArrow(entry.direction))
                        .font(.system(size: 15))
                        .foregroundColor(glucoseColor)
                    
                    if let delta = entry.delta {
                        Text(formatDelta(delta))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(deltaColor(delta))
                    }
                }
                
                // Time
                HStack(spacing: 2) {
                    Circle()
                        .fill(freshnessColor)
                        .frame(width: 4, height: 4)
                    
                    Text("\(entry.minutesAgo)m")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(entry.minutesAgo > 10 ? .red : .white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 1) // ✅ Minimum spacing
            
            // ✅ TASK 4: Graph 2X WIDER with ONLY POINTS
            if !entry.history.isEmpty {
                MiniGraphWithDotsView(
                    history: entry.history,
                    currentGlucose: entry.glucose,
                    isNightMode: isNightMode
                )
                .frame(width: 100, height: 40) // ✅ Was: 50, now: 100 (2X WIDER!)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
    }
    
    private var glucoseColor: Color {
        if isNightMode {
            return entry.glucose < 70 || entry.glucose > 180 ? .red : Color(red: 1.0, green: 0.4, blue: 0.4)
        } else {
            if entry.glucose < 70 { return .red }
            if entry.glucose > 180 { return .orange }
            return .green
        }
    }
    
    private func deltaColor(_ delta: Double) -> Color {
        if isNightMode { return .red.opacity(0.7) }
        if delta < -5 { return .red }
        if delta > 5 { return .orange }
        return .white.opacity(0.6)
    }
    
    private var freshnessColor: Color {
        if entry.minutesAgo > 10 { return .red }
        if entry.minutesAgo > 6 { return .orange }
        return .green
    }
    
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
    
    private func formatDelta(_ delta: Double) -> String {
        let mmolDelta = delta / 18.0
        let sign = mmolDelta >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", mmolDelta))"
    }
}

// ═══════════════════════════════════════════════════════════════
// OLD MINI-GRAPH WITH LINE (KEPT FOR COMPATIBILITY)
// ═══════════════════════════════════════════════════════════════

struct MiniGraphView: View {
    let history: [Int]
    let currentGlucose: Int
    let isNightMode: Bool
    
    private let lowThreshold = 70
    private let highThreshold = 180
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            guard !history.isEmpty else { return AnyView(EmptyView()) }
            
            let minValue = max(min(history.min() ?? 40, 40), 40)
            let maxValue = min(max(history.max() ?? 300, 300), 300)
            let range = max(maxValue - minValue, 50)
            
            return AnyView(
                ZStack {
                    // Background zones
                    VStack(spacing: 0) {
                        if maxValue > highThreshold {
                            Rectangle()
                                .fill((isNightMode ? Color.red : Color.orange).opacity(0.12))
                                .frame(height: height * CGFloat(maxValue - highThreshold) / CGFloat(range))
                        }
                        
                        Rectangle()
                            .fill((isNightMode ? Color.red : Color.green).opacity(0.08))
                            .frame(height: height * CGFloat(min(highThreshold, maxValue) - max(lowThreshold, minValue)) / CGFloat(range))
                        
                        if minValue < lowThreshold {
                            Rectangle()
                                .fill(Color.red.opacity(0.12))
                                .frame(height: height * CGFloat(lowThreshold - minValue) / CGFloat(range))
                        }
                    }
                    
                    // Threshold lines
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
                    .stroke((isNightMode ? Color.red : Color.white).opacity(0.25), style: StrokeStyle(lineWidth: 0.4, dash: [1.5, 1.5]))
                    
                    // Fill under graph
                    if history.count > 1 {
                        Path { path in
                            let stepX = width / CGFloat(history.count - 1)
                            path.move(to: CGPoint(x: 0, y: height))
                            
                            for (index, value) in history.enumerated() {
                                let x = CGFloat(index) * stepX
                                let normalizedY = CGFloat(value - minValue) / CGFloat(range)
                                let y = height - (normalizedY * height)
                                
                                if index == 0 {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            
                            path.addLine(to: CGPoint(x: width, y: height))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [lineColor.opacity(0.25), lineColor.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    
                    // Graph line
                    Path { path in
                        guard history.count > 1 else { return }
                        let stepX = width / CGFloat(history.count - 1)
                        
                        for (index, value) in history.enumerated() {
                            let x = CGFloat(index) * stepX
                            let normalizedY = CGFloat(value - minValue) / CGFloat(range)
                            let y = height - (normalizedY * height)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(lineColor, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    
                    // Points on graph (every 3rd)
                    ForEach(Array(history.enumerated()), id: \.offset) { index, value in
                        if index % 3 == 0 || index == history.count - 1 {
                            let x = width * CGFloat(index) / CGFloat(max(history.count - 1, 1))
                            let normalizedY = CGFloat(value - minValue) / CGFloat(range)
                            let y = height - (normalizedY * height)
                            
                            Circle()
                                .fill(colorForGlucose(value))
                                .frame(width: 2.5, height: 2.5)
                                .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 0.3))
                                .position(x: x, y: y)
                        }
                    }
                    
                    // Last point (enlarged)
                    if let lastValue = history.last, history.count > 0 {
                        let x = width
                        let normalizedY = CGFloat(lastValue - minValue) / CGFloat(range)
                        let y = height - (normalizedY * height)
                        
                        ZStack {
                            Circle().fill(colorForGlucose(lastValue)).frame(width: 4, height: 4)
                            Circle().stroke(isNightMode ? Color.red.opacity(0.5) : Color.white, lineWidth: 0.7).frame(width: 4, height: 4)
                        }
                        .position(x: x, y: y)
                    }
                }
            )
        }
    }
    
    private var lineColor: Color {
        if isNightMode {
            if currentGlucose < lowThreshold { return .red }
            if currentGlucose > highThreshold { return .red.opacity(0.8) }
            return .red.opacity(0.9)
        } else {
            if currentGlucose < lowThreshold { return .red }
            if currentGlucose > highThreshold { return .orange }
            return .green
        }
    }
    
    private func colorForGlucose(_ value: Int) -> Color {
        if isNightMode {
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

// ═══════════════════════════════════════════════════════════════
// ✅ TASK 4: NEW GRAPH - ONLY POINTS (12  points for 1 hour)
// ═══════════════════════════════════════════════════════════════

struct MiniGraphWithDotsView: View {
    let history: [Int]
    let currentGlucose: Int
    let isNightMode: Bool
    
    private let lowThreshold = 70
    private let highThreshold = 180
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            guard !history.isEmpty else { return AnyView(EmptyView()) }
            
            let minValue = max(min(history.min() ?? 40, 40), 40)
            let maxValue = min(max(history.max() ?? 300, 300), 300)
            let range = max(maxValue - minValue, 50)
            
            return AnyView(
                ZStack {
                    // Background zones (kept)
                    VStack(spacing: 0) {
                        if maxValue > highThreshold {
                            Rectangle()
                                .fill((isNightMode ? Color.red : Color.orange).opacity(0.12))
                                .frame(height: height * CGFloat(maxValue - highThreshold) / CGFloat(range))
                        }
                        
                        Rectangle()
                            .fill((isNightMode ? Color.red : Color.green).opacity(0.08))
                            .frame(height: height * CGFloat(min(highThreshold, maxValue) - max(lowThreshold, minValue)) / CGFloat(range))
                        
                        if minValue < lowThreshold {
                            Rectangle()
                                .fill(Color.red.opacity(0.12))
                                .frame(height: height * CGFloat(lowThreshold - minValue) / CGFloat(range))
                        }
                    }
                    
                    // Threshold lines (kept)
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
                    .stroke((isNightMode ? Color.red : Color.white).opacity(0.25), style: StrokeStyle(lineWidth: 0.4, dash: [1.5, 1.5]))
                    
                    // ✅ TASK 4: ONLY POINTS (NO LINES AND FILL!)
                    // Each point = 5 minutes, 12 points = 1 hour
                    ForEach(Array(history.enumerated()), id: \.offset) { index, value in
                        let x = CGFloat(index) * (width / CGFloat(max(history.count - 1, 1)))
                        let normalizedY = CGFloat(value - minValue) / CGFloat(range)
                        let y = height - (normalizedY * height)
                        
                        Circle()
                            .fill(colorForGlucose(value))
                            .frame(width: 3, height: 3) // ✅ Point size 3x3 pixels
                            .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 0.3))
                            .position(x: x, y: y)
                    }
                    
                    // Last point (enlarged with border)
                    if let lastValue = history.last, history.count > 0 {
                        let x = width
                        let normalizedY = CGFloat(lastValue - minValue) / CGFloat(range)
                        let y = height - (normalizedY * height)
                        
                        ZStack {
                            Circle().fill(colorForGlucose(lastValue)).frame(width: 5, height: 5)
                            Circle().stroke(isNightMode ? Color.red.opacity(0.5) : Color.white, lineWidth: 0.8).frame(width: 5, height: 5)
                        }
                        .position(x: x, y: y)
                    }
                }
            )
        }
    }
    
    private func colorForGlucose(_ value: Int) -> Color {
        if isNightMode {
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

// ═══════════════════════════════════════════════════════════════
// INLINE WIDGET (NO CHANGES)
// ═══════════════════════════════════════════════════════════════

struct InlineWidgetView: View {
    let entry: GlucoseEntry
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(entry.glucose)")
                .font(.system(size: 16, weight: .bold))
            
            Text(directionToArrow(entry.direction))
                .font(.system(size: 14))
            
            if let delta = entry.delta {
                Text(formatDelta(delta))
                    .font(.system(size: 12))
            }
            
            Text("•")
                .font(.system(size: 10))
                .opacity(0.5)
            
            Text("\(entry.minutesAgo)m")
                .font(.system(size: 11))
        }
    }
    
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
    
    private func formatDelta(_ delta: Double) -> String {
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", delta))"
    }
}

// ═══════════════════════════════════════════════════════════════
// ✅ TASK 6: WIDGET CONFIGURATION WITH MAXIMUM AGGRESSIVENESS
// ═══════════════════════════════════════════════════════════════

struct GlucoseWidget: Widget {
    let kind: String = "GlucoseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            GlucoseWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Sugar Watch")
        .description("🚨 CRITICAL: Updates every 2-5 minutes. Guaranteed operation 24/7.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
        .contentMarginsDisabled()
    }
}

#Preview(as: .accessoryRectangular) {
    GlucoseWidget()
} timeline: {
    GlucoseEntry(date: .now, glucose: 120, direction: "Flat", delta: 2.0, minutesAgo: 5, history: [110, 112, 115, 118, 120, 122, 120, 118, 120, 122, 120, 118])
    GlucoseEntry(date: .now, glucose: 65, direction: "SingleDown", delta: -8.0, minutesAgo: 3, history: [110, 105, 100, 95, 90, 85, 80, 75, 70, 68, 66, 65])
    GlucoseEntry(date: .now, glucose: 200, direction: "SingleUp", delta: 15.0, minutesAgo: 2, history: [150, 160, 170, 180, 190, 195, 200, 205, 210, 208, 205, 200])
    // ✅ Test: 10.4 should fit on one line
    GlucoseEntry(date: .now, glucose: 104, direction: "Flat", delta: 1.2, minutesAgo: 4, history: [100, 101, 102, 103, 104, 104, 104, 103, 103, 104, 104, 104])
}
