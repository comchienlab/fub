# CLI Interface Specification

## ADDED Requirements

### Requirement: Command Structure

**Priority**: P0

The system MUST provide a simple, intuitive command structure following Unix conventions.

#### Scenario: Basic cleanup execution

**Given** FUB is installed
**When** user executes `fub clean`
**Then** the system MUST:
- Run interactive cleanup with confirmation prompts
- Apply profile-based category selection
- Display progress for each category
- Show total space freed at completion

#### Scenario: Dry-run preview

**Given** user wants to preview cleanup
**When** user executes `fub clean --dry-run`
**Then** the system MUST:
- Scan all enabled categories
- Calculate potential space recovery
- Display detailed preview without making changes
- Show message: "This is a DRY-RUN. No changes made."

#### Scenario: Version display

**Given** user needs version info
**When** user executes `fub --version`
**Then** system MUST display: `FUB v1.0.0`

---

### Requirement: Category Selection

**Priority**: P0

The system MUST allow users to select specific cleanup categories.

#### Scenario: Cleanup specific categories only

**Given** user wants to clean only APT and kernels
**When** user executes `fub clean --only apt,kernels`
**Then** the system MUST:
- Run cleanup for APT cache only
- Run cleanup for old kernels only
- Skip all other categories
- Display: "Enabled categories: apt, kernels"

#### Scenario: Skip specific categories

**Given** user wants all cleanup except browser
**When** user executes `fub clean --skip browser`
**Then** the system MUST:
- Enable all profile-default categories
- Disable browser cleanup
- Display: "Skipped categories: browser"

---

### Requirement: Profile Selection

**Priority**: P1

The system SHALL support explicit profile selection via command line.

#### Scenario: Force server profile on desktop

**Given** desktop system (graphical.target)
**When** user executes `fub clean --profile server`
**Then** the system MUST:
- Use server profile (skip browser, thumbnails)
- Override auto-detected desktop profile
- Display: "Using profile: server (manual override)"

---

### Requirement: Batch Mode

**Priority**: P1

The system MUST support non-interactive batch mode for automation.

#### Scenario: Unattended cleanup

**Given** automated cleanup script
**When** user executes `fub clean --yes`
**Then** the system MUST:
- Skip all confirmation prompts
- Proceed with cleanup automatically
- Log all operations
- Exit with 0 on success, non-zero on failure

---

### Requirement: Verbose Output

**Priority**: P2

The system SHALL provide verbose output for debugging.

#### Scenario: Verbose cleanup execution

**Given** user needs detailed output
**When** user executes `fub clean --verbose`
**Then** the system SHOULD:
- Display detailed operation steps
- Show files being removed (within reason)
- Display timing information
- Show debug-level log messages

---

## Cross-References

- `cleanup-core`: CLI invokes cleanup engine
- `safety-system`: --dry-run flag for safety
- `configuration`: Profile selection affects behavior
