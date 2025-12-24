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
# Version: 1.4
#
# DISCLAIMER: Use at your own risk. Always backup important data first.
#
################################################################################

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
PROTECTED_COUNT=0

# Mode flags
AUDIT_ONLY=true
FORCE_MODE=false
SKIP_RESTART=false

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
    ((FOUND_COUNT++)) || true
}

print_not_found() {
    echo -e "  ${YELLOW}○${NC} Not found: $1"
}

print_removed() {
    echo -e "  ${GREEN}✓${NC} Removed: $1"
    ((REMOVED_COUNT++)) || true
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
# Full Disk Access Check
################################################################################

check_full_disk_access() {
    # Try to read a TCC-protected database as a test
    # If we can read from ~/Library/Containers, we likely have FDA or can remove user containers
    # The real test is whether we can modify .com.apple.containermanagerd.metadata.plist

    local test_container=""
    local containers_path="$HOME/Library/Containers"

    # Find a Microsoft container to test
    if [[ -d "$containers_path" ]]; then
        test_container=$(find "$containers_path" -maxdepth 1 -name "com.microsoft.*" -print -quit 2>/dev/null)
    fi

    if [[ -n "$test_container" ]]; then
        local metadata_file="$test_container/.com.apple.containermanagerd.metadata.plist"
        if [[ -f "$metadata_file" ]]; then
            # Try to remove it - if it fails, we don't have FDA
            if ! rm -f "$metadata_file" 2>/dev/null; then
                return 1  # No FDA
            fi
        fi
    fi

    return 0  # Either has FDA or no containers to test
}

show_fda_instructions() {
    echo ""
    print_header "FULL DISK ACCESS REQUIRED"
    echo -e "${YELLOW}macOS protects app containers with its sandbox system.${NC}"
    echo -e "${YELLOW}To fully remove Microsoft containers, Terminal needs Full Disk Access.${NC}"
    echo ""
    echo -e "${BOLD}To enable Full Disk Access for Terminal:${NC}"
    echo ""
    echo "  1. Open ${CYAN}System Settings${NC} (or System Preferences on older macOS)"
    echo "  2. Go to ${CYAN}Privacy & Security${NC} → ${CYAN}Full Disk Access${NC}"
    echo "  3. Click the ${CYAN}+${NC} button (you may need to unlock with your password)"
    echo "  4. Navigate to ${CYAN}/Applications/Utilities/${NC}"
    echo "  5. Select ${CYAN}Terminal${NC} and click ${CYAN}Open${NC}"
    echo "  6. Toggle Terminal ${CYAN}ON${NC} in the list"
    echo "  7. ${BOLD}Quit Terminal completely${NC} (Cmd+Q)"
    echo "  8. Re-open Terminal and run this script again"
    echo ""
    echo -e "${BLUE}Quick Access:${NC} Run this command to open the settings directly:"
    echo -e "     ${BOLD}open x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles${NC}"
    echo ""
}

################################################################################
# Sudo Handling
################################################################################

acquire_sudo() {
    print_info "This script requires administrator privileges for some operations."
    echo ""

    # Request sudo upfront
    if ! sudo -v; then
        echo -e "${RED}Error: Failed to acquire sudo privileges.${NC}"
        exit 1
    fi

    # Keep sudo alive in the background
    (while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done) &
    SUDO_KEEPER_PID=$!

    echo -e "${GREEN}✓${NC} Administrator privileges acquired."
    echo ""
}

cleanup_sudo() {
    # Kill the sudo keeper process if it exists
    if [[ -n "${SUDO_KEEPER_PID:-}" ]]; then
        kill "$SUDO_KEEPER_PID" 2>/dev/null || true
    fi
}

# Ensure cleanup on exit
trap cleanup_sudo EXIT

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

remove_path() {
    local path="$1"
    local description="$2"

    if [[ -e "$path" ]]; then
        # Try to remove extended attributes first (helps with sandboxed containers)
        xattr -cr "$path" 2>/dev/null || true

        # Try removal with sudo
        if sudo rm -rf "$path" 2>/dev/null; then
            print_removed "$description"
            return 0
        else
            # Check if it's a container protected by containermanagerd
            if [[ "$path" == *"/Containers/"* ]] || [[ "$path" == *"/Group Containers/"* ]]; then
                print_warning "Protected container: $(basename "$path") (needs Full Disk Access)"
                ((PROTECTED_COUNT++)) || true
                return 1
            else
                print_error "Could not remove $path"
                return 1
            fi
        fi
    fi
    return 1
}

remove_path_pattern() {
    local base_dir="$1"
    local pattern="$2"
    local description="$3"

    if [[ ! -d "$base_dir" ]]; then
        return 1
    fi

    local found=false
    while IFS= read -r -d '' file; do
        if [[ -n "$file" ]]; then
            found=true
            if sudo rm -rf "$file" 2>/dev/null; then
                print_removed "$(basename "$file")"
            else
                print_error "Could not remove $file"
            fi
        fi
    done < <(find "$base_dir" -maxdepth 1 -name "$pattern" -print0 2>/dev/null)

    return 0
}

################################################################################
# Process Handling
################################################################################

kill_microsoft_processes() {
    print_section "Stopping Microsoft Processes"

    local processes=(
        "Microsoft Word"
        "Microsoft Excel"
        "Microsoft PowerPoint"
        "Microsoft Outlook"
        "Microsoft OneNote"
        "Microsoft Teams"
        "Teams"
        "OneDrive"
        "Microsoft AutoUpdate"
        "Microsoft Update Assistant"
    )

    local killed=false
    for proc in "${processes[@]}"; do
        if pgrep -f "$proc" > /dev/null 2>&1; then
            echo -e "  ${YELLOW}●${NC} Stopping: $proc"
            pkill -9 -f "$proc" 2>/dev/null || true
            killed=true
        fi
    done

    if [[ "$killed" == true ]]; then
        sleep 2
        echo -e "  ${GREEN}✓${NC} Processes stopped"
    else
        echo -e "  ${GREEN}✓${NC} No Microsoft processes were running"
    fi
}

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

    if [[ "$running" == false ]]; then
        echo -e "  ${GREEN}✓${NC} No Microsoft processes running"
    fi
}

