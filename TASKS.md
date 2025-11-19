# Fub Ubuntu Port - Implementation Tasks

**Project:** Port Fub from macOS to Ubuntu 24.04 (Ubuntu-only fork)
**Timeline:** 3-4 weeks
**Priority:** Core features first (Clean → Analyze → Optimize → Uninstall)
**Package Managers:** APT/DPKG, Snap, Flatpak, AppImage
**Cleanup Philosophy:** Aggressive (similar depth to macOS version)

---

## Phase 1: Core Cleanup Features (Week 1)
**Goal:** Get basic cleanup and analysis working on Ubuntu

### Task 1.1: Create Ubuntu Path Constants
**File:** `lib/paths_ubuntu.sh`
**Priority:** P0 (Blocker)
**Effort:** 2 hours

**Implementation:**
```bash
# Create new file with XDG directory mappings
- Define USER_CACHE_DIR="$HOME/.cache"
- Define USER_CONFIG_DIR="$HOME/.config"
- Define USER_DATA_DIR="$HOME/.local/share"
- Define USER_STATE_DIR="$HOME/.local/state"
- Define SYSTEM_CACHE_DIR="/var/cache"
- Define SYSTEM_LOG_DIR="/var/log"
- Define TRASH_DIR="$HOME/.local/share/Trash"
```

**Acceptance Criteria:**
- [ ] All XDG_* variables properly defined with fallbacks
- [ ] System-level directories defined
- [ ] Source-able by other scripts
- [ ] No hardcoded paths

**References:** `UBUNTU_PORT_SUMMARY.md` lines 18-30

---

### Task 1.2: Port clean.sh - Path Replacement
**File:** `bin/clean.sh`
**Priority:** P0 (Blocker)
**Effort:** 1 day

**Implementation:**
1. Source `lib/paths_ubuntu.sh`
2. Replace all macOS paths:
   - `~/Library/Caches` → `$USER_CACHE_DIR`
   - `~/Library/Logs` → `$USER_STATE_DIR` or `$USER_CACHE_DIR/logs`
   - `~/Library/Application Support` → `$USER_DATA_DIR`
   - `~/Library/Preferences` → `$USER_CONFIG_DIR`
   - `~/.Trash` → `$TRASH_DIR`
   - `/Library/Caches` → `$SYSTEM_CACHE_DIR`
   - `/Library/Logs` → `$SYSTEM_LOG_DIR`

3. Remove macOS-specific cleanup:
   - Rosetta 2 cache cleanup
   - Time Machine cleanup functions
   - iOS device backup cleanup
   - QuickLook cache cleanup
   - Xcode derived data (or keep for Linux CLion/IntelliJ)

**Acceptance Criteria:**
- [ ] All macOS paths replaced with XDG equivalents
- [ ] macOS-specific cleanup removed
- [ ] Script runs without errors on Ubuntu 24.04
- [ ] Dry-run mode works correctly
- [ ] Whitelist system still functional

**Testing:**
- Run `./fub clean --dry-run` on Ubuntu 24.04
- Verify it scans XDG directories
- Check no errors about missing macOS paths

---

### Task 1.3: Add Ubuntu-Specific Cleanup
**File:** `bin/clean.sh`
**Priority:** P0 (Blocker)
**Effort:** 1 day

**Implementation:**
Add new cleanup functions:

```bash
# 1. APT Cache Cleanup (500MB-2GB)
clean_apt_cache() {
    apt-get clean
    apt-get autoclean
}

# 2. Journal Log Cleanup (5-10GB potential)
clean_journal_logs() {
    journalctl --vacuum-time=7d --vacuum-size=100M
}

# 3. Old Kernel Cleanup (200-400MB each)
clean_old_kernels() {
    # Keep current + 1 previous
    apt-get autoremove --purge
}

# 4. Snap Revision Cleanup (2-3GB per app)
clean_snap_revisions() {
    # Set retention to 2 versions
    snap set system refresh.retain=2
    # Remove disabled snaps
    snap list --all | awk '/disabled/ {print $1, $3}' | xargs -n2 snap remove --revision
}

# 5. Flatpak Unused Dependencies
clean_flatpak_unused() {
    flatpak uninstall --unused -y
}

# 6. Docker Cleanup (10-50GB potential)
clean_docker() {
    if command -v docker &>/dev/null; then
        docker system prune -a --volumes -f
    fi
}

# 7. Thumbnail Cache (100-500MB)
clean_thumbnails() {
    rm -rf "$HOME/.cache/thumbnails"/*
}
```

