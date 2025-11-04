# Kernel Cleanup Specification

## ADDED Requirements

### Requirement: Current Kernel Protection

**Priority**: P0 (Critical - System Safety)

The system MUST NEVER remove the currently running kernel to prevent unbootable system.

#### Scenario: Cleanup with current kernel detected

**Given** system is running kernel `6.8.0-48-generic`
**And** old kernels `6.8.0-47-generic` and `5.15.0-91-generic` are installed
**When** user executes `fub clean --only kernels`
**Then** the system MUST:
- Detect current kernel with `uname -r`
- Exclude `linux-image-6.8.0-48-generic` from removal list
- Exclude `linux-headers-6.8.0-48-generic` from removal list
- Include only old kernels in removal candidates
- Display: "Current kernel: 6.8.0-48-generic (protected)"

**And** the current kernel MUST NOT appear in any removal list, even with `--force` flag

---

### Requirement: Minimum Kernel Count

**Priority**: P0 (Critical - System Safety)

The system MUST maintain at least 2 kernels installed (current + one previous) for rollback capability.

#### Scenario: Safe kernel cleanup with 4 kernels

**Given** system has 4 kernels installed:
- `6.8.0-48-generic` (current)
- `6.8.0-47-generic` (previous)
- `6.8.0-46-generic` (old)
- `5.15.0-91-generic` (old)
**When** kernel cleanup executes
**Then** the system MUST:
- Keep `6.8.0-48-generic` (current)
- Keep `6.8.0-47-generic` (latest previous for rollback)
- Remove `6.8.0-46-generic`
- Remove `5.15.0-91-generic`
- Result in 2 kernels remaining

#### Scenario: Refuse cleanup with only 2 kernels

**Given** system has exactly 2 kernels:
- `6.8.0-48-generic` (current)
- `6.8.0-47-generic` (previous)
**When** kernel cleanup executes
**Then** the system MUST:
- Detect only 2 kernels present
- Display: "Only 2 kernels detected. Skipping cleanup for safety."
- Display: "Minimum 2 kernels required (current + rollback)."
- Not remove any kernels
- Exit cleanup successfully (not an error)

#### Scenario: Refuse cleanup with only 1 kernel

**Given** system has only 1 kernel (minimal install):
- `6.8.0-48-generic` (current)
**When** kernel cleanup executes
**Then** the system MUST:
- Detect only 1 kernel
- Display: "WARNING: Only 1 kernel detected. Cannot cleanup."
- Display: "Install at least one additional kernel before using cleanup."
- Not remove any kernels
- Exit cleanup successfully

---

### Requirement: Kernel Version Sorting

**Priority**: P0 (Critical)

The system MUST correctly sort kernel versions to identify which kernels are older.

#### Scenario: Correct version sorting

**Given** installed kernels (unsorted):
- `linux-image-5.15.0-91-generic`
- `linux-image-6.8.0-48-generic`
- `linux-image-6.8.0-47-generic`
- `linux-image-5.15.0-100-generic`
**When** kernel cleanup analyzes versions
**Then** the system MUST sort versions correctly:
1. `6.8.0-48-generic` (newest)
2. `6.8.0-47-generic`
3. `5.15.0-100-generic` (note: 100 > 91)
4. `5.15.0-91-generic` (oldest)

**And** MUST use version-aware sorting (`sort -V`) not alphabetical sorting

#### Scenario: Handle HWE kernels

**Given** Ubuntu 22.04 with HWE (Hardware Enablement) kernels:
- `linux-image-5.15.0-91-generic` (GA kernel)
- `linux-image-6.8.0-48-generic` (HWE kernel, current)
- `linux-image-6.5.0-35-generic` (HWE kernel, old)
**When** kernel cleanup analyzes
**Then** the system MUST:
- Recognize both GA and HWE kernels
- Sort by version number correctly
- Keep current HWE kernel (6.8.0-48)
- Keep previous for rollback (6.5.0-35)
- Remove old GA kernel (5.15.0-91) if more than 2 total

---

### Requirement: Kernel Package Completeness

**Priority**: P1 (High)

The system MUST remove all components of a kernel (image, headers, modules) together to prevent partial removal.

#### Scenario: Complete kernel removal

