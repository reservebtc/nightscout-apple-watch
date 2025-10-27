# 🩸 SugarWatch - Nightscout Apple Watch Client

<div align="center">

[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20watchOS-blue)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/swift-5.9-orange)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green)](https://github.com/reservebtc/nightscout-apple-watch/blob/main/LICENSE)
[![iOS](https://img.shields.io/badge/iOS-17.0+-blue)](https://www.apple.com/ios/)
[![watchOS](https://img.shields.io/badge/watchOS-10.0+-blue)](https://www.apple.com/watchos/)
[![GitHub Issues](https://img.shields.io/github/issues/reservebtc/nightscout-apple-watch)](https://github.com/reservebtc/nightscout-apple-watch/issues)
[![GitHub Stars](https://img.shields.io/github/stars/reservebtc/nightscout-apple-watch?style=social)](https://github.com/reservebtc/nightscout-apple-watch/stargazers)

**A life-saving glucose monitoring companion for Type 1 diabetes management**

[Features](#-features) • [Installation](#-installation) • [Documentation](#-documentation) • [Contributing](#-contributing) • [Support](#-support)

</div>

---

## ⚠️ DISCLAIMER

**This is experimental software created for personal use and shared to benefit the diabetes community.**

- ❗ **NOT A MEDICAL DEVICE** - This app is not approved by any medical authority
- ❗ **EXPERIMENTAL** - Use at your own risk
- ❗ **NO WARRANTY** - No guarantees of accuracy or reliability
- ❗ **VERIFY READINGS** - Always confirm glucose values with your actual CGM device
- ❗ **MEDICAL DECISIONS** - Never make treatment decisions based solely on this app
- ❗ **CONSULT DOCTOR** - Always work with your healthcare provider

**Your safety is paramount. This app is a companion tool, not a replacement for medical devices.**

> **Note:** This software was developed for personal needs and is shared in hopes it may help others in the Type 1 diabetes community. Use with caution and understanding of the risks involved.

---

## 📖 About

**SugarWatch** is an open-source iOS and watchOS application that connects to your [Nightscout](https://nightscout.github.io/) server to provide real-time glucose monitoring on your iPhone, Apple Watch, and iOS widgets.

### Why SugarWatch?

- 🚨 **Critical Alerts** - Immediate notifications for dangerous glucose levels
- ⌚ **Apple Watch Native** - Full-featured Watch app with complications
- 🔋 **Battery Efficient** - Optimized for all-day monitoring
- 🧩 **iOS Widgets** - Home Screen, Lock Screen, and Control Center
- 📊 **Rich Data** - Glucose trends, graphs, pump data (IOB, COB, etc.)
- 🔒 **Privacy First** - Your data stays between your device and Nightscout
- 🆓 **Free & Open Source** - No subscriptions, no tracking, no ads

---

## ✨ Features

### 📱 iOS App

<details>
<summary><b>Click to expand iOS features</b></summary>

- ✅ **Real-time glucose monitoring** from Nightscout
- ✅ **Glucose graph** with 1-hour history (12 data points)
- ✅ **Trend arrows** (↑ ↗ → ↘ ↓) showing glucose direction
- ✅ **Critical glucose alerts** for low/high values
- ✅ **Automatic background updates** every 5 minutes
- ✅ **Bolus history** showing last 3 hours of insulin doses
- ✅ **Pump data display:**
  - IOB (Insulin On Board)
  - COB (Carbs On Board)
  - Basal rate
  - Pump battery
  - Reservoir level
- ✅ **Pull-to-refresh** for manual updates
- ✅ **mmol/L and mg/dL** support
- ✅ **Dark mode** fully supported

</details>

### ⌚ Apple Watch App

<details>
<summary><b>Click to expand Apple Watch features</b></summary>

- ✅ **Standalone Watch app** - works independently from iPhone
- ✅ **Watch complications** for all watch faces:
  - Corner complications
  - Circular complications
  - Rectangular complications
  - Inline complications
- ✅ **Glucose graph** with data points (1-hour view)
- ✅ **Long press gesture** for manual refresh
- ✅ **Critical notifications** with repeating vibration
- ✅ **Auto-update** every 5 minutes (2 minutes for critical values)
- ✅ **Large, readable text** optimized for quick glances
- ✅ **Battery optimized** for all-day wear

</details>

### 🧩 iOS Widgets

<details>
<summary><b>Click to expand Widget features</b></summary>

**Home Screen Widgets:**
- **Small:** Glucose value + trend arrow + time
- **Medium:** Glucose + 1-hour graph
- **Large:** Glucose + graph + pump data

**Lock Screen Widgets (iOS 17+):**
- **Circular:** Glucose value in circle
- **Rectangular:** Glucose + trend arrow
- **Inline:** Glucose in status bar

**Control Center Widget:**
- Quick glucose check without opening app
- Tap to open full app

**Widget Features:**
- ✅ **Guaranteed updates** every 2-5 minutes
- ✅ **Aggressive refresh policy** using `.after()` timeline
- ✅ **Dense update grid** (updates every 1-15 minutes)
- ✅ **Color-coded** based on glucose range
- ✅ **Works offline** with cached data

</details>

### 🔔 Notifications

- 🔴 **Critical Low** (< 55 mg/dL / 3.1 mmol/L) - Bypasses Do Not Disturb
- 🟡 **Low Warning** (< 70 mg/dL / 3.9 mmol/L)
- 🟠 **High Warning** (> 180 mg/dL / 10.0 mmol/L)
- 🔴 **Critical High** (> 250 mg/dL / 13.9 mmol/L) - Bypasses Do Not Disturb
- ⚠️ **Data Staleness** - Alert when no new data for 15+ minutes
- 📳 **Repeating vibration** on Apple Watch for critical alerts

---

## 🚀 Quick Start

### Prerequisites

- **macOS** 14.0+ with **Xcode** 15.0+
- **iPhone** running **iOS 17.0+**
- **Apple Watch** running **watchOS 10.0+** (optional)
- **Active Nightscout server** with API access
- **Apple Developer account** (free or paid)

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/reservebtc/nightscout-apple-watch.git
cd nightscout-apple-watch

# 2. Create configuration file
cp Configuration/Config.example.swift Configuration/Config.swift

# 3. Edit Config.swift with your Nightscout settings
nano Configuration/Config.swift
# or
open Configuration/Config.swift -a Xcode

# 4. Open in Xcode
open SugarWatch.xcodeproj

# 5. Select your device and run (⌘ + R)
```

### Configuration

Edit `Configuration/Config.swift`:

```swift
struct NightscoutConfig {
    // Your Nightscout URL (without trailing slash)
    static let serverURL = "https://your-nightscout-domain.com"
    
    // Your API Secret (SHA1 hash)
    // Generate: echo -n "your-api-secret" | shasum
    static let apiSecret = "your-sha1-hash-here"
    
    // Glucose thresholds (mg/dL)
    static let criticalLow: Int = 55
    static let low: Int = 70
    static let high: Int = 180
    static let criticalHigh: Int = 250
    
    // App Group (change if you modify Bundle ID)
    static let appGroupIdentifier = "group.com.devsugar.SugarWatch"
}
```

**Generate SHA1 hash:**
```bash
echo -n "your-api-secret" | shasum
```

📚 **Detailed setup:** [Installation Guide](https://github.com/reservebtc/nightscout-apple-watch/blob/main/Docs/INSTALLATION.md)

---

## 📚 Documentation

### Core Documentation

- 📦 **[Installation Guide](https://github.com/reservebtc/nightscout-apple-watch/blob/main/Docs/INSTALLATION.md)** - Step-by-step setup instructions
- ⚙️ **[Configuration Guide](https://github.com/reservebtc/nightscout-apple-watch/blob/main/Docs/CONFIGURATION.md)** - Detailed configuration options
- 🐛 **[Troubleshooting Guide](https://github.com/reservebtc/nightscout-apple-watch/blob/main/Docs/TROUBLESHOOTING.md)** - Common issues and solutions

### Code Documentation

- 📱 **[iOS App](https://github.com/reservebtc/nightscout-apple-watch/tree/main/SugarWatch)** - iPhone application source
- ⌚ **[Watch App](https://github.com/reservebtc/nightscout-apple-watch/tree/main/SugarWatch%20Watch%20App)** - Apple Watch application source
- 🧩 **[Widget Extension](https://github.com/reservebtc/nightscout-apple-watch/tree/main/GlucoseWidget)** - iOS widgets source
- 🔧 **[Shared Components](https://github.com/reservebtc/nightscout-apple-watch/tree/main/Shared)** - Common services and managers

---

## 🏗️ Project Structure

```
nightscout-apple-watch/
├── 📱 SugarWatch/                     # iOS App
│   ├── SugarWatchApp.swift           # App entry point
│   ├── ContentView.swift             # Main UI
│   └── Info.plist                    # App configuration
│
├── ⌚ SugarWatch Watch App/           # watchOS App
│   ├── SugarWatch_Watch_AppApp.swift # Watch app entry
│   ├── ContentView.swift             # Watch UI
│   ├── NotificationController.swift  # Critical alerts handler
│   └── Info.plist                    # Watch configuration
│
├── 🧩 GlucoseWidget/                 # Widget Extension
│   ├── GlucoseWidget.swift           # Widget provider
│   ├── GlucoseWidgetBundle.swift     # Widget bundle
│   ├── GlucoseWidgetControl.swift    # Control Center widget
│   ├── AppIntent.swift               # Widget actions
│   └── Info.plist                    # Widget configuration
│
├── 📦 Shared/                        # Shared code
│   ├── Models/
│   │   └── GlucoseDataManager.swift  # Data model & cache
│   ├── Services/
│   │   └── NightscoutService.swift   # Nightscout API client
│   └── Managers/
│       └── BackgroundRefreshManager.swift  # Background updates
│
├── ⚙️ Configuration/
│   └── Config.example.swift          # Configuration template
│
├── 📖 Docs/
│   ├── INSTALLATION.md               # Setup guide
│   ├── CONFIGURATION.md              # Config guide
│   └── TROUBLESHOOTING.md            # Problem solutions
│
├── .gitignore                        # Git ignore rules
├── LICENSE                           # MIT License
└── README.md                         # This file
```

---

## 🔧 Technical Details

### Architecture

- **SwiftUI** - Modern declarative UI framework
- **Combine** - Reactive data flow
- **WidgetKit** - Native iOS widget support
- **WatchKit** - Apple Watch integration
- **ClockKit** - Watch complications
- **BackgroundTasks** - Reliable background updates
- **UserNotifications** - Critical alerts system

### API Integration

- **Nightscout REST API** - Real-time glucose data
- **SHA1 Authentication** - Secure API access
- **Auto-retry logic** - Network resilience
- **Offline caching** - Works without connection
- **30-second timeout** - Fast failure detection

### Update Strategy

**Normal Range (70-180 mg/dL):**
- App: Every 5 minutes
- Widget: Every 5 minutes
- Watch: Every 5 minutes
- Complications: iOS-managed (50/day budget)

**Critical Range (<55 or >250 mg/dL):**
- App: Every 2 minutes
- Widget: Every 2 minutes
- Watch: Every 2 minutes
- Immediate notifications

### Battery Optimization

- **Smart refresh intervals** - More frequent only when needed
- **Efficient networking** - Minimal data transfer
- **Background task scheduling** - iOS-optimized timing
- **Watch independence** - Reduces iPhone wake-ups
- **Widget timeline management** - Dense grid with .after() policy

---

## 🛡️ Security & Privacy

### Data Security

- ✅ **Local processing** - No data sent to third parties
- ✅ **SHA1 API authentication** - Secure Nightscout access
- ✅ **HTTPS only** - Encrypted communication
- ✅ **No tracking** - Zero analytics or telemetry
- ✅ **No ads** - Completely ad-free
- ✅ **Open source** - Transparent and auditable

### Privacy Protection

- 🔒 **Config.swift excluded** - Never commit secrets
- 🔒 **API secrets hashed** - SHA1, not plain text
- 🔒 **Local data only** - Stored in App Group sandbox
- 🔒 **No cloud sync** - Data never leaves your devices
- 🔒 **Template configs** - Safe public repository

### Best Practices

```bash
# ✅ Always use Config.example.swift for public sharing
cp Config.swift Config.example.swift
# Edit Config.example.swift to remove real credentials

# ✅ Verify .gitignore excludes secrets
cat .gitignore | grep Config.swift

# ✅ Never commit real API secrets
git status  # Config.swift should not appear
```

---

## 🤝 Contributing

Contributions are welcome! This project was created to help the diabetes community, and your improvements can help others.

### How to Contribute

1. **Fork the repository**
2. **Create a feature branch:** `git checkout -b feature/amazing-feature`
3. **Commit your changes:** `git commit -m 'Add amazing feature'`
4. **Push to branch:** `git push origin feature/amazing-feature`
5. **Open a Pull Request**

### Contribution Guidelines

- ✅ Follow Swift style guidelines
- ✅ Add comments for complex logic
- ✅ Test on real devices (iPhone + Apple Watch)
- ✅ Update documentation if needed
- ✅ Keep commits focused and descriptive
- ✅ Ensure no secrets in code

### Areas for Contribution

- 🐛 Bug fixes
- ✨ New features
- 📖 Documentation improvements
- 🌍 Translations
- 🎨 UI/UX enhancements
- ⚡ Performance optimizations
- 🧪 Test coverage

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](https://github.com/reservebtc/nightscout-apple-watch/blob/main/LICENSE) file for details.

### What This Means

- ✅ **Free to use** - Personal and commercial
- ✅ **Free to modify** - Adapt to your needs
- ✅ **Free to distribute** - Share with others
- ⚠️ **No warranty** - Use at your own risk
- ⚠️ **No liability** - Author not responsible for any issues

---

## 🙏 Acknowledgments

### Built With

- [Nightscout](https://nightscout.github.io/) - Open source CGM in the cloud
- [Apple Developer](https://developer.apple.com) - Development tools and frameworks
- Swift programming language
- SwiftUI framework
- WidgetKit & WatchKit

### Inspiration

- The **Type 1 Diabetes community** for their resilience and innovation
- **#WeAreNotWaiting** movement for DIY diabetes solutions
- All open source contributors to diabetes technology

### Special Thanks

- Nightscout community for the amazing platform
- Early testers who provided valuable feedback
- Everyone who contributes to open source diabetes tools

---

## 💬 Support & Community

### Get Help

- 📖 **Documentation:** Start with [Installation Guide](https://github.com/reservebtc/nightscout-apple-watch/blob/main/Docs/INSTALLATION.md)
- 🐛 **Issues:** Search [existing issues](https://github.com/reservebtc/nightscout-apple-watch/issues) or [create new one](https://github.com/reservebtc/nightscout-apple-watch/issues/new)
- 💬 **Discussions:** [GitHub Discussions](https://github.com/reservebtc/nightscout-apple-watch/discussions)
- 🌐 **Nightscout Community:** [Facebook Group](https://www.facebook.com/groups/cgminthecloud)

### Stay Updated

- ⭐ **Star this repository** to follow updates
- 👀 **Watch releases** for new versions
- 🔔 **Enable notifications** for important updates

---

## 🔮 Roadmap

### Planned Features

- [ ] **Siri Shortcuts** integration
- [ ] **Live Activities** for Dynamic Island (iOS 16.4+)
- [ ] **Customizable alerts** per time of day
- [ ] **Multiple Nightscout accounts** support
- [ ] **Export glucose data** to Health app
- [ ] **Watch app improvements** - More complications
- [ ] **iPad app** - Larger screens support
- [ ] **Enhanced graphs** - Multiple time ranges
- [ ] **Predictive alerts** - Machine learning trends
- [ ] **Family sharing** - Monitor multiple accounts

### Future Considerations

- Standalone Watch app (no iPhone required)
- macOS app for desktop monitoring
- Integration with other diabetes platforms
- Advanced analytics and reports

**Have ideas?** [Open a feature request](https://github.com/reservebtc/nightscout-apple-watch/issues/new?labels=enhancement)!

---

## ⚠️ Important Reminders

### Medical Disclaimer

**READ THIS CAREFULLY:**

- ❗ This app is **NOT** a medical device
- ❗ This app is **NOT** FDA approved
- ❗ This app is **NOT** CE marked
- ❗ This app is **NOT** clinically validated
- ❗ **DO NOT** use for diagnosis or treatment
- ❗ **DO NOT** make insulin decisions based solely on this app
- ❗ **ALWAYS** verify readings with your actual CGM device
- ❗ **ALWAYS** consult your healthcare provider

### Emergency Situations

If you experience:
- Severe hypoglycemia symptoms
- Confusion or loss of consciousness
- Severe hyperglycemia with ketones
- Any medical emergency

**DO NOT rely on this app. Call emergency services immediately (911 in USA).**

### Responsibility

- You are responsible for your diabetes management
- This is a **companion tool**, not a replacement for medical care
- The developer assumes **NO liability** for any health outcomes
- Use this software at your own risk

---

## 📊 Statistics

<div align="center">

**Used by the Type 1 Diabetes Community Worldwide**

*This is experimental software created for personal use and shared to benefit others. Your feedback helps improve safety and reliability.*

</div>

---

## 🌟 Star History

If this project helps you or someone you love manage diabetes better, please consider:

- ⭐ **Starring the repository**
- 🐛 **Reporting bugs** you find
- 💡 **Suggesting improvements**
- 🤝 **Contributing code**
- 📢 **Sharing with others** who might benefit

**Every contribution helps the diabetes community!**

---

## 📞 Contact

- **GitHub Issues:** [Report bugs or request features](https://github.com/reservebtc/nightscout-apple-watch/issues)
- **GitHub Discussions:** [Ask questions or share ideas](https://github.com/reservebtc/nightscout-apple-watch/discussions)
- **Project Link:** [https://github.com/reservebtc/nightscout-apple-watch](https://github.com/reservebtc/nightscout-apple-watch)

---

<div align="center">

## ❤️ Made with Love for the T1D Community

**This project is dedicated to everyone living with Type 1 Diabetes**

*Your strength inspires us. Your feedback improves this app. Together, we are not waiting.*

---

**⚠️ FINAL REMINDER:** This is experimental software. Always verify glucose readings with your actual CGM device. Never make treatment decisions based solely on this app. Consult your healthcare provider for diabetes management.

---

**[⬆ Back to Top](#-sugarwatch---nightscout-apple-watch-client)**

</div>

---

*Last updated: December 2024*
