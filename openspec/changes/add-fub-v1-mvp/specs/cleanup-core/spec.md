# Cleanup Core Engine Specification

## ADDED Requirements

### Requirement: Modular Cleanup Architecture
**Priority**: P0
The system MUST implement modular cleanup architecture where each category is independent.

#### Scenario: Multi-category cleanup execution
**Given** APT, kernels, and journal cleanup enabled
**When** `fub clean` executes
**Then** each module MUST run independently and failure in one MUST NOT prevent others from executing.

### Requirement: Space Calculation
**Priority**: P1
The system MUST accurately calculate disk space to be freed before and after cleanup.

#### Scenario: Pre-cleanup space calculation
**Given** cleanup targets identified
**When** dry-run or actual cleanup starts
**Then** system MUST calculate total size using `du -sb` and display in human-readable format (MB/GB).

### Requirement: Profile-Based Category Selection
**Priority**: P0
The system MUST enable/disable cleanup categories based on detected or configured profile.

#### Scenario: Desktop profile category selection
**Given** profile is "desktop"
**When** cleanup initializes
**Then** enable: apt, kernels, journal, browser, thumbnails, temp
**And** display: "Profile: desktop (6 categories enabled)"

#### Scenario: Server profile category selection
**Given** profile is "server"
**When** cleanup initializes
**Then** enable: apt, kernels, journal, temp
**And** disable: browser, thumbnails
**And** display: "Profile: server (4 categories enabled)"

### Requirement: Cleanup Progress Reporting
**Priority**: P2
The system SHALL display progress during cleanup execution.

#### Scenario: Progress display
**Given** multi-category cleanup
**When** each category executes
**Then** display: "[1/6] Cleaning APT cache...", "[2/6] Cleaning old kernels...", etc.

## Cross-References
- All cleanup-* specs implement modules integrated via this core engine
- `safety-system`: Pre-flight validation before core execution
- `cli-interface`: User interaction with cleanup engine
