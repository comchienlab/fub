<div align="center">
  <h1>Fub</h1>
  <p><em>Dig deep to clean your Ubuntu system.</em></p>
</div>

## Features

- **Deep System Cleanup** - Deep system cleaning - caches, logs, temp files, APT/Snap/Flatpak cleanup, telemetry removal
- **Thorough Uninstall** - Multi-package manager support (APT, Snap, Flatpak, AppImage) with fzf fuzzy finder
- **System Optimization** - Performance tuning, cache rebuilds, TLP/auto-cpufreq power management for laptops
- **Interactive Disk Analyzer** - Navigate folders with arrow keys, find and delete large files quickly
- **Swap File Manager** - Create/manage swap files with interactive size selection
- **Security Hardening** - UFW firewall and Fail2Ban setup with sensible defaults
- **Startup Manager** - Enable/disable auto-start programs to improve boot time
- **Fast & Lightweight** - Terminal-based with fzf fuzzy finder, arrow-key navigation, and batch operations

## Quick Start

**Install:**

```bash
curl -fsSL https://raw.githubusercontent.com/comchienlab/fub/main/install.sh | bash
```

Or via Homebrew:

```bash
brew install comchienlab/tap/fub
```

**Run:**

```bash
fub                      # Interactive menu (7 options)
fub clean                # System cleanup
fub clean --dry-run      # Preview mode
fub clean --whitelist    # Manage protected caches
fub uninstall            # Uninstall apps (APT, Snap, Flatpak, AppImage)
fub optimize             # System optimization & performance tuning
fub analyze              # Disk analyzer
fub swap                 # Swap file manager
fub security             # Security hardening (UFW, Fail2Ban)
fub startup              # Startup applications manager

fub touchid              # Configure Touch ID for sudo (macOS only)
fub update               # Update Fub
fub remove               # Remove Fub from system
fub --help               # Show help
fub --version            # Show installed version

```

## Tips

- Safety first, if your Ubuntu system is mission-critical, wait for Fub to mature before full cleanups.
- Preview the cleanup by running `fub clean --dry-run` and reviewing the generated list.
- Use `fub clean --whitelist` to manage protected caches.
- Use `fub touchid` to approve sudo with Touch ID instead of typing your password.

## Features in Detail

### Deep System Cleanup

```bash
$ fub clean

Scanning cache directories...

  ✓ User app cache                                           45.2GB
  ✓ Browser cache (Chrome, Safari, Firefox)                  10.5GB
  ✓ Developer tools (Xcode, Node.js, npm)                    23.3GB
  ✓ System logs and temp files                                3.8GB
  ✓ App-specific cache (Spotify, Dropbox, Slack)              8.4GB
  ✓ Trash                                                     12.3GB

====================================================================
Space freed: 95.5GB | Free space now: 223.5GB
====================================================================
```

### Smart App Uninstaller

```bash
$ fub uninstall

Select Apps to Remove
═══════════════════════════
▶ ☑ Adobe Creative Cloud      (12.4G) | Old
  ☐ WeChat                    (2.1G) | Recent
  ☐ Final Cut Pro             (3.8G) | Recent

Uninstalling: Adobe Creative Cloud

  ✓ Removed application
  ✓ Cleaned 52 related files across 12 locations
    - Application Support, Caches, Preferences
    - Logs, WebKit storage, Cookies
    - Extensions, Plugins, Launch daemons

====================================================================
Space freed: 12.8GB
====================================================================
```

### System Optimization

```bash
$ fub optimize

System: 5/32 GB RAM | 333/460 GB Disk (72%) | Uptime 6d

  ✓ Rebuild system databases and flush caches
  ✓ Reset network services
  ✓ Refresh Finder and Dock
  ✓ Clean diagnostic and crash logs
  ✓ Purge swap files and restart dynamic pager
  ✓ Rebuild launch services and spotlight index

====================================================================
System optimization completed
====================================================================
```

### Disk Space Analyzer

```bash
$ fub analyze

Analyze Disk  ~/Documents  |  Total: 156.8GB

 ▶  1. ███████████████████  48.2%  |  📁 Library                     75.4GB  >6mo
    2. ██████████░░░░░░░░░  22.1%  |  📁 Downloads                   34.6GB
    3. ████░░░░░░░░░░░░░░░  14.3%  |  📁 Movies                      22.4GB
    4. ███░░░░░░░░░░░░░░░░  10.8%  |  📁 Documents                   16.9GB
    5. ██░░░░░░░░░░░░░░░░░   5.2%  |  📄 backup_2023.zip              8.2GB

  ↑↓←→ Navigate  |  O Open  |  F Reveal  |  ⌫ Delete  |  L Large(24)  |  Q Quit
```