################################################################################
# Application Removal
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
        "/Applications/Windows App.app"
        "/Applications/Microsoft Remote Desktop.app"
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
        "/Applications/Windows App.app"
        "/Applications/Microsoft Remote Desktop.app"
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

    if [[ -d "$containers_path" ]]; then
        while IFS= read -r -d '' dir; do
            if [[ -n "$dir" ]]; then
                print_found "$(basename "$dir")"
            fi
        done < <(find "$containers_path" -maxdepth 1 \( -name "com.microsoft.*" -o -name "Microsoft *" \) -print0 2>/dev/null)
    fi
}

remove_user_containers() {
    print_section "Removing User Library Containers"

    local containers_path="$HOME/Library/Containers"

    # Remove all com.microsoft.* containers
    remove_path_pattern "$containers_path" "com.microsoft.*" "Microsoft containers"

    # Remove "Microsoft *" named containers
    remove_path_pattern "$containers_path" "Microsoft *" "Microsoft containers"
}

################################################################################
# Group Containers
################################################################################

check_group_containers() {
    print_section "User Library Group Containers (~/Library/Group Containers)"

    local group_path="$HOME/Library/Group Containers"

    if [[ -d "$group_path" ]]; then
        while IFS= read -r -d '' dir; do
            if [[ -n "$dir" ]]; then
                print_found "$(basename "$dir")"
            fi
        done < <(find "$group_path" -maxdepth 1 -name "UBF8T346G9.*" -print0 2>/dev/null)
    fi
}

