# Microsoft Office Complete Cleanup Tool for macOS

A comprehensive script to completely remove ALL Microsoft Office products from macOS, including:

- **Microsoft Office apps** (Word, Excel, PowerPoint, Outlook, OneNote)
- **Microsoft Teams** (new and classic versions)
- **Microsoft OneDrive**
- **Microsoft AutoUpdate**
- **All associated files**, preferences, caches, launch agents, and background services

## Why This Script?

Microsoft products on Mac leave behind numerous files in various locations. Simply dragging apps to the Trash doesn't remove:

- User containers and group containers
- Application support files
- Preferences and caches
- Launch agents and daemons
- Privileged helper tools
- Package receipts
- Keychain entries

This script finds and removes ALL of these locations.

## Quick Start

### 1. Download the script

```bash
# Download directly
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/msoffice-mac-cleanup/main/ms-office-cleanup.sh

# Make it executable
chmod +x ms-office-cleanup.sh
```

Or clone the repository:
```bash
git clone https://github.com/YOUR_USERNAME/msoffice-mac-cleanup.git
cd msoffice-mac-cleanup
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

**Note:** You'll be prompted for confirmation and may need to enter your admin password.

## What the Script Does

### Audit Mode (--audit)
- Scans all known Microsoft file locations
- Checks for running Microsoft processes
- Lists all found items with their paths
- Shows package receipts
- Reminds you to check Keychain and Login Items manually
- **Does NOT delete anything**

### Removal Mode (--remove)
- Prompts for confirmation (with 5-second cancel window)
- Force quits any running Microsoft processes (optional)
- Removes all Microsoft applications from /Applications
- Deletes user library containers and group containers
- Removes application scripts, preferences, and caches
- Removes system-level application support files
- Unloads and removes launch agents/daemons
- Removes privileged helper tools
- Removes Microsoft fonts
- Forgets package receipts (pkgutil)
- Prompts to restart your Mac

## Locations Checked/Cleaned

### Applications
- `/Applications/Microsoft *.app`
- `/Applications/OneDrive.app`

### User Library (`~/Library/`)
| Location | What's There |
|----------|--------------|
| `Containers/com.microsoft.*` | App sandboxed data |
| `Group Containers/UBF8T346G9.*` | Shared Office data |
| `Application Scripts/com.microsoft.*` | App scripts |
| `Preferences/com.microsoft.*` | User preferences |
| `Caches/com.microsoft.*` | Cached data |
| `Application Support/Microsoft/` | Support files |
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

## Manual Steps Required

Some items cannot be removed automatically:

### 1. Keychain Entries
1. Open **Keychain Access** (Spotlight: `Cmd+Space`, type "Keychain")
2. Search for: `Microsoft`, `Office`, `Teams`, `OneDrive`, `Outlook`
3. Delete any entries found

### 2. Login Items
1. Open **System Settings** → **General** → **Login Items**
2. Remove any Microsoft items from:
   - "Open at Login"
   - "Allow in the Background"

### 3. Dock Icons
- Right-click any Microsoft app in the Dock
- Select **Options** → **Remove from Dock**

## Important Warnings

- **Outlook Data**: All local Outlook data (emails, calendar, contacts stored "On My Computer") will be permanently deleted. Back up if needed.
- **OneDrive Sync**: Local sync data will be removed. Files remain on OneDrive.com.
- **Teams Data**: All local Teams data will be removed.
- **Cannot Be Undone**: Once removed, you'll need to reinstall from scratch.
- **Admin Required**: You'll need administrator privileges for system-level removals.

## Troubleshooting

### "Operation not permitted" errors
Some files may require special permissions. The script will try sudo automatically. If issues persist, you may need to:
1. Disable System Integrity Protection (SIP) temporarily, OR
2. Boot into Recovery Mode to remove stubborn files

### Script won't execute
```bash
chmod +x ms-office-cleanup.sh
./ms-office-cleanup.sh
```

### Files still remain after removal
1. Make sure all Microsoft apps are quit
2. Check Activity Monitor for lingering processes
3. Restart and run the script again
4. Some files may be locked - check file permissions

## Based On

This script is based on:
- [Official Microsoft uninstall documentation](https://support.microsoft.com/en-us/office/uninstall-office-for-mac-eefa1199-5b58-43af-8a3d-b73dc1a8cae3)
- Community scripts and best practices
- Paul Bowden's Office-Reset tool concepts

## License

MIT License - Use at your own risk. Always backup important data before running system modification scripts.

## Contributing

Issues and pull requests welcome!