### Swap File Manager

```bash
$ fub swap

Current Memory Status
═══════════════════════════════════════════════
  RAM:         Total: 8.0G | Used: 2.5G | Free: 5.5G
  Swap:        No swap file configured

Select swap file size:
▶ 2GB
  4GB
  8GB
  16GB
  32GB
  Custom
  Remove Swap
  Cancel

Creating 8GB swap file...
  → Creating 8GB swap file (this may take a moment)...
  → Setting permissions...
  → Formatting as swap...
  → Enabling swap...
  → Adding to /etc/fstab for persistence...

✓ Swap file created successfully!
```

### Security Hardening

```bash
$ fub security

Current Security Status
═══════════════════════════════════════════════
  UFW Firewall:    Not installed
  Fail2Ban:        Not installed
  SSH Server:      Running

Select security action:
▶ Setup UFW Firewall
  Setup Fail2Ban
  Show UFW Rules
  Show Fail2Ban Status
  Exit

Setting up UFW Firewall...
  → Installing UFW...
  → Configuring default policies...
  → Allowing SSH (port 22)...

Allow HTTP (port 80)? [y/N]: y
  ✓ HTTP allowed

✓ UFW Firewall configured and enabled!
```

### Startup Applications Manager

```bash
$ fub startup

Startup Applications Status
═══════════════════════════════════════════════
  Total:      12 startup applications
  Enabled:    8 active
  Disabled:   4 inactive

  User apps:   5 applications
  System apps: 7 applications

Select action:
▶ Disable Apps
  Enable Apps
  Remove User Apps
  List All Apps
  Exit

Select startup apps to DISABLE: (Tab: select, Ctrl-A: all)
▶ ☑ [ENABLED ] [USER  ]  Dropbox
  ☐ [ENABLED ] [SYSTEM]  GNOME Keyring
  ☑ [ENABLED ] [USER  ]  Slack Startup

Disabling startup applications...
  ✓ Disabled: Dropbox
  ✓ Disabled: Slack Startup

✓ Disabled 2 startup application(s)
```

## Environment Variables

Fub supports environment variables for non-interactive configuration:

### Clean Command
```bash
FUB_REMOVE_BLOAT=true       # Remove bloatware packages (gnome-games, etc.)
FUB_REMOVE_TELEMETRY=true   # Disable Ubuntu telemetry (apport, whoopsie)
FUB_CLEAR_PRIVACY_LOGS=true # Clear privacy logs (default: true)
```

### Optimize Command
```bash
FUB_INSTALL_NERDFONTS=true    # Install Nerd Fonts (JetBrains, FiraCode, etc.)
FUB_INSTALL_TLP=true          # Install TLP power management (laptops only)
FUB_INSTALL_AUTOCPUFREQ=true  # Install auto-cpufreq (alternative to TLP)
```

### Swap Command
```bash
FUB_SWAP_SIZE=8               # Create swap file with specified size in GB
```

### Security Command
```bash
FUB_SETUP_UFW=true            # Auto-setup UFW firewall
FUB_SETUP_FAIL2BAN=true       # Auto-setup Fail2Ban
```

### Example Usage
```bash
# Deep privacy cleanup
FUB_REMOVE_TELEMETRY=true FUB_REMOVE_BLOAT=true fub clean

# Full laptop optimization
FUB_INSTALL_TLP=true FUB_INSTALL_NERDFONTS=true fub optimize

# Create 16GB swap file
FUB_SWAP_SIZE=16 fub swap

# Auto-configure security
FUB_SETUP_UFW=true FUB_SETUP_FAIL2BAN=true fub security
```

## Quick Launchers

Launch Fub commands instantly from Raycast or Alfred:

```bash
curl -fsSL https://raw.githubusercontent.com/comchienlab/fub/main/scripts/setup-quick-launchers.sh | bash
```

Adds 4 commands: `clean`, `uninstall`, `optimize`, `analyze`. Auto-detects your terminal or set `MO_LAUNCHER_APP=<name>` to override.