remove_group_containers() {
    print_section "Removing Group Containers"

    local group_path="$HOME/Library/Group Containers"
    remove_path_pattern "$group_path" "UBF8T346G9.*" "Office group containers"
}

################################################################################
# Application Scripts
################################################################################

check_application_scripts() {
    print_section "Application Scripts (~/Library/Application Scripts)"

    local scripts_path="$HOME/Library/Application Scripts"

    if [[ -d "$scripts_path" ]]; then
        while IFS= read -r -d '' dir; do
            if [[ -n "$dir" ]]; then
                print_found "$(basename "$dir")"
            fi
        done < <(find "$scripts_path" -maxdepth 1 \( -name "com.microsoft.*" -o -name "UBF8T346G9.*" \) -print0 2>/dev/null)
    fi
}

remove_application_scripts() {
    print_section "Removing Application Scripts"

    local scripts_path="$HOME/Library/Application Scripts"
    remove_path_pattern "$scripts_path" "com.microsoft.*" "Microsoft application scripts"
    remove_path_pattern "$scripts_path" "UBF8T346G9.*" "Office application scripts"
}

################################################################################
# Preferences
################################################################################

check_user_preferences() {
    print_section "User Preferences (~/Library/Preferences)"

    local prefs_path="$HOME/Library/Preferences"

    if [[ -d "$prefs_path" ]]; then
        local count=0
        while IFS= read -r -d '' file; do
            if [[ -n "$file" ]]; then
                ((count++)) || true
            fi
        done < <(find "$prefs_path" -maxdepth 1 -name "com.microsoft.*" -print0 2>/dev/null)

        if [[ $count -gt 0 ]]; then
            echo -e "  ${GREEN}✓${NC} Found $count Microsoft preference files"
            ((FOUND_COUNT+=count)) || true
        fi
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
        local count=0
        while IFS= read -r -d '' file; do
            if [[ -n "$file" ]]; then
                ((count++)) || true
            fi
        done < <(find "$prefs_path" -maxdepth 1 -name "com.microsoft.*" -print0 2>/dev/null)

        if [[ $count -gt 0 ]]; then
            echo -e "  ${GREEN}✓${NC} Found $count Microsoft system preference files"
            ((FOUND_COUNT+=count)) || true
        fi
    fi
}

remove_system_preferences() {
    print_section "Removing System Preferences"

    local prefs_path="/Library/Preferences"
    remove_path_pattern "$prefs_path" "com.microsoft.*" "Microsoft system preferences"
}

################################################################################
# Caches
################################################################################

check_caches() {
    print_section "User Caches (~/Library/Caches)"

    local cache_path="$HOME/Library/Caches"

    if [[ -d "$cache_path" ]]; then
        while IFS= read -r -d '' dir; do
            if [[ -n "$dir" ]]; then
                print_found "$(basename "$dir")"
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

    check_path "/Library/Application Support/Microsoft" "Microsoft" || true
}

remove_system_application_support() {
    print_section "Removing System Application Support"

    remove_path "/Library/Application Support/Microsoft" "Microsoft"
}

################################################################################
# LaunchAgents and LaunchDaemons
################################################################################

check_launch_agents() {
    print_section "User LaunchAgents (~/Library/LaunchAgents)"

    local agents_path="$HOME/Library/LaunchAgents"

    if [[ -d "$agents_path" ]]; then
        while IFS= read -r -d '' file; do
            if [[ -n "$file" ]]; then
                print_found "$(basename "$file")"
            fi
        done < <(find "$agents_path" -maxdepth 1 -name "com.microsoft.*" -print0 2>/dev/null)
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
        while IFS= read -r -d '' file; do
            if [[ -n "$file" ]]; then
                print_found "$(basename "$file")"
            fi
        done < <(find "$agents_path" -maxdepth 1 -name "com.microsoft.*" -print0 2>/dev/null)
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

    remove_path_pattern "$agents_path" "com.microsoft.*" "Microsoft system launch agents"
}

