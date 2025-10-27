// NotificationController.swift for Watch App
// Put this file in: SugarWatch Watch App Watch App/NotificationController.swift
// CRITICAL: Handles notifications and vibration on watch!
// Child's life depends on reliability!

import WatchKit
import UserNotifications
import SwiftUI

// ════════════════════════════════════════════════════════════════
// NOTIFICATION CONTROLLER FOR WATCH
// CRITICAL: Handles notifications and VIBRATION on watch!
// ════════════════════════════════════════════════════════════════

class NotificationController: WKUserNotificationHostingController<NotificationView> {
    
    // Timer for repeated vibration
    private var vibrationTimer: Timer?
    
    override var body: NotificationView {
        return NotificationView()
    }
    
    // ════════════════════════════════════════════════════════════
    // CRITICAL: This method is called WHEN NOTIFICATION ARRIVES
    // ════════════════════════════════════════════════════════════
    
    override func didReceive(_ notification: UNNotification) {
        print("\n🚨 [WATCH NOTIFICATION] ═══════════════════════")
        print("🚨 Notification received on WATCH!")
        print("   Title: \(notification.request.content.title)")
        print("   Body: \(notification.request.content.body)")
        print("   Category: \(notification.request.content.categoryIdentifier)")
        
        // ✅ CRITICAL: START VIBRATION!
        startRepeatingVibration()
        
        print("🚨 [WATCH NOTIFICATION] ═══════════════════════\n")
    }
    
    // Stop vibration when controller disappears
    override func didDeactivate() {
        super.didDeactivate()
        stopVibration()
    }
    
    // ════════════════════════════════════════════════════════════
    // VIBRATION ON WATCH - REPEATS UNTIL SNOOZED
    // ════════════════════════════════════════════════════════════
    
    private func startRepeatingVibration() {
        print("📳 [WATCH VIBRATION] Starting repeated vibration...")
        
        // Stop old timer if exists
        stopVibration()
        
        // FIRST vibration immediately
        WKInterfaceDevice.current().play(.notification)
        
        // ✅ REPEAT VIBRATION every 2 seconds
        vibrationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            print("📳 [WATCH VIBRATION] Repeated vibration...")
            WKInterfaceDevice.current().play(.notification)
        }
        
        // Add to RunLoop for reliability
        if let timer = vibrationTimer {
            RunLoop.main.add(timer, forMode: .common)
            print("✅ [WATCH VIBRATION] Vibration timer started")
        }
    }
    
    private func stopVibration() {
        vibrationTimer?.invalidate()
        vibrationTimer = nil
        print("⏹ [WATCH VIBRATION] Vibration stopped")
    }
}

// ════════════════════════════════════════════════════════════════
// VIEW FOR NOTIFICATION
// ════════════════════════════════════════════════════════════════

struct NotificationView: View {
    var body: some View {
        VStack(spacing: 10) {
            // Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            // Text
            Text("Check glucose!")
                .font(.headline)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
            
            Text("Open app")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
    }
}

// ════════════════════════════════════════════════════════════════
// PREVIEW
// ════════════════════════════════════════════════════════════════

#Preview {
    NotificationView()
}

//
//  NotificationController.swift
//  SugarWatch
//
//  Created  24/10/25.
