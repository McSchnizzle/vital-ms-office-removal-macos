#!/bin/bash

################################################################################
# Microsoft Office Complete Cleanup Tool for macOS
################################################################################
#
# This script completely removes ALL Microsoft Office products from macOS:
# - Microsoft Office apps (Word, Excel, PowerPoint, Outlook, OneNote)
# - Microsoft Teams
# - Microsoft OneDrive
# - Microsoft AutoUpdate
# - All associated files, caches, preferences, and background services
#
# Based on:
# - Official Microsoft documentation
# - Community best practices (Paul Bowden's Office-Reset concepts)
# - Comprehensive research from multiple sources
#
# Created: December 2025
# Version: 1.0
#
# DISCLAIMER: Use at your own risk. Always backup important data first.
#
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Counters
FOUND_COUNT=0
REMOVED_COUNT=0

# Mode flag
AUDIT_ONLY=true

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}  $1${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}\n"
}

print_section() {
    echo -e "\n${CYAN}▶ $1${NC}"
    echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"
}

print_found() {
    echo -e "  ${GREEN}✓${NC} Found: $1"
    ((FOUND_COUNT++))
}

print_not_found() {
    echo -e "  ${YELLOW}○${NC} Not found: $1"
}

print_removed() {
    echo -e "  ${GREEN}✓${NC} Removed: $1"
    ((REMOVED_COUNT++))
}

