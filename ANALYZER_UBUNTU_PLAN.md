# Analyzer Ubuntu Optimization Plan

## Current State Analysis

### ✅ Already Working
- Basic directory scanning (platform-independent)
- Size calculation via `du` command (works on both platforms)
- Cache system using ~/.cache/fub (already updated)
- File tree traversal and deletion
- Progress bars and TUI interface

### ❌ macOS-Specific Code Found

#### 1. **Overview Directories** (main.go:188-210)
**Current (macOS):**
```go
entries = append(entries,
    dirEntry{Name: "Home (~)", Path: home, IsDir: true, Size: -1},
    dirEntry{Name: "Library (~/Library)", Path: filepath.Join(home, "Library"), ...},
    dirEntry{Name: "Applications", Path: "/Applications", ...},
    dirEntry{Name: "System Library", Path: "/Library", ...},
)
```

**Problem:** Shows macOS-specific directories that don't exist on Ubuntu.

#### 2. **Spotlight Integration** (scanner.go:288-300)
**Current:** Uses `mdfind` (macOS Spotlight) for fast large file discovery.
```go
cmd := exec.CommandContext(ctx, "mdfind", "-onlyin", root, query)
```

**Problem:** `mdfind` doesn't exist on Ubuntu, silently falls back to slower method.

#### 3. **Skip Directories** (constants.go)
**Has macOS entries:**
- `"Application Scripts": true`
- `"Saved Application State": true`
- `"Mobile Documents": true` (iCloud)
- `.Spotlight-V100`, `.fseventsd`, `.DocumentRevisions-V100`

**Missing Ubuntu entries:**
- Snap directories: `/snap`, `~/snap`
- Flatpak: `~/.var/app`, `/var/lib/flatpak`
- APT cache: `/var/cache/apt`
- System: `/proc`, `/sys`, `/run`, `/dev`

---

## 📋 Proposed Ubuntu Enhancements

### Priority 1: Core Functionality

#### 1.1 **Ubuntu Overview Directories**
Replace macOS directories with Ubuntu-relevant locations:

**High Priority (Always Show):**
- `Home (~)` - User home directory
- `Downloads (~/Downloads)` - Often largest user directory
- `Documents (~/Documents)` - User documents
- `Cache (~/.cache)` - User application caches (can be huge)
- `Local Data (~/.local/share)` - User application data
- `Trash (~/.local/share/Trash)` - Deleted files taking space

**Medium Priority (Show if exist/large):**
- `/var` - System variable data (logs, cache, apt packages)
- `/usr` - System applications and libraries
- `/opt` - Optional third-party software
- `/tmp` - Temporary files
- `/snap` - Snap packages (if snapd installed)
- `Docker (if exists)` - Docker images/containers

**Low Priority (Advanced users):**
- `/home` - All user directories (if root/multiple users)
- `/var/log` - System logs
- `/var/cache` - System caches

#### 1.2 **Ubuntu Fast File Discovery**
Replace `mdfind` with Ubuntu alternatives:

**Option A: Use `locate` (if mlocate/plocate installed)**
```bash
locate -i --regex ".*" --size-range 100M- /path
```
- Fast (uses index)
- Requires `updatedb` to be current
- Not always installed

**Option B: Optimized `find` with size filters**
```bash
find /path -type f -size +100M -printf "%s %p\n" 2>/dev/null
```
- Always available
- Slower than locate but faster than full tree walk
- Can run in parallel with main scan

**Option C: Hybrid approach (Recommended)**
1. Try `locate` first (if available and DB recent)
2. Fall back to optimized `find`
3. Fall back to existing tree walk

#### 1.3 **Ubuntu-Specific Skip Directories**

**Add to foldDirs:**
```go
// Ubuntu/Linux system directories
".gvfs":              true, // GNOME virtual filesystem
".dbus":              true, // D-Bus session data
".thumbnails":        true, // Old thumbnail cache
"thumbnails":         true, // In ~/.cache/thumbnails
".mozilla":           true, // Firefox (often huge)
".thunderbird":       true, // Thunderbird email
".wine":              true, // Wine Windows emulator

// Package managers
"snap":               true, // User snap data (in ~)
".var":               true, // Flatpak app data

// Developer tools (additional to existing)
".rustup/toolchains": true, // Rust toolchains
".sdkman/candidates": true, // SDK manager
".nvm/versions":      true, // Node Version Manager

// Databases
".postgresql":        true,
".redis":            true,
```

**Add to skipSystemDirs:**
```go
// Linux system directories (in addition to existing)
"proc":    true, // Pseudo-filesystem
"sys":     true, // Kernel interface
"run":     true, // Runtime data
"dev":     true, // Device files (already exists)
"boot":    true, // Kernel/bootloader
"lost+found": true, // ext4 recovery
"snap":    true, // Snap mounts (in /)
"media":   true, // Removable media
"mnt":     true, // Mount points
"srv":     true, // Service data
```

### Priority 2: Enhanced Features

#### 2.1 **Package Manager Integration**
Show package-related storage in overview:

```go
dirEntry{Name: "APT Packages (/var/cache/apt)", Path: "/var/cache/apt", ...}
dirEntry{Name: "Snap Packages (/var/lib/snapd)", Path: "/var/lib/snapd", ...}
dirEntry{Name: "Flatpak Apps (~/.var/app)", Path: "~/.var/app", ...}
```

#### 2.2 **Docker Integration**
Detect and show Docker usage:

```go
if _, err := os.Stat("/var/lib/docker"); err == nil {
    // Docker is installed
    entries = append(entries,
        dirEntry{Name: "Docker (/var/lib/docker)", Path: "/var/lib/docker", ...}
    )
}
```

#### 2.3 **Trash Detection**
Highlight trash that can be emptied:

```go
trashPath := filepath.Join(home, ".local/share/Trash/files")
if stat, err := os.Stat(trashPath); err == nil && stat.IsDir() {
    entries = append(entries,
        dirEntry{Name: "Trash", Path: trashPath, ...}
    )
}
```

### Priority 3: UI/UX Improvements

#### 3.1 **Platform-Specific Help Text**
Update help messages for Ubuntu context:

**Current (macOS):**
```
Press 'o' to open in Finder
```

**Ubuntu:**
```
Press 'o' to open in file manager (Nautilus/Dolphin)
```

#### 3.2 **Open Command Detection**
```go
// Detect file manager
func getOpenCommand() string {
    if runtime.GOOS == "darwin" {
        return "open"
    }
    // Ubuntu: try xdg-open (standard), nautilus, dolphin, thunar
    for _, cmd := range []string{"xdg-open", "nautilus", "dolphin", "thunar"} {
        if _, err := exec.LookPath(cmd); err == nil {
            return cmd
        }
    }
    return "xdg-open" // fallback
}
```

---

## 🏗️ Implementation Plan

### Phase 1: Core Compatibility (Immediate)
**Goal:** Make analyzer fully functional on Ubuntu

- [ ] **Task 1.1:** Replace hardcoded macOS overview directories
  - Create `createOverviewEntries()` for Ubuntu
  - Detect platform at runtime
  - File: `cmd/analyze/main.go:188-210`

- [ ] **Task 1.2:** Fix Spotlight dependency
  - Add Ubuntu fast-find alternatives (find/locate)
  - Make fallback more obvious (log when using slow method)
  - File: `cmd/analyze/scanner.go:288-300`

- [ ] **Task 1.3:** Add Ubuntu skip directories
  - Add Linux-specific entries to `foldDirs`
  - Add Linux system dirs to `skipSystemDirs`
  - File: `cmd/analyze/constants.go`

### Phase 2: Ubuntu-Specific Features (Enhancement)
**Goal:** Optimize for Ubuntu usage patterns

- [ ] **Task 2.1:** Package manager directory highlighting
  - Auto-detect apt/snap/flatpak/docker
  - Show in overview if present and large (>1GB)

- [ ] **Task 2.2:** XDG directory emphasis
  - Prioritize ~/.cache (often 5-10GB)
  - Highlight ~/.local/share (apps store data here)
  - Show trash size prominently

- [ ] **Task 2.3:** System directory warnings
  - Warn when scanning /var, /usr (requires sudo for cleanup)
  - Show apt cache size (can be cleaned safely)

### Phase 3: Polish & Testing (Validation)
**Goal:** Production-ready Ubuntu experience

- [ ] **Task 3.1:** Update UI text for Ubuntu
  - Change "Finder" to "file manager"
  - Update help text
  - Platform-specific tips

- [ ] **Task 3.2:** Test on Ubuntu systems
  - Fresh Ubuntu 24.04
  - Ubuntu with Docker/Snap/Flatpak
  - Developer workstation

- [ ] **Task 3.3:** Performance benchmarks
  - Compare mdfind (macOS) vs find/locate (Ubuntu)
  - Optimize large directory scanning
  - Test on 1TB+ disks

---

## 📊 Expected Impact

### Before (Current)
- Shows macOS directories that don't exist (confusing)
- Slower large file discovery (no mdfind)
- Misses Ubuntu-specific cache locations
- Scans unnecessary system directories

### After (Optimized)
- Shows relevant Ubuntu directories in overview
- Fast file discovery with locate/find
- Highlights major space consumers:
  - APT cache (500MB-2GB)
  - Snap old revisions (2-3GB per app)
  - Docker (10-50GB on dev machines)
  - ~/.cache (5-10GB typical)
  - ~/.local/share (varies widely)
- Skips pseudo-filesystems (/proc, /sys)

---

## 🔍 Questions for Clarification

1. **Priority Level:**
   - Should we fix this immediately (blocking) or after PR is merged?
   - Is this required for initial Ubuntu release or can be follow-up?

2. **Scope:**
   - Should we maintain macOS compatibility or Ubuntu-only?
   - If both: runtime detection or build tags?

3. **Features:**
   - Which overview directories are MUST-HAVE vs nice-to-have?
   - Should we auto-detect package managers or hardcode common ones?
   - Should we show system directories (/var, /usr) or hide them by default?

4. **Performance:**
   - Is `locate` dependency acceptable (not always installed)?
   - Should we pre-scan common locations vs pure on-demand?

5. **UI/UX:**
   - Keep current macOS-style UI or adapt to GNOME conventions?
   - Should we show APT/Snap/Flatpak separately or grouped?

---

## 📝 Recommendation

**My suggestion:**
1. **Fix Phase 1 NOW** (before PR) - It's critical for Ubuntu usability
2. **Add Phase 2** in follow-up PR - Enhanced features can be iterative
3. **Phase 3** during beta testing - Get user feedback first

This ensures the analyzer is functional on Ubuntu from day 1, with room for optimization based on real usage patterns.

**Estimated effort:**
- Phase 1: 2-3 hours (runtime platform detection + directory updates)
- Phase 2: 3-4 hours (package manager detection + UI enhancements)
- Phase 3: 2-3 hours (testing + polish)

**Total: 7-10 hours of focused work**