check_launch_daemons() {
    print_section "System LaunchDaemons (/Library/LaunchDaemons)"

    local daemons_path="/Library/LaunchDaemons"

    if [[ -d "$daemons_path" ]]; then
        while IFS= read -r -d '' file; do
            if [[ -n "$file" ]]; then
                print_found "$(basename "$file")"
            fi
        done < <(find "$daemons_path" -maxdepth 1 -name "com.microsoft.*" -print0 2>/dev/null)
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

    remove_path_pattern "$daemons_path" "com.microsoft.*" "Microsoft launch daemons"
}

################################################################################
# Privileged Helper Tools
################################################################################

check_privileged_helpers() {
    print_section "Privileged Helper Tools (/Library/PrivilegedHelperTools)"

    local helpers_path="/Library/PrivilegedHelperTools"

    if [[ -d "$helpers_path" ]]; then
        while IFS= read -r -d '' file; do
            if [[ -n "$file" ]]; then
                print_found "$(basename "$file")"
            fi
        done < <(find "$helpers_path" -maxdepth 1 -name "com.microsoft.*" -print0 2>/dev/null)
    fi
}

remove_privileged_helpers() {
    print_section "Removing Privileged Helper Tools"

    local helpers_path="/Library/PrivilegedHelperTools"
    remove_path_pattern "$helpers_path" "com.microsoft.*" "Microsoft helper tools"
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

    remove_path "/Library/Fonts/Microsoft" "Microsoft Fonts folder"
}

################################################################################
# Package Receipts
################################################################################

check_receipts() {
    print_section "Package Receipts (pkgutil)"

    local packages
    packages=$(pkgutil --pkgs 2>/dev/null | grep -i "com.microsoft" || true)

    if [[ -n "$packages" ]]; then
        local count
        count=$(echo "$packages" | wc -l | tr -d ' ')
        echo -e "  ${GREEN}✓${NC} Found $count Microsoft package receipts"
        ((FOUND_COUNT+=count)) || true
    else
        echo -e "  ${YELLOW}○${NC} No Microsoft package receipts found"
    fi
}

remove_receipts() {
    print_section "Forgetting Package Receipts"

    local packages
    packages=$(pkgutil --pkgs 2>/dev/null | grep -i "com.microsoft" || true)

    if [[ -n "$packages" ]]; then
        while IFS= read -r pkg; do
            if [[ -n "$pkg" ]]; then
                if sudo pkgutil --forget "$pkg" >/dev/null 2>&1; then
                    print_removed "Forgot: $pkg"
                else
                    print_error "Could not forget: $pkg"
                fi
            fi
        done <<< "$packages"
    else
        echo -e "  ${YELLOW}○${NC} No package receipts to forget"
    fi
}

################################################################################
# Identity Cache (Azure AD / MSAL tokens)
################################################################################

check_identity_cache() {
    print_section "Identity Cache (Azure AD tokens)"

    # OneAuth folder in Application Support
    local oneauth_path="$HOME/Library/Application Support/Microsoft/OneAuth"
    if [[ -d "$oneauth_path" ]]; then
        print_found "OneAuth cache"
    fi

    # IdentityCache folder
    local identity_path="$HOME/Library/Application Support/Microsoft/IdentityCache"
    if [[ -d "$identity_path" ]]; then
        print_found "IdentityCache"
    fi

    # Saved Application State
    local saved_state="$HOME/Library/Saved Application State/com.microsoft.teams.savedState"
    if [[ -d "$saved_state" ]]; then
        print_found "Teams saved state"
    fi

    # HTTPStorages
    local http_storage="$HOME/Library/HTTPStorages/com.microsoft.teams"
    if [[ -d "$http_storage" ]]; then
        print_found "Teams HTTP storage"
    fi
}

