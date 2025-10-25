//
//  NightscoutService.swift
//  SugarWatch
//
//  CRITICAL: Service for fetching data from Nightscout server
//  The reliability of this service is vital for the child's life!
//
//  UPDATES:
//  ✅ Added fetchGlucoseHistory(hours:) for flexibility
//  ✅ Added fetchTreatments(hours:) to load boluses for a period
//  ✅ Improved error handling and logging

import Foundation
import CryptoKit

class NightscoutService {
    static let shared = NightscoutService()
    
    // ⚠️ IMPORTANT: Configure these values in Config.swift
    // See Config.example.swift for setup instructions
    private let baseURL = NightscoutConfig.serverURL
    private let apiSecret = NightscoutConfig.apiSecret
    
    // ═══════════════════════════════════════════════════════════════
    // DATA STRUCTURES
    // ═══════════════════════════════════════════════════════════════
    
    struct GlucoseEntry: Codable {
        let sgv: Int
        let date: Double
        let direction: String
        let dateString: String?
        let delta: Double?
    }
    
    struct Treatment: Codable {
        let created_at: String
        let eventType: String?
        let insulin: Double?
        let carbs: Double?
        let rate: Double?
        let duration: Double?
        let mills: Double?
        
        // ✅ NEW: Convert created_at to Date
        var date: Date {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let date = formatter.date(from: created_at) {
                return date
            }
            
            // Fallback: try without milliseconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: created_at) {
                return date
            }
            
            // Last resort: return current date
            return Date()
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PROFILE - Therapy profile (for scheduled basal)
    // ═══════════════════════════════════════════════════════════════
    
    struct Profile: Codable {
        let defaultProfile: String?
        let store: [String: ProfileStore]
        
        struct ProfileStore: Codable {
            let dia: Double?
            let carbratio: [BasalEntry]?
            let sens: [BasalEntry]?
            let basal: [BasalEntry]?
            let target_low: [BasalEntry]?
            let target_high: [BasalEntry]?
            let timezone: String?
            let units: String?
            
            struct BasalEntry: Codable {
                let time: String  // "00:00"
                let value: Double
                let timeAsSeconds: Int?
            }
        }
    }
    
    struct PumpStatus: Codable {
        let clock: String?
        let battery: BatteryInfo?
        let reservoir: Double?
        let loop: LoopData?
        let pump: PumpInfo?  // ✅ NEW: Pump data inside "pump"
        let uploader: UploaderInfo?  // For phone battery
        
        struct BatteryInfo: Codable {
            let percent: Int?
        }
        
        // ✅ NEW: Pump structure (Insulet Dash)
        struct PumpInfo: Codable {
            let reservoir: Double?
            let battery: Int?
            let bolusing: Bool?
            let suspended: Bool?
            let pumpID: String?
            let clock: String?
            let model: String?
            let manufacturer: String?
        }
        
        // ✅ NEW: Uploader (iPhone battery)
        struct UploaderInfo: Codable {
            let battery: Int?
            let timestamp: String?
            let name: String?
        }
        
        // ✅ NEW: Loop data structure
        struct LoopData: Codable {
            let iob: IOBData?
            let cob: COBData?
            let enacted: EnactedData?
            let predicted: PredictedData?
            
            struct IOBData: Codable {
                let iob: Double?
                let basaliob: Double?
                let bolusiob: Double?
                let timestamp: String?
            }
            
            struct COBData: Codable {
                let cob: Double?
                let timestamp: String?
            }
            
            struct EnactedData: Codable {
                let rate: Double?              // ✅ Basal rate U/h
                let duration: Int?             // Duration in minutes
                let timestamp: String?
                let temp: String?              // "absolute" or "percent"
                let bg: Int?
                let tick: String?
                let eventualBG: Int?
                let insulinReq: Double?
                let reason: String?
            }
            
