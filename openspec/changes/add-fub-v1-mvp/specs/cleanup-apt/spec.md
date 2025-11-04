# APT Cache Cleanup Specification

## ADDED Requirements

### Requirement: APT Cache Cleanup
**Priority**: P0
The system MUST safely clean APT package cache using official APT commands.

#### Scenario: Clean APT cache
**Given** APT cache exists in `/var/cache/apt/archives/`
**When** APT cleanup executes
**Then** system MUST:
- Check APT lock status first
- Execute `sudo apt-get clean` or `sudo apt-get autoclean`
- Remove downloaded .deb files
- Calculate space freed
- Log operation

#### Scenario: APT cache cleanup with lock
**Given** APT is locked
**When** APT cleanup attempts to run
**Then** system MUST skip with message: "APT locked, skipping cache cleanup"

### Requirement: APT Autoremove
**Priority**: P1
The system SHALL remove unused packages with apt-get autoremove.

#### Scenario: Remove unused dependencies
**Given** unused packages exist
**When** APT cleanup executes (if enabled in config)
**Then** system SHOULD:
- Execute `sudo apt-get autoremove --purge`
- Display packages to be removed
- Require confirmation unless --yes

## Cross-References
- `safety-system`: APT lock detection
- `cleanup-core`: Integrated as cleanup module
