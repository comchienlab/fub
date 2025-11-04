# Browser Cache Cleanup Specification

## ADDED Requirements

### Requirement: Firefox Cache Cleanup
**Priority**: P1
The system SHALL clean Firefox cache safely.

#### Scenario: Clean Firefox cache
**Given** Firefox cache exists in `~/.cache/mozilla/firefox/`
**When** browser cleanup executes
**And** Firefox is NOT running
**Then** system MUST:
- Remove `~/.cache/mozilla/firefox/*/cache2/`
- Calculate space freed
- Display: "Firefox cache cleaned (XXX MB)"

#### Scenario: Skip Firefox cleanup if running
**Given** Firefox is running (pgrep firefox)
**When** browser cleanup executes
**Then** system MUST:
- Display: "Firefox is running, skipping cache cleanup"
- Skip cleanup entirely
- Log warning

### Requirement: Chrome/Chromium Cache Cleanup
**Priority**: P1
The system SHALL clean Chrome and Chromium caches.

#### Scenario: Clean Chrome cache
**Given** Chrome cache exists in `~/.cache/google-chrome/`
**When** browser cleanup executes
**And** Chrome is NOT running
**Then** remove `~/.cache/google-chrome/Default/Cache/`

### Requirement: Profile-Aware Browser Cleanup
**Priority**: P0
The system MUST skip browser cleanup on server profile.

#### Scenario: Server profile skips browser
**Given** profile is "server"
**When** cleanup executes
**Then** browser module MUST NOT run

## Cross-References
- `safety-system`: Process detection for running browsers
- `cleanup-core`: Profile-based module enabling