print_error() {
    echo -e "  ${RED}✗${NC} Error: $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

################################################################################
# Check/Remove Functions
################################################################################

check_path() {
    local path="$1"
    local description="$2"

    if [[ -e "$path" ]]; then
        print_found "$description"
        echo -e "     ${YELLOW}→ $path${NC}"
        return 0
    else
        return 1
    fi
}

check_path_pattern() {
    local pattern="$1"
    local description="$2"
    local found=false

    # Use find for patterns
    while IFS= read -r -d '' file; do
        if [[ -n "$file" ]]; then
            if [[ "$found" == false ]]; then
                print_found "$description"
                found=true
            fi
            echo -e "     ${YELLOW}→ $file${NC}"
            ((FOUND_COUNT++))
        fi
    done < <(find "$(dirname "$pattern")" -maxdepth 1 -name "$(basename "$pattern")" -print0 2>/dev/null)

    if [[ "$found" == true ]]; then
        ((FOUND_COUNT--))  # Adjust since we increment inside loop
        return 0
    fi
    return 1
}

remove_path() {
    local path="$1"
    local description="$2"
    local use_sudo="$3"

    if [[ -e "$path" ]]; then
        if [[ "$use_sudo" == "sudo" ]]; then
            if sudo rm -rf "$path" 2>/dev/null; then
                print_removed "$description"
                return 0
            else
                print_error "Could not remove $path"
                return 1
            fi
        else
            if rm -rf "$path" 2>/dev/null; then
                print_removed "$description"
                return 0
            else
                # Try with sudo if regular removal fails
                if sudo rm -rf "$path" 2>/dev/null; then
                    print_removed "$description (required sudo)"
                    return 0
                else
                    print_error "Could not remove $path"
                    return 1
                fi
            fi
        fi
    fi
    return 1
}

remove_path_pattern() {
    local base_dir="$1"
    local pattern="$2"
    local description="$3"
    local use_sudo="$4"

    if [[ ! -d "$base_dir" ]]; then
        return 1
    fi

    local found=false
    while IFS= read -r -d '' file; do
        if [[ -n "$file" ]]; then
            found=true
            if [[ "$use_sudo" == "sudo" ]]; then
                if sudo rm -rf "$file" 2>/dev/null; then
                    print_removed "$(basename "$file")"
                else
                    print_error "Could not remove $file"
                fi
            else
                if rm -rf "$file" 2>/dev/null; then
                    print_removed "$(basename "$file")"
                else
                    if sudo rm -rf "$file" 2>/dev/null; then
                        print_removed "$(basename "$file") (required sudo)"
                    else
                        print_error "Could not remove $file"
                    fi
                fi
            fi
        fi
    done < <(find "$base_dir" -maxdepth 1 -name "$pattern" -print0 2>/dev/null)

    return 0
}

################################################################################
# Process Checking
################################################################################

check_running_processes() {
    print_section "Checking for Running Microsoft Processes"

    local processes=(
        "Microsoft Word"
        "Microsoft Excel"
        "Microsoft PowerPoint"
        "Microsoft Outlook"
        "Microsoft OneNote"
        "Microsoft Teams"
        "OneDrive"
        "Microsoft AutoUpdate"
        "Microsoft Update Assistant"
    )

    local running=false
    for proc in "${processes[@]}"; do
        if pgrep -f "$proc" > /dev/null 2>&1; then
            echo -e "  ${RED}●${NC} Running: $proc"
            running=true
        fi
    done

    if [[ "$running" == true ]]; then
        echo ""
        print_warning "Some Microsoft processes are running!"
        print_warning "Please quit all Microsoft applications before proceeding."
        echo ""

        if [[ "$AUDIT_ONLY" == false ]]; then
            read -p "Would you like to force quit all Microsoft processes? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "Force quitting Microsoft processes..."
                pkill -f "Microsoft Word" 2>/dev/null || true
                pkill -f "Microsoft Excel" 2>/dev/null || true
                pkill -f "Microsoft PowerPoint" 2>/dev/null || true
                pkill -f "Microsoft Outlook" 2>/dev/null || true
                pkill -f "Microsoft OneNote" 2>/dev/null || true
                pkill -f "Microsoft Teams" 2>/dev/null || true
                pkill -f "OneDrive" 2>/dev/null || true
                pkill -f "Microsoft AutoUpdate" 2>/dev/null || true
                pkill -f "Microsoft Update" 2>/dev/null || true
                sleep 2
                echo -e "  ${GREEN}✓${NC} Processes terminated"
            fi
        fi
    else
        echo -e "  ${GREEN}✓${NC} No Microsoft processes running"
    fi
}

################################################################################
# Application Checks
################################################################################

check_applications() {
    print_section "Applications (/Applications)"

    local apps=(
        "/Applications/Microsoft Word.app"
        "/Applications/Microsoft Excel.app"
        "/Applications/Microsoft PowerPoint.app"
        "/Applications/Microsoft Outlook.app"
        "/Applications/Microsoft OneNote.app"
        "/Applications/Microsoft Teams.app"
        "/Applications/Microsoft Teams classic.app"
        "/Applications/OneDrive.app"
        "/Applications/Microsoft AutoUpdate.app"
    )

    for app in "${apps[@]}"; do
        check_path "$app" "$(basename "$app")" || true
    done
}

remove_applications() {
    print_section "Removing Applications"

    local apps=(
        "/Applications/Microsoft Word.app"
        "/Applications/Microsoft Excel.app"
        "/Applications/Microsoft PowerPoint.app"
        "/Applications/Microsoft Outlook.app"
        "/Applications/Microsoft OneNote.app"
        "/Applications/Microsoft Teams.app"
        "/Applications/Microsoft Teams classic.app"
        "/Applications/OneDrive.app"
        "/Applications/Microsoft AutoUpdate.app"
    )

    for app in "${apps[@]}"; do
        remove_path "$app" "$(basename "$app")"
    done
}

################################################################################
# User Library Containers
################################################################################

check_user_containers() {
    print_section "User Library Containers (~/Library/Containers)"

    local containers_path="$HOME/Library/Containers"

    local containers=(
        "Microsoft Error Reporting"
        "Microsoft Excel"
        "Microsoft Outlook"
        "Microsoft PowerPoint"
        "Microsoft Word"
        "Microsoft OneNote"
        "com.microsoft.errorreporting"
        "com.microsoft.Excel"
        "com.microsoft.Outlook"
        "com.microsoft.Powerpoint"
        "com.microsoft.Word"
        "com.microsoft.onenote.mac"
        "com.microsoft.netlib.shipassertprocess"
        "com.microsoft.Office365ServiceV2"
        "com.microsoft.RMS-XPCService"
        "com.microsoft.teams"
        "com.microsoft.teams2"
        "com.microsoft.OneDrive"
        "com.microsoft.OneDrive-mac"
        "com.microsoft.OneDriveLauncher"
        "com.microsoft.OneDrive.FinderSync"
    )

    for container in "${containers[@]}"; do
        check_path "$containers_path/$container" "$container" || true
    done
}

remove_user_containers() {
    print_section "Removing User Library Containers"

    local containers_path="$HOME/Library/Containers"

    # Remove specific containers
    local containers=(
        "Microsoft Error Reporting"
        "Microsoft Excel"
        "Microsoft Outlook"
        "Microsoft PowerPoint"
        "Microsoft Word"
        "Microsoft OneNote"
        "com.microsoft.errorreporting"
        "com.microsoft.Excel"
        "com.microsoft.Outlook"
        "com.microsoft.Powerpoint"
        "com.microsoft.Word"
        "com.microsoft.onenote.mac"
        "com.microsoft.netlib.shipassertprocess"
        "com.microsoft.Office365ServiceV2"
        "com.microsoft.RMS-XPCService"
        "com.microsoft.teams"
        "com.microsoft.teams2"
        "com.microsoft.OneDrive"
        "com.microsoft.OneDrive-mac"
        "com.microsoft.OneDriveLauncher"
        "com.microsoft.OneDrive.FinderSync"
    )

    for container in "${containers[@]}"; do
        remove_path "$containers_path/$container" "$container"
    done

    # Also catch any other com.microsoft.* containers
    remove_path_pattern "$containers_path" "com.microsoft.*" "Additional Microsoft containers"
}

################################################################################
# Group Containers
################################################################################

check_group_containers() {
    print_section "User Library Group Containers (~/Library/Group Containers)"

    local group_path="$HOME/Library/Group Containers"

    local containers=(
        "UBF8T346G9.ms"
        "UBF8T346G9.Office"
        "UBF8T346G9.OfficeOsfWebHost"
        "UBF8T346G9.OneDriveStandaloneSuite"
        "UBF8T346G9.OneDriveSyncClientSuite"
    )

    for container in "${containers[@]}"; do
        check_path "$group_path/$container" "$container" || true
    done
}

remove_group_containers() {
    print_section "Removing Group Containers"

    local group_path="$HOME/Library/Group Containers"

    local containers=(
        "UBF8T346G9.ms"
        "UBF8T346G9.Office"
        "UBF8T346G9.OfficeOsfWebHost"
        "UBF8T346G9.OneDriveStandaloneSuite"
        "UBF8T346G9.OneDriveSyncClientSuite"
    )

    for container in "${containers[@]}"; do
        remove_path "$group_path/$container" "$container"
    done

    # Catch any other UBF8T346G9.* containers
    remove_path_pattern "$group_path" "UBF8T346G9.*" "Additional Office group containers"
}

################################################################################
# Application Scripts
################################################################################

check_application_scripts() {
    print_section "Application Scripts (~/Library/Application Scripts)"

    local scripts_path="$HOME/Library/Application Scripts"

    if [[ -d "$scripts_path" ]]; then
        local found=false
        while IFS= read -r -d '' dir; do
            if [[ -n "$dir" ]]; then
                print_found "$(basename "$dir")"
                echo -e "     ${YELLOW}→ $dir${NC}"
                found=true
                ((FOUND_COUNT++))
            fi
        done < <(find "$scripts_path" -maxdepth 1 -name "com.microsoft.*" -print0 2>/dev/null)

        if [[ "$found" == true ]]; then
            ((FOUND_COUNT--))  # Adjust count
        fi
    fi
}

remove_application_scripts() {
    print_section "Removing Application Scripts"

    local scripts_path="$HOME/Library/Application Scripts"
    remove_path_pattern "$scripts_path" "com.microsoft.*" "Microsoft application scripts"
}

################################################################################
# Preferences
################################################################################

check_user_preferences() {
    print_section "User Preferences (~/Library/Preferences)"

    local prefs_path="$HOME/Library/Preferences"

    if [[ -d "$prefs_path" ]]; then
        local found=false
        while IFS= read -r -d '' file; do
            if [[ -n "$file" ]]; then
                if [[ "$found" == false ]]; then
                    found=true
                fi
                echo -e "  ${GREEN}✓${NC} Found: $(basename "$file")"
                ((FOUND_COUNT++))
            fi
        done < <(find "$prefs_path" -maxdepth 1 -name "com.microsoft.*" -print0 2>/dev/null)
    fi
}

remove_user_preferences() {
    print_section "Removing User Preferences"

    local prefs_path="$HOME/Library/Preferences"
    remove_path_pattern "$prefs_path" "com.microsoft.*" "Microsoft preferences"
}

check_system_preferences() {
    print_section "System Preferences (/Library/Preferences)"

    local prefs_path="/Library/Preferences"

    if [[ -d "$prefs_path" ]]; then
        local found=false
        while IFS= read -r -d '' file; do
            if [[ -n "$file" ]]; then
                if [[ "$found" == false ]]; then
                    found=true
                fi
                echo -e "  ${GREEN}✓${NC} Found: $(basename "$file")"
                ((FOUND_COUNT++))
            fi
        done < <(find "$prefs_path" -maxdepth 1 -name "com.microsoft.*" -print0 2>/dev/null)
    fi
}

remove_system_preferences() {
    print_section "Removing System Preferences"

    local prefs_path="/Library/Preferences"
    remove_path_pattern "$prefs_path" "com.microsoft.*" "Microsoft system preferences" "sudo"
}

################################################################################
# Caches
################################################################################

check_caches() {
    print_section "User Caches (~/Library/Caches)"

    local cache_path="$HOME/Library/Caches"

    if [[ -d "$cache_path" ]]; then
        local found=false
        while IFS= read -r -d '' dir; do
            if [[ -n "$dir" ]]; then
                if [[ "$found" == false ]]; then
                    found=true
                fi
                echo -e "  ${GREEN}✓${NC} Found: $(basename "$dir")"
                ((FOUND_COUNT++))
            fi
        done < <(find "$cache_path" -maxdepth 1 \( -name "com.microsoft.*" -o -name "Microsoft*" \) -print0 2>/dev/null)
    fi
}

remove_caches() {
    print_section "Removing User Caches"

    local cache_path="$HOME/Library/Caches"
    remove_path_pattern "$cache_path" "com.microsoft.*" "Microsoft caches"
    remove_path_pattern "$cache_path" "Microsoft*" "Microsoft caches"
}

################################################################################
# Application Support
################################################################################

check_application_support() {
    print_section "User Application Support (~/Library/Application Support)"

    local support_path="$HOME/Library/Application Support"

    local dirs=(
        "Microsoft"
        "com.microsoft.teams"
        "OneDrive"
        "Microsoft Edge"
    )

    for dir in "${dirs[@]}"; do
        check_path "$support_path/$dir" "$dir" || true
    done
}

remove_application_support() {
    print_section "Removing User Application Support"

    local support_path="$HOME/Library/Application Support"

    local dirs=(
        "Microsoft"
        "com.microsoft.teams"
        "OneDrive"
    )

    for dir in "${dirs[@]}"; do
        remove_path "$support_path/$dir" "$dir"
    done
}

check_system_application_support() {
    print_section "System Application Support (/Library/Application Support)"

    local support_path="/Library/Application Support"

    check_path "$support_path/Microsoft" "Microsoft" || true
}

remove_system_application_support() {
    print_section "Removing System Application Support"

    remove_path "/Library/Application Support/Microsoft" "Microsoft" "sudo"
}

################################################################################
# LaunchAgents and LaunchDaemons
################################################################################

check_launch_agents() {
    print_section "User LaunchAgents (~/Library/LaunchAgents)"

    local agents_path="$HOME/Library/LaunchAgents"

    if [[ -d "$agents_path" ]]; then
        local found=false
        while IFS= read -r -d '' file; do
            if [[ -n "$file" ]]; then
                print_found "$(basename "$file")"
                echo -e "     ${YELLOW}→ $file${NC}"
                found=true
                ((FOUND_COUNT++))
            fi
        done < <(find "$agents_path" -maxdepth 1 -name "com.microsoft.*" -print0 2>/dev/null)

        if [[ "$found" == true ]]; then
            ((FOUND_COUNT--))
        fi
    fi
}

remove_launch_agents() {
    print_section "Removing User LaunchAgents"

    local agents_path="$HOME/Library/LaunchAgents"

    # Unload agents first
    if [[ -d "$agents_path" ]]; then
        while IFS= read -r -d '' file; do
            if [[ -n "$file" ]]; then
                launchctl unload "$file" 2>/dev/null || true
            fi
        done < <(find "$agents_path" -maxdepth 1 -name "com.microsoft.*" -print0 2>/dev/null)
    fi

    remove_path_pattern "$agents_path" "com.microsoft.*" "Microsoft launch agents"
}

check_system_launch_agents() {
    print_section "System LaunchAgents (/Library/LaunchAgents)"

    local agents_path="/Library/LaunchAgents"

    if [[ -d "$agents_path" ]]; then
        local found=false
        while IFS= read -r -d '' file; do
            if [[ -n "$file" ]]; then
                print_found "$(basename "$file")"
                echo -e "     ${YELLOW}→ $file${NC}"
                found=true
                ((FOUND_COUNT++))
            fi
        done < <(find "$agents_path" -maxdepth 1 -name "com.microsoft.*" -print0 2>/dev/null)

        if [[ "$found" == true ]]; then
            ((FOUND_COUNT--))
        fi
    fi
}

remove_system_launch_agents() {
    print_section "Removing System LaunchAgents"

    local agents_path="/Library/LaunchAgents"

    # Unload agents first
    if [[ -d "$agents_path" ]]; then
        while IFS= read -r -d '' file; do
            if [[ -n "$file" ]]; then
                sudo launchctl unload "$file" 2>/dev/null || true
            fi
        done < <(find "$agents_path" -maxdepth 1 -name "com.microsoft.*" -print0 2>/dev/null)
    fi

    remove_path_pattern "$agents_path" "com.microsoft.*" "Microsoft system launch agents" "sudo"
}

check_launch_daemons() {
    print_section "System LaunchDaemons (/Library/LaunchDaemons)"

    local daemons_path="/Library/LaunchDaemons"

    if [[ -d "$daemons_path" ]]; then
        local found=false
        while IFS= read -r -d '' file; do
            if [[ -n "$file" ]]; then
                print_found "$(basename "$file")"
                echo -e "     ${YELLOW}→ $file${NC}"
                found=true
                ((FOUND_COUNT++))
            fi
        done < <(find "$daemons_path" -maxdepth 1 -name "com.microsoft.*" -print0 2>/dev/null)

        if [[ "$found" == true ]]; then
            ((FOUND_COUNT--))
        fi
    fi
}

remove_launch_daemons() {
    print_section "Removing System LaunchDaemons"

    local daemons_path="/Library/LaunchDaemons"

    # Unload daemons first
    if [[ -d "$daemons_path" ]]; then
        while IFS= read -r -d '' file; do
            if [[ -n "$file" ]]; then
                sudo launchctl unload "$file" 2>/dev/null || true
            fi
        done < <(find "$daemons_path" -maxdepth 1 -name "com.microsoft.*" -print0 2>/dev/null)
    fi

    remove_path_pattern "$daemons_path" "com.microsoft.*" "Microsoft launch daemons" "sudo"
}

################################################################################
# Privileged Helper Tools
################################################################################

check_privileged_helpers() {
    print_section "Privileged Helper Tools (/Library/PrivilegedHelperTools)"

    local helpers_path="/Library/PrivilegedHelperTools"

    if [[ -d "$helpers_path" ]]; then
        local found=false
        while IFS= read -r -d '' file; do
            if [[ -n "$file" ]]; then
                print_found "$(basename "$file")"
                echo -e "     ${YELLOW}→ $file${NC}"
                found=true
                ((FOUND_COUNT++))
            fi
        done < <(find "$helpers_path" -maxdepth 1 -name "com.microsoft.*" -print0 2>/dev/null)

        if [[ "$found" == true ]]; then
            ((FOUND_COUNT--))
        fi
    fi
}

remove_privileged_helpers() {
    print_section "Removing Privileged Helper Tools"

    local helpers_path="/Library/PrivilegedHelperTools"
    remove_path_pattern "$helpers_path" "com.microsoft.*" "Microsoft helper tools" "sudo"
}

################################################################################
# Microsoft Fonts
################################################################################

check_fonts() {
    print_section "Microsoft Fonts (/Library/Fonts/Microsoft)"

    check_path "/Library/Fonts/Microsoft" "Microsoft Fonts folder" || true
}

remove_fonts() {
    print_section "Removing Microsoft Fonts"

    remove_path "/Library/Fonts/Microsoft" "Microsoft Fonts folder" "sudo"
}

################################################################################
# Package Receipts
################################################################################

check_receipts() {
    print_section "Package Receipts (pkgutil)"

    local packages=$(pkgutil --pkgs 2>/dev/null | grep -i "com.microsoft" || true)

    if [[ -n "$packages" ]]; then
        echo "$packages" | while read -r pkg; do
            echo -e "  ${GREEN}✓${NC} Found package: $pkg"
            ((FOUND_COUNT++))
        done
    else
        echo -e "  ${YELLOW}○${NC} No Microsoft package receipts found"
    fi
}

remove_receipts() {
    print_section "Forgetting Package Receipts"

    local packages=$(pkgutil --pkgs 2>/dev/null | grep -i "com.microsoft" || true)

    if [[ -n "$packages" ]]; then
        echo "$packages" | while read -r pkg; do
            if sudo pkgutil --forget "$pkg" 2>/dev/null; then
                print_removed "Forgot package: $pkg"
            else
                print_error "Could not forget package: $pkg"
            fi
        done
    fi
}

################################################################################
# Keychain Entries
################################################################################

check_keychain() {
    print_section "Keychain Entries"

    print_info "Keychain entries cannot be listed programmatically without user interaction."
    print_info "You may want to manually check Keychain Access for entries containing:"
    echo -e "     - Microsoft"
    echo -e "     - Office"
    echo -e "     - Teams"
    echo -e "     - OneDrive"
    echo -e "     - Outlook"
    echo ""
    print_info "To check: Open Keychain Access → Search for 'Microsoft' or 'Teams'"
}

################################################################################
# Login Items
################################################################################

check_login_items() {
    print_section "Login Items (System Settings)"

    print_info "Login Items must be checked manually in System Settings."
    print_info "Go to: System Settings → General → Login Items"
    print_info "Look for and remove:"
    echo -e "     - Microsoft AutoUpdate"
    echo -e "     - Microsoft Teams"
    echo -e "     - OneDrive"
    echo -e "     - Any other Microsoft items"
}

################################################################################
# Summary Functions
################################################################################

show_audit_summary() {
    echo ""
    print_header "AUDIT SUMMARY"

    if [[ $FOUND_COUNT -gt 0 ]]; then
        echo -e "${YELLOW}Found $FOUND_COUNT Microsoft items on this system.${NC}"
        echo ""
        print_info "To remove all items, run this script with --remove flag:"
        echo -e "     ${BOLD}./ms-office-cleanup.sh --remove${NC}"
    else
        echo -e "${GREEN}No Microsoft Office items found on this system!${NC}"
        echo -e "${GREEN}Your Mac appears to be clean of Microsoft software.${NC}"
    fi
    echo ""
}

show_removal_summary() {
    echo ""
    print_header "REMOVAL SUMMARY"

    echo -e "${GREEN}Removed $REMOVED_COUNT Microsoft items.${NC}"
    echo ""
    print_info "Recommended next steps:"
    echo "  1. Check Login Items in System Settings → General → Login Items"
    echo "  2. Check Keychain Access for any remaining Microsoft entries"
    echo "  3. Remove any Microsoft apps from your Dock"
    echo "  4. Empty your Trash"
    echo "  5. Restart your Mac"
    echo ""
}

################################################################################
# Main Functions
################################################################################

run_audit() {
    print_header "MICROSOFT OFFICE CLEANUP AUDIT"
    echo "This will scan your system for Microsoft Office components."
    echo "No files will be modified or deleted."
    echo ""

    check_running_processes
    check_applications
    check_user_containers
    check_group_containers
    check_application_scripts
    check_user_preferences
    check_system_preferences
    check_caches
    check_application_support
    check_system_application_support
    check_launch_agents
    check_system_launch_agents
    check_launch_daemons
    check_privileged_helpers
    check_fonts
    check_receipts
    check_keychain
    check_login_items

    show_audit_summary
}

run_removal() {
    print_header "MICROSOFT OFFICE COMPLETE REMOVAL"

    echo -e "${BOLD}This will permanently remove ALL Microsoft Office components including:${NC}"
    echo "  • Microsoft Office apps (Word, Excel, PowerPoint, Outlook, OneNote)"
    echo "  • Microsoft Teams"
    echo "  • Microsoft OneDrive"
    echo "  • Microsoft AutoUpdate"
    echo "  • All preferences, caches, and support files"
    echo ""

    print_warning "⚠️  IMPORTANT WARNINGS:"
    print_warning "• All Outlook data (emails, calendar) will be permanently removed"
    print_warning "• OneDrive sync data will be removed (cloud files remain on OneDrive.com)"
    print_warning "• Teams data will be removed"
    print_warning "• This action cannot be undone!"
    echo ""

    read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Removal cancelled."
        exit 0
    fi

    echo ""
    print_warning "Last chance! Press Ctrl+C within 5 seconds to cancel..."
    sleep 5
    echo ""

    check_running_processes
    remove_applications
    remove_user_containers
    remove_group_containers
    remove_application_scripts
    remove_user_preferences
    remove_system_preferences
    remove_caches
    remove_application_support
    remove_system_application_support
    remove_launch_agents
    remove_system_launch_agents
    remove_launch_daemons
    remove_privileged_helpers
    remove_fonts
    remove_receipts

    check_keychain
    check_login_items

    show_removal_summary

    read -p "Would you like to restart your Mac now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Restarting in 10 seconds... Press Ctrl+C to cancel."
        sleep 10
        sudo shutdown -r now
    else
        print_info "Please restart your Mac manually to complete the cleanup."
    fi
}

show_help() {
    echo ""
    echo -e "${BOLD}Microsoft Office Complete Cleanup Tool for macOS${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --audit    Scan and show all Microsoft items (default, no changes made)"
    echo "  --remove   Remove all Microsoft Office components"
    echo "  --help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Run audit (same as --audit)"
    echo "  $0 --audit      # Scan system for Microsoft items"
    echo "  $0 --remove     # Remove all Microsoft items"
    echo ""
    echo "It's recommended to run --audit first to see what will be removed."
    echo ""
}

################################################################################
# Entry Point
################################################################################

main() {
    # Check if running as root (we don't want that)
    if [[ $EUID -eq 0 ]]; then
        echo -e "${RED}Error: Do not run this script as root or with sudo.${NC}"
        echo "The script will request sudo access when needed."
        exit 1
    fi

    # Check if on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        echo -e "${RED}Error: This script is designed for macOS only.${NC}"
        exit 1
    fi

    # Parse arguments
    case "${1:-}" in
        --remove)
            AUDIT_ONLY=false
            run_removal
            ;;
        --audit|"")
            AUDIT_ONLY=true
            run_audit
            ;;
        --help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
