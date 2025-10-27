#!/bin/bash

# ═══════════════════════════════════════════════════════════════
# SugarWatch Setup Script
# Automated setup for Nightscout Apple Watch Client
# ═══════════════════════════════════════════════════════════════

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# ═══════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# ═══════════════════════════════════════════════════════════════
# SYSTEM CHECKS
# ═══════════════════════════════════════════════════════════════

check_system_requirements() {
    print_header "Checking System Requirements"
    
    # Check macOS version
    macos_version=$(sw_vers -productVersion)
    print_info "macOS version: $macos_version"
    
    # Check if Xcode is installed
    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode is not installed!"
        print_info "Install Xcode from Mac App Store: https://apps.apple.com/app/xcode/id497799835"
        exit 1
    fi
    
    xcode_version=$(xcodebuild -version | head -n 1)
    print_success "Xcode found: $xcode_version"
    
    # Check Xcode command line tools
    if ! xcode-select -p &> /dev/null; then
        print_warning "Xcode Command Line Tools not found"
        print_info "Installing Command Line Tools..."
        xcode-select --install
        print_info "Please complete installation and run this script again"
        exit 1
    fi
    
    print_success "Xcode Command Line Tools installed"
    
    # Check if git is available
    if command -v git &> /dev/null; then
        git_version=$(git --version)
        print_success "Git found: $git_version"
    fi
    
    print_success "All system requirements met!"
}

# ═══════════════════════════════════════════════════════════════
# CONFIGURATION SETUP
# ═══════════════════════════════════════════════════════════════

setup_configuration() {
    print_header "Configuration Setup"
    
    CONFIG_FILE="$PROJECT_ROOT/Configuration/Config.swift"
    EXAMPLE_FILE="$PROJECT_ROOT/Configuration/Config.example.swift"
    
    # Check if Config.swift already exists
    if [ -f "$CONFIG_FILE" ]; then
        print_warning "Config.swift already exists!"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Keeping existing Config.swift"
            return
        fi
    fi
    
    # Create Config.swift from example
    if [ ! -f "$EXAMPLE_FILE" ]; then
        print_error "Config.example.swift not found!"
        exit 1
    fi
    
    cp "$EXAMPLE_FILE" "$CONFIG_FILE"
    print_success "Created Config.swift from template"
    
    # Interactive configuration
    print_info "Let's configure your Nightscout connection..."
    echo ""
    
    # Get Nightscout URL
    read -p "Enter your Nightscout URL (e.g., https://yourname.herokuapp.com): " nightscout_url
    
    if [ -z "$nightscout_url" ]; then
        print_warning "No URL provided - using placeholder"
        nightscout_url="https://YOUR_NIGHTSCOUT_DOMAIN"
    else
        # Remove trailing slash
        nightscout_url=$(echo "$nightscout_url" | sed 's:/*$::')
        print_success "Nightscout URL: $nightscout_url"
    fi
    
    # Get API Secret
    echo ""
    read -p "Enter your Nightscout API Secret: " -s api_secret
    echo ""
    
    if [ -z "$api_secret" ]; then
        print_warning "No API secret provided - using placeholder"
        api_secret_hash="YOUR_API_SECRET_SHA1_HASH"
    else
        # Generate SHA1 hash
        api_secret_hash=$(echo -n "$api_secret" | shasum | awk '{print $1}')
        print_success "Generated SHA1 hash: ${api_secret_hash:0:10}..."
    fi
    
    # Update Config.swift
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|https://YOUR_NIGHTSCOUT_DOMAIN|$nightscout_url|g" "$CONFIG_FILE"
        sed -i '' "s|YOUR_API_SECRET_SHA1_HASH|$api_secret_hash|g" "$CONFIG_FILE"
    else
        # Linux
        sed -i "s|https://YOUR_NIGHTSCOUT_DOMAIN|$nightscout_url|g" "$CONFIG_FILE"
        sed -i "s|YOUR_API_SECRET_SHA1_HASH|$api_secret_hash|g" "$CONFIG_FILE"
    fi
    
    print_success "Configuration file updated!"
    
    # Glucose thresholds
    echo ""
    print_info "Default glucose thresholds:"
    echo "  Critical Low:  55 mg/dL (3.1 mmol/L)"
    echo "  Low:          70 mg/dL (3.9 mmol/L)"
    echo "  High:        180 mg/dL (10.0 mmol/L)"
    echo "  Critical High: 250 mg/dL (13.9 mmol/L)"
    echo ""
    read -p "Do you want to customize these? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "$CONFIG_FILE"
        print_info "Config.swift opened in default editor"
        print_warning "Please customize thresholds and save the file"
        read -p "Press Enter when done..."
    fi
}

# ═══════════════════════════════════════════════════════════════
# INFO.PLIST SETUP
# ═══════════════════════════════════════════════════════════════

setup_info_plist() {
    print_header "Info.plist Configuration"
    
    WIDGET_PLIST="$PROJECT_ROOT/GlucoseWidget/Info.plist"
    
    if [ ! -f "$WIDGET_PLIST" ]; then
        print_warning "Widget Info.plist not found - skipping"
        return
    fi
    
    echo ""
    read -p "Do you want to update network security settings in Info.plist? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Skipping Info.plist configuration"
        return
    fi
    
    read -p "Enter your Nightscout domain (e.g., yourname.herokuapp.com): " ns_domain
    
    if [ -z "$ns_domain" ]; then
        print_warning "No domain provided - skipping Info.plist update"
        return
    fi
    
    # Update Widget Info.plist
    if command -v plutil &> /dev/null; then
        print_info "Updating Widget Info.plist..."
        # This is a placeholder - actual plist editing is complex
        print_warning "Please manually update GlucoseWidget/Info.plist"
        print_info "Add your domain: $ns_domain to NSExceptionDomains"
    else
        print_warning "plutil not found - please manually update Info.plist files"
    fi
}

