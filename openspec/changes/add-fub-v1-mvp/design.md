# FUB v1.0 MVP - Technical Design

## Overview

This document captures architectural decisions, technical patterns, and implementation strategies for FUB v1.0 MVP. It complements the proposal by explaining **how** we achieve the stated goals.

## Architecture Decision Records (ADRs)

### ADR-001: Pure Bash Implementation

**Decision**: Implement FUB entirely in POSIX-compliant bash with no external dependencies beyond standard Ubuntu system tools.

**Context**:
- Mole achieved 4,000+ stars with pure shell implementation
- Ubuntu ships with bash and systemd by default
- No dependency management complexity
- Lightweight installation (<1MB)

**Alternatives Considered**:
1. Python + Click: Better testing, more readable, but requires Python installation
2. Go binary: Fast, single binary, but requires compilation and cross-platform builds
3. Rust: Memory-safe, performant, but steep learning curve and compilation overhead

**Rationale**:
- **Zero friction**: No dependency installation during setup
- **Universal compatibility**: Every Ubuntu system has bash
- **Maintainability**: Simple codebase, easy community contributions
- **Size**: <1MB vs 5-20MB for compiled binaries
- **Transparency**: Users can read/audit shell scripts

**Consequences**:
- ✅ Fast installation, no build step
- ✅ Easy debugging (users can `cat /usr/local/bin/fub`)
- ✅ Low barrier to contributions
- ❌ Limited error handling compared to modern languages
- ❌ Harder to test (no built-in test framework)
- ⚠️ Must use ShellCheck for quality assurance

**Implementation Notes**:
- Use `set -Eeuo pipefail` for strict error handling
- Follow Google Shell Style Guide
- ShellCheck all scripts in CI/CD
- Modular functions for testability

---

### ADR-002: Profile-Based Cleanup System

**Decision**: Implement automatic desktop vs server detection with profile-based cleanup configurations.

**Context**:
- Desktop users have browser caches, thumbnails (GUI-specific)
- Servers should skip GUI cleanup, focus on logs/APT
- Current tools don't differentiate (BleachBit cleans everything)

**Detection Strategy**:
```bash
detect_profile() {
  # Method 1: systemd target (most reliable)
  if systemctl get-default | grep -q "graphical.target"; then
    echo "desktop"
  elif systemctl get-default | grep -q "multi-user.target"; then
    echo "server"
  # Method 2: Fallback to DISPLAY variable
  elif [ -n "$DISPLAY" ]; then
    echo "desktop"
  else
    echo "server"
  fi
}
```

**Profile Configurations**:

| Category | Desktop | Server | Minimal |
|----------|---------|--------|---------|
| APT cache | ✅ | ✅ | ✅ |
| Old kernels | ✅ | ✅ | ❌ (too risky for minimal) |
| systemd journal | ✅ | ✅ | ✅ |
| Browser caches | ✅ | ❌ | ❌ |
| Thumbnails | ✅ | ❌ | ❌ |
| Temp files | ✅ | ✅ | ✅ |

**User Override**:
```bash
# Explicit profile selection
fub clean --profile server

# Category override
fub clean --profile server --only apt,journal
```

**Consequences**:
- ✅ Safe defaults for different environments
- ✅ Prevents cleaning non-existent GUI caches on servers
- ✅ Better user experience (smart defaults)
- ⚠️ Detection logic needs testing on various Ubuntu configurations

---

### ADR-003: Kernel Protection Strategy

**Decision**: Implement multi-layer kernel protection to prevent unbootable systems.

**Context**:
- **Critical Risk**: Deleting all kernels or current kernel makes system unbootable
- Ubuntu accumulates old kernels over time (each kernel update leaves old ones)
- Users often don't understand kernel version numbering

**Protection Layers**:

**Layer 1: Current Kernel Detection**
```bash
CURRENT_KERNEL=$(uname -r)
# Never delete current kernel
```

**Layer 2: Keep Previous Kernel**
```bash
# Get all installed kernels, sorted by version
KERNELS=$(dpkg -l | grep linux-image | sort -V)

# Keep:
# - Current kernel
# - Latest previous kernel (rollback safety)
# Remove:
# - All older kernels
```

**Layer 3: Minimum Kernel Count**
```bash
KERNEL_COUNT=$(dpkg -l | grep -c linux-image)

if [ "$KERNEL_COUNT" -le 2 ]; then
  echo "Only 2 or fewer kernels detected. Skipping cleanup for safety."
  exit 0
fi
```