remove_identity_cache() {
    print_section "Removing Identity Cache"

    # OneAuth folder
    remove_path "$HOME/Library/Application Support/Microsoft/OneAuth" "OneAuth cache"

    # IdentityCache folder
    remove_path "$HOME/Library/Application Support/Microsoft/IdentityCache" "IdentityCache"

    # Saved Application State
    remove_path "$HOME/Library/Saved Application State/com.microsoft.teams.savedState" "Teams saved state"

    # HTTPStorages
    remove_path "$HOME/Library/HTTPStorages/com.microsoft.teams" "Teams HTTP storage"
}

################################################################################
# Keychain Entries
################################################################################

check_keychain() {
    print_section "Keychain Entries"

    # Check for known Microsoft keychain entries
    local found_keychain=false

    if security find-generic-password -s "Microsoft Teams Safe Storage" >/dev/null 2>&1; then
        print_found "Microsoft Teams Safe Storage"
        found_keychain=true
    fi

    if security find-generic-password -s "OneAuthAccount" >/dev/null 2>&1; then
        print_found "OneAuthAccount (Azure AD tokens)"
        found_keychain=true
    fi

    if security find-generic-password -s "com.microsoft.adalcache" >/dev/null 2>&1; then
        print_found "com.microsoft.adalcache"
        found_keychain=true
    fi

    if security find-generic-password -s "com.microsoft.onedrive.cookies" >/dev/null 2>&1; then
        print_found "com.microsoft.onedrive.cookies"
        found_keychain=true
    fi

    if [[ "$found_keychain" == false ]]; then
        echo -e "  ${YELLOW}○${NC} No Microsoft keychain entries found"
    fi
}

remove_keychain_entries() {
    print_section "Removing Keychain Entries"

    # Delete Microsoft Teams Safe Storage
    if security delete-generic-password -s "Microsoft Teams Safe Storage" >/dev/null 2>&1; then
        print_removed "Microsoft Teams Safe Storage"
    fi

    # Delete all OneAuthAccount entries (there can be multiple)
    local deleted_oneauth=0
    while security delete-generic-password -s "OneAuthAccount" >/dev/null 2>&1; do
        ((deleted_oneauth++)) || true
    done
    if [[ $deleted_oneauth -gt 0 ]]; then
        print_removed "OneAuthAccount entries ($deleted_oneauth)"
        ((REMOVED_COUNT+=deleted_oneauth-1)) || true  # Already counted one
    fi

    # Delete adalcache
    if security delete-generic-password -s "com.microsoft.adalcache" >/dev/null 2>&1; then
        print_removed "com.microsoft.adalcache"
    fi

    # Delete OneDrive cookies
    if security delete-generic-password -s "com.microsoft.onedrive.cookies" >/dev/null 2>&1; then
        print_removed "com.microsoft.onedrive.cookies"
    fi
}

################################################################################
# Login Items
################################################################################

check_login_items() {
    print_section "Login Items (System Settings)"

    print_info "Login Items should be checked manually."
    print_info "Go to: System Settings → General → Login Items"
    echo -e "     - Microsoft AutoUpdate"
    echo -e "     - Microsoft Teams"
    echo -e "     - OneDrive"
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
        print_info "To remove all items, run:"
        echo -e "     ${BOLD}sudo ./ms-office-cleanup.sh --remove${NC}"
        echo ""
        print_info "To skip confirmations, add --force:"
        echo -e "     ${BOLD}sudo ./ms-office-cleanup.sh --remove --force${NC}"
        echo ""
        print_warning "Note: If app containers fail to remove, Terminal needs Full Disk Access."
        print_info "See: System Settings → Privacy & Security → Full Disk Access → Terminal"
    else
        echo -e "${GREEN}No Microsoft Office items found on this system!${NC}"
        echo -e "${GREEN}Your Mac appears to be clean of Microsoft software.${NC}"
    fi
    echo ""
}