# ═══════════════════════════════════════════════════════════════
# DEPENDENCIES CHECK
# ═══════════════════════════════════════════════════════════════

check_dependencies() {
    print_header "Checking Dependencies"
    
    # Check if project file exists
    if [ ! -f "$PROJECT_ROOT/SugarWatch.xcodeproj/project.pbxproj" ]; then
        print_error "SugarWatch.xcodeproj not found!"
        print_info "Make sure you're running this script from the project directory"
        exit 1
    fi
    
    print_success "Project file found"
    
    # Check required files
    local required_files=(
        "SugarWatch/SugarWatchApp.swift"
        "SugarWatch Watch App/SugarWatch_Watch_AppApp.swift"
        "GlucoseWidget/GlucoseWidget.swift"
        "Shared/Services/NightscoutService.swift"
        "Shared/Models/GlucoseDataManager.swift"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$PROJECT_ROOT/$file" ]; then
            print_success "$file"
        else
            print_error "$file not found!"
            exit 1
        fi
    done
    
    print_success "All required files present"
}

# ═══════════════════════════════════════════════════════════════
# TEST NIGHTSCOUT CONNECTION
# ═══════════════════════════════════════════════════════════════

test_nightscout_connection() {
    print_header "Testing Nightscout Connection"
    
    # Read Config.swift
    CONFIG_FILE="$PROJECT_ROOT/Configuration/Config.swift"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        print_warning "Config.swift not found - skipping connection test"
        return
    fi
    
    # Extract serverURL from Config.swift (basic parsing)
    server_url=$(grep 'static let serverURL' "$CONFIG_FILE" | sed 's/.*"\(.*\)".*/\1/')
    
    if [[ $server_url == *"YOUR_NIGHTSCOUT_DOMAIN"* ]]; then
        print_warning "Nightscout URL not configured - skipping test"
        return
    fi
    
    print_info "Testing connection to: $server_url"
    
    # Test /api/v1/status endpoint
    if curl -s -f -m 10 "$server_url/api/v1/status" > /dev/null 2>&1; then
        print_success "Successfully connected to Nightscout!"
    else
        print_error "Could not connect to Nightscout server"
        print_info "Please verify:"
        echo "  1. URL is correct: $server_url"
        echo "  2. Server is running"
        echo "  3. You have internet connection"
    fi
}

# ═══════════════════════════════════════════════════════════════
# OPEN PROJECT
# ═══════════════════════════════════════════════════════════════

open_project() {
    print_header "Opening Project"
    
    PROJECT_FILE="$PROJECT_ROOT/SugarWatch.xcodeproj"
    
    if [ ! -d "$PROJECT_FILE" ]; then
        print_error "Project file not found!"
        exit 1
    fi
    
    read -p "Do you want to open the project in Xcode now? (Y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        open "$PROJECT_FILE"
        print_success "Project opened in Xcode!"
        
        echo ""
        print_info "Next steps in Xcode:"
        echo "  1. Select your development team"
        echo "  2. Update Bundle Identifiers (if needed)"
        echo "  3. Configure App Groups (if you changed Bundle IDs)"
        echo "  4. Select your device"
        echo "  5. Build and run! (⌘ + R)"
    else
        print_info "You can open the project later with:"
        echo "  open SugarWatch.xcodeproj"
    fi
}

# ═══════════════════════════════════════════════════════════════
# PRINT SUMMARY
# ═══════════════════════════════════════════════════════════════

print_summary() {
    print_header "Setup Complete!"
    
    print_success "Configuration file created"
    print_success "All dependencies checked"
    
    echo ""
    print_info "Documentation:"
    echo "  Installation:  docs/INSTALLATION.md"
    echo "  Configuration: docs/CONFIGURATION.md"
    echo "  Troubleshooting: docs/TROUBLESHOOTING.md"
    
    echo ""
    print_info "GitHub Repository:"
    echo "  https://github.com/reservebtc/nightscout-apple-watch"
    
    echo ""
    print_warning "IMPORTANT REMINDERS:"
    echo "  ⚠ This app is NOT a medical device"
    echo "  ⚠ Always verify readings with your actual CGM"
    echo "  ⚠ Never make treatment decisions based solely on this app"
    echo "  ⚠ Consult your healthcare provider for diabetes management"
    
    echo ""
    print_info "Need help? Open an issue:"
    echo "  https://github.com/reservebtc/nightscout-apple-watch/issues"
    
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# MAIN SCRIPT
# ═══════════════════════════════════════════════════════════════

main() {
    clear
    
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                        ║${NC}"
    echo -e "${BLUE}║         🩸 SugarWatch Setup Script 🩸                  ║${NC}"
    echo -e "${BLUE}║                                                        ║${NC}"
    echo -e "${BLUE}║     Nightscout Apple Watch Client Setup               ║${NC}"
    echo -e "${BLUE}║                                                        ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    print_warning "This is experimental software created for personal use"
    print_warning "and shared to benefit the diabetes community."
    echo ""
    read -p "Press Enter to continue..."
    
    check_system_requirements
    check_dependencies
    setup_configuration
    setup_info_plist
    test_nightscout_connection
    open_project
    print_summary
    
    echo ""
    print_success "Setup complete! 🎉"
    echo ""
}

# Run main function
main