**Acceptance Criteria:**
- [ ] All 7 cleanup functions implemented
- [ ] Each function has safety checks (command exists, directories exist)
- [ ] Docker cleanup only runs if Docker is installed
- [ ] Snap cleanup only runs if snapd is installed
- [ ] All functions respect dry-run mode
- [ ] Space savings are calculated and displayed

**Testing:**
- Test on system with APT, Snap, Flatpak, Docker installed
- Verify space calculations are accurate
- Test dry-run shows what would be deleted
- Verify no critical system files are touched

---

### Task 1.4: Update analyze.sh Cache Paths
**File:** `bin/analyze.sh`, `cmd/analyze/main.go`
**Priority:** P1 (High)
**Effort:** 2 hours

**Implementation:**
1. In `bin/analyze.sh`:
   - Change cache path from `~/Library/Caches/fub` → `~/.cache/fub`

2. In `cmd/analyze/main.go`:
   - Update `getCacheDir()` function
   - Change from `~/Library/Caches/fub` → `~/.cache/fub`
   - Test on Ubuntu (likely already works due to Go's cross-platform nature)

**Acceptance Criteria:**
- [ ] Cache directory correctly set to `~/.cache/fub`
- [ ] Cache directory is created if it doesn't exist
- [ ] Go analyzer compiles on Ubuntu
- [ ] TUI renders correctly on Ubuntu terminal
- [ ] Keyboard navigation works

**Testing:**
- Compile: `./scripts/build-analyze.sh`
- Run: `./fub analyze`
- Verify cache files are created in `~/.cache/fub/analyze_cache/`
- Test navigation, deletion features

---

### Task 1.5: Port optimize.sh - systemd Integration
**File:** `bin/optimize.sh`
**Priority:** P1 (High)
**Effort:** 1 day

**Implementation:**

Replace macOS maintenance commands:

```bash
# 1. Service Management (launchctl → systemctl)
# REMOVE: launchctl unload/load
# ADD: systemctl operations (if needed for optimization)

# 2. Desktop Database Update (lsregister → update-desktop-database)
update_desktop_database() {
    update-desktop-database ~/.local/share/applications
    update-mime-database ~/.local/share/mime
}

# 3. Locate Database Update (mdutil → updatedb)
update_locate_database() {
    sudo updatedb  # Updates mlocate database
}

# 4. Font Cache Rebuild (atsutil → fc-cache)
rebuild_font_cache() {
    fc-cache -fv
}

# 5. DNS Cache Flush
flush_dns_cache() {
    sudo systemd-resolve --flush-caches
    # OR: sudo resolvectl flush-caches
}

# 6. Memory Cache Purge
purge_memory_cache() {
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches
}

# 7. Journal Optimization
optimize_journal() {
    # Set persistent journal size limit
    sudo journalctl --vacuum-time=7d --vacuum-size=100M
}
```

Remove macOS-specific:
- `periodic daily/weekly/monthly` scripts
- `mdutil -E /` (Spotlight indexing)
- `atsutil databases -remove` (font cache)
- Touch ID sudo configuration (or replace with fprintd if desired)

**Acceptance Criteria:**
- [ ] All launchctl references removed
- [ ] systemd equivalents implemented
- [ ] DNS flush works on Ubuntu
- [ ] Font cache rebuild works
- [ ] Desktop database updates work
- [ ] No macOS-specific commands remain
- [ ] All operations have proper error handling

**Testing:**
- Run `./fub optimize` on Ubuntu 24.04
- Verify each optimization completes successfully
- Check system health metrics before/after
- Verify no errors in terminal output

---

### Task 1.6: Update common.sh - Remove macOS Functions
**File:** `lib/common.sh`
**Priority:** P1 (High)
**Effort:** 4 hours

**Implementation:**

1. **Remove macOS-specific functions:**
   - `IS_M_SERIES` detection (or replace with arch detection)
   - Any `sw_vers` usage
   - Any `defaults` command usage
   - Code signing verification functions
   - Rosetta 2 detection

2. **Update system detection:**
   ```bash
   # Replace
   detect_macos_version()

   # With
   detect_ubuntu_version() {
       lsb_release -rs  # Returns 24.04
   }

   detect_architecture() {
       uname -m  # x86_64 or aarch64
   }
   ```

3. **Update file size functions:**
   ```bash
   # macOS: stat -f%z
   # Ubuntu: stat -c%s

   get_file_size() {
       stat -c%s "$1"
   }

   get_mod_time() {
       stat -c%Y "$1"
   }
   ```

4. **Keep cross-platform functions:**
   - Logging functions (log_info, log_error, etc.)
   - Spinner functions
   - Keyboard input (read_key)
   - Color definitions
   - Menu systems

**Acceptance Criteria:**
- [ ] All macOS-specific functions removed or replaced
- [ ] System detection works on Ubuntu
- [ ] File operations use Linux stat format
- [ ] No references to macOS-specific tools
- [ ] All shared utilities still functional
- [ ] No breaking changes to dependent scripts

**Testing:**
- Source `lib/common.sh` in bash
- Call each function to verify it works
- Check no macOS commands are called

---

### Task 1.7: Update Main Entry Point
**File:** `fub` (main script)
**Priority:** P1 (High)
**Effort:** 2 hours

**Implementation:**

1. **Remove macOS checks:**
   ```bash
   # REMOVE checks like:
   # if [[ $(uname) != "Darwin" ]]; then
   #     echo "This script is for macOS only"
   #     exit 1
   # fi
   ```

2. **Add Ubuntu checks:**
   ```bash
   # ADD check for Ubuntu
   if [[ ! -f /etc/lsb-release ]]; then
       log_error "This script is designed for Ubuntu 24.04+"
       exit 1
   fi

   # Check Ubuntu version
   UBUNTU_VERSION=$(lsb_release -rs)
   if [[ $(echo "$UBUNTU_VERSION < 24.04" | bc -l) -eq 1 ]]; then
       log_warning "This script is optimized for Ubuntu 24.04+. You have $UBUNTU_VERSION."
       read -p "Continue anyway? [y/N] " response
       [[ ! $response =~ ^[Yy]$ ]] && exit 0
   fi
   ```

3. **Update help text:**
   - Change "macOS" references to "Ubuntu"
   - Update feature descriptions for Ubuntu context

4. **Keep menu system:**
   - Interactive menu should work as-is
   - Verify keyboard navigation on Ubuntu

**Acceptance Criteria:**
- [ ] macOS checks removed
- [ ] Ubuntu version detection works
- [ ] Help text updated for Ubuntu
- [ ] Menu system works on Ubuntu
- [ ] Version display updated
- [ ] Update command still works (if using GitHub releases)

**Testing:**
- Run `./fub` on Ubuntu 24.04
- Verify menu displays correctly
- Test `./fub --help`
- Test `./fub --version`

---

## Phase 2: Package Management (Week 2-3)
**Goal:** Full multi-package-manager support for app uninstallation

### Task 2.1: Create Package Manager Abstraction Layer
**File:** `lib/package_managers.sh`
**Priority:** P0 (Blocker for uninstall)
**Effort:** 2 days

**Implementation:**

Create comprehensive package manager interface:

```bash
#!/bin/bash
# lib/package_managers.sh - Multi-package-manager abstraction

# Package manager detection
detect_package_managers() {
    local managers=()
    command -v apt &>/dev/null && managers+=("apt")
    command -v snap &>/dev/null && managers+=("snap")
    command -v flatpak &>/dev/null && managers+=("flatpak")
    echo "${managers[@]}"
}

# APT Functions
scan_apt_packages() {
    dpkg -l | awk '/^ii/ {print $2 "\t" $3 "\t" $4}'
}

get_apt_package_info() {
    local pkg="$1"
    apt-cache show "$pkg" 2>/dev/null
}

uninstall_apt_package() {
    local pkg="$1"
    sudo apt-get remove --purge -y "$pkg"
}

# Snap Functions
scan_snap_packages() {
    snap list --color=never | tail -n +2 | awk '{print $1 "\t" $2 "\t" $3}'
}

get_snap_package_info() {
    local pkg="$1"
    snap info "$pkg"
}

uninstall_snap_package() {
    local pkg="$1"
    sudo snap remove "$pkg"
}

# Flatpak Functions
scan_flatpak_packages() {
    flatpak list --app --columns=application,name,version
}

get_flatpak_package_info() {
    local pkg="$1"
    flatpak info "$pkg"
}

uninstall_flatpak_package() {
    local pkg="$1"
    flatpak uninstall -y "$pkg"
}

# AppImage Detection
scan_appimage_files() {
    # Search common locations
    find ~ -maxdepth 3 -name "*.AppImage" -type f 2>/dev/null
    find ~/.local/bin -name "*.AppImage" -type f 2>/dev/null
    find ~/Applications -name "*.AppImage" -type f 2>/dev/null
}

uninstall_appimage() {
    local appimage_path="$1"
    rm "$appimage_path"
}

# Unified package listing
list_all_packages() {
    echo "=== APT Packages ==="
    scan_apt_packages

    echo -e "\n=== Snap Packages ==="
    scan_snap_packages

    echo -e "\n=== Flatpak Packages ==="
    scan_flatpak_packages

    echo -e "\n=== AppImage Files ==="
    scan_appimage_files
}

# Get package type
get_package_type() {
    local pkg="$1"

    if dpkg -l "$pkg" &>/dev/null; then
        echo "apt"
    elif snap list "$pkg" &>/dev/null; then
        echo "snap"
    elif flatpak list | grep -q "$pkg"; then
        echo "flatpak"
    elif [[ -f "$pkg" ]] && [[ "$pkg" == *.AppImage ]]; then
        echo "appimage"
    else
        echo "unknown"
    fi
}

# Unified uninstall
uninstall_package() {
    local pkg="$1"
    local type="${2:-$(get_package_type "$pkg")}"

    case "$type" in
        apt)
            uninstall_apt_package "$pkg"
            ;;
        snap)
            uninstall_snap_package "$pkg"
            ;;
        flatpak)
            uninstall_flatpak_package "$pkg"
            ;;
        appimage)
            uninstall_appimage "$pkg"
            ;;
        *)
            log_error "Unknown package type for: $pkg"
            return 1
            ;;
    esac
}
```

**Acceptance Criteria:**
- [ ] All 4 package managers supported
- [ ] Detection functions work correctly
- [ ] Info retrieval works for each type
- [ ] Uninstall functions work for each type
- [ ] Error handling for missing package managers
- [ ] Unified interface for all package types

**Testing:**
- Install test packages from each manager
- Verify detection works
- Test uninstall for each type
- Verify cleanup after uninstall

---

### Task 2.2: Create .desktop File Parser
**File:** `lib/desktop_parser.sh`
**Priority:** P0 (Blocker for uninstall)
**Effort:** 1 day

**Implementation:**

```bash
#!/bin/bash
# lib/desktop_parser.sh - Parse .desktop files for app metadata

# Find all .desktop files
find_desktop_files() {
    find /usr/share/applications ~/.local/share/applications -name "*.desktop" 2>/dev/null
}

# Parse .desktop file
parse_desktop_file() {
    local desktop_file="$1"
    local key="$2"  # Name, Exec, Icon, Comment, etc.

    grep "^${key}=" "$desktop_file" | head -1 | cut -d= -f2-
}

# Get app name from .desktop file
get_desktop_app_name() {
    local desktop_file="$1"
    parse_desktop_file "$desktop_file" "Name"
}

# Get app executable
get_desktop_app_exec() {
    local desktop_file="$1"
    local exec_line
    exec_line=$(parse_desktop_file "$desktop_file" "Exec")
    # Remove field codes (%U, %F, etc.)
    echo "$exec_line" | sed 's/ %[A-Za-z]//g'
}

# Get app icon
get_desktop_app_icon() {
    local desktop_file="$1"
    parse_desktop_file "$desktop_file" "Icon"
}

# Get app comment/description
get_desktop_app_comment() {
    local desktop_file="$1"
    parse_desktop_file "$desktop_file" "Comment"
}

# Find .desktop file by app name
find_desktop_by_name() {
    local app_name="$1"
    find_desktop_files | while read -r desktop_file; do
        local name
        name=$(get_desktop_app_name "$desktop_file")
        if [[ "$name" == *"$app_name"* ]]; then
            echo "$desktop_file"
        fi
    done | head -1
}

# Get associated package for .desktop file
get_desktop_package() {
    local desktop_file="$1"

    # Try dpkg first
    if dpkg -S "$desktop_file" 2>/dev/null | cut -d: -f1; then
        return
    fi

    # Try snap
    if [[ "$desktop_file" == */snap/* ]]; then
        echo "$desktop_file" | grep -oP 'snap/\K[^/]+'
        return
    fi

    # Try flatpak
    if [[ "$desktop_file" == */flatpak/* ]]; then
        echo "$desktop_file" | grep -oP 'flatpak/[^/]+/\K[^/]+'
        return
    fi

    echo "unknown"
}
```

**Acceptance Criteria:**
- [ ] Can find all .desktop files
- [ ] Can parse all standard .desktop keys
- [ ] Can associate .desktop file with package
- [ ] Works for APT, Snap, and Flatpak installed apps
- [ ] Handles malformed .desktop files gracefully

**Testing:**
- Test with APT-installed app (e.g., Firefox)
- Test with Snap-installed app (e.g., Chromium)
- Test with Flatpak-installed app
- Verify all metadata is extracted correctly

---

### Task 2.3: Port uninstall.sh - Multi-Package-Manager Support
**File:** `bin/uninstall.sh`
**Priority:** P0 (Blocker)
**Effort:** 3 days

**Implementation:**

Major refactor required:

1. **Source new libraries:**
   ```bash
   source "$(dirname "$0")/../lib/package_managers.sh"
   source "$(dirname "$0")/../lib/desktop_parser.sh"
   ```

2. **New package scanning flow:**
   ```bash
   scan_all_applications() {
       # Scan each package manager
       local apt_pkgs snap_pkgs flatpak_pkgs appimages

       apt_pkgs=$(scan_apt_packages)
       snap_pkgs=$(scan_snap_packages)
       flatpak_pkgs=$(scan_flatpak_packages)
       appimages=$(scan_appimage_files)

       # Combine and format for UI
       # Return: package_name|type|version|size
   }
   ```

3. **Config file discovery:**
   ```bash
   find_app_config_files() {
       local app_name="$1"
       local pkg_type="$2"

       case "$pkg_type" in
           apt|unknown)
               # XDG standard locations
               find ~/.config -iname "*${app_name}*" 2>/dev/null
               find ~/.local/share -iname "*${app_name}*" 2>/dev/null
               find ~/.cache -iname "*${app_name}*" 2>/dev/null
               ;;
           snap)
               # Snap-specific locations
               find ~/snap -name "$app_name" 2>/dev/null
               ;;
           flatpak)
               # Flatpak-specific locations
               find ~/.var/app -iname "*${app_name}*" 2>/dev/null
               ;;
           appimage)
               # No standard config location
               find ~/.config -iname "*${app_name}*" 2>/dev/null
               ;;
       esac
   }
   ```

4. **Update UI for package types:**
   - Show package type badge in app selector
   - Group by package manager
   - Show different icons/colors per type

5. **Remove macOS-specific:**
   - Bundle ID matching (replaced with package name matching)
   - `/Applications` scanning (replaced with package manager queries)
   - Code signature verification
   - All 22 macOS app location scanning

**Acceptance Criteria:**
- [ ] All 4 package managers detected and scanned
- [ ] Apps from all sources shown in UI
- [ ] Uninstall works for each package type
- [ ] Config file discovery works for each type
- [ ] Batch uninstall works
- [ ] Whitelist for protected packages works
- [ ] Dry-run mode works
- [ ] No macOS-specific code remains

**Testing:**
- Install test apps from each package manager
- Verify all detected in UI
- Test uninstall for each type
- Verify config files are found and removed
- Test batch uninstall with mixed types

---

### Task 2.4: Update App Protection Lists
**File:** `lib/common.sh` or new `lib/protected_packages.sh`
**Priority:** P1 (High)
**Effort:** 2 hours

**Implementation:**

Replace macOS bundle IDs with Ubuntu package names:

```bash
# System-critical packages (NEVER uninstall)
SYSTEM_CRITICAL_PACKAGES=(
    "ubuntu-desktop"
    "gnome-shell"
    "systemd"
    "linux-generic"
    "linux-image-generic"
    "network-manager"
    "gdm3"
    "firefox"  # Default browser
    "nautilus"  # Default file manager
    "gnome-terminal"
    "bash"
    "sudo"
    "apt"
)

# Data-protected packages (warn before uninstall)
DATA_PROTECTED_PACKAGES=(
    "code"  # VS Code
    "sublime-text"
    "jetbrains-*"
    "vim"
    "emacs"
    "keepassxc"
    "bitwarden"
    "1password"
    "brave-browser"
    "google-chrome-stable"
    "thunderbird"
)

# Network tools (protected, cannot be disabled)
NETWORK_CRITICAL=(
    "network-manager"
    "wpasupplicant"
)
```

**Acceptance Criteria:**
- [ ] Critical packages defined for Ubuntu
- [ ] Data-protected packages defined
- [ ] Packages cannot be uninstalled if in critical list
- [ ] Warning shown for data-protected packages
- [ ] Pattern matching works (e.g., jetbrains-*)

---

## Phase 3: Polish & Testing (Week 4)
**Goal:** Production-ready Ubuntu release

### Task 3.1: Comprehensive Testing - Fresh Ubuntu Install
**Priority:** P0 (Blocker)
**Effort:** 1 day

**Test Environment:** Fresh Ubuntu 24.04 VM

**Test Cases:**
1. **Clean mode:**
   - [ ] Basic cache cleanup
   - [ ] Journal log cleanup
   - [ ] Old kernel cleanup
   - [ ] Thumbnail cleanup
   - [ ] Dry-run mode
   - [ ] Whitelist protection

2. **Analyze mode:**
   - [ ] Disk analyzer launches
   - [ ] TUI renders correctly
   - [ ] Navigation works
   - [ ] Cache persistence
   - [ ] File deletion works

3. **Optimize mode:**
   - [ ] All optimizations complete successfully
   - [ ] No errors in output
   - [ ] System remains stable after

4. **Update mode:**
   - [ ] Self-update works (if implemented)
   - [ ] Version detection correct

**Success Criteria:**
- All tests pass on fresh Ubuntu 24.04
- No errors in any mode
- Help text displays correctly
- All features work as expected

---

### Task 3.2: Testing - Development Workstation
**Priority:** P0 (Blocker)
**Effort:** 1 day

**Test Environment:** Ubuntu 24.04 with heavy development setup

**Pre-requisites:**
- Install: Node.js, Python, Rust, Go, Docker
- Install: VS Code, Chromium, Firefox
- Generate caches by using the system

**Test Cases:**
1. **Clean mode - Developer caches:**
   - [ ] NPM cache detected and cleaned
   - [ ] Pip cache detected and cleaned
   - [ ] Cargo cache detected and cleaned
   - [ ] Go cache detected and cleaned
   - [ ] Docker cleanup works
   - [ ] Whitelist protects important caches

2. **Uninstall mode:**
   - [ ] All dev tools detected
   - [ ] Can uninstall safely
   - [ ] Config files found
   - [ ] No critical tools uninstalled accidentally

**Success Criteria:**
- Large space savings (10GB+)
- No critical development tools affected
- System remains fully functional

---

### Task 3.3: Testing - Mixed Package Managers
**Priority:** P0 (Blocker)
**Effort:** 1 day

**Test Environment:** Ubuntu 24.04 with all package managers

**Setup:**
```bash
# Install test apps from each manager
sudo apt install gimp          # APT
sudo snap install vlc          # Snap
flatpak install flathub org.gimp.GIMP  # Flatpak
# Download test AppImage
```

**Test Cases:**
1. **Package detection:**
   - [ ] All 4 package types detected
   - [ ] Correct package info displayed
   - [ ] Package types labeled correctly

2. **Uninstall:**
   - [ ] APT package uninstalls completely
   - [ ] Snap package uninstalls completely
   - [ ] Flatpak package uninstalls completely
   - [ ] AppImage deletes correctly
   - [ ] Config files cleaned for each

3. **Batch uninstall:**
   - [ ] Can select mixed package types
   - [ ] All uninstall correctly in batch
   - [ ] No conflicts

**Success Criteria:**
- All package types work seamlessly
- No errors during mixed uninstalls
- Config cleanup works for all types

---

### Task 3.4: Update Documentation
**Files:** `README.md`, `CLAUDE.md`, `INSTALL.md`
**Priority:** P1 (High)
**Effort:** 4 hours

**Implementation:**

1. **Update README.md:**
   - Change title to reflect Ubuntu support
   - Update installation instructions for Ubuntu
   - Update feature descriptions for Ubuntu context
   - Add Ubuntu-specific features (kernel cleanup, snap management, etc.)
   - Update screenshots if needed
   - Change all macOS references to Ubuntu

2. **Update CLAUDE.md:**
   - Update project overview
   - Document Ubuntu-specific implementations
   - Update directory structure (new lib files)
   - Update command examples for Ubuntu
   - Document new package manager abstraction
   - Update testing instructions for Ubuntu

3. **Create/Update INSTALL.md:**
   ```bash
   # Installation for Ubuntu 24.04+

   # Prerequisites
   sudo apt update
   sudo apt install -y curl git

   # Install
   curl -fsSL https://raw.githubusercontent.com/user/fub/main/install.sh | bash

   # Manual install
   git clone https://github.com/user/fub.git
   cd fub
   sudo ln -s $(pwd)/fub /usr/local/bin/fub
   ```

**Acceptance Criteria:**
- [ ] All documentation updated for Ubuntu
- [ ] No macOS references remain (except in porting notes)
- [ ] Installation instructions work on Ubuntu 24.04
- [ ] Feature list accurate
- [ ] Examples use Ubuntu paths

---

### Task 3.5: Update Build Scripts
**Files:** `scripts/*.sh`, `Makefile` (if exists)
**Priority:** P2 (Medium)
**Effort:** 2 hours

**Implementation:**

1. **Update build-analyze.sh:**
   ```bash
   # Ensure Go is available
   if ! command -v go &>/dev/null; then
       echo "Installing Go..."
       sudo apt install -y golang-go
   fi

   # Build for Linux
   cd cmd/analyze
   go build -o ../../bin/fub-analyze
   ```

2. **Update format.sh:**
   ```bash
   # Install shfmt if needed
   if ! command -v shfmt &>/dev/null; then
       echo "Installing shfmt..."
       sudo apt install -y shfmt
   fi
   ```

3. **Update check.sh:**
   ```bash
   # Install shellcheck if needed
   if ! command -v shellcheck &>/dev/null; then
       echo "Installing shellcheck..."
       sudo apt install -y shellcheck
   fi
   ```

**Acceptance Criteria:**
- [ ] Build scripts work on Ubuntu
- [ ] Dependencies auto-install if missing
- [ ] All scripts use Ubuntu package manager (apt)

---

### Task 3.6: Create Installation Script
**File:** `install.sh`
**Priority:** P1 (High)
**Effort:** 2 hours

**Implementation:**

```bash
#!/bin/bash
# install.sh - Install Fub on Ubuntu

set -euo pipefail

# Check Ubuntu
if [[ ! -f /etc/lsb-release ]]; then
    echo "Error: This installer is for Ubuntu only"
    exit 1
fi

# Check version
UBUNTU_VERSION=$(lsb_release -rs)
if [[ $(echo "$UBUNTU_VERSION < 24.04" | bc -l) -eq 1 ]]; then
    echo "Warning: Fub is designed for Ubuntu 24.04+. You have $UBUNTU_VERSION."
    read -p "Continue anyway? [y/N] " response
    [[ ! $response =~ ^[Yy]$ ]] && exit 0
fi

# Install location
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/share/fub}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

# Download or clone
echo "Installing Fub..."
if [[ -d "$INSTALL_DIR" ]]; then
    echo "Updating existing installation..."
    cd "$INSTALL_DIR"
    git pull
else
    git clone https://github.com/user/fub.git "$INSTALL_DIR"
fi

# Build analyzer
cd "$INSTALL_DIR"
./scripts/build-analyze.sh

# Create symlink
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/fub" "$BIN_DIR/fub"

# Add to PATH if needed
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "Adding $BIN_DIR to PATH..."
    echo "export PATH=\"\$PATH:$BIN_DIR\"" >> ~/.bashrc
    echo "Run: source ~/.bashrc"
fi

echo "✓ Fub installed successfully!"
echo "Run: fub"
```

**Acceptance Criteria:**
- [ ] Detects Ubuntu version
- [ ] Clones repository
- [ ] Builds analyzer
- [ ] Creates symlink
- [ ] Adds to PATH if needed
- [ ] Can be run with curl | bash

---

### Task 3.7: Edge Case Handling
**Priority:** P2 (Medium)
**Effort:** 1 day

**Implementation:**

Add robust error handling:

1. **Permission errors:**
   ```bash
   # Check sudo access before operations
   check_sudo() {
       if ! sudo -n true 2>/dev/null; then
           log_info "Some operations require sudo access"
           sudo -v
       fi
   }
   ```

2. **Missing package managers:**
   ```bash
   # Gracefully handle missing snap/flatpak
   if ! command -v snap &>/dev/null; then
       log_warning "Snap not installed, skipping snap packages"
   fi
   ```

3. **Disk full scenarios:**
   ```bash
   # Check free space before operations
   check_free_space() {
       local free_space
       free_space=$(df -B1 / | tail -1 | awk '{print $4}')
       if [[ $free_space -lt 1073741824 ]]; then  # Less than 1GB
           log_error "Less than 1GB free space available"
           exit 1
       fi
   }
   ```

4. **Interrupted operations:**
   ```bash
   # Cleanup on exit
   trap cleanup EXIT INT TERM
   cleanup() {
       # Clean up temporary files
       # Restore system state if needed
   }
   ```

**Acceptance Criteria:**
- [ ] Permission errors handled gracefully
- [ ] Missing package managers don't cause crashes
- [ ] Low disk space detected and warned
- [ ] Interrupted operations clean up properly
- [ ] All errors logged appropriately

---

## Optional Enhancements (Future)

### Task 4.1: Fingerprint Authentication Support
**File:** `bin/touchid.sh` → `bin/fingerprint.sh`
**Priority:** P3 (Nice to have)
**Effort:** 4 hours

**Implementation:**
- Replace Touch ID with fprintd (fingerprint authentication)
- Configure PAM for fingerprint sudo authentication

---

### Task 4.2: Desktop Environment Detection
**File:** `lib/de_detection.sh`
**Priority:** P3 (Nice to have)
**Effort:** 2 hours

**Implementation:**
- Detect GNOME, KDE, XFCE, etc.
- Adjust cleanup paths based on DE
- Handle DE-specific caches

---

### Task 4.3: Snap Store Integration
**File:** `bin/uninstall.sh`
**Priority:** P3 (Nice to have)
**Effort:** 2 hours

**Implementation:**
- Show snap ratings/downloads
- Link to Ubuntu Software app for reinstall

---

## Success Metrics

**Phase 1 Complete When:**
- [x] Basic cleaning works on Ubuntu 24.04
- [x] Disk analyzer works
- [x] System optimization works
- [x] No macOS-specific code in core features

**Phase 2 Complete When:**
- [x] All 4 package managers supported
- [x] App uninstallation works for all types
- [x] Config file cleanup works
- [x] Multi-select batch uninstall works

**Phase 3 Complete When:**
- [x] All tests pass on fresh Ubuntu
- [x] All tests pass on dev workstation
- [x] Documentation complete
- [x] Installation script works
- [x] Ready for public release

---

## Timeline Summary

| Phase | Duration | Key Deliverables |
|-------|----------|------------------|
| Phase 1 | Week 1 | Clean, Analyze, Optimize working |
| Phase 2 | Week 2-3 | Full uninstall with 4 package managers |
| Phase 3 | Week 4 | Testing, docs, polish, release |
| **Total** | **3-4 weeks** | Production-ready Ubuntu version |

---

## Notes

- **Backward compatibility:** Not needed (Ubuntu-only fork)
- **Testing priority:** Focus on Ubuntu 24.04 LTS (primary target)
- **Go version:** 1.21+ required for Bubble Tea analyzer
- **Bash version:** Ubuntu has Bash 5.x (can use modern features!)
- **Dependencies:** Minimize external deps, use standard Ubuntu tools

---

## References

- `UBUNTU_PORT_RESEARCH.json` - Complete technical details
- `UBUNTU_PORT_SUMMARY.md` - Research summary
- `QUICK_REFERENCE.md` - Code examples and cheat sheets

---

**Last Updated:** 2025-11-19
**Status:** Ready for implementation
**Next Action:** Begin Task 1.1 (Create Ubuntu Path Constants)