            struct PredictedData: Codable {
                let values: [Double]?  // ✅ FIXED: Double instead of Int
                let startDate: String?
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // AUTHENTICATION
    // ═══════════════════════════════════════════════════════════════
    
    // SHA1 hash for API Secret
    private func sha1Hash(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = Insecure.SHA1.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
    
    // Create authenticated request
    private func createAuthenticatedRequest(for urlString: String) -> URLRequest? {
        guard let url = URL(string: urlString) else {
            print("❌ [NIGHTSCOUT] Invalid URL: \(urlString)")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        // KEY: use SHA1 hash in header
        let hashedSecret = sha1Hash(apiSecret)
        request.setValue(hashedSecret, forHTTPHeaderField: "api-secret")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return request
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MAIN METHOD: FETCH CURRENT GLUCOSE
    // ═══════════════════════════════════════════════════════════════
    
    func fetchLatestGlucose(completion: @escaping (Result<GlucoseData, Error>) -> Void) {
        let urlString = "\(baseURL)/api/v1/entries.json?count=2"
        
        print("\n🚀 [NIGHTSCOUT] ════════════════════════════")
        print("🚀 [NIGHTSCOUT] Fetching current glucose")
        print("📡 URL: \(urlString)")
        
        guard let request = createAuthenticatedRequest(for: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        
        let startTime = Date()
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            let duration = Date().timeIntervalSince(startTime)
            
            if let error = error {
                print("❌ [NIGHTSCOUT] Network error: \(error.localizedDescription)")
                print("⏱️ Duration: \(String(format: "%.2f", duration))s")
                print("🚀 [NIGHTSCOUT] ════════════════════════════\n")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [NIGHTSCOUT] Invalid response")
                print("🚀 [NIGHTSCOUT] ════════════════════════════\n")
                completion(.failure(NSError(domain: "Invalid response", code: -1)))
                return
            }
            
            print("📊 HTTP Status: \(httpResponse.statusCode)")
            print("⏱️ Response time: \(String(format: "%.2f", duration))s")
            
            guard httpResponse.statusCode == 200 else {
                print("❌ [NIGHTSCOUT] Server returned error \(httpResponse.statusCode)")
                print("🚀 [NIGHTSCOUT] ════════════════════════════\n")
                completion(.failure(NSError(domain: "HTTP \(httpResponse.statusCode)", code: httpResponse.statusCode)))
                return
            }
            
            guard let data = data else {
                print("❌ [NIGHTSCOUT] No data received")
                print("🚀 [NIGHTSCOUT] ════════════════════════════\n")
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }
            
            print("📦 Data size: \(data.count) bytes")
            
            do {
                let entries = try JSONDecoder().decode([GlucoseEntry].self, from: data)
                
                guard let latest = entries.first else {
                    print("⚠️ [NIGHTSCOUT] No entries in response")
                    print("🚀 [NIGHTSCOUT] ════════════════════════════\n")
                    completion(.failure(NSError(domain: "No entries", code: -1)))
                    return
                }
                
                let glucoseData = GlucoseData(
                    value: latest.sgv,
                    direction: latest.direction,
                    delta: latest.delta,
                    timestamp: Date(timeIntervalSince1970: latest.date / 1000)
                )
                
                print("✅ [NIGHTSCOUT] Glucose: \(latest.sgv) mg/dL")
                print("   Direction: \(latest.direction)")
                if let delta = latest.delta {
                    print("   Delta: \(self.formatDelta(delta)) mg/dL")
                }
                print("   Time: \(glucoseData.timestamp)")
                print("   Entries in response: \(entries.count)")
                print("🚀 [NIGHTSCOUT] ════════════════════════════\n")
                
                completion(.success(glucoseData))
                
            } catch {
                print("❌ [NIGHTSCOUT] Decode error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Raw JSON (first 500 chars):")
                    print(String(jsonString.prefix(500)))
                }
                print("🚀 [NIGHTSCOUT] ════════════════════════════\n")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // ═══════════════════════════════════════════════════════════════
    // GLUCOSE HISTORY
    // ═══════════════════════════════════════════════════════════════
    
    func fetchGlucoseHistory(hours: Int = 3, completion: @escaping (Result<[GlucoseEntry], Error>) -> Void) {
        let count = hours * 12
        let urlString = "\(baseURL)/api/v1/entries.json?count=\(count)"
        
        print("\n📊 [HISTORY] ═════════════════════════")
        print("📊 [HISTORY] Fetching history for \(hours) hours")
        print("📡 Entries to fetch: \(count)")
        
        guard let request = createAuthenticatedRequest(for: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [HISTORY] Error: \(error.localizedDescription)")
                print("📊 [HISTORY] ═════════════════════════\n")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("❌ [HISTORY] No data")
                print("📊 [HISTORY] ═════════════════════════\n")
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }
            
            do {
                let entries = try JSONDecoder().decode([GlucoseEntry].self, from: data)
                print("✅ [HISTORY] Loaded \(entries.count) entries")
                
                if let first = entries.first, let last = entries.last {
                    let firstDate = Date(timeIntervalSince1970: first.date / 1000)
                    let lastDate = Date(timeIntervalSince1970: last.date / 1000)
                    let span = firstDate.timeIntervalSince(lastDate) / 3600
                    print("   Time span: \(String(format: "%.1f", span)) hours")
                }
                
                print("📊 [HISTORY] ═════════════════════════\n")
                completion(.success(entries))
                
            } catch {
                print("❌ [HISTORY] Decode error: \(error)")
                print("📊 [HISTORY] ═════════════════════════\n")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // ═══════════════════════════════════════════════════════════════
    // TREATMENTS (BOLUSES)
    // ═══════════════════════════════════════════════════════════════
    
    func fetchTreatments(hours: Int = 6, completion: @escaping (Result<[Treatment], Error>) -> Void) {
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -hours, to: now)!
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let startString = formatter.string(from: startDate)
        
        let urlString = "\(baseURL)/api/v1/treatments.json?find[created_at][$gte]=\(startString)"
        
        print("\n💉 [TREATMENTS] ═════════════════════════")
        print("💉 [TREATMENTS] Fetching treatments for \(hours) hours")
        print("📡 Start: \(startString)")
        
        guard let request = createAuthenticatedRequest(for: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [TREATMENTS] Error: \(error.localizedDescription)")
                print("💉 [TREATMENTS] ═════════════════════════\n")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("❌ [TREATMENTS] No data")
                print("💉 [TREATMENTS] ═════════════════════════\n")
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }
            
            do {
                let treatments = try JSONDecoder().decode([Treatment].self, from: data)
                
                let boluses = treatments.filter { $0.insulin != nil && $0.insulin! > 0 }
                print("✅ [TREATMENTS] Loaded \(treatments.count) treatments")
                print("   Boluses: \(boluses.count)")
                
                if !boluses.isEmpty {
                    let totalInsulin = boluses.compactMap { $0.insulin }.reduce(0, +)
                    print("   Total insulin: \(String(format: "%.2f", totalInsulin)) U")
                }
                
                print("💉 [TREATMENTS] ═════════════════════════\n")
                completion(.success(treatments))
                
            } catch {
                print("❌ [TREATMENTS] Decode error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Raw JSON (first 500 chars):")
                    print(String(jsonString.prefix(500)))
                }
                print("💉 [TREATMENTS] ═════════════════════════\n")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PUMP STATUS
    // ═══════════════════════════════════════════════════════════════
    
    func fetchPumpStatus(completion: @escaping (Result<PumpStatus, Error>) -> Void) {
        let urlString = "\(baseURL)/api/v1/devicestatus.json?count=1"
        
        print("\n🔋 [PUMP STATUS] ═════════════════════════")
        print("🔋 [PUMP STATUS] Fetching pump status")
        
        guard let request = createAuthenticatedRequest(for: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [PUMP STATUS] Error: \(error.localizedDescription)")
                print("🔋 [PUMP STATUS] ═════════════════════════\n")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("❌ [PUMP STATUS] No data")
                print("🔋 [PUMP STATUS] ═════════════════════════\n")
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }
            
            do {
                let statusArray = try JSONDecoder().decode([PumpStatus].self, from: data)
                
                if let status = statusArray.first {
                    print("✅ [PUMP STATUS] Status loaded")
                    
                    // Battery
                    if let battery = status.battery?.percent {
                        print("   🔋 Battery: \(battery)%")
                    } else if let pumpBattery = status.pump?.battery {
                        print("   🔋 Pump battery: \(pumpBattery)%")
                    } else {
                        print("   ⚠️ Battery: NOT FOUND")
                    }
                    
                    // Phone battery
                    if let phoneBattery = status.uploader?.battery {
                        print("   📱 Phone battery: \(phoneBattery)%")
                    }
                    
                    // Reservoir
                    if let reservoir = status.reservoir {
                        print("   💧 Reservoir: \(String(format: "%.1f", reservoir)) U")
                    } else if let pumpReservoir = status.pump?.reservoir {
                        print("   💧 Pump reservoir: \(String(format: "%.1f", pumpReservoir)) U")
                    } else {
                        print("   ⚠️ Reservoir: NOT FOUND")
                    }
                    
                    // IOB/COB
                    if let iob = status.loop?.iob?.iob {
                        print("   💉 IOB: \(String(format: "%.2f", iob)) U")
                    }
                    if let cob = status.loop?.cob?.cob {
                        print("   🍞 COB: \(String(format: "%.0f", cob)) g")
                    }
                    
                    // Basal rate
                    if let loop = status.loop {
                        print("   🔄 Loop data: available")
                        
                        if let enacted = loop.enacted, let rate = enacted.rate {
                            print("   📊 Basal rate: \(String(format: "%.2f", rate)) U/h")
                        } else {
                            print("   ⚠️ Basal: NOT FOUND in 'loop.enacted.rate'")
                        }
                    } else {
                        print("   ⚠️ Loop data: missing (normal for xDrip)")
                    }
                    
                    // Pump info
                    if let pump = status.pump {
                        if let model = pump.model {
                            print("   🏥 Pump model: \(model)")
                        }
                        if let suspended = pump.suspended {
                            print("   ⚠️ Suspended: \(suspended)")
                        }
                    }
                    
                    // ✅ CRITICAL: If reservoir or basal not found - output JSON!
                    let hasReservoir = (status.reservoir != nil || status.pump?.reservoir != nil)
                    let hasBasal = (status.loop?.enacted?.rate != nil)
                    
                    if !hasReservoir || !hasBasal {
                        print("\n🔍 [PUMP STATUS] DIAGNOSTICS: Missing data!")
                        if let jsonString = String(data: data, encoding: .utf8) {
                            print("📄 [PUMP STATUS] Full JSON for analysis:")
                            print(jsonString)
                        }
                    }
                    
                    print("🔋 [PUMP STATUS] ═════════════════════════\n")
                    completion(.success(status))
                    
                } else {
                    print("⚠️ [PUMP STATUS] No status data")
                    print("🔋 [PUMP STATUS] ═════════════════════════\n")
                    
                    // Return empty status instead of error
                    let emptyStatus = PumpStatus(clock: nil, battery: nil, reservoir: nil, loop: nil, pump: nil, uploader: nil)
                    completion(.success(emptyStatus))
                }
                
            } catch {
                print("⚠️ [PUMP STATUS] Decode error: \(error)")
                
                // ✅ NEW: Output raw JSON for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 [PUMP STATUS] Raw JSON (first 3000 chars):")
                    print(String(jsonString.prefix(3000)))
                }
                
                print("🔋 [PUMP STATUS] ═════════════════════════\n")
                
                // Return empty status instead of error
                let emptyStatus = PumpStatus(clock: nil, battery: nil, reservoir: nil, loop: nil, pump: nil, uploader: nil)
                completion(.success(emptyStatus))
            }
        }.resume()
    }
    
    // ═══════════════════════════════════════════════════════════════
    // HELPER FUNCTIONS
    // ═══════════════════════════════════════════════════════════════
    
    func directionToArrow(_ direction: String) -> String {
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
    
    func formatDelta(_ delta: Double?) -> String {
        guard let delta = delta else { return "" }
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", delta))"
    }
    
    // ✅ NEW: Server availability check
    func checkServerAvailability(completion: @escaping (Bool) -> Void) {
        let urlString = "\(baseURL)/api/v1/status.json"
        
        print("🏥 [SERVER CHECK] Checking server availability")
        
        guard let request = createAuthenticatedRequest(for: urlString) else {
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [SERVER CHECK] Server unavailable: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                let isAvailable = httpResponse.statusCode == 200
                print(isAvailable ? "✅ [SERVER CHECK] Server OK" : "❌ [SERVER CHECK] Server error \(httpResponse.statusCode)")
                completion(isAvailable)
            } else {
                completion(false)
            }
        }.resume()
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PROFILE - Load therapy profile (for scheduled basal)
    // ═══════════════════════════════════════════════════════════════
    
    func fetchProfile(completion: @escaping (Result<Profile, Error>) -> Void) {
        let urlString = "\(baseURL)/api/v1/profile.json"
        
        print("\n📊 [PROFILE] ═════════════════════════")
        print("📊 [PROFILE] Fetching therapy profile")
        print("📡 URL: \(urlString)")
        
        guard let request = createAuthenticatedRequest(for: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [PROFILE] Error: \(error.localizedDescription)")
                print("📊 [PROFILE] ═════════════════════════\n")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("❌ [PROFILE] No data")
                print("📊 [PROFILE] ═════════════════════════\n")
                completion(.failure(NSError(domain: "No data", code: -1)))
                return
            }
            
            do {
                let profileArray = try JSONDecoder().decode([Profile].self, from: data)
                
                if let profile = profileArray.first {
                    print("✅ [PROFILE] Profile loaded")
                    if let defaultName = profile.defaultProfile {
                        print("   Default profile: \(defaultName)")
                        
                        if let store = profile.store[defaultName],
                           let basalSchedule = store.basal {
                            print("   Basal entries: \(basalSchedule.count)")
                            
                            // Find current basal
                            let currentBasal = self.getCurrentScheduledBasal(from: basalSchedule)
                            print("   ✅ Scheduled basal: \(String(format: "%.2f", currentBasal)) U/h")
                        }
                    }
                    
                    print("📊 [PROFILE] ═════════════════════════\n")
                    completion(.success(profile))
                } else {
                    print("⚠️ [PROFILE] No profile data")
                    print("📊 [PROFILE] ═════════════════════════\n")
                    completion(.failure(NSError(domain: "No profile", code: -1)))
                }
                
            } catch {
                print("❌ [PROFILE] Decode error: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 [PROFILE] Raw JSON:")
                    print(String(jsonString.prefix(500)))
                }
                print("📊 [PROFILE] ═════════════════════════\n")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Get current scheduled basal for current time
    func getCurrentScheduledBasal(from schedule: [Profile.ProfileStore.BasalEntry]) -> Double {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentSeconds = hour * 3600 + minute * 60
        
        // Find appropriate basal entry
        var currentBasal = schedule.first?.value ?? 0.0
        
        for entry in schedule {
            let components = entry.time.split(separator: ":").compactMap { Int($0) }
            guard components.count == 2 else { continue }
            
            let entrySeconds = components[0] * 3600 + components[1] * 60
            
            if currentSeconds >= entrySeconds {
                currentBasal = entry.value
            } else {
                break
            }
        }
        
        return currentBasal
    }
}
