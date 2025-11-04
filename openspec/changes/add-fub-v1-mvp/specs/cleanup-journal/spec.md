# systemd Journal Cleanup Specification

## ADDED Requirements

### Requirement: Journal Vacuum
**Priority**: P0
The system MUST clean systemd journal logs using official journalctl commands.

#### Scenario: Vacuum journal to size limit
**Given** systemd journal is >100MB
**When** journal cleanup executes
**Then** system MUST:
- Execute `sudo journalctl --vacuum-size=100M`
- Calculate space freed (before/after comparison)
- Display: "Journal vacuumed to 100M"
- Log operation

#### Scenario: Vacuum journal by time
**Given** old journal entries exist
**When** journal cleanup with time-based config
**Then** system MAY execute `sudo journalctl --vacuum-time=7d` to keep last 7 days

### Requirement: Journal Size Detection
**Priority**: P1
The system SHALL detect current journal size before cleanup.

#### Scenario: Display journal size
**Given** journal cleanup starting
**When** size detection runs
**Then** execute `journalctl --disk-usage` and display current size

## Cross-References
- `cleanup-core`: Integrated as cleanup module
- `configuration`: vacuum-size configurable
