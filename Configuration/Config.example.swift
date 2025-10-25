//
//  Config.example.swift
//  SugarWatch
//
//  ⚠️ IMPORTANT: This is a template file!
//
//  SETUP INSTRUCTIONS:
//  1. Copy this file and rename it to "Config.swift"
//  2. Replace the placeholder values with your actual Nightscout server details
//  3. Never commit Config.swift to Git (it's in .gitignore for your safety)
//
//  🔒 SECURITY: Keep your API secret private!
//

import Foundation

struct NightscoutConfig {
    // ═══════════════════════════════════════════════════════════════
    // 🌐 YOUR NIGHTSCOUT SERVER CONFIGURATION
    // ═══════════════════════════════════════════════════════════════
    
    /// Your Nightscout server URL
    /// Example: "https://your-nightscout-site.herokuapp.com"
    /// ⚠️ NO trailing slash!
    static let serverURL = "https://your-nightscout-site.com"
    
    /// Your Nightscout API Secret (plain text, NOT hashed)
    /// This is the API_SECRET you set when deploying your Nightscout server
    /// Example: "your_secret_passphrase_here"
    static let apiSecret = "your_api_secret_here"
    
    // ═══════════════════════════════════════════════════════════════
    // 📝 HOW TO FIND YOUR VALUES:
    // ═══════════════════════════════════════════════════════════════
    //
    // serverURL:
    //   - This is the web address where your Nightscout is hosted
    //   - You can find it in your browser when accessing Nightscout
    //   - Make sure to use "https://" and remove any trailing "/"
    //
    // apiSecret:
    //   - This is the API_SECRET you configured on your server
    //   - Check your server deployment settings (Heroku, Railway, etc.)
    //   - If using GitHub server: check your .env or docker-compose.yml
    //   - ⚠️ Use the plain text version, NOT the SHA1 hash
    //
    // ═══════════════════════════════════════════════════════════════
    // 🔗 SETTING UP YOUR NIGHTSCOUT SERVER:
    // ═══════════════════════════════════════════════════════════════
    //
    // If you don't have a Nightscout server yet, check:
    // https://github.com/reservebtc/nightscout-professional-server
    //
    // This provides a ready-to-deploy Nightscout setup with:
    // ✅ Docker Compose configuration
    // ✅ MongoDB database
    // ✅ Automatic backups
    // ✅ SSL/HTTPS support
    // ✅ Easy deployment instructions
    //
    // ═══════════════════════════════════════════════════════════════
}
