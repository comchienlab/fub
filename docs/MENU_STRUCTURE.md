# Fub Menu Structure

## 🎯 Main Menu (5 Options)

```
 _____     _
|  ___|   | |
| |_ _   _| |__
|  _| | | | '_ \   https://github.com/tw93/fub
| | | |_| | |_) |  can dig deep to clean your Ubuntu system.
\_|  \__,_|_.__/

1. Clean System - Remove junk files and optimize
2. Uninstall Apps - Remove applications completely
3. Optimize System - System health & tuning
4. Analyze Disk - Interactive space explorer
5. More Tools - Additional utilities & setup

↑/↓ Nav  |  Enter Select  |  H Help  |  Q Quit
```

### Navigation
- **Arrow Keys**: ↑/↓ to navigate
- **Numbers**: Press 1-5 for instant selection
- **Enter**: Confirm selection
- **H**: Show help
- **Q**: Quit

---

## 🔧 More Tools Sub-Menu (5 Options)

When selecting **"5. More Tools"** from main menu:

```
╔═══════════════════════════════════════════════════════╗
║                    More Tools                         ║
╚═══════════════════════════════════════════════════════╝

1. Swap Manager - Create/manage swap file
2. Security - UFW firewall & Fail2Ban setup
3. Startup Apps - Manage auto-start programs
4. Nerd Fonts - Install patched developer fonts
5. Back to Main Menu

↑/↓ Nav  |  Enter Select  |  Q Back
```

### Navigation
- **Arrow Keys**: ↑/↓ to navigate
- **Numbers**: Press 1-5 for instant selection
- **Enter**: Execute selected tool
- **Q**: Return to main menu

---

## 📋 Complete Menu Tree

```
Fub Main Menu
├── 1. Clean System
│   └─→ bin/clean.sh
│       ├─ Browser caches (Chrome, Firefox, Brave, Edge)
│       ├─ Package caches (APT, Snap, Flatpak)
│       ├─ Developer caches (npm, pip, cargo, go)
│       ├─ Thumbnails & logs
│       ├─ System orphans
│       └─ Options: --dry-run, --whitelist
│
├── 2. Uninstall Apps ⚡ OPTIMIZED
│   └─→ bin/uninstall.sh
│       ├─ Parallel scanning (5-10x faster)
│       ├─ 5-minute intelligent cache
│       ├─ Multi-package manager support
│       ├─ Interactive fzf selection
│       └─ Options: --refresh
│
├── 3. Optimize System
│   └─→ bin/optimize.sh
│       ├─ System health check
│       ├─ Memory optimization
│       ├─ Swappiness tuning
│       └─ Performance diagnostics
│
├── 4. Analyze Disk
│   └─→ bin/analyze.sh
│       ├─ Interactive disk explorer
│       ├─ Space usage analysis
│       └─ Large file detection
│
└── 5. More Tools
    ├── 1. Swap Manager
    │   └─→ bin/swap.sh
    │       ├─ Create swap file
    │       ├─ Resize swap
    │       └─ Remove swap
    │
    ├── 2. Security
    │   └─→ bin/security.sh
    │       ├─ UFW firewall setup
    │       └─ Fail2Ban configuration
    │
    ├── 3. Startup Apps
    │   └─→ bin/startup.sh
    │       ├─ Manage autostart programs
    │       └─ Speed up boot time
    │
    ├── 4. Nerd Fonts
    │   └─→ bin/nerd-fonts.sh
    │       ├─ Install developer fonts
    │       ├─ 10 popular fonts available
    │       └─ Font management
    │
    └── 5. Back to Main Menu
        └─→ Return to main menu
```

---

## 💻 Command-Line Interface

All features remain accessible via direct commands:

### Core Commands
```bash
fub                    # Interactive main menu (5 options)
fub clean              # Deep system cleanup
fub clean --dry-run    # Preview cleanup
fub clean --whitelist  # Manage protected caches
fub uninstall          # Remove applications (optimized!)
fub uninstall --refresh # Force cache refresh
fub optimize           # System optimization
fub analyze            # Disk space explorer
```

### More Tools Commands
```bash
fub swap               # Swap file manager
fub security           # Security setup
fub startup            # Startup apps manager
fub nerd-fonts         # Font installer
```

### Utility Commands
```bash
fub update             # Update Fub
fub remove             # Uninstall Fub
fub --version          # Show version
fub --help             # Show help
```

---

## 🎨 Design Principles

### Main Menu (5 Options)
**Focus**: Core daily maintenance tasks
- ✅ **Clean** - Most frequently used
- ✅ **Uninstall** - Common task
- ✅ **Optimize** - System health
- ✅ **Analyze** - Disk diagnostics
- ✅ **More Tools** - Everything else

**Benefits**:
- Less overwhelming for new users
- Faster navigation (fewer options)
- Clear primary vs secondary tools
- All features remain accessible

### More Tools Sub-Menu
**Focus**: Less frequent but important utilities
- ⚙️ **Swap** - One-time setup
- 🔒 **Security** - One-time configuration
- 🚀 **Startup** - Periodic optimization
- 🎨 **Fonts** - Development setup
- ↩️ **Back** - Easy return to main menu

**Benefits**:
- Organized by use frequency
- Dedicated screen (no clutter)
- Easy navigation back to main menu

---

## 🔄 User Flow Examples

### Example 1: Quick Cleanup
```
User runs: fub
├─ Main Menu appears (5 options)
├─ Selects: 1. Clean System
├─ Runs cleanup
└─ Returns to shell
```

### Example 2: Font Installation
```
User runs: fub
├─ Main Menu appears (5 options)
├─ Selects: 5. More Tools
├─ More Tools Menu appears (5 options)
├─ Selects: 4. Nerd Fonts
├─ Font installer launches
└─ Returns to shell
```

### Example 3: Direct Command
```
User runs: fub nerd-fonts
└─ Bypasses all menus, goes directly to font installer
```

---

## 📊 Feature Comparison

| Aspect | Before | After |
|--------|--------|-------|
| **Main Menu Options** | 8 | 5 ✅ |
| **Visual Clutter** | High | Low ✅ |
| **New User Experience** | Overwhelming | Clean ✅ |
| **Feature Accessibility** | All visible | Sub-menu |
| **CLI Commands** | All work | All work ✅ |
| **Navigation Speed** | Slower | Faster ✅ |

---

## 🚀 Quick Reference Card

### Main Menu Shortcuts
| Key | Action |
|-----|--------|
| `1` | Clean System |
| `2` | Uninstall Apps |
| `3` | Optimize System |
| `4` | Analyze Disk |
| `5` | More Tools |
| `H` | Help |
| `Q` | Quit |

### More Tools Shortcuts
| Key | Action |
|-----|--------|
| `1` | Swap Manager |
| `2` | Security |
| `3` | Startup Apps |
| `4` | Nerd Fonts |
| `5` | Back to Main |
| `Q` | Back to Main |

---

## 📝 Implementation Details

### File Modified
- `fub` (+98 lines)

### Functions Added
- `show_more_tools_menu()` - Sub-menu handler with full navigation

### Navigation Changes
- Main menu: 8 options → 5 options
- Added sub-menu navigation system
- Keyboard shortcuts work for both menus
- Consistent UI/UX across both screens

### Backward Compatibility
✅ All CLI commands unchanged
✅ All features accessible
✅ No breaking changes

---

## 🎯 Summary

**Main Menu**: 5 focused options highlighting core features
**Sub-Menu**: 4 additional tools + back button
**Total Features**: All 9 original features preserved
**User Experience**: Cleaner, faster, more intuitive

The menu structure provides the perfect balance between simplicity and functionality! 🚀
