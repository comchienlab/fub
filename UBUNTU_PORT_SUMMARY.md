# Fub → Ubuntu 24.04 Port: Technical Research Summary

## Executive Summary

**Feasibility:** ✅ **HIGHLY FEASIBLE** - The port is practical and straightforward with medium complexity.

**Effort Estimate:** 3-4 weeks for an experienced developer

**Key Finding:** The core architecture and cleanup logic of Fub translate well to Ubuntu. The main challenges are:
1. Multi-package-manager support (APT, Snap, Flatpak, AppImage)
2. Path mapping from macOS Library structure to XDG directories
3. Replacing macOS-specific system commands with Linux equivalents

---

## Critical Path Mappings

### 1. Directory Structure Mapping

| macOS Path | Ubuntu Path | XDG Variable | Purpose |
|------------|-------------|--------------|---------|
| `~/Library/Caches` | `~/.cache` | `$XDG_CACHE_HOME` | User app caches |
| `~/Library/Preferences` | `~/.config` | `$XDG_CONFIG_HOME` | User configs |
| `~/Library/Application Support` | `~/.local/share` | `$XDG_DATA_HOME` | User app data |
| `~/Library/Logs` | `~/.local/state` | `$XDG_STATE_HOME` | User logs |
| `~/Library/Saved Application State` | `~/.local/state` | `$XDG_STATE_HOME` | App states |
| `~/.Trash` | `~/.local/share/Trash` | `$XDG_DATA_HOME/Trash` | Trash |
| `/Library/Caches` | `/var/cache` | - | System caches |
| `/Library/Logs` | `/var/log` | - | System logs |

### 2. Command Equivalents

| macOS Command | Ubuntu Command | Notes |
|---------------|----------------|-------|
| `mdfind` | `locate` / `find` | Spotlight → locate database |
| `tmutil` | `timeshift` / `rsync` | Time Machine → backup tools |
| `defaults` | `gsettings` / `dconf` | plist → config files |
| `launchctl` | `systemctl` | Launch Agents → systemd |
| `lsregister` | `update-desktop-database` | LaunchServices → .desktop |
| `mdutil -E` | `updatedb` | Spotlight index → locate DB |
| `stat -f%z` | `stat -c%s` | File size format |
| `stat -f%m` | `stat -c%Y` | Modification time |

### 3. Package Management Strategy

Ubuntu requires handling **4 different package managers** vs macOS's unified Homebrew:

```bash
# Detection order (priority)
1. APT/DPKG (native) - dpkg -l, apt list --installed
2. Snap (Canonical) - snap list
3. Flatpak (cross-distro) - flatpak list
4. AppImage (portable) - find *.AppImage files
```

**Uninstall locations:**
- APT: `/usr/bin`, `/usr/lib`, `/usr/share`, `/etc`
- Snap: `/snap`, `~/snap`, `/var/lib/snapd`
- Flatpak: `/var/lib/flatpak`, `~/.var/app`, `~/.local/share/flatpak`
- AppImage: User directories (no standard location)

---

## Ubuntu-Specific Cleanup Targets

### High-Impact Cleanup Locations (Similar Depth to Fub)

```bash
# APT Cache (500MB - 2GB typical)
/var/cache/apt/archives/*

# System Logs (can be 5-10GB if not managed)
/var/log/journal/*
journalctl --vacuum-time=7d --vacuum-size=100M

# Old Kernels (200-400MB each, multiple versions)
/boot/vmlinuz-*
/boot/initrd.img-*
apt autoremove --purge

# Browser Caches (GB range)
~/.cache/google-chrome/*
~/.cache/chromium/*
~/.cache/mozilla/firefox/*

# Thumbnails (100-500MB)
~/.cache/thumbnails/*

# Snap Revisions (keeps old versions, can be 2-3GB per app)
snap set system refresh.retain=2

# Docker (can be 10-50GB+)
docker system prune -a --volumes

# Developer Caches (similar to macOS, 10-50GB potential)
~/.npm/_cacache
~/.cargo/registry/cache
~/.gradle/caches
~/.cache/pip
~/.cache/go-build

# User Application Caches
~/.cache/*

# Flatpak Unused Dependencies
flatpak uninstall --unused

# Trash
~/.local/share/Trash/files/*
```

---

## Major Code Changes Required

### 1. **Clean Mode** (`bin/clean.sh`) - MEDIUM Complexity

