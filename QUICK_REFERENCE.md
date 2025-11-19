# Ubuntu Port Quick Reference Guide

## 🗂️ Path Mappings Cheat Sheet

### User Directories
```bash
# Caches
~/Library/Caches/*                    →  ~/.cache/*

# Configuration
~/Library/Preferences/*               →  ~/.config/*

# Application Data
~/Library/Application Support/*       →  ~/.local/share/*

# Application State/Logs
~/Library/Saved Application State/*   →  ~/.local/state/*
~/Library/Logs/*                      →  ~/.local/state/*

# Containers (Sandboxed Apps)
~/Library/Containers/*                →  ~/.var/app/* (Flatpak)
                                      →  ~/snap/* (Snap)

# Trash
~/.Trash/*                            →  ~/.local/share/Trash/*
```

### System Directories
```bash
# System Caches
/Library/Caches/*                     →  /var/cache/*

# System Logs
/Library/Logs/*                       →  /var/log/*
                                      →  journalctl (systemd journal)

# System Configuration
/Library/Preferences/*                →  /etc/*

# Applications
/Applications/*                       →  /usr/bin, /usr/share/applications
~/Applications/*                      →  ~/.local/bin, ~/.local/share/applications

# Launch Agents/Daemons
~/Library/LaunchAgents/*              →  ~/.config/systemd/user/*
/Library/LaunchAgents/*               →  /etc/systemd/system/*
/Library/LaunchDaemons/*              →  /lib/systemd/system/*
```

---

## 📦 Package Manager Comparison

| Feature | macOS Homebrew | Ubuntu APT | Ubuntu Snap | Ubuntu Flatpak | Ubuntu AppImage |
|---------|----------------|------------|-------------|----------------|-----------------|
| **Install** | `brew install` | `apt install` | `snap install` | `flatpak install` | `chmod +x; ./file.AppImage` |
| **Uninstall** | `brew uninstall` | `apt remove --purge` | `snap remove` | `flatpak uninstall` | `rm file.AppImage` |
| **List** | `brew list` | `dpkg -l` / `apt list --installed` | `snap list` | `flatpak list` | Find `.AppImage` files |
| **Update** | `brew upgrade` | `apt upgrade` | `snap refresh` | `flatpak update` | Manual download |
| **App Location** | `/usr/local/Cellar` | `/usr/bin`, `/usr/lib` | `/snap`, `~/snap` | `/var/lib/flatpak` | User directories |
| **Config Location** | App-specific | `~/.config`, `/etc` | `~/snap/*/common` | `~/.var/app/*` | `~/.config` |
| **Cache Location** | `~/Library/Caches` | `~/.cache` | `~/snap/*/common/.cache` | `~/.var/app/*/cache` | `~/.cache` |

---

## ⌨️ Command Equivalents

### File Operations
```bash
# Get file size
macOS:  stat -f%z file
Ubuntu: stat -c%s file

# Get modification time
macOS:  stat -f%m file
Ubuntu: stat -c%Y file

# Disk usage (compatible)
macOS:  du -sh directory
Ubuntu: du -sh directory
```

### System Management
```bash
# Service management
macOS:  launchctl load/unload plist
Ubuntu: systemctl start/stop/enable/disable service

# DNS cache flush
macOS:  dscacheutil -flushcache && killall -HUP mDNSResponder
Ubuntu: systemd-resolve --flush-caches
        # OR resolvectl flush-caches

# Memory purge
macOS:  purge
Ubuntu: sync && echo 3 | sudo tee /proc/sys/vm/drop_caches

# View logs
macOS:  log show / Console.app
Ubuntu: journalctl
```

### Search & Indexing
```bash
# File search
macOS:  mdfind "query"
Ubuntu: locate "pattern"
        # OR find / -name "pattern"

# Update search index
macOS:  mdutil -E /
Ubuntu: updatedb
```

### Application Management
```bash
# Rebuild app database
macOS:  /System/Library/.../lsregister -kill -r -domain all
Ubuntu: update-desktop-database ~/.local/share/applications

# Get installed apps
macOS:  find /Applications -name "*.app" -maxdepth 1
Ubuntu: find /usr/share/applications ~/.local/share/applications -name "*.desktop"
```

### Configuration
```bash
# Read/write preferences
macOS:  defaults read/write domain key value
Ubuntu: gsettings get/set schema key value
        # OR dconf read/write /path/to/key
```

---

