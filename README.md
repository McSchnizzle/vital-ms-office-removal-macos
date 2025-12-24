# Microsoft Office Complete Cleanup Tool for macOS

A comprehensive script to completely remove ALL Microsoft Office products from macOS, including:

- **Microsoft Office apps** (Word, Excel, PowerPoint, Outlook, OneNote)
- **Microsoft Teams** (new and classic versions)
- **Microsoft OneDrive**
- **Microsoft AutoUpdate**
- **Windows App / Remote Desktop** (Microsoft's remote desktop client)
- **Azure AD / MSAL identity caches** (cached login credentials and tenant data)
- **Keychain entries** (automatically detected and removed)
- **All associated files**, preferences, caches, launch agents, and background services

## Why This Script?

Microsoft products on Mac leave behind numerous files in various locations. Simply dragging apps to the Trash doesn't remove:

- User containers and group containers
- Application support files
- Preferences and caches
- Launch agents and daemons
- Privileged helper tools
- Package receipts
- **Keychain entries** (now automatically removed!)
- **Azure AD / MSAL identity caches** (cached tenant credentials that cause login issues)

This script finds and removes ALL of these locations, including the credential caches that can cause problems when switching Microsoft 365 tenants or reinstalling Office.

## Quick Start

### 1. Download the script

```bash
# Download directly
curl -O https://raw.githubusercontent.com/McSchnizzle/vital-ms-office-removal-macos/main/ms-office-cleanup.sh

# Make it executable
chmod +x ms-office-cleanup.sh
```

Or clone the repository:
```bash
git clone https://github.com/McSchnizzle/vital-ms-office-removal-macos.git
cd vital-ms-office-removal-macos
```

### 2. Run an audit first (recommended)

This shows what Microsoft items exist on your system WITHOUT making any changes:

```bash
./ms-office-cleanup.sh --audit
```

or simply:

```bash
./ms-office-cleanup.sh
```

### 3. Remove all Microsoft items

Once you've reviewed the audit, run the removal:

```bash
./ms-office-cleanup.sh --remove
```

You'll be prompted for your admin password and confirmation.

### 4. Fully automated removal (no prompts)

For scripted/automated deployments:

```bash
./ms-office-cleanup.sh --remove --force --no-restart
```

## What the Script Does

### Audit Mode (--audit)
- Scans all known Microsoft file locations
- Checks for running Microsoft processes
- Lists all found items with their paths
- Shows package receipts
- **Detects Azure AD / MSAL identity caches** (OneAuth, IdentityCache)
- **Scans Keychain for Microsoft credentials** (Teams, OneDrive, Office, Azure AD tokens)
- **Does NOT delete anything**

### Removal Mode (--remove)
- Acquires sudo privileges upfront (asks for password once)
- Prompts for confirmation (unless --force is used)
- Force quits all running Microsoft processes automatically
- Removes all Microsoft applications from /Applications
- Deletes user library containers and group containers
- Removes application scripts, preferences, and caches
- Removes system-level application support files
- Unloads and removes launch agents/daemons
- Removes privileged helper tools
- Removes Microsoft fonts
- Forgets package receipts (pkgutil)
- **Clears Azure AD / MSAL identity caches** (OneAuth, IdentityCache, Teams HTTP storage)
- **Removes Keychain entries** (Teams Safe Storage, OneAuthAccount, OneDrive, ADAL cache)
- Prompts to restart your Mac

## Locations Checked/Cleaned

### Applications
- `/Applications/Microsoft *.app`
- `/Applications/OneDrive.app`
- `/Applications/Windows App.app`
- `/Applications/Remote Desktop.app`

### User Library (`~/Library/`)
| Location | What's There |
|----------|--------------|
| `Containers/com.microsoft.*` | App sandboxed data |
| `Group Containers/UBF8T346G9.*` | Shared Office data, **OneAuth identity cache** |
| `Application Scripts/com.microsoft.*` | App scripts |
| `Application Scripts/UBF8T346G9.*` | Office extension scripts |
| `Preferences/com.microsoft.*` | User preferences |
| `Caches/com.microsoft.*` | Cached data |
| `Application Support/Microsoft/` | Support files, **OneAuth & IdentityCache folders** |
| `Saved Application State/com.microsoft.*` | App state data |
| `HTTPStorages/com.microsoft.*` | HTTP storage caches |
| `LaunchAgents/com.microsoft.*` | Background agents |

### System Library (`/Library/`)
| Location | What's There |
|----------|--------------|
| `Application Support/Microsoft/` | System-wide support |
| `Preferences/com.microsoft.*` | System preferences |
| `LaunchAgents/com.microsoft.*` | System launch agents |
| `LaunchDaemons/com.microsoft.*` | Background daemons |
| `PrivilegedHelperTools/com.microsoft.*` | Helper tools |
| `Fonts/Microsoft/` | Microsoft fonts |

### Package Receipts
- All `com.microsoft.*` packages registered with macOS

### Keychain Entries (automatically removed)
The script automatically detects and removes these keychain entries:
- `Microsoft Teams Safe Storage` - Teams credentials
- `OneAuthAccount` - Azure AD / Entra ID tokens (can have multiple entries)
- `com.microsoft.adalcache` - ADAL authentication cache
- `com.microsoft.onedrive.cookies` - OneDrive session cookies
- `com.microsoft.OneDrive.FinderSync.HockeySDK` - OneDrive telemetry
- `MicrosoftOfficeIdentityCache` - Office license cache

## Manual Steps Required

Most cleanup is now fully automated. Only a few items require manual action:

### 1. Login Items
1. Open **System Settings** → **General** → **Login Items**
2. Remove any Microsoft items from:
   - "Open at Login"
   - "Allow in the Background"

### 2. Dock Icons
- Right-click any Microsoft app in the Dock
- Select **Options** → **Remove from Dock**

### 3. Additional Keychain Entries (if any remain)
The script automatically removes known Microsoft keychain entries. If you still see any after running the script:
1. Open **Keychain Access** (Spotlight: `Cmd+Space`, type "Keychain")
2. Search for: `Microsoft`, `Office`, `Teams`, `OneDrive`, `Outlook`
3. Delete any entries found

## Important Warnings

- **Outlook Data**: All local Outlook data (emails, calendar, contacts stored "On My Computer") will be permanently deleted. Back up if needed.
- **OneDrive Sync**: Local sync data will be removed. Files remain on OneDrive.com.
- **Teams Data**: All local Teams data will be removed.
- **Cannot Be Undone**: Once removed, you'll need to reinstall from scratch.
- **Admin Required**: You'll need administrator privileges for system-level removals.

## Troubleshooting

### Protected containers won't delete (most common issue)

macOS Sonoma and later protect app containers with a sandbox system called `containermanagerd`.
Even with sudo, you'll see "Operation not permitted" errors for containers in `~/Library/Containers/`.

**Solution: Grant Terminal Full Disk Access**

1. Open **System Settings** → **Privacy & Security** → **Full Disk Access**
2. Click the **+** button (unlock with your password if needed)
3. Navigate to **/Applications/Utilities/**
4. Select **Terminal** and click **Open**
5. Toggle Terminal **ON** in the list
6. **Quit Terminal completely** (Cmd+Q)
7. Re-open Terminal and run the script again

**Quick access to settings:**
```bash
open x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles
```

### Script won't execute
```bash
chmod +x ms-office-cleanup.sh
./ms-office-cleanup.sh
```

### Files still remain after removal
1. Make sure all Microsoft apps are quit
2. Check Activity Monitor for lingering processes
3. Ensure Terminal has Full Disk Access (see above)
4. Restart and run the script again

### Tenant migration issues (AADSTS50020 error)

If you're getting login errors after your organization changed Microsoft 365 tenants, or you see errors like:
- `AADSTS50020: User account from identity provider does not exist in tenant`
- Office apps trying to use an old tenant ID
- Can't log into Teams/Outlook after reinstalling Office

**This is exactly what this script fixes!** The identity cache cleanup removes:
- Cached tenant IDs from `~/Library/Group Containers/UBF8T346G9.com.microsoft.oneauth`
- Azure AD tokens from Keychain (`OneAuthAccount` entries)
- MSAL/ADAL authentication caches

Run the full removal with `--remove` flag, restart your Mac, then reinstall Office. The apps will properly discover your new tenant on first login.

## Based On

This script is based on:
- [Official Microsoft uninstall documentation](https://support.microsoft.com/en-us/office/uninstall-office-for-mac-eefa1199-5b58-43af-8a3d-b73dc1a8cae3)
- Community scripts and best practices
- Paul Bowden's Office-Reset tool concepts

## License

MIT License - Use at your own risk. Always backup important data before running system modification scripts.

## Contributing

Issues and pull requests welcome!
