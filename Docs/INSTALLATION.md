# 📦 Installation Guide

Complete step-by-step installation guide for **SugarWatch** - Nightscout Apple Watch client for Type 1 diabetes management.

---

## 📋 Table of Contents

- [System Requirements](#system-requirements)
- [Prerequisites](#prerequisites)
- [Installation Steps](#installation-steps)
- [Xcode Setup](#xcode-setup)
- [Bundle Identifiers](#bundle-identifiers)
- [App Groups Configuration](#app-groups-configuration)
- [Signing & Certificates](#signing--certificates)
- [First Launch](#first-launch)
- [Widget Installation](#widget-installation)
- [Apple Watch Setup](#apple-watch-setup)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

---

## 💻 System Requirements

### Minimum Requirements

- **macOS:** 14.0 (Sonoma) or later
- **Xcode:** 15.0 or later
- **iOS Device:** iPhone running iOS 17.0+
- **Apple Watch:** watchOS 10.0+ (optional but recommended)
- **Internet:** Stable connection for Nightscout access

### Recommended

- **macOS:** Latest version
- **Xcode:** Latest stable release
- **iPhone:** iPhone 12 or newer
- **Apple Watch:** Series 6 or newer
- **Storage:** 500 MB free space

---

## 🎯 Prerequisites

Before installing SugarWatch, ensure you have:

### 1. Active Nightscout Server

- ✅ Self-hosted or cloud-hosted Nightscout instance
- ✅ Nightscout URL (e.g., `https://yourname.herokuapp.com`)
- ✅ API Secret (admin password)
- ✅ CGM data flowing to Nightscout

**Don't have Nightscout?** Visit [Nightscout Project](https://nightscout.github.io/) to set up.

### 2. Apple Developer Account

- ✅ **Free account:** For personal device testing
- ✅ **Paid account ($99/year):** For App Store distribution

**Sign up:** [Apple Developer Program](https://developer.apple.com/programs/)

### 3. Development Tools

- ✅ Xcode installed from Mac App Store
- ✅ Command Line Tools: `xcode-select --install`
- ✅ Git installed: `brew install git` or Xcode includes it

### 4. Device Preparation

- ✅ iPhone connected via USB or Wi-Fi
- ✅ Developer Mode enabled (iOS 16+)
- ✅ Apple Watch paired with iPhone (optional)
- ✅ Device trusted in Xcode

---

## 🚀 Installation Steps

### Step 1: Clone the Repository

Open **Terminal** and run:

```bash
# Navigate to your projects folder
cd ~/Documents

# Clone the repository
git clone https://github.com/reservebtc/nightscout-apple-watch.git

# Enter project directory
cd nightscout-apple-watch
```

**Alternative:** Download ZIP from GitHub and extract.

---

### Step 2: Create Configuration File

```bash
# Copy example config to Config.swift
cp Configuration/Config.example.swift Configuration/Config.swift
```

---

### Step 3: Configure Nightscout Connection

Open `Configuration/Config.swift` in a text editor:

```bash
# Using nano
nano Configuration/Config.swift

# Or using Xcode
open Configuration/Config.swift -a Xcode
```

Update the following values:

```swift
struct NightscoutConfig {
    // 1. Your Nightscout URL (NO trailing slash!)
    static let serverURL = "https://your-nightscout-domain.com"
    
    // 2. Your API Secret SHA1 hash
    // Generate: echo -n "your-api-secret" | shasum
    static let apiSecret = "your-sha1-hash-here"
    
    // 3. Glucose thresholds (adjust as needed)
    static let criticalLow: Int = 55
    static let low: Int = 70
    static let high: Int = 180
    static let criticalHigh: Int = 250
    
    // 4. App Group (change if you modify Bundle ID)
    static let appGroupIdentifier = "group.com.devsugar.SugarWatch"
}
```

**Generate SHA1 hash:**
```bash
echo -n "your-api-secret" | shasum
```

**Save and close** the file.

📚 **Detailed configuration:** [CONFIGURATION.md](https://github.com/reservebtc/nightscout-apple-watch/blob/main/Docs/CONFIGURATION.md)

---

### Step 4: Update Info.plist Files

Update network security settings for your Nightscout domain.

#### iOS App Info.plist

Open `SugarWatch/Info.plist` and verify it contains:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.devsugar.SugarWatch.refresh</string>
    <string>com.devsugar.SugarWatch.criticalCheck</string>
    <string>com.devsugar.SugarWatch.widgetForce</string>
</array>
<key>UIBackgroundModes</key>
<array>
    <string>processing</string>
    <string>remote-notification</string>
    <string>fetch</string>
</array>
```

#### Widget Info.plist

Open `GlucoseWidget/Info.plist` and update your domain:

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

---

## 🔧 Xcode Setup

### Step 1: Open Project in Xcode

```bash
cd ~/Documents/nightscout-apple-watch
open SugarWatch.xcodeproj
```

Wait for Xcode to index the project (may take 1-2 minutes).

---

### Step 2: Select Your Development Team

1. Click on **SugarWatch** project in Project Navigator (left sidebar)
2. Select **SugarWatch** target under TARGETS
3. Go to **Signing & Capabilities** tab
4. Under **Team**, select your Apple ID/Team

**Repeat for all three targets:**
- ✅ **SugarWatch** (iOS app)
- ✅ **SugarWatch Watch App** (watchOS app)
- ✅ **GlucoseWidget** (Widget extension)

---

## 🆔 Bundle Identifiers

### Default Bundle IDs

The project uses these Bundle Identifiers by default:

| Target | Bundle Identifier |
|--------|-------------------|
| iOS App | `com.devsugar.SugarWatch` |
| Watch App | `com.devsugar.SugarWatch.watchkitapp` |
| Widget | `com.devsugar.SugarWatch.GlucoseWidget` |

### Change Bundle IDs (Optional)

If you want to use your own Bundle IDs:

1. Select **SugarWatch** target
2. Go to **General** tab
3. Change **Bundle Identifier** to: `com.yourname.SugarWatch`
4. Repeat for **SugarWatch Watch App**: `com.yourname.SugarWatch.watchkitapp`
5. Repeat for **GlucoseWidget**: `com.yourname.SugarWatch.GlucoseWidget`

⚠️ **Important:** Keep the `.watchkitapp` and `.GlucoseWidget` suffixes!

---

## 👥 App Groups Configuration

App Groups allow data sharing between app, widget, and watch.

### Step 1: Update App Group Identifier

If you changed Bundle IDs, update App Group in `Config.swift`:

```swift
static let appGroupIdentifier = "group.com.yourname.SugarWatch"
```

### Step 2: Configure in Xcode

For **each target** (SugarWatch, Watch App, GlucoseWidget):

1. Select target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **App Groups**
5. Click **+** under App Groups
6. Enter: `group.com.yourname.SugarWatch`
7. Enable the checkbox

**All three targets MUST use the SAME App Group identifier!**

---

## 🔐 Signing & Certificates

### Automatic Signing (Recommended)

1. Select each target
2. Go to **Signing & Capabilities**
3. Check **Automatically manage signing**
4. Select your **Team**

Xcode will automatically:
- ✅ Create provisioning profiles
- ✅ Generate certificates
- ✅ Handle code signing

### Manual Signing (Advanced)

Only needed for:
- App Store distribution
- Enterprise deployment
- TestFlight

1. Uncheck **Automatically manage signing**
2. Select **Provisioning Profile** for each target
3. Ensure certificates are valid

---

## 🏗️ Build the Project

### Step 1: Select Device

In Xcode toolbar:
1. Click on device selector (next to Play button)
2. Select your **iPhone** (connected via USB or Wi-Fi)

For Apple Watch:
1. Device selector will show: **iPhone → Apple Watch**

### Step 2: Build

**Keyboard shortcut:** `⌘ + B`

Or click **Product** → **Build**

✅ **Success:** Build Succeeded
❌ **Error:** Check [Troubleshooting](#troubleshooting) section

### Step 3: Run on Device

**Keyboard shortcut:** `⌘ + R`

Or click the **Play button** (▶️)

---

## 🚦 First Launch

### On iPhone

1. App will launch on your iPhone
2. **First launch prompt:** Grant permissions
   - ✅ Allow Notifications
   - ✅ Allow Critical Alerts
   - ✅ Allow Background App Refresh

3. App will connect to Nightscout
4. Wait 5-10 seconds for first glucose reading

### Trust Developer Certificate

If you see **"Untrusted Developer"**:

1. Go to **Settings** → **General** → **VPN & Device Management**
2. Tap your **Apple ID**
3. Tap **Trust "Your Name"**
4. Confirm **Trust**

---

## 🧩 Widget Installation

### Home Screen Widgets

1. Long press on **Home Screen**
2. Tap **+** (top-left corner)
3. Search for **"SugarWatch"**
4. Choose widget size:
   - **Small:** Glucose + arrow
   - **Medium:** Glucose + 1-hour graph
   - **Large:** Glucose + graph + pump data
5. Tap **Add Widget**
6. Position on home screen

### Lock Screen Widgets (iOS 17+)

1. Long press on **Lock Screen**
2. Tap **Customize**
3. Tap widget area
4. Search for **"SugarWatch"**
5. Choose widget:
   - **Circular:** Glucose value
   - **Rectangular:** Glucose + trend
   - **Inline:** Glucose in status bar
6. Tap **Done**

### Control Center Widget

1. Open **Settings** → **Control Center**
2. Scroll to **More Controls**
3. Find **SugarWatch**
4. Tap **+** to add
5. Swipe down from top-right to access

---

## ⌚ Apple Watch Setup

### Automatic Installation

When you run the project, the Watch app installs automatically if:
- ✅ Apple Watch is paired with iPhone
- ✅ Watch is nearby and unlocked
- ✅ iPhone and Watch on same Wi-Fi

### Manual Installation

If app doesn't appear on Watch:

1. Open **Watch app** on iPhone
2. Scroll to **Available Apps**
3. Find **SugarWatch**
4. Tap **Install**

### Add Watch Complications

1. Long press on **Watch Face**
2. Tap **Edit**
3. Swipe to **Complications**
4. Tap a complication slot
5. Scroll to **SugarWatch**
6. Select complication style
7. Press **Digital Crown** to save

### Available Complications

- **Corner:** Glucose + arrow
- **Circular:** Glucose value
- **Rectangular:** Glucose + graph
- **Inline:** Text format

---

## ✅ Verification

### Test iPhone App

1. ✅ Open app - see glucose reading
2. ✅ Pull to refresh - updates data
3. ✅ View graph - shows last hour
4. ✅ Check pump data (IOB, COB, etc.)
5. ✅ Verify bolus history

### Test Widgets

1. ✅ Home screen widget updates
2. ✅ Lock screen widget shows data
3. ✅ Control Center widget works
4. ✅ Widgets update every 5 minutes

### Test Apple Watch

1. ✅ Watch app opens
2. ✅ Shows current glucose
3. ✅ Graph displays data
4. ✅ Long press refreshes
5. ✅ Complications update

### Test Notifications

1. Set glucose to critical value in Nightscout
2. Wait 2-5 minutes
3. ✅ Notification appears on iPhone
4. ✅ Watch vibrates with alert
5. ✅ Critical alert bypasses Do Not Disturb

---

## 🔄 Updates & Maintenance

### Pull Latest Changes

```bash
cd ~/Documents/nightscout-apple-watch
git pull origin main
```

### Rebuild Project

After pulling updates:
```bash
# Clean build folder
⌘ + Shift + K (in Xcode)

# Rebuild
⌘ + B
```

### Keep Nightscout Updated

- ✅ Update Nightscout server regularly
- ✅ Check API compatibility
- ✅ Backup Nightscout data

---

## 🐛 Troubleshooting

### Common Issues

#### "Command CodeSign failed"

**Solution:**
1. Go to **Signing & Capabilities**
2. Uncheck **Automatically manage signing**
3. Check it again
4. Select your Team
5. Clean build: `⌘ + Shift + K`
6. Rebuild: `⌘ + B`

#### "Could not find developer disk image"

**Solution:**
1. Update Xcode to latest version
2. Update iOS device to latest version
3. Restart Mac and device
4. Reconnect device

#### "App installation failed"

**Solution:**
1. Delete app from device
2. Go to **Settings** → **General** → **VPN & Device Management**
3. Delete all certificates for your Apple ID
4. Clean build: `⌘ + Shift + K`
5. Rebuild and run: `⌘ + R`

#### "Cannot connect to Nightscout"

**Solution:**
1. Verify Nightscout URL in `Config.swift`
2. Check API secret SHA1 hash
3. Test in browser: `https://your-domain.com/api/v1/status`
4. Check Info.plist domain settings
5. Ensure device has internet connection

#### "Widget not updating"

**Solution:**
1. Check App Group identifier matches in all targets
2. Go to **Settings** → **General** → **Background App Refresh**
3. Enable for **SugarWatch**
4. Remove and re-add widget
5. Restart device

#### "Watch app not installing"

**Solution:**
1. Unpair and re-pair Apple Watch
2. Ensure Watch is unlocked
3. Check Watch has enough storage
4. Update watchOS to latest version
5. Restart both iPhone and Watch

---

## 📚 Next Steps

After successful installation:

1. **Configure settings:** [CONFIGURATION.md](https://github.com/reservebtc/nightscout-apple-watch/blob/main/Docs/CONFIGURATION.md)
2. **Customize thresholds:** Adjust glucose alerts
3. **Test notifications:** Verify critical alerts work
4. **Add complications:** Set up Watch face
5. **Install widgets:** Add to home/lock screen

---

## 🆘 Need More Help?

- 📖 [Configuration Guide](https://github.com/reservebtc/nightscout-apple-watch/blob/main/Docs/CONFIGURATION.md)
- 🐛 [Troubleshooting Guide](https://github.com/reservebtc/nightscout-apple-watch/blob/main/Docs/TROUBLESHOOTING.md)
- 💬 [GitHub Issues](https://github.com/reservebtc/nightscout-apple-watch/issues)
- 🌐 [Nightscout Community](https://www.facebook.com/groups/cgminthecloud)
- 📝 [Open New Issue](https://github.com/reservebtc/nightscout-apple-watch/issues/new)

---

## 🎉 Success!

Congratulations! You've successfully installed **SugarWatch**. 

Your iPhone, Apple Watch, and widgets are now monitoring glucose levels 24/7.

**Remember:** Always verify readings with your actual CGM device. This app is a companion tool, not a medical device.

---

**⚠️ Medical Disclaimer:** This app is NOT a medical device. Always verify glucose readings with your actual CGM device. Never make treatment decisions based solely on this app. Consult your healthcare provider for diabetes management.

---

*Made with ❤️ for the Type 1 Diabetes community*