show_removal_summary() {
    echo ""
    print_header "REMOVAL SUMMARY"

    echo -e "${GREEN}Successfully removed $REMOVED_COUNT Microsoft items.${NC}"

    if [[ $PROTECTED_COUNT -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  $PROTECTED_COUNT containers are protected by macOS sandbox.${NC}"
        echo ""
        echo -e "${BOLD}To remove these protected containers:${NC}"
        echo -e "  ${CYAN}Terminal needs Full Disk Access permission.${NC}"
        echo ""
        show_fda_instructions
        echo -e "${BOLD}After enabling Full Disk Access:${NC}"
        echo -e "  1. Quit Terminal completely (Cmd+Q)"
        echo -e "  2. Re-open Terminal"
        echo -e "  3. Run: ${CYAN}sudo ./ms-office-cleanup.sh --remove --force${NC}"
    fi

    echo ""
    print_info "Manual steps remaining:"
    echo "  1. Check Login Items: System Settings → General → Login Items"
    echo "  2. Remove Microsoft apps from your Dock (right-click → Remove from Dock)"
    echo "  3. Empty your Trash"
    echo ""
}

################################################################################
# Main Functions
################################################################################

run_audit() {
    print_header "MICROSOFT OFFICE CLEANUP AUDIT"
    echo "Scanning your system for Microsoft Office components..."
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
    check_identity_cache
    check_keychain
    check_login_items

    show_audit_summary
}

run_removal() {
    print_header "MICROSOFT OFFICE COMPLETE REMOVAL"

    echo -e "${BOLD}This will permanently remove ALL Microsoft Office components:${NC}"
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

    if [[ "$FORCE_MODE" == false ]]; then
        read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Removal cancelled."
            exit 0
        fi

        echo ""
        print_warning "Starting in 3 seconds... Press Ctrl+C to cancel."
        sleep 3
        echo ""
    fi

    # Acquire sudo privileges upfront
    acquire_sudo

    # Kill running processes
    kill_microsoft_processes

    # Remove everything
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
    remove_identity_cache
    remove_keychain_entries

    # Show manual steps
    check_login_items

    show_removal_summary

    if [[ "$SKIP_RESTART" == false && "$FORCE_MODE" == false ]]; then
        read -p "Would you like to restart your Mac now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Restarting in 5 seconds... Press Ctrl+C to cancel."
            sleep 5
            sudo shutdown -r now
        else
            print_info "Please restart your Mac manually to complete the cleanup."
        fi
    else
        print_info "Please restart your Mac to complete the cleanup."
    fi
}

show_help() {
    echo ""
    echo -e "${BOLD}Microsoft Office Complete Cleanup Tool for macOS${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --audit         Scan and show all Microsoft items (default)"
    echo "  --remove        Remove all Microsoft Office components"
    echo "  --force, -f     Skip confirmation prompts (use with --remove)"
    echo "  --no-restart    Don't prompt to restart (use with --remove)"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                          # Run audit (safe, no changes)"
    echo "  $0 --audit                  # Same as above"
    echo "  sudo $0 --remove            # Remove with confirmation prompts"
    echo "  sudo $0 --remove --force    # Remove without prompts"
    echo ""
    echo "Note: The --remove option requires sudo for full cleanup."
    echo ""
}

################################################################################
# Entry Point
################################################################################

main() {
    # Check if on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        echo -e "${RED}Error: This script is designed for macOS only.${NC}"
        exit 1
    fi

    # Parse arguments
    local mode="audit"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --remove)
                mode="remove"
                AUDIT_ONLY=false
                shift
                ;;
            --force|-f)
                FORCE_MODE=true
                shift
                ;;
            --no-restart)
                SKIP_RESTART=true
                shift
                ;;
            --audit)
                mode="audit"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done

    # Run the appropriate mode
    case "$mode" in
        remove)
            run_removal
            ;;
        audit|*)
            run_audit
            ;;
    esac
}

main "$@"