**Layer 4: Explicit Confirmation**
```bash
echo "WARNING: Kernel removal can make system unbootable if done incorrectly."
echo "Keeping: $CURRENT_KERNEL, $PREVIOUS_KERNEL"
echo "Removing: $OLD_KERNELS"
read -p "Proceed? [y/N]: " confirm
```

**Layer 5: Dry-Run Verification**
```bash
# Dry-run MUST show exactly what would be removed
fub clean --only kernels --dry-run
# Output:
# [DRY-RUN] Would remove: linux-image-5.15.0-91-generic (250MB)
# [DRY-RUN] Keeping: linux-image-6.8.0-48-generic (current)
# [DRY-RUN] Keeping: linux-image-6.8.0-47-generic (previous)
```

**Testing Requirements**:
- Test on systems with 2, 3, 5, 10+ kernels
- Verify current kernel never appears in removal list
- Confirm at least 2 kernels remain after cleanup
- Test with custom kernel naming (Ubuntu + HWE kernels)

**Consequences**:
- ✅ Virtually eliminates unbootable system risk
- ✅ Provides rollback capability (previous kernel)
- ✅ Clear user communication about what's being removed
- ⚠️ May leave 1 extra old kernel for ultra-safety (acceptable trade-off)

---

### ADR-004: Dry-Run Implementation

**Decision**: Make dry-run mode a first-class feature with accurate preview matching actual execution.

**Context**:
- Mole's dry-run is cited as killer feature for user trust
- Users need to verify cleanup safety before execution
- Dry-run output must match actual cleanup (no surprises)

**Implementation Pattern**:
```bash
cleanup_category() {
  local category=$1
  local dry_run=$2  # true/false

  # Calculate targets
  local targets=$(find_cleanup_targets "$category")
  local size=$(calculate_size "$targets")

  if [ "$dry_run" = true ]; then
    echo "[DRY-RUN] Would clean: $category ($size)"
    echo "$targets" | while read -r target; do
      echo "  - $target"
    done
  else
    echo "Cleaning: $category ($size)"
    perform_cleanup "$targets"
    log_cleanup "$category" "$size"
  fi
}
```

**Accuracy Guarantee**:
- **Same Target Calculation**: Dry-run and execution use identical `find_cleanup_targets()` function
- **Size Calculation**: Show exact MB/GB that will be freed
- **Path Listing**: Show actual files/directories to be removed
- **No Side Effects**: Dry-run never modifies filesystem

**Output Format**:
```
$ fub clean --dry-run

=== FUB Cleanup Preview (DRY-RUN) ===
Ubuntu 24.04 LTS | Profile: desktop | 6 categories enabled

[✓] APT cache: 347 MB
    /var/cache/apt/archives/*.deb (143 packages)

[✓] Old kernels: 520 MB
    linux-image-5.15.0-91-generic (250 MB)
    linux-image-5.15.0-89-generic (270 MB)
    Keeping: 6.8.0-48 (current), 6.8.0-47 (previous)

[✓] systemd journal: 1.2 GB
    /var/log/journal/* (older than 7 days)

[✓] Browser caches: 890 MB
    ~/.cache/mozilla/firefox (620 MB)
    ~/.cache/google-chrome (270 MB)

[✓] Thumbnails: 450 MB
    ~/.cache/thumbnails/*

[✓] Temporary files: 180 MB
    /tmp/* (older than 7 days)

Total potential recovery: 3.6 GB

This is a DRY-RUN. No changes made.
Run 'fub clean' to execute cleanup.
```

**Consequences**:
- ✅ Builds user trust through transparency
- ✅ Allows verification before execution
- ✅ Educational (users learn what accumulates)
- ⚠️ Requires careful testing to ensure dry-run matches execution

---

### ADR-005: Logging Strategy

**Decision**: Implement comprehensive, structured logging with rotation and privacy considerations.