**Given** kernel `5.15.0-91-generic` marked for removal
**And** packages exist:
- `linux-image-5.15.0-91-generic`
- `linux-headers-5.15.0-91-generic`
- `linux-modules-5.15.0-91-generic`
- `linux-modules-extra-5.15.0-91-generic`
**When** kernel cleanup executes
**Then** the system MUST:
- Identify all related packages via `dpkg -l | grep 5.15.0-91`
- Queue all packages for removal together
- Remove in correct order (headers, then image)
- Verify all packages removed successfully

**And** if any package removal fails, MUST log error and continue with next kernel (not abort entirely)

---

### Requirement: Dry-Run Kernel Preview

**Priority**: P0 (Critical)

The system MUST provide accurate dry-run preview of kernel cleanup showing exactly what will be removed.

#### Scenario: Dry-run shows kernels to remove

**Given** 4 kernels installed (6.8.0-48 current, 6.8.0-47, 6.8.0-46, 5.15.0-91)
**When** user executes `fub clean --only kernels --dry-run`
**Then** the system MUST display:
```
[DRY-RUN] Old Kernel Cleanup
Current kernel: 6.8.0-48-generic (protected)

Kernels to keep:
  ✓ linux-image-6.8.0-48-generic (current)
  ✓ linux-image-6.8.0-47-generic (previous, rollback)

Kernels to remove:
  ✗ linux-image-6.8.0-46-generic (250 MB)
  ✗ linux-image-5.15.0-91-generic (270 MB)

Total recovery: 520 MB
Kernels after cleanup: 2

This is a DRY-RUN. No kernels will be removed.
```

**And** dry-run output MUST exactly match what would be removed in actual execution

---

### Requirement: Explicit Kernel Confirmation

**Priority**: P0 (Critical)

The system MUST require explicit user confirmation before removing kernels, with clear warning about risks.

#### Scenario: Kernel removal confirmation

**Given** kernel cleanup is ready to execute
**When** user runs `fub clean --only kernels` (without `--yes` flag)
**Then** the system MUST:
- Display kernels to be removed (with sizes)
- Display warning:
  ```
  WARNING: Incorrect kernel removal can make your system unbootable.

  The following kernels will be removed:
    - linux-image-6.8.0-46-generic (250 MB)
    - linux-image-5.15.0-91-generic (270 MB)

  Kernels that will remain:
    - linux-image-6.8.0-48-generic (current)
    - linux-image-6.8.0-47-generic (rollback)

  Proceed with kernel removal? [y/N]:
  ```
- Wait for user input
- Proceed only if user types 'y' or 'Y'
- Abort if user types anything else or presses Enter (default: No)

#### Scenario: Batch mode kernel cleanup

**Given** user wants unattended cleanup
**When** user runs `fub clean --only kernels --yes`
**Then** the system MUST:
- Skip interactive confirmation (--yes flag)
- Still display what will be removed
- Proceed automatically
- Log warning that unattended kernel removal occurred

---

### Requirement: Bootloader Update

**Priority**: P1 (High)

The system SHALL update GRUB bootloader after kernel removal to reflect changes.

#### Scenario: GRUB update after kernel removal

**Given** kernels were successfully removed
**When** cleanup completes
**Then** the system SHOULD:
- Execute `sudo update-grub` or `sudo update-grub2`
- Capture output and log it
- Display: "Updating bootloader (GRUB)..."
- If update-grub fails, log warning but don't fail cleanup
- Display: "GRUB update completed"

#### Scenario: GRUB update failure

**Given** kernel removal succeeded
**When** `update-grub` fails (e.g., permission error)
**Then** the system MUST:
- Log error: "GRUB update failed: [error message]"
- Display warning to user:
  ```
  Warning: Bootloader update failed.
  Kernels removed but GRUB not updated.
  Run manually: sudo update-grub
  ```