**Changes:**
```bash
# Replace paths
~/Library/Caches/* → ~/.cache/*
~/Library/Logs/* → ~/.local/state/* OR ~/.cache/logs/*
~/Library/Application\ Support/* → ~/.local/share/*

# Add Ubuntu-specific cleaning
- journalctl --vacuum-time=7d --vacuum-size=100M
- apt clean && apt autoclean
- apt autoremove --purge (old kernels)
- snap set system refresh.retain=2
- flatpak uninstall --unused
- docker system prune (if docker present)

# Remove macOS-specific
- Rosetta 2 cleanup
- Time Machine cleanup
- iOS device backups
- QuickLook cache
```

### 2. **Uninstall Mode** (`bin/uninstall.sh`) - HIGH Complexity

**Major refactor needed:**
```bash
# NEW: Multi-package-manager detection
scan_apt_packages() {
    dpkg -l | awk '/^ii/ {print $2}'
}

scan_snap_packages() {
    snap list --color=never | tail -n +2
}

scan_flatpak_packages() {
    flatpak list --app --columns=application
}

scan_appimage_files() {
    find ~ -name "*.AppImage" -type f
}

# NEW: Parse .desktop files for app metadata
get_app_info() {
    local desktop_file="$1"
    # Parse: Name, Exec, Icon, Comment from .desktop
    # No CFBundleIdentifier equivalent - use desktop file name
}

# NEW: Package-specific uninstall
uninstall_apt() { apt remove --purge "$pkg"; }
uninstall_snap() { snap remove "$pkg"; }
uninstall_flatpak() { flatpak uninstall "$pkg"; }
uninstall_appimage() { rm "$appimage_path"; }

# File cleanup still similar
find_app_files() {
    # ~/.config/$app_name
    # ~/.local/share/$app_name
    # ~/.cache/$app_name
    # For snap: ~/snap/$app_name
    # For flatpak: ~/.var/app/$app_id
}
```

### 3. **Optimize Mode** (`bin/optimize.sh`) - MEDIUM Complexity

**Changes:**
```bash
# Replace launchctl with systemctl
- launchctl unload → systemctl stop/disable
- launchctl load → systemctl start/enable

# Replace macOS maintenance
- periodic daily/weekly/monthly → apt autoclean + autoremove
- lsregister -kill → update-desktop-database ~/.local/share/applications
- mdutil -E / → updatedb (locate database)
- atsutil databases -remove → fc-cache -fv (font cache)

# Add Ubuntu-specific
- journalctl --vacuum-time=7d
- apt autoremove --purge
- updatedb (locate database)
- update-mime-database ~/.local/share/mime

# Keep (with different commands)
- DNS cache flush: systemd-resolve --flush-caches OR resolvectl flush-caches
- Memory purge: sync && echo 3 > /proc/sys/vm/drop_caches (requires root)
```

### 4. **Analyze Mode** (`bin/analyze.sh` + Go) - LOW Complexity

**Minimal changes needed:**
- Go Bubble Tea analyzer is already cross-platform ✅
- Update cache path from `~/Library/Caches` to `~/.cache`
- Test on Ubuntu to verify (likely works as-is)

---

## Implementation Recommendations

### Phase 1: Core Path Migration (Week 1)
```bash
1. Create lib/paths_ubuntu.sh with XDG path constants
2. Update clean.sh to use XDG paths
3. Add journal log cleanup
4. Add apt cache cleanup
5. Test basic cleaning on Ubuntu 24.04
```

### Phase 2: Package Management (Week 2-3)
```bash
1. Create lib/package_managers.sh
   - detect_package_manager()
   - scan_all_packages()
   - get_package_info()
   - uninstall_package()

2. Create lib/desktop_parser.sh
   - parse_desktop_file()
   - find_desktop_files()
   - get_app_metadata()

3. Update uninstall.sh
   - Use new package detection
   - Multi-select UI for each package type
   - Config file cleanup per XDG

4. Test all 4 package managers
```

### Phase 3: System Integration (Week 4)
```bash
1. Update optimize.sh
   - systemctl integration
   - Ubuntu maintenance commands
   - Desktop database updates

2. Polish and testing
   - Test on fresh Ubuntu 24.04 install
   - Test with APT, Snap, Flatpak, AppImage
   - Test with GNOME, KDE (if supporting multiple DEs)
   - Documentation updates

3. Optional: Add fingerprint auth support (fprintd)
```

---

## Risk Assessment

