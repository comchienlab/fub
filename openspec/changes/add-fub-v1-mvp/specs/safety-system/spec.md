# Safety System Specification

## ADDED Requirements

### Requirement: Pre-flight Validation

**Priority**: P0

The system MUST validate system state before executing any cleanup operations.

#### Scenario: Pre-flight checks before cleanup

**Given** user initiates cleanup
**When** FUB starts execution
**Then** the system MUST verify:
- Ubuntu version is detected and supported
- systemd is running (`systemctl is-system-running`)
- User has necessary permissions (sudo available for privileged ops)
- No critical APT locks present
- Sufficient disk space for logging (10MB minimum)

**And** if any check fails, MUST:
- Display specific failure reason
- Abort cleanup with exit code 1
- Log failure details

---

### Requirement: APT Lock Detection

**Priority**: P0

The system MUST detect and handle APT lock conditions gracefully.

#### Scenario: APT locked by unattended-upgrades

**Given** unattended-upgrades is running
**When** FUB attempts APT or kernel cleanup
**Then** the system MUST:
- Detect lock via `fuser /var/lib/dpkg/lock-frontend`
- Display: "APT is locked (possibly updates running)"
- Skip APT and kernel cleanup
- Continue with other categories
- Log: "APT cleanup skipped: locked"

---

### Requirement: Service Detection

**Priority**: P1

The system SHALL detect running services that may be affected by cleanup.

#### Scenario: Browser running during cache cleanup

**Given** Firefox is running (PID 1234)
**When** browser cache cleanup starts
**Then** the system SHOULD:
- Detect Firefox process via `pgrep firefox`
- Display: "Warning: Firefox is running (PID 1234)"
- Display: "Skipping browser cache cleanup for safety"
- Skip browser cleanup
- Continue with other categories

---

### Requirement: Path Validation

**Priority**: P0

The system MUST validate all paths before deletion to prevent system damage.

#### Scenario: Reject dangerous path deletion

**Given** cleanup targets are being validated
**When** a path matches system directory (/, /bin, /boot, /etc, /lib, /sbin, /usr)
**Then** the system MUST:
- Reject path with error
- Display: "ERROR: Refusing to clean system directory: [path]"
- Log critical error
- Abort that specific operation
- Not delete anything from that path

#### Scenario: Prevent path traversal

**Given** cleanup path contains `..`
**When** path validation runs
**Then** the system MUST:
- Detect parent directory traversal
- Reject path with error
- Display: "ERROR: Path traversal detected: [path]"
- Abort operation

---

### Requirement: Dry-Run Accuracy

**Priority**: P0

The system MUST ensure dry-run preview exactly matches actual execution.

#### Scenario: Dry-run matches execution

**Given** user runs `fub clean --only apt --dry-run`
**And** dry-run shows "Would free: 347 MB"
**When** user then runs `fub clean --only apt`
**Then** the system MUST:
- Remove the exact same files shown in dry-run
- Free approximately same space (within 10% tolerance for race conditions)
- Not remove any additional files not shown in dry-run
- Not skip any files shown in dry-run (unless locked/changed)

---

### Requirement: Comprehensive Logging

**Priority**: P1

The system MUST log all operations for audit and debugging.

#### Scenario: Operation logging

**Given** cleanup is executing
**When** any operation occurs
**Then** the system MUST log:
- Timestamp (YYYY-MM-DD HH:MM:SS)
- Log level (INFO, WARN, ERROR)
- Operation description
- Success/failure result
- Space freed (if applicable)
- Errors encountered

**And** logs MUST be written to `~/.local/share/fub/logs/fub-[timestamp].log`

---

### Requirement: Error Recovery

**Priority**: P1

The system MUST handle errors gracefully without leaving partial state.

#### Scenario: Single category failure

**Given** multi-category cleanup (apt, kernels, journal)
**When** kernels cleanup fails (APT locked)
**Then** the system MUST:
- Log error for kernel cleanup
- Continue with remaining categories (journal)
- Display partial success message
- Show which categories succeeded and failed
- Exit with non-zero code (partial failure)

---

### Requirement: Confirmation Prompts

**Priority**: P0

The system MUST require explicit confirmation for destructive operations unless --yes flag provided.

#### Scenario: Kernel removal confirmation

**Given** kernel cleanup will remove 2 old kernels
**When** user runs `fub clean --only kernels` (no --yes)
**Then** the system MUST:
- Display what will be removed
- Display warning about risks
- Prompt: "Proceed with kernel removal? [y/N]:"
- Wait for input
- Proceed only on 'y' or 'Y'
- Abort on any other input

---

## Cross-References

- `cleanup-kernels`: Critical safety for kernel protection
- `cleanup-core`: Safety checks before all cleanup
- `cli-interface`: --dry-run flag implementation