- Continue with cleanup (don't fail entire operation)

---

### Requirement: Kernel Cleanup Logging

**Priority**: P1 (High)

The system MUST comprehensively log all kernel operations for audit and debugging.

#### Scenario: Kernel cleanup audit log

**Given** kernel cleanup executes
**When** any kernel operation occurs
**Then** the system MUST log:
- Timestamp of operation
- Current kernel detected
- List of installed kernels found
- Kernel version sorting results
- Kernels marked for removal
- Kernels marked for keeping (with reasons)
- Each package removal attempt
- Success/failure of each removal
- GRUB update attempt and result
- Total space freed
- Final kernel count

**Example log**:
```
[2025-11-04 14:30:22] [INFO] Kernel cleanup: started
[2025-11-04 14:30:22] [INFO] Current kernel: 6.8.0-48-generic
[2025-11-04 14:30:23] [INFO] Installed kernels: 4 found
[2025-11-04 14:30:23] [INFO] Keeping: 6.8.0-48-generic (current)
[2025-11-04 14:30:23] [INFO] Keeping: 6.8.0-47-generic (previous)
[2025-11-04 14:30:23] [INFO] Removing: 6.8.0-46-generic (250 MB)
[2025-11-04 14:30:25] [INFO] Package removed: linux-image-6.8.0-46-generic
[2025-11-04 14:30:26] [INFO] Package removed: linux-headers-6.8.0-46-generic
[2025-11-04 14:30:27] [INFO] Removing: 5.15.0-91-generic (270 MB)
[2025-11-04 14:30:30] [INFO] Package removed: linux-image-5.15.0-91-generic
[2025-11-04 14:30:32] [INFO] GRUB update: started
[2025-11-04 14:30:35] [INFO] GRUB update: completed
[2025-11-04 14:30:35] [INFO] Kernel cleanup: completed (520 MB freed, 2 kernels remain)
```

---

### Requirement: Kernel Cleanup Error Recovery

**Priority**: P1 (High)

The system MUST handle kernel removal failures gracefully without leaving system in broken state.

#### Scenario: Single kernel removal failure

**Given** 2 kernels marked for removal: 6.8.0-46, 5.15.0-91
**When** removal of 6.8.0-46 fails (e.g., package locked)
**Then** the system MUST:
- Log error: "Failed to remove linux-image-6.8.0-46-generic: [error]"
- Continue attempting to remove 5.15.0-91
- Not abort entire cleanup
- Report partial success: "1 of 2 kernels removed"
- Display advice: "Re-run cleanup later to retry failed removals"

#### Scenario: APT lock during kernel removal

**Given** kernel cleanup is starting
**When** APT is locked (e.g., unattended-upgrades running)
**Then** the system MUST:
- Detect APT lock via `fuser /var/lib/dpkg/lock-frontend`
- Display: "APT is locked (possibly updates running). Cannot remove kernels."
- Skip kernel cleanup entirely (don't attempt)
- Return to continue with other categories (if multi-category cleanup)
- Log: "Kernel cleanup skipped: APT locked"

---

### Requirement: Profile-Based Kernel Cleanup

**Priority**: P2 (Medium)

The system SHALL adjust kernel cleanup behavior based on system profile.

#### Scenario: Desktop profile kernel cleanup

**Given** profile is "desktop"
**When** kernel cleanup executes
**Then** the system SHOULD:
- Use standard safety (keep 2 kernels)
- Proceed with cleanup

#### Scenario: Server profile kernel cleanup

**Given** profile is "server"
**When** kernel cleanup executes
**Then** the system SHOULD:
- Use extra caution (keep 3 kernels if available)
- Display additional warning about production system
- Require explicit confirmation even in batch mode (first time)

#### Scenario: Minimal profile kernel cleanup

**Given** profile is "minimal"
**When** kernel cleanup executes
**Then** the system MUST:
- Skip kernel cleanup by default (too risky)
- Display: "Kernel cleanup disabled in minimal profile"
- Allow override with explicit `--force-kernels` flag

---

## Cross-References

**Related Specifications**:
- `safety-system`: Kernel protection is critical safety feature
- `cleanup-core`: Integrates as cleanup module
- `cli-interface`: Provides `--only kernels` flag
- `configuration`: Profile settings affect kernel cleanup behavior

**Dependencies**:
- `dpkg` for package queries and removal
- `uname` for current kernel detection
- `sort` with version sorting (`-V` flag)
- `update-grub` for bootloader updates
- `apt-get` or `dpkg` for package removal

**Risk Mitigation**:
- Multi-layer protection prevents accidental removal of current kernel
- Minimum count enforcement prevents removing all kernels
- Explicit confirmation required for user awareness
- Comprehensive logging for debugging issues
- Graceful error handling prevents partial broken state
