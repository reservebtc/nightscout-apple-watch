# ⚙️ Configuration Guide

Complete configuration guide for **SugarWatch** - Nightscout Apple Watch client for Type 1 diabetes management.

---

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Nightscout Configuration](#nightscout-configuration)
- [App Configuration](#app-configuration)
- [Glucose Thresholds](#glucose-thresholds)
- [Update Intervals](#update-intervals)
- [Notifications](#notifications)
- [Widget Configuration](#widget-configuration)
- [Advanced Settings](#advanced-settings)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Prerequisites

Before configuring SugarWatch, ensure you have:

- ✅ **Active Nightscout server** (self-hosted or cloud)
- ✅ **Nightscout API Secret** (admin password)
- ✅ **Xcode 15.0+** installed
- ✅ **iOS 17.0+** device or **watchOS 10.0+** Apple Watch
- ✅ **Apple Developer account** (free or paid)

---

## 🚀 Initial Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/reservebtc/nightscout-apple-watch.git
cd nightscout-apple-watch
```

### Step 2: Create Configuration File

```bash
cp Configuration/Config.example.swift Configuration/Config.swift
```

### Step 3: Open in Xcode

```bash
open SugarWatch.xcodeproj
```

---

## 🌐 Nightscout Configuration

### 1. Get Your Nightscout URL

Your Nightscout URL format:
- **Heroku:** `https://yourname.herokuapp.com`
- **Custom domain:** `https://your-nightscout-domain.com`
- **Self-hosted:** `https://your-server.com` or `http://YOUR_IP:1337`

⚠️ **Important:** 
- Always use `https://` for secure connection
- Remove trailing slash from URL

### 2. Generate API Secret SHA1 Hash

Your Nightscout API secret must be hashed with SHA1.

**On macOS/Linux:**
```bash
echo -n "your-api-secret" | shasum
```

**Example output:**
```
a94a8fe5ccb19ba61c4c0873d391e987982fbbd3
```

Copy this hash - you'll need it in the next step!

### 3. Update Config.swift

Open `Configuration/Config.swift` and update:

```swift
struct NightscoutConfig {
    // Your Nightscout server URL
    static let serverURL = "https://your-nightscout-domain.com"
    
    // Your API Secret (SHA1 hash)
    static let apiSecret = "a94a8fe5ccb19ba61c4c0873d391e987982fbbd3"
    
    // ... rest of configuration
}
```

---

## 🍬 Glucose Thresholds

Configure glucose alert thresholds in `Config.swift`:

```swift
// Glucose thresholds (mg/dL)
static let criticalLow: Int = 55      // 🔴 Critical low alert
static let low: Int = 70              // 🟡 Low warning
static let high: Int = 180            // 🟠 High warning
static let criticalHigh: Int = 250    // 🔴 Critical high alert
```

### Recommended Values

| Level | mg/dL | mmol/L | Description |
|-------|-------|--------|-------------|
| 🔴 Critical Low | 55 | 3.1 | Immediate action required |
| 🟡 Low | 70 | 3.9 | Warning - take carbs |
| ✅ Target | 70-180 | 3.9-10.0 | Normal range |
| 🟠 High | 180 | 10.0 | Warning - check ketones |
| 🔴 Critical High | 250 | 13.9 | Immediate action required |

### Customization

Adjust values based on:
- Doctor's recommendations
- Individual diabetes management plan
- Age and lifestyle factors
- Time of day (day vs night thresholds)

---

## ⏱ Update Intervals

Configure how often the app checks for new glucose data:

```swift
// Update intervals (seconds)
static let normalUpdateInterval: TimeInterval = 300    // 5 minutes
static let criticalUpdateInterval: TimeInterval = 120  // 2 minutes
static let widgetUpdateInterval: TimeInterval = 300    // 5 minutes
```

### Interval Explanations

| Interval | Value | When Used |
|----------|-------|-----------|
| **Normal** | 300s (5 min) | Glucose in target range |
| **Critical** | 120s (2 min) | Glucose outside safe range |
| **Widget** | 300s (5 min) | Home/Lock screen updates |

⚠️ **Battery Impact:**
- Shorter intervals = more battery usage
- Recommended: Keep normal interval at 5 minutes
- Critical interval can be 2-3 minutes for safety

---

## 🔔 Notifications

### Enable Notifications

```swift
// Notification settings
static let enableNotifications: Bool = true
static let enableCriticalAlerts: Bool = true
static let notificationSound: String = "default"
```

### Notification Types

1. **Critical Glucose Alerts** (🔴)
   - Triggered when glucose < 55 or > 250 mg/dL
   - Bypasses Do Not Disturb
   - Repeating vibration on Apple Watch
   - Requires immediate attention

2. **Warning Alerts** (🟡🟠)
   - Triggered when glucose < 70 or > 180 mg/dL
   - Standard notification
   - Single vibration

3. **Data Staleness Alert**
   - No new data for 15+ minutes
   - Check CGM sensor connection

### Configure in iOS Settings

1. Open **Settings** → **Notifications** → **SugarWatch**
2. Enable **Allow Notifications**
3. Enable **Critical Alerts** (requires permission)
4. Choose alert style: **Banners** or **Alerts**
5. Enable **Sounds** and **Badges**

---

## 🧩 Widget Configuration

### Available Widgets

1. **Home Screen Widgets**
   - Small: Glucose + trend arrow
   - Medium: Glucose + 1-hour graph
   - Large: Glucose + graph + pump data

2. **Lock Screen Widgets**
   - Circular: Glucose value
   - Rectangular: Glucose + trend
   - Inline: Glucose in status bar

3. **Control Center Widget**
   - Quick glucose check
   - Tap to open app

### Update Frequency

Widgets update automatically:
- **Normal range:** Every 5 minutes
- **Critical values:** Every 2 minutes
- **Background refresh:** iOS manages optimal timing

### Add Widgets

**Home Screen:**
1. Long press on home screen
2. Tap **+** in top corner
3. Search **"SugarWatch"**
4. Choose widget size
5. Tap **Add Widget**

**Lock Screen (iOS 17+):**
1. Long press on lock screen
2. Tap **Customize**
3. Tap widget area
4. Search **"SugarWatch"**
5. Add to lock screen

---

## 🔧 Advanced Settings

### App Group Identifier

Required for sharing data between app, widget, and watch:

```swift
static let appGroupIdentifier = "group.com.devsugar.SugarWatch"
```

⚠️ **Important:** If you change Bundle Identifier, update App Group:
1. Open Xcode
2. Select target → **Signing & Capabilities**
3. Update **App Groups** for all three targets:
   - SugarWatch (iOS)
   - SugarWatch Watch App
   - GlucoseWidget

### Network Security (Info.plist)

Configure secure connections in `Info.plist` files:

**For your Nightscout domain:**
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

### Background Modes

Enabled in `SugarWatch/Info.plist`:
- ✅ **Background fetch** - Periodic data updates
- ✅ **Remote notifications** - Push notifications
- ✅ **Background processing** - Critical alerts

---

## 🔐 Security Best Practices

### 1. Never Commit Secrets

The `.gitignore` file automatically excludes:
```
Configuration/Config.swift
Config.swift
**/Config.swift
```

✅ Always use `Config.example.swift` as template
❌ Never commit your actual `Config.swift`

### 2. Use HTTPS

Always use `https://` for your Nightscout URL:
```swift
// ✅ Good
static let serverURL = "https://your-domain.com"

// ❌ Bad (insecure)
static let serverURL = "http://your-domain.com"
```

### 3. SHA1 Hash Your API Secret

Never store plain text API secret:
```swift
// ✅ Good (SHA1 hash)
static let apiSecret = "a94a8fe5ccb19ba61c4c0873d391e987982fbbd3"

// ❌ Bad (plain text)
static let apiSecret = "my-secret-password"
```

### 4. Protect Your Repository

If your repository is public:
- ✅ Use `Config.example.swift` with placeholders
- ✅ Add real credentials only locally
- ✅ Document security requirements in README

---

## 🎯 Customization Examples

### Example 1: Tighter Control (More Frequent Updates)

```swift
static let normalUpdateInterval: TimeInterval = 180    // 3 minutes
static let criticalUpdateInterval: TimeInterval = 60   // 1 minute
```

⚠️ **Higher battery usage!**

### Example 2: Conservative Thresholds

```swift
static let criticalLow: Int = 60
static let low: Int = 80
static let high: Int = 160
static let criticalHigh: Int = 240
```

### Example 3: Nighttime Settings

Create a separate config for night:
```swift
static let nightModeLow: Int = 75       // Higher threshold
static let nightModeHigh: Int = 170     // Tighter control
static let nightModeStart = 22          // 10 PM
static let nightModeEnd = 7             // 7 AM
```

---

## 🐛 Troubleshooting

### Configuration Issues

**Problem:** "Cannot connect to Nightscout server"
- ✅ Verify URL is correct (no trailing slash)
- ✅ Check API secret SHA1 hash
- ✅ Test URL in browser: `https://your-domain.com/api/v1/status`

**Problem:** "Invalid API secret"
- ✅ Regenerate SHA1 hash: `echo -n "your-secret" | shasum`
- ✅ Ensure no spaces in hash
- ✅ Check Nightscout admin password matches

**Problem:** "Widgets not updating"
- ✅ Check App Group identifier matches in all targets
- ✅ Enable Background App Refresh in iOS Settings
- ✅ Restart device

**Problem:** "Critical alerts not working"
- ✅ Enable Critical Alerts in iOS Settings
- ✅ Grant notification permissions
- ✅ Check Do Not Disturb settings

---

## 📚 Additional Resources

- [Installation Guide](https://github.com/reservebtc/nightscout-apple-watch/blob/main/Docs/INSTALLATION.md)
- [Troubleshooting Guide](https://github.com/reservebtc/nightscout-apple-watch/blob/main/Docs/TROUBLESHOOTING.md)
- [Config.example.swift](https://github.com/reservebtc/nightscout-apple-watch/blob/main/Configuration/Config.example.swift)
- [Main README](https://github.com/reservebtc/nightscout-apple-watch/blob/main/README.md)

---

## 💬 Need Help?

1. Check [Troubleshooting Guide](https://github.com/reservebtc/nightscout-apple-watch/blob/main/Docs/TROUBLESHOOTING.md)
2. Search [GitHub Issues](https://github.com/reservebtc/nightscout-apple-watch/issues)
3. Join [Nightscout Community](https://www.facebook.com/groups/cgminthecloud)
4. Open a [new issue](https://github.com/reservebtc/nightscout-apple-watch/issues/new)

---

**⚠️ Medical Disclaimer:** This app is NOT a medical device. Always verify glucose readings with your actual CGM device. Never make treatment decisions based solely on this app. Consult your healthcare provider for diabetes management.

---

*Made with ❤️ for the Type 1 Diabetes community*