## 🧹 Cleanup Commands

### Package Cache
```bash
# macOS
brew cleanup -s --prune=all

# Ubuntu
apt clean                    # Clear all package cache
apt autoclean               # Clear only obsolete packages
apt autoremove --purge      # Remove orphaned packages
snap set system refresh.retain=2  # Keep only 2 snap revisions
flatpak uninstall --unused  # Remove unused Flatpak runtimes
```

### System Logs
```bash
# macOS
sudo find /var/log -name "*.log" -delete
sudo find /Library/Logs -name "*.log" -delete

# Ubuntu
journalctl --vacuum-time=7d      # Keep 7 days
journalctl --vacuum-size=100M    # Max 100MB
sudo find /var/log -name "*.log" -delete
sudo find /var/log -name "*.gz" -delete
```

### User Caches
```bash
# macOS
rm -rf ~/Library/Caches/*

# Ubuntu
rm -rf ~/.cache/*
rm -rf ~/.cache/thumbnails/*
```

### Developer Caches (similar on both)
```bash
npm cache clean --force
cargo cache --autoclean
pip cache purge
go clean -cache -modcache
docker system prune -a --volumes
```

### Old Kernels (Ubuntu only)
```bash
apt autoremove --purge    # Auto-remove old kernels
# OR manually:
dpkg -l | grep linux-image
apt remove --purge linux-image-VERSION-generic
```

---

## 🔍 Detection Scripts

### Detect Installed Apps

**macOS:**
```bash
find /Applications ~/Applications -name "*.app" -maxdepth 1 | while read app; do
    bundle_id=$(defaults read "$app/Contents/Info.plist" CFBundleIdentifier)
    app_name=$(basename "$app" .app)
    echo "$app_name ($bundle_id)"
done
```

**Ubuntu:**
```bash
# APT packages
dpkg -l | awk '/^ii/ {print $2}'

# Snap packages
snap list

# Flatpak apps
flatpak list --app

# AppImages
find ~ -name "*.AppImage" -type f

# Parse .desktop files
find /usr/share/applications ~/.local/share/applications -name "*.desktop" | while read desktop; do
    name=$(grep "^Name=" "$desktop" | head -1 | cut -d= -f2)
    echo "$name"
done
```

### Get App Metadata

**macOS:**
```bash
app="/Applications/Safari.app"
defaults read "$app/Contents/Info.plist" CFBundleIdentifier
defaults read "$app/Contents/Info.plist" CFBundleVersion
mdls -name kMDItemLastUsedDate "$app"
```

**Ubuntu:**
```bash
# From .desktop file
desktop="/usr/share/applications/firefox.desktop"
grep "^Name=" "$desktop" | cut -d= -f2
grep "^Exec=" "$desktop" | cut -d= -f2
grep "^Icon=" "$desktop" | cut -d= -f2

# From package manager
dpkg -l firefox | grep ^ii
snap info firefox
flatpak info org.mozilla.firefox

# Last access time (less reliable)
stat -c%X "$desktop"
```

---

## 🛡️ Safety Checks

### Protected System Paths

**macOS:**
```bash
# Never delete
/System/*
/Library/Extensions/*
/bin, /sbin, /usr/bin, /usr/sbin
```

**Ubuntu:**
```bash
# Never delete
/bin, /sbin, /usr/bin, /usr/sbin
/lib, /lib64, /usr/lib
/etc (system config)
/boot (kernels)
/dev, /proc, /sys (virtual filesystems)
```

### Verify Before Deletion
```bash
# macOS
validate_path_for_deletion() {
    [[ "$path" == / ]] && return 1
    [[ "$path" =~ ^/System ]] && return 1
    return 0
}

# Ubuntu (similar)
validate_path_for_deletion() {
    [[ "$path" == / ]] && return 1
    [[ "$path" =~ ^/(bin|sbin|lib|boot|dev|proc|sys) ]] && return 1
    return 0
}
```

---

## 🎯 Ubuntu-Specific Additions

### Journal Log Management
```bash
# Check journal size
journalctl --disk-usage

# Configure limits in /etc/systemd/journald.conf
SystemMaxUse=100M         # Max disk space
SystemMaxFileSize=10M     # Max file size
MaxRetentionSec=1week     # Max age

# Apply changes
systemctl restart systemd-journald
```