| Risk Area | Level | Mitigation |
|-----------|-------|------------|
| Multi-package-manager detection | High | Extensive testing, fallback to manual selection |
| Snap confinement complexity | Medium | Document snap-specific behaviors |
| Config file discovery | Medium | Use .desktop file hints, common XDG paths |
| systemd service management | Low | Well-documented systemd API |
| Cross-DE compatibility | Low | Focus on Ubuntu 24.04 default (GNOME) |

---

## Key Advantages of Ubuntu Port

1. **Better Bash Version**: Ubuntu has Bash 4.x+ (vs macOS 3.2)
   - Associative arrays available
   - Better string handling
   - Modern features

2. **Simpler File System**:
   - No extended attributes complexity
   - No code signing checks
   - Straightforward permissions

3. **Unified Package Manager API**:
   - Each package manager has clear CLI
   - No complex bundle ID system
   - Direct dpkg/snap/flatpak queries

4. **Larger Cleanup Potential**:
   - Journal logs can be huge (5-10GB)
   - Docker layers accumulate quickly (10-50GB)
   - Snap keeps multiple revisions (2-3GB per app)
   - Developer caches just as large as macOS

---

## Ubuntu-Specific Features to Add

### High-Value Additions
```bash
1. Old Kernel Cleanup
   - Keep 2 most recent kernels
   - Auto-detect and remove old versions
   - Free 500MB-2GB

2. Snap Revision Management
   - Set retention to 2 versions
   - Clean old snaps: snap list --all | awk '/disabled/ {print $1, $3}' | xargs -n2 snap remove --revision

3. Journal Log Optimization
   - Configure /etc/systemd/journald.conf
   - Set SystemMaxUse=100M
   - Vacuum old logs

4. Docker Aggressive Cleanup
   - Remove unused images, containers, volumes
   - Prune build cache
   - Can free 10-50GB

5. APT Orphaned Package Detection
   - deborphan tool (optional)
   - apt autoremove --purge
```

---

## Tool Recommendations

### Keep Existing
- ✅ **Bash scripts** - Universal on Linux, better version available
- ✅ **Go Bubble Tea analyzer** - Cross-platform, minimal changes
- ✅ **Modular architecture** - Works perfectly for Linux

### Add New
- 📦 **Desktop file parser** - Parse .desktop files for app metadata
- 🔄 **Package manager abstraction** - Unified interface for apt/snap/flatpak/appimage
- ⚙️ **systemd utilities** - Service and journal management

### Replace
- 🔄 **launchctl → systemctl** - Service management
- 🔄 **mdfind → find/locate** - File search
- 🔄 **defaults → gsettings/dconf** - Configuration management

---

## Testing Strategy

### Test Environments
1. **Vanilla Ubuntu 24.04 (GNOME)** - Primary target
2. **With Snap packages** - Verify snap detection/cleanup
3. **With Flatpak packages** - Verify flatpak detection/cleanup
4. **With AppImage apps** - Verify manual detection
5. **Docker installed** - Test docker cleanup
6. **Developer workstation** - Test dev tool caches (npm, cargo, pip, etc.)

### Test Cases
- Fresh install (minimal packages)
- Heavy development environment (50+ packages)
- Long-running system (old kernels, logs, caches)
- Mixed package managers (apt + snap + flatpak)
- Low disk space scenario

---

## Conclusion

**Port is highly feasible** with medium-high complexity. The core cleanup logic translates well to Ubuntu, with the main work being:

1. ✅ **Path mapping** (straightforward, XDG is well-defined)
2. ⚠️ **Multi-package-manager support** (complex but necessary)
3. ✅ **Command replacements** (well-documented equivalents exist)
4. ✅ **System integration** (systemd is mature and stable)

**Expected Outcome:** A powerful Ubuntu system cleaner that rivals or exceeds BleachBit in depth, with the aggressive cleanup philosophy of Fub, optimized for Ubuntu 24.04's multi-package-manager ecosystem.

**Unique Selling Points:**
- Multi-package-manager support (no other tool handles all 4 seamlessly)
- Aggressive cleanup similar to macOS version
- Developer-focused (huge cache cleanup potential)
- TUI disk analyzer (modern, fast)
- Open source, transparent, safe

---

## Full Research Data

See `UBUNTU_PORT_RESEARCH.json` for complete technical details including:
- All macOS-specific features and Ubuntu equivalents
- Complete directory structure mapping
- Comprehensive cleanup location list
- Package manager integration details
- Command reference table
- Implementation recommendations
- Community insights and best practices

---

**Research Date:** 2025-11-19
**Target Platform:** Ubuntu 24.04 LTS
**Source Project:** Fub v1.9.15 (macOS)