**Context**:
- Critical for debugging user issues
- Audit trail for system administrators
- Must not log sensitive information
- Disk space management (logs shouldn't accumulate indefinitely)

**Log Location**:
```
~/.local/share/fub/logs/
├── fub-2025-11-04-14-30-15.log  # Timestamped logs
├── fub-latest.log                # Symlink to latest
└── fub.log                       # Compatibility symlink
```

**Log Format**:
```
[2025-11-04 14:30:15] [INFO] FUB v1.0.0 started
[2025-11-04 14:30:15] [INFO] Ubuntu 24.04 LTS detected
[2025-11-04 14:30:15] [INFO] Profile: desktop (auto-detected)
[2025-11-04 14:30:16] [INFO] Dry-run: disabled
[2025-11-04 14:30:16] [INFO] Categories: apt,kernels,journal,browser,thumbnails,temp
[2025-11-04 14:30:17] [INFO] Pre-flight validation: PASSED
[2025-11-04 14:30:18] [INFO] APT cache cleanup: started
[2025-11-04 14:30:22] [INFO] APT cache cleanup: completed (347 MB freed)
[2025-11-04 14:30:22] [INFO] Old kernel cleanup: started
[2025-11-04 14:30:25] [WARN] Kernel count: 4 (keeping 2)
[2025-11-04 14:30:30] [INFO] Old kernel cleanup: completed (520 MB freed)
[2025-11-04 14:30:35] [ERROR] Browser cleanup failed: Firefox running (PID 1234)
[2025-11-04 14:30:35] [INFO] Cleanup completed: 867 MB freed (1 error)
```

**Log Levels**:
- **INFO**: Normal operations, success messages
- **WARN**: Non-critical issues (skipped items, running services)
- **ERROR**: Failures requiring user attention
- **DEBUG**: Detailed execution info (enabled with `--verbose`)

**Privacy Considerations**:
- Never log file contents
- Never log user credentials or sensitive data
- Sanitize paths to use `~` instead of `/home/username`
- Log file sizes/counts, not filenames (unless debug mode)

**Rotation Strategy**:
- Keep last 10 log files
- Delete logs older than 30 days
- Max 10MB per log file
- Rotation check on each run

**Implementation**:
```bash
log() {
  local level=$1
  shift
  local message="$*"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local logfile="$HOME/.local/share/fub/logs/fub-$(date '+%Y-%m-%d-%H-%M-%S').log"

  echo "[$timestamp] [$level] $message" | tee -a "$logfile"

  # Update latest symlink
  ln -sf "$(basename "$logfile")" "$HOME/.local/share/fub/logs/fub-latest.log"
}
```

**Consequences**:
- ✅ Comprehensive debugging capability
- ✅ Audit trail for compliance
- ✅ User privacy protected
- ⚠️ Requires log rotation to prevent disk accumulation

---

### ADR-006: Configuration System

**Decision**: Use simple INI-style configuration with sensible defaults and minimal user input required.

**Context**:
- Users should get good experience without configuration
- Power users want customization
- Configuration should be human-readable and editable

**Configuration Location**:
```
~/.config/fub/fub.conf
```

**Configuration Format** (INI-style for simplicity):
```ini
# FUB Configuration
# Generated: 2025-11-04

[general]
profile = auto              # auto, desktop, server, minimal
dry_run_default = false     # Always dry-run unless --yes specified
verbose = false             # Verbose output by default

[cleanup]
# Enable/disable categories (true/false)
apt_cache = true
old_kernels = true
systemd_journal = true
browser_caches = true       # Auto-disabled for server profile
thumbnails = true           # Auto-disabled for server profile
temp_files = true

[safety]
min_kernels = 2             # Minimum kernels to keep
journal_max_size = 100M     # Max systemd journal size
temp_age_days = 7           # Only delete temp files older than N days
browser_check_running = true  # Skip browser cleanup if running

[logging]
log_level = INFO            # DEBUG, INFO, WARN, ERROR
log_retention_days = 30
max_log_files = 10
```

**Configuration Hierarchy** (order of precedence):
1. Command-line flags (highest priority)
2. User configuration (`~/.config/fub/fub.conf`)
3. System defaults (fallback if no config)

**Example Override**:
```bash
# Config says dry_run_default=true
# Command overrides with --yes
fub clean --yes  # Executes cleanup despite config
```

**Default Generation**:
- Installation creates template config with comments
- First run detects profile and writes config
- Config is optional (tool works without it)

**Validation**:
- Parse errors show line number and fall back to defaults
- Invalid values logged as warnings, use defaults
- Config changes take effect immediately (no restart needed)

**Consequences**:
- ✅ Zero configuration required for basic use
- ✅ Power users can customize behavior
- ✅ Human-readable and editable
- ⚠️ INI parsing requires bash implementation (or use simple grep/awk)

---

## System Integration

### systemd Awareness

**Service Detection**:
```bash
check_apt_locks() {
  if fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
    echo "APT is locked (possibly unattended-upgrades running)"
    echo "Skipping APT cleanup. Try again later."
    return 1
  fi
  return 0
}

check_browser_running() {
  local browser=$1
  if pgrep -x "$browser" >/dev/null; then
    echo "Warning: $browser is running (PID: $(pgrep -x "$browser"))"
    echo "Skipping browser cache cleanup for safety."
    return 1
  fi
  return 0
}
```

**Journal Management**:
```bash
cleanup_journal() {
  local max_size=${1:-100M}
  local dry_run=$2

  # Use systemd's official vacuum command
  if [ "$dry_run" = true ]; then
    echo "[DRY-RUN] Would vacuum journal to $max_size"
    journalctl --disk-usage
  else
    echo "Vacuuming systemd journal to $max_size..."
    sudo journalctl --vacuum-size="$max_size"
    log INFO "Journal vacuumed to $max_size"
  fi
}
```

### Ubuntu Version Handling

**Version Detection**:
```bash
detect_ubuntu_version() {
  if [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    echo "$DISTRIB_RELEASE"
  elif command -v lsb_release >/dev/null; then
    lsb_release -rs
  else
    echo "unknown"
  fi
}

validate_ubuntu() {
  local version=$(detect_ubuntu_version)

  case $version in
    24.04|22.04|20.04)
      echo "Ubuntu $version detected (supported)"
      return 0
      ;;
    *)
      echo "Warning: Ubuntu $version not explicitly tested"
      echo "Supported versions: 24.04, 22.04, 20.04"
      read -p "Continue anyway? [y/N]: " confirm
      [[ $confirm =~ ^[Yy]$ ]]
      ;;
  esac
}
```

---

## Error Handling Strategy

### Fail-Safe Principles

1. **Never Partial State**: Either complete operation or rollback
2. **Preserve User Data**: Conservative path matching, no wildcards on user directories
3. **Graceful Degradation**: Skip failed categories, continue with others
4. **Clear Error Messages**: Tell user what failed and how to fix

**Implementation Pattern**:
```bash
# Set strict error handling
set -Eeuo pipefail

# Global error trap
trap 'error_handler $? $LINENO' ERR

error_handler() {
  local exit_code=$1
  local line_number=$2

  log ERROR "Failed at line $line_number with exit code $exit_code"
  echo "ERROR: Cleanup failed. Check logs: ~/.local/share/fub/logs/fub-latest.log"

  # Cleanup temporary files
  cleanup_temp_files

  exit "$exit_code"
}

# Safe cleanup wrapper
safe_cleanup() {
  local category=$1

  if cleanup_"$category"; then
    log INFO "$category cleanup: SUCCESS"
  else
    log ERROR "$category cleanup: FAILED (continuing with other categories)"
    # Don't exit, continue with next category
  fi
}
```

---

## Testing Strategy

### Test Pyramid

**Level 1: Unit Tests** (bash-test-framework or bats)
- Individual functions (detect_profile, calculate_size, etc.)
- Mocking system commands
- Edge cases (empty directories, permission errors)

**Level 2: Integration Tests**
- Full cleanup flows on test fixtures
- Configuration parsing
- Logging functionality

**Level 3: System Tests**
- Run on actual Ubuntu VMs (24.04, 22.04, 20.04)
- Desktop vs Server environments
- Different kernel counts (2, 3, 5, 10+)

**Level 4: Acceptance Tests**
- Alpha user testing
- Real-world scenarios
- Performance benchmarks

### Test Environments

**Docker Containers** (for CI/CD):
```dockerfile
FROM ubuntu:24.04
RUN apt-get update && \
    apt-get install -y linux-image-generic && \
    # Setup test fixtures
```

**Manual Testing Checklist**:
- [ ] Fresh Ubuntu 24.04 install (desktop)
- [ ] Fresh Ubuntu 24.04 install (server)
- [ ] Ubuntu 22.04 LTS
- [ ] Ubuntu 20.04 LTS
- [ ] System with 2 kernels (edge case)
- [ ] System with 10+ kernels
- [ ] System with running Firefox
- [ ] System with locked APT
- [ ] Low disk space scenario (<1GB free)

---

## Performance Considerations

### Optimization Targets

- **Installation**: <30 seconds (download + setup)
- **Dry-run scan**: <30 seconds (disk analysis)
- **Full cleanup**: <10 minutes (worst case)
- **Memory usage**: <50MB peak
- **CPU usage**: <50% average (on single core)

### Performance Patterns

**Parallel Execution** (where safe):
```bash
# Sequential (slow)
cleanup_apt
cleanup_journal
cleanup_temp

# Parallel (fast, but needs careful dependency analysis)
cleanup_apt &
cleanup_journal &
wait  # Wait for background jobs
cleanup_temp  # Run after others complete
```

**Efficient Size Calculation**:
```bash
# Slow: du on each file
for file in $files; do du -sh "$file"; done

# Fast: du on directory once
du -sb "$directory" | awk '{print $1}'
```

**Avoid Expensive Operations**:
- Don't calculate sizes twice (dry-run vs execution)
- Cache kernel list (don't call dpkg multiple times)
- Use bash built-ins instead of external commands where possible

---

## Security Considerations

### Input Validation

**Path Sanitization**:
```bash
sanitize_path() {
  local path=$1

  # Never allow:
  # - Root directory (/)
  # - Parent directory traversal (..)
  # - System directories (/bin, /boot, /etc, /lib, /sbin, /usr)

  case $path in
    /|/bin*|/boot*|/etc*|/lib*|/sbin*|/usr*)
      echo "ERROR: Refusing to clean system directory: $path"
      return 1
      ;;
    *..*)
      echo "ERROR: Path traversal detected: $path"
      return 1
      ;;
  esac

  # Resolve symlinks to detect sneaky paths
  realpath "$path"
}
```

**Command Injection Prevention**:
```bash
# Bad (vulnerable)
eval "rm -rf $user_input"

# Good (safe)
rm -rf -- "${user_input}"  # -- prevents flag injection
```

### Privilege Management

**Principle of Least Privilege**:
- Run as user by default
- Request sudo only for operations requiring it
- Drop sudo after privileged operation

```bash
# Check if we need sudo
needs_sudo() {
  local operation=$1

  case $operation in
    apt|kernels|journal)
      return 0  # Needs sudo
      ;;
    browser|thumbnails|temp)
      return 1  # User-level cleanup
      ;;
  esac
}

# Request sudo upfront for privileged operations
request_sudo() {
  echo "This operation requires administrator privileges."
  sudo -v  # Cache sudo credentials
}
```

---

## Future Extensibility

### Module System (v1.1+)

**Design for Plugin Architecture**:
```bash
# ~/.local/share/fub/modules/
# Each module is a bash script implementing standard interface

# Module template:
# module_snap_cleanup.sh
module_name() { echo "snap-cleanup"; }
module_description() { echo "Clean old Snap revisions"; }
module_category() { echo "packages"; }
module_profiles() { echo "desktop server"; }
module_dry_run() {
  # Calculate what would be cleaned
}
module_execute() {
  # Perform cleanup
}
```

**Module Discovery**:
```bash
load_modules() {
  local module_dir="$HOME/.local/share/fub/modules"

  if [ -d "$module_dir" ]; then
    for module in "$module_dir"/*.sh; do
      source "$module"
      register_module "$(module_name)"
    done
  fi
}
```

This design allows community contributions without modifying core code.

---

## Open Questions & TODOs

1. **Bash Version Requirements**:
   - Ubuntu 20.04 ships bash 5.0
   - Can we use bash 5 features or stick to bash 4 for broader compatibility?
   - **Decision Needed**: Target bash 4.0+ (POSIX-compliant)

2. **Browser Cache Cleanup Safety**:
   - Should we check for browser processes even if user forces cleanup?
   - What about browser sessions saved to disk?
   - **Decision Needed**: Always skip if browser running, add `--force-browser` flag for override

3. **Configuration Migration**:
   - How to handle config changes between versions?
   - Config versioning needed?
   - **Decision Needed**: Include version in config, migrate on first run if needed

4. **Localization (i18n)**:
   - Support for non-English locales?
   - **Decision Needed**: English-only for v1.0, i18n in v1.2+

---

**Last Updated**: 2025-11-04
**Status**: Design Complete, Pending Approval
