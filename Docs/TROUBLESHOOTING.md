# 🐛 Troubleshooting Guide

Comprehensive troubleshooting guide for **SugarWatch** - solutions to common issues with the Nightscout Apple Watch client.

---

## 📋 Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [Connection Issues](#connection-issues)
- [Data Not Updating](#data-not-updating)
- [Widget Problems](#widget-problems)
- [Apple Watch Issues](#apple-watch-issues)
- [Notification Problems](#notification-problems)
- [Build & Compilation Errors](#build--compilation-errors)
- [Performance Issues](#performance-issues)
- [Data Accuracy](#data-accuracy)
- [Advanced Diagnostics](#advanced-diagnostics)
- [Getting Help](#getting-help)

---

## 🚀 Quick Diagnostics

### First Steps (Try These First!)

Before diving into specific issues, try these quick fixes:

#### 1. Force Refresh
```
• iPhone App: Pull down to refresh
• Apple Watch: Long press on screen
• Widget: Wait 5 minutes for auto-update
```

#### 2. Restart Everything
```
1. Force quit SugarWatch app
2. Restart iPhone
3. Restart Apple Watch (if applicable)
4. Reopen app
```

#### 3. Check Internet Connection
```
• Open Safari on iPhone
• Visit your Nightscout URL
• Verify you can see glucose data
```

#### 4. Verify Nightscout Server
```
• Test API: https://your-domain.com/api/v1/status
• Should return JSON with status: "ok"
```

---

## 🌐 Connection Issues

### Problem: "Cannot Connect to Server"

**Symptoms:**
- App shows "No data" or "---"
- Error message about connection
- Glucose value stuck at 0

**Solutions:**

#### Solution 1: Verify Nightscout URL

Check `Configuration/Config.swift`:

```swift
// ✅ Correct formats:
static let serverURL = "https://yourname.herokuapp.com"
static let serverURL = "https://your-domain.com"

// ❌ Wrong formats:
static let serverURL = "https://yourname.herokuapp.com/"  // No trailing slash!
static let serverURL = "http://yourname.herokuapp.com"    // Use HTTPS!
static let serverURL = "yourname.herokuapp.com"           // Missing https://
```

#### Solution 2: Verify API Secret

Generate correct SHA1 hash:

```bash
# On Mac/Linux
echo -n "your-api-secret" | shasum

# Copy the ENTIRE hash (40 characters)
# Example: a94a8fe5ccb19ba61c4c0873d391e987982fbbd3
```

Update in `Config.swift`:
```swift
static let apiSecret = "your-sha1-hash-here"
```

⚠️ **Common mistakes:**
- Using plain text password instead of SHA1
- Extra spaces in hash
- Wrong API secret

#### Solution 3: Update Info.plist

Add your domain to network exceptions:

**File:** `GlucoseWidget/Info.plist`

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>your-nightscout-domain.com</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
        </dict>
    </dict>
</dict>
```

**Repeat for:** `SugarWatch/Info.plist`

#### Solution 4: Test API Endpoint

```bash
# Test in Terminal
curl "https://your-domain.com/api/v1/entries.json?count=1"

# Should return glucose data
# If you get 401: Wrong API secret
# If you get 404: Wrong URL
# If you get timeout: Server down
```

---

### Problem: "SSL/TLS Certificate Error"

**Symptoms:**
- "The certificate for this server is invalid"
- Connection works in browser but not in app

**Solutions:**

#### Solution 1: Use HTTPS

Always use `https://` (not `http://`):

```swift
// ✅ Correct
static let serverURL = "https://your-domain.com"

// ❌ Wrong
static let serverURL = "http://your-domain.com"
```

#### Solution 2: Check Certificate Validity

```bash
# Test certificate
openssl s_client -connect your-domain.com:443 -servername your-domain.com

# Look for: "Verify return code: 0 (ok)"
```

If certificate expired:
- Renew SSL certificate on server
- Use Let's Encrypt for free certificates

---

### Problem: "Timeout - Request Taking Too Long"

**Symptoms:**
- App hangs while loading
- "Request timeout" message
- Data appears after 30+ seconds

**Solutions:**

#### Solution 1: Check Server Response Time

```bash
# Test server speed
time curl "https://your-domain.com/api/v1/entries.json?count=1"

# Should complete in < 5 seconds
```

#### Solution 2: Increase Timeout (if needed)

Edit `Shared/Services/NightscoutService.swift`:

```swift
// Find timeout setting
request.timeoutInterval = 30  // Increase to 45 if needed
```

#### Solution 3: Optimize Nightscout

- Reduce database size
- Use CDN for faster access
- Upgrade hosting plan
- Clear old data

---

## 📊 Data Not Updating

### Problem: "Glucose Data Stuck / Not Refreshing"

**Symptoms:**
- Same glucose value for 10+ minutes
- "X minutes ago" keeps increasing
- Data doesn't auto-update

**Solutions:**

#### Solution 1: Check CGM Connection

**Most common cause!**

1. Open Nightscout website
2. Check if data is updating there
3. If Nightscout has no new data:
   - Check CGM transmitter battery
   - Verify uploader app is running
   - Check uploader phone has internet

#### Solution 2: Enable Background Refresh

**iPhone Settings:**
1. Go to **Settings** → **General**
2. Tap **Background App Refresh**
3. Enable **Background App Refresh** (top toggle)
4. Scroll to **SugarWatch**
5. Enable it

#### Solution 3: Check App Group

All three targets must use the same App Group:

**In Xcode:**
1. Select **SugarWatch** target → **Signing & Capabilities**
2. Verify App Group: `group.com.devsugar.SugarWatch`
3. Repeat for **SugarWatch Watch App**
4. Repeat for **GlucoseWidget**

**In Config.swift:**
```swift
static let appGroupIdentifier = "group.com.devsugar.SugarWatch"
```

All must match exactly!

#### Solution 4: Force Background Task

```bash
# In Xcode Console while running
# Type this when app is in background:
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.devsugar.SugarWatch.refresh"]
```

---

### Problem: "Data Shows But Never Updates Automatically"

**Symptoms:**
- Pull to refresh works
- Auto-update doesn't work
- Need to open app manually

**Solutions:**

#### Solution 1: Check Background Modes

**File:** `SugarWatch/Info.plist`

Must contain:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>processing</string>
    <string>remote-notification</string>
    <string>fetch</string>
</array>
```

#### Solution 2: Register Background Tasks

**File:** `SugarWatch/SugarWatchApp.swift`

Verify it contains:
```swift
BackgroundRefreshManager.shared.registerBackgroundTasks()
```

#### Solution 3: Check iOS Restrictions

**Settings to verify:**
1. **Low Power Mode:** Turn OFF (prevents background updates)
2. **Focus/Do Not Disturb:** Allow notifications
3. **Screen Time limits:** Exclude SugarWatch
4. **Data Mode:** Use "Standard" not "Low Data Mode"

---

## 🧩 Widget Problems

### Problem: "Widget Not Showing / Blank Widget"

**Symptoms:**
- Widget appears as empty box
- "SugarWatch" not in widget list
- Widget shows placeholder data

**Solutions:**

#### Solution 1: Rebuild Widget Extension

1. In Xcode, select **GlucoseWidget** scheme
2. Clean: `⌘ + Shift + K`
3. Build: `⌘ + B`
4. Run on device: `⌘ + R`

#### Solution 2: Check Widget Bundle

**File:** `GlucoseWidget/GlucoseWidgetBundle.swift`

Must contain:
```swift
@main
struct GlucoseWidgetBundle: WidgetBundle {
    var body: some Widget {
        GlucoseWidget()
        GlucoseWidgetControl()
    }
}
```

#### Solution 3: Reinstall Widget

1. Long press on widget
2. Tap **Remove Widget**
3. Wait 10 seconds
4. Add widget again
5. Choose **SugarWatch**

---

### Problem: "Widget Shows Old Data"

**Symptoms:**
- Widget glucose is 15+ minutes old
- Widget timestamp doesn't update
- App has new data but widget doesn't

**Solutions:**

#### Solution 1: Check Timeline Policy

**File:** `GlucoseWidget/GlucoseWidget.swift`

Should use `.after()` policy:
```swift
let timeline = Timeline(
    entries: entries,
    policy: .after(nextForceUpdate)  // ✅ Most aggressive
)
```

#### Solution 2: Force Widget Refresh

```swift
// In app code after data update
WidgetCenter.shared.reloadAllTimelines()
```

#### Solution 3: Check Widget Update Interval

**File:** `Configuration/Config.swift`

```swift
static let widgetUpdateInterval: TimeInterval = 300  // 5 minutes
```

For faster updates (uses more battery):
```swift
static let widgetUpdateInterval: TimeInterval = 180  // 3 minutes
```

---

### Problem: "Widget Shows Error / Cannot Load"

**Symptoms:**
- Widget displays "Error loading data"
- Widget shows "Unable to load"
- Widget placeholder never loads

**Solutions:**

#### Solution 1: Check App Group Access

Widget needs permission to read shared data:

```swift
// In GlucoseWidget.swift
let sharedDefaults = UserDefaults(
    suiteName: NightscoutConfig.appGroupIdentifier
)
```

#### Solution 2: Test Widget in Simulator

1. Run widget scheme in Xcode
2. Check Console for errors
3. Look for:
   - "App Group not found"
   - "Permission denied"
   - Network errors

#### Solution 3: Reset Widget Cache

```bash
# Delete widget cache
rm -rf ~/Library/Developer/Xcode/DerivedData/SugarWatch-*/

# Rebuild
⌘ + Shift + K  # Clean
⌘ + B          # Build
```

---

## ⌚ Apple Watch Issues

### Problem: "Watch App Not Installing"

**Symptoms:**
- Watch app doesn't appear
- Installation stuck at "Installing..."
- App icon shows on Watch but won't open

**Solutions:**

#### Solution 1: Check Requirements

- ✅ Watch is paired with iPhone
- ✅ Watch is unlocked
- ✅ Watch is on same Wi-Fi as iPhone
- ✅ Watch has enough storage (500 MB free)
- ✅ watchOS 10.0 or later

#### Solution 2: Manual Installation

1. Open **Watch** app on iPhone
2. Scroll to **Available Apps**
3. Find **SugarWatch**
4. Tap **Install**
5. Wait 2-5 minutes

#### Solution 3: Unpair & Re-pair Watch

**⚠️ Last resort - backs up Watch first!**

1. **iPhone:** Settings → Bluetooth
2. Tap **(i)** next to Apple Watch
3. Tap **Forget This Device**
4. Re-pair using Watch app
5. Restore from backup
6. Reinstall SugarWatch

---

### Problem: "Watch App Shows No Data"

**Symptoms:**
- Watch shows "---" or "0 mg/dL"
- iPhone app works fine
- Watch complications blank

**Solutions:**

#### Solution 1: Check Watch Connectivity

```swift
// Must have WatchConnectivity enabled
import WatchConnectivity

WCSession.default.isReachable  // Should be true
```

#### Solution 2: Force Data Sync

On iPhone app:
1. Open SugarWatch
2. Pull to refresh
3. Wait 10 seconds
4. Check Watch

On Watch:
1. Open SugarWatch
2. Long press screen
3. Release to refresh

#### Solution 3: Check App Group (Again!)

Watch app must access same App Group:

**Xcode → SugarWatch Watch App → Signing & Capabilities**

Verify: `group.com.devsugar.SugarWatch`

---

### Problem: "Watch Complications Not Updating"

**Symptoms:**
- Complication shows old data
- Complication never refreshes
- Complication stuck at "--"

**Solutions:**

#### Solution 1: Reload Complications

```swift
// In Watch app code
CLKComplicationServer.sharedInstance().reloadTimeline(
    for: complication
)
```

#### Solution 2: Check Complication Budget

Apple limits complication updates:
- ~50 updates per day
- Budget refreshes at midnight

**Check budget in Xcode:**
```swift
// While debugging Watch app
CLKComplicationServer.sharedInstance().getPrivacyBehavior { behavior in
    print("Budget remaining: \(behavior)")
}
```

#### Solution 3: Use Most Efficient Timeline

**File:** `SugarWatch Watch App/SugarWatch_Watch_AppApp.swift`

```swift
// Update complications efficiently
func scheduleComplicationUpdate() {
    let server = CLKComplicationServer.sharedInstance()
    server.activeComplications?.forEach { complication in
        server.reloadTimeline(for: complication)
    }
}
```

---

## 🔔 Notification Problems

### Problem: "No Notifications Received"

**Symptoms:**
- Critical glucose but no alert
- No vibration on Watch
- No banner on iPhone

**Solutions:**

#### Solution 1: Check Notification Permissions

**iPhone Settings:**
1. Go to **Settings** → **Notifications** → **SugarWatch**
2. Enable **Allow Notifications**
3. Choose **Immediate Delivery**
4. Enable **Banners**
5. Enable **Sounds**
6. Enable **Badges**

#### Solution 2: Enable Critical Alerts

**Critical alerts bypass Do Not Disturb!**

**iPhone Settings:**
1. Go to **Settings** → **Notifications** → **SugarWatch**
2. Enable **Critical Alerts**
3. Grant permission when prompted

**In app:**
```swift
// Request critical alert permission
UNUserNotificationCenter.current().requestAuthorization(
    options: [.alert, .sound, .badge, .criticalAlert]
)
```

#### Solution 3: Check Notification Code

**File:** `Shared/Managers/BackgroundRefreshManager.swift`

Verify notifications are triggered:
```swift
func sendGlucoseAlert(glucose: Int, isCritical: Bool) {
    let content = UNMutableNotificationContent()
    content.title = "Glucose Alert"
    content.body = "Glucose: \(glucose) mg/dL"
    content.sound = .default
    
    if isCritical {
        content.interruptionLevel = .critical
        content.sound = .defaultCritical
    }
    
    // Send notification
    UNUserNotificationCenter.current().add(request)
}
```

---

### Problem: "Watch Doesn't Vibrate on Critical Alert"

**Symptoms:**
- iPhone gets notification
- Watch shows notification
- No vibration on Watch

**Solutions:**

#### Solution 1: Check Watch Notification Settings

**Watch App on iPhone:**
1. Go to **Notifications** in Watch app
2. Scroll to **SugarWatch**
3. Ensure **Mirror iPhone** is enabled
4. Check **Haptic Alerts** is ON

**On Apple Watch:**
1. Open **Settings**
2. Go to **Sounds & Haptics**
3. Check **Haptic Strength** is not Off
4. Enable **Prominent Haptic**

#### Solution 2: Verify Repeating Vibration

**File:** `SugarWatch Watch App/NotificationController.swift`

Must contain:
```swift
private func startRepeatingVibration() {
    WKInterfaceDevice.current().play(.notification)
    
    vibrationTimer = Timer.scheduledTimer(
        withTimeInterval: 2.0,
        repeats: true
    ) { _ in
        WKInterfaceDevice.current().play(.notification)
    }
}
```

#### Solution 3: Test Haptic Directly

```swift
// In Watch app
WKInterfaceDevice.current().play(.notification)  // Standard
WKInterfaceDevice.current().play(.directionUp)   // Strong
WKInterfaceDevice.current().play(.failure)       // Intense
```

---

## 🔨 Build & Compilation Errors

### Problem: "Command CodeSign Failed"

**Error message:**
```
Command CodeSign failed with a nonzero exit code
```

**Solutions:**

#### Solution 1: Reset Signing

1. Select target in Xcode
2. Go to **Signing & Capabilities**
3. **Uncheck** "Automatically manage signing"
4. **Check** it again
5. Select your Team
6. Clean: `⌘ + Shift + K`
7. Build: `⌘ + B`

#### Solution 2: Delete Derived Data

```bash
# Close Xcode first!
rm -rf ~/Library/Developer/Xcode/DerivedData/

# Reopen Xcode
open SugarWatch.xcodeproj

# Clean and build
⌘ + Shift + K
⌘ + B
```

#### Solution 3: Revoke & Regenerate Certificates

1. Go to [developer.apple.com](https://developer.apple.com)
2. Account → Certificates
3. Revoke old certificates
4. In Xcode: Preferences → Accounts
5. Click **Download Manual Profiles**
6. Try building again

---

### Problem: "Module Not Found" / "No Such Module"

**Error message:**
```
No such module 'WidgetKit'
No such module 'WatchConnectivity'
```

**Solutions:**

#### Solution 1: Check Deployment Target

**All targets must have correct deployment targets:**
- iOS App: iOS 17.0
- Watch App: watchOS 10.0
- Widget: iOS 17.0

**In Xcode:**
1. Select target
2. Go to **General**
3. Check **Minimum Deployments**

#### Solution 2: Clean Build Folder

```
⌘ + Shift + K  # Clean
⌘ + Option + Shift + K  # Deep clean
⌘ + B  # Rebuild
```

#### Solution 3: Check Framework Imports

**File headers should be:**

```swift
// iOS App
import SwiftUI
import UserNotifications
import BackgroundTasks

// Watch App
import SwiftUI
import WatchKit
import ClockKit

// Widget
import WidgetKit
import SwiftUI
```

---

### Problem: "Build Succeeded but App Crashes on Launch"

**Symptoms:**
- Build completes successfully
- App launches and immediately crashes
- Xcode shows crash log

**Solutions:**

#### Solution 1: Check Console Output

In Xcode Console, look for:
```
Fatal error: ...
Assertion failed: ...
EXC_BAD_ACCESS
```

#### Solution 2: Common Crash Causes

**Config.swift missing:**
```bash
# Create it from template
cp Configuration/Config.example.swift Configuration/Config.swift
```

**Invalid API Secret:**
```swift
// Check it's a valid SHA1 (40 characters)
static let apiSecret = "a94a8fe5ccb19ba61c4c0873d391e987982fbbd3"
```

**Wrong App Group:**
```swift
// Must exist in all three targets
static let appGroupIdentifier = "group.com.devsugar.SugarWatch"
```

#### Solution 3: Enable Exception Breakpoint

**In Xcode:**
1. Go to **Breakpoint Navigator** (⌘ + 8)
2. Click **+** at bottom
3. Select **Exception Breakpoint**
4. Run app again
5. Xcode will stop at crash location

---

## ⚡ Performance Issues

### Problem: "App Uses Too Much Battery"

**Symptoms:**
- Battery drains quickly
- iPhone gets warm
- Battery usage shows SugarWatch at top

**Solutions:**

#### Solution 1: Increase Update Interval

**File:** `Configuration/Config.swift`

```swift
// From 3 minutes to 5 minutes
static let normalUpdateInterval: TimeInterval = 300  // 5 min

// Keep critical short for safety
static let criticalUpdateInterval: TimeInterval = 120  // 2 min
```

#### Solution 2: Optimize Network Requests

**File:** `Shared/Services/NightscoutService.swift`

```swift
// Reduce data fetched
func fetchGlucoseHistory(hours: Int = 1)  // Was 3, now 1

// Use caching
private var cachedData: GlucoseData?
private var cacheTime: Date?
```

#### Solution 3: Disable Unused Features

```swift
// In Config.swift
static let enableContinuousMonitoring: Bool = false
static let enableAdvancedLogging: Bool = false
```

---

### Problem: "App Slow to Launch / Laggy UI"

**Symptoms:**
- App takes 5+ seconds to open
- UI stutters when scrolling
- Graph lags when updating

**Solutions:**

#### Solution 1: Reduce Graph Data Points

**File:** `GlucoseWidget/GlucoseWidget.swift`

```swift
// Use fewer points in graph
let maxPoints = 12  // Was 24, now 12 (1 hour)
```

#### Solution 2: Optimize SwiftUI Views

```swift
// Use LazyVStack instead of VStack
LazyVStack {
    ForEach(data) { item in
        GlucoseRow(item)
    }
}
```

#### Solution 3: Profile Performance

**In Xcode:**
1. Product → Profile (⌘ + I)
2. Choose **Time Profiler**
3. Run app
4. Find slow functions
5. Optimize bottlenecks

---

## 📏 Data Accuracy

### Problem: "Glucose Values Don't Match CGM"

**Symptoms:**
- App shows different value than CGM
- 5-10 mg/dL difference
- Trend doesn't match

**Solutions:**

#### Solution 1: Check Data Source

**Verify data flow:**
```
CGM → Uploader → Nightscout → SugarWatch
```

Each step can introduce delay:
- CGM: 5 min intervals
- Uploader: 1-2 min delay
- Nightscout: Near real-time
- SugarWatch: 5 min refresh

**Total possible delay: 10-15 minutes**

#### Solution 2: Compare with Nightscout Website

1. Open Nightscout in browser
2. Check glucose value and time
3. Compare with SugarWatch app
4. If they match → CGM delay, not app issue
5. If different → Check API connection

#### Solution 3: Verify Unit Conversion

App shows mmol/L but you expect mg/dL?

**File:** `Shared/Models/GlucoseDataManager.swift`

```swift
// mg/dL to mmol/L conversion
var mmol: Double {
    return Double(glucose) / 18.0
}
```

To show mg/dL instead:
```swift
Text("\(glucose) mg/dL")  // Not glucose.mmol
```

---

## 🔬 Advanced Diagnostics

### Enable Debug Logging

**File:** `Shared/Services/NightscoutService.swift`

Uncomment debug prints:
```swift
print("🌐 [API] Request: \(url)")
print("📊 [API] Response: \(data)")
print("⚠️ [API] Error: \(error)")
```

**View logs:**
1. Run app in Xcode
2. Open Console (⌘ + Shift + C)
3. Filter by "API" or "WIDGET"

### Test API Manually

```bash
# Get latest entry
curl -H "API-SECRET: your-sha1-hash" \
  "https://your-domain.com/api/v1/entries.json?count=1"

# Get status
curl "https://your-domain.com/api/v1/status"

# Get device status (pump data)
curl "https://your-domain.com/api/v1/devicestatus.json?count=1"
```

### Check Network Traffic

**Using Charles Proxy or Proxyman:**

1. Install proxy app
2. Configure iPhone to use proxy
3. Trust SSL certificate
4. Watch SugarWatch network requests
5. Verify API calls are correct

---

## 🆘 Getting Help

### Before Asking for Help

Gather this information:

**Device Info:**
- iOS version: Settings → General → About → Software Version
- watchOS version: Watch app → General → About
- Device model: iPhone 12 Pro, Apple Watch Series 7, etc.

**App Info:**
- SugarWatch version/commit hash
- Xcode version used to build
- Installation method: Xcode / TestFlight / App Store

**Error Info:**
- Exact error message
- When it occurs (launch, background, etc.)
- Steps to reproduce
- Console logs if available

### Where to Get Help

1. **Check Documentation:**
   - [Installation Guide](https://github.com/reservebtc/nightscout-apple-watch/blob/main/Docs/INSTALLATION.md)
   - [Configuration Guide](https://github.com/reservebtc/nightscout-apple-watch/blob/main/Docs/CONFIGURATION.md)
   - [Main README](https://github.com/reservebtc/nightscout-apple-watch/blob/main/README.md)

2. **Search Existing Issues:**
   - [GitHub Issues](https://github.com/reservebtc/nightscout-apple-watch/issues)
   - Someone may have solved your problem!

3. **Open New Issue:**
   - [Create Issue](https://github.com/reservebtc/nightscout-apple-watch/issues/new)
   - Include all info from "Before Asking for Help"
   - Be specific and detailed

4. **Community Support:**
   - [Nightscout Facebook Group](https://www.facebook.com/groups/cgminthecloud)
   - [Nightscout Discord](https://discord.gg/zg7CvCQ)

---

## 📚 Additional Resources

- **Source Code:** [GitHub Repository](https://github.com/reservebtc/nightscout-apple-watch)
- **Nightscout Docs:** [nightscout.github.io](https://nightscout.github.io/)
- **Apple Developer:** [developer.apple.com](https://developer.apple.com)
- **WidgetKit:** [Apple Documentation](https://developer.apple.com/documentation/widgetkit)
- **WatchKit:** [Apple Documentation](https://developer.apple.com/documentation/watchkit)

---

## ✅ Issue Resolved?

If you solved your issue:
- ✅ Consider contributing the solution back!
- ✅ Update documentation if needed
- ✅ Help others with similar issues

**This is an open source project - your contributions help everyone!**

---

**⚠️ Medical Disclaimer:** This app is NOT a medical device. Always verify glucose readings with your actual CGM device. Never make treatment decisions based solely on this app. Consult your healthcare provider for diabetes management.

---

*Made with ❤️ for the Type 1 Diabetes community*