### Snap Management
```bash
# List all revisions
snap list --all

# Remove specific revision
snap remove --revision=N package

# Set retention policy (keep 2 versions)
snap set system refresh.retain=2

# Disable snap (if desired)
systemctl disable snapd.service
systemctl disable snapd.socket
```

### Docker Cleanup
```bash
# Remove all unused
docker system prune -a --volumes

# Specific cleanup
docker image prune -a      # Unused images
docker container prune     # Stopped containers
docker volume prune        # Unused volumes
docker network prune       # Unused networks
```

### Desktop Database Update
```bash
# Update .desktop file cache
update-desktop-database ~/.local/share/applications
update-desktop-database /usr/share/applications

# Update MIME types
update-mime-database ~/.local/share/mime
```

---

## 📊 Disk Analysis Tools

### macOS Fub Analyzer
```bash
# Built-in Go Bubble Tea TUI
./fub analyze
```

### Ubuntu Options
```bash
# 1. Keep Fub's analyzer (works on Linux)
./fub analyze

# 2. Use ncdu (popular alternative)
apt install ncdu
ncdu ~

# 3. Use baobab (GUI)
apt install baobab
baobab

# 4. Use du with sorting
du -sh ~/* | sort -hr | head -20
```

---

## 🔧 Environment Variables

### XDG Base Directories
```bash
# Set in ~/.profile or ~/.bashrc
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_RUNTIME_DIR="/run/user/$UID"

# Use with fallback
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
```

---

## 📝 Code Examples

### Safe File Deletion (Both Platforms)
```bash
safe_delete() {
    local path="$1"

    # Validate
    [[ -z "$path" ]] && return 1
    [[ ! -e "$path" ]] && return 0

    # Check if system path
    case "$path" in
        /|/bin|/sbin|/usr|/lib|/boot|/dev|/proc|/sys)
            echo "Refusing to delete system path: $path" >&2
            return 1
            ;;
    esac

    # Calculate size before deletion
    local size=$(du -sh "$path" | cut -f1)

    # Delete
    if rm -rf "$path" 2>/dev/null; then
        echo "Deleted $path ($size)"
        return 0
    else
        echo "Failed to delete $path" >&2
        return 1
    fi
}
```

### Multi-Package-Manager Detection
```bash
detect_package_manager() {
    local app_name="$1"

    # Check APT
    if dpkg -l "$app_name" 2>/dev/null | grep -q ^ii; then
        echo "apt:$app_name"
        return 0
    fi

    # Check Snap
    if snap list "$app_name" 2>/dev/null | grep -q "$app_name"; then
        echo "snap:$app_name"
        return 0
    fi

    # Check Flatpak
    if flatpak list --app | grep -q "$app_name"; then
        echo "flatpak:$app_name"
        return 0
    fi

    # Check AppImage
    if find ~ -name "$app_name*.AppImage" -type f | head -1; then
        echo "appimage:$app_name"
        return 0
    fi

    return 1
}
```

---

## 🚀 Quick Start Porting Guide

1. **Update path constants**
   ```bash
   # In lib/common.sh or new lib/paths_ubuntu.sh
   readonly CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
   readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
   readonly DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
   readonly STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
   ```

2. **Replace macOS commands**
   ```bash
   # Find all instances
   grep -r "mdfind\|tmutil\|launchctl\|defaults\|lsregister" bin/ lib/

   # Replace with Ubuntu equivalents
   sed -i 's/launchctl/systemctl/g' bin/optimize.sh
   ```

3. **Add Ubuntu cleanup targets**
   ```bash
   # In bin/clean.sh
   safe_clean() {
       # Add journal cleanup
       journalctl --vacuum-time=7d --vacuum-size=100M

       # Add apt cleanup
       apt clean && apt autoclean && apt autoremove --purge

       # Add snap cleanup
       snap set system refresh.retain=2
   }
   ```

4. **Implement package detection**
   ```bash
   # In new lib/package_managers.sh
   scan_all_packages() {
       dpkg -l | awk '/^ii/ {print $2}' > /tmp/apt_packages
       snap list > /tmp/snap_packages
       flatpak list --app > /tmp/flatpak_packages
       find ~ -name "*.AppImage" > /tmp/appimage_files
   }
   ```

5. **Test on Ubuntu 24.04**
   ```bash
   # Run in VM or container
   docker run -it --rm ubuntu:24.04 bash
   # Install and test
   ```

---

**Last Updated:** 2025-11-19
**Target Platform:** Ubuntu 24.04 LTS
