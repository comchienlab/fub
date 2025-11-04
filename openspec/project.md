# Project Context

## Purpose

FUB (Filesystem Ubuntu Buddy) is a terminal-based cleanup utility for Ubuntu, inspired by Mole for macOS. The project aims to provide Ubuntu users with a simple, safe, and effective tool to reclaim disk space by cleaning system caches, old kernels, and temporary files.

**Tagline**: "Dig deep like a mole to clean your Ubuntu"

## Tech Stack

- **Primary Language**: Bash 4.0+ (pure shell script, no external dependencies)
- **Target Platform**: Ubuntu 20.04 LTS, 22.04 LTS, 24.04 LTS
- **Terminal Interface**: ANSI escape sequences, Unicode box drawing characters
- **Installation**: One-command curl installation
- **Package Management**: APT, systemd journal management

## Project Conventions

### Code Style

- **Strict Error Handling**: All scripts use `set -Eeuo pipefail`
- **ShellCheck Compliance**: Zero errors required for all code
- **Function Naming**: Descriptive names with underscores (e.g., `calculate_border_width`)
- **Variable Naming**: Uppercase for globals, lowercase for locals
- **Comments**: Complex logic documented, safety-critical sections clearly marked

### Architecture Patterns

- **Single Executable Design**: One main `fub` script with modular functions
- **Safety-First Design**: Dry-run mode, confirmation prompts, kernel protection
- **Graceful Degradation**: Fallback mechanisms for different terminal capabilities
- **Modular Cleanup**: Separate functions for each cleanup category

### Testing Strategy

- **Platform Testing**: Validate on Ubuntu 20.04, 22.04, 24.04
- **Safety Testing**: Extensive testing for kernel cleanup (VM snapshots)
- **Terminal Compatibility**: Test across different terminal emulators
- **Error Scenarios**: Verify graceful handling of edge cases

### Git Workflow

- **Feature Branches**: Use descriptive branch names
- **Commit Messages**: Clear, conventional commits with scope
- **Pull Requests**: Required for all changes
- **Version Tags**: Semantic versioning (v1.0.0, v1.1.0, etc.)

## Domain Context

### Ubuntu System Administration

- **Package Management**: APT cache cleanup with lock detection
- **Kernel Management**: Safe removal of old kernels with GRUB updates
- **Systemd Journal**: Log rotation and size management
- **Browser Caches**: Firefox, Chrome, Chromium profile detection
- **User Directories**: Safe cache cleaning with important exclusions

### Safety Considerations

- **Never remove current kernel**: Triple validation required
- **Respect running processes**: Skip browser caches when browsers are running
- **Honor system locks**: Skip APT operations when package management is active
- **Provide dry-run mode**: Always show what will be changed before execution

## Important Constraints

### Technical Constraints

- **Zero External Dependencies**: Only use standard Ubuntu system tools
- **Pure Bash Implementation**: No Python, Node.js, or compiled languages
- **Cross-Version Compatibility**: Must work on Ubuntu 20.04-24.04 LTS
- **Terminal Compatibility**: Must work on basic terminals without advanced features

### Safety Constraints

- **Zero Data Loss**: No accidental deletion of user files
- **System Stability**: Never make system unbootable
- **Reversible Operations**: All changes should be recoverable
- **Clear Warnings**: Users must understand what will be changed

### Performance Constraints

- **Fast Installation**: <30 seconds for complete setup
- **Quick Execution**: Cleanup operations should complete in minutes
- **Small Footprint**: <1MB installed size
- **Minimal Resource Usage**: Low CPU and memory consumption

## External Dependencies

### System Tools (Standard Ubuntu)

- `apt-get`: Package management and cache operations
- `dpkg`: Package query operations
- `journalctl`: Systemd journal management
- `systemctl`: Service status detection
- `uname`: Kernel information
- `find`, `rm`, `du`: File operations
- `lsb_release`: Ubuntu version detection
- `tput`: Terminal capability detection

### Installation Dependencies

- `curl`: For one-command installation downloads
- `bash`: Shell environment (version 4.0+)
- Standard POSIX utilities: `grep`, `sed`, `awk`, etc.

### No External Libraries

- **No runtime dependencies**: Everything is self-contained
- **No package managers**: No npm, pip, cargo, etc.
- **No compiled code**: Pure shell script implementation
- **No configuration files**: Runtime configuration via command line only
