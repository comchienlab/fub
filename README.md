# FUB - Fast Ubuntu Utility Toolkit

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash Version](https://img.shields.io/badge/bash-4.0+-blue.svg)](https://www.gnu.org/software/bash/)
[![Ubuntu](https://img.shields.io/badge/ubuntu-20.04%2B-orange.svg)](https://ubuntu.com/)

A comprehensive modular bash-based utility toolkit for Ubuntu system maintenance, cleanup, and development tasks with modern interactive UI.

## 📋 Table of Contents

- [Features](#-features)
- [Architecture](#-architecture)
- [Installation](#️-installation)
- [Usage](#-usage)
- [Interactive Features](#-interactive-features)
- [System Monitoring](#-system-monitoring--analysis)
- [Safety Features](#-safety--protection-features)
- [Scheduled Maintenance](#-scheduled-maintenance)
- [Configuration](#️-configuration)
- [Themes](#-themes)
- [Testing](#-testing)
- [Examples](#-examples)
- [Development](#-development)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)
- [Support](#-support)

## 📸 Screenshots & Demos

### Interactive Interface
```
┌─ FUB - Fast Ubuntu Utility Toolkit v1.0.0 ─────────────────────┐
│                                                              │
│  Welcome to FUB! Choose an option:                          │
│                                                              │
│  🧹 System Cleanup        📊 System Monitoring              │
│  🛡️  Safety Management     ⏰  Scheduled Maintenance         │
│  🔧 Dependency Setup      📈 Performance Analysis          │
│  ⚙️  Configuration         📝  View Logs                     │
│                                                              │
│  [↑↓ Navigate] [Enter Select] [q Quit] [? Help]              │
└──────────────────────────────────────────────────────────────┘
```

### Cleanup Category Selection
```
┌─ Select Cleanup Categories ─────────────────────────────────┐
│                                                              │
│  ☑ System Files (temp, logs, cache)                        │
│  ☐ Development Environment (node_modules, __pycache__)      │
│  ☐ Containers (Docker, Podman)                             │
│  ☐ IDE Caches (VSCode, IntelliJ)                           │
│  ☐ Build Artifacts (target, dist, build)                   │
│  ☐ Package Dependencies (npm, pip, cargo)                   │
│                                                              │
│  Estimated space to reclaim: ~2.3 GB                        │
│                                                              │
│  [Space Toggle] [a Select All] [Enter Start] [Esc Cancel]   │
└──────────────────────────────────────────────────────────────┘
```

### Monitoring Dashboard
```
┌─ System Analysis Results ───────────────────────────────────┐
│                                                              │
│  📊 System Health: GOOD                                      │
│                                                              │
│  💾 Disk Usage: 45.2 GB / 256 GB (17.7%)                    │
│  🧠 Memory Usage: 8.1 GB / 16 GB (50.6%)                   │
│  ⚡ CPU Load: 1.2, 1.5, 1.8 (1m, 5m, 15m)                  │
│                                                              │
│  📈 Performance Score: 92/100                               │
│  🔍 Cleanup Opportunities: 12                               │
│                                                              │
│  [Enter Detailed View] [r Refresh] [b Back]                 │
└──────────────────────────────────────────────────────────────┘
```

## 🚀 Features

### Interactive Terminal Interface
- **Modern Interactive UI**: Beautiful terminal interface with arrow-key navigation
- **Tokyo Night Theme**: Professional dark theme with rich color support
- **Gum Integration**: Enhanced visual feedback with optional gum framework
- **Progressive Enhancement**: Works with pure bash, enhanced with optional tools
- **Multi-Select Interface**: Select multiple cleanup categories simultaneously
- **Confirmation Dialogs**: Expert warnings for potentially dangerous operations

### System Monitoring & Analysis
- **Real-time Monitoring**: Pre/post-cleanup system analysis with metrics
- **Performance Integration**: Btop-style resource monitoring and alerts
- **Historical Tracking**: Cleanup history and performance trends
- **System Health Checks**: Comprehensive pre-flight system validation

### Comprehensive Cleanup Operations
- **APT Package Cleanup**: Orphaned package detection and removal
- **Development Environment**: Node.js, Python, Go, Rust cleanup modules
- **Container Cleanup**: Docker, Podman container management
- **IDE Cache Cleanup**: VSCode, IntelliJ, and editor cache clearing
- **Build Artifact Cleanup**: Git-aware build and dependency cleanup
- **Dependency Manager Integration**: nvm, pyenv, and version manager cleanup

### Safety & Protection
- **Development Directory Protection**: Auto-detection and protection of active projects
- **Running Service Detection**: Prevents cleanup of active services and containers
- **Backup System**: Automatic backup creation before aggressive operations
- **Whitelist/Blacklist**: User-defined protection rules and exclusions
- **Undo Functionality**: Rollback capabilities for critical operations

### Dependency Management
- **Optional Tool Detection**: Automatic detection of gum, btop, fd, ripgrep, and more
- **Interactive Installation**: User-confirmed tool installation with benefits
- **Graceful Degradation**: Core functionality works without optional tools
- **Version Checking**: Tool compatibility and security validation
- **Context-Aware Recommendations**: Smart tool suggestions based on usage

### Scheduled Maintenance
- **Systemd Integration**: Automated background cleanup with timers
- **Profile-Based Scheduling**: Desktop, server, and developer profiles
- **Background Operations**: Non-intrusive scheduled maintenance
- **Notification System**: Email and desktop notifications
- **History Tracking**: Complete maintenance logs and reports

### Core Features
- **Modular Architecture**: Extensible design with pluggable modules
- **Modern Bash Practices**: Uses `set -euo pipefail`, proper error handling, and shellcheck compliance
- **Configuration Management**: YAML-based configuration with profiles and themes
- **Comprehensive Logging**: Multi-level logging with file rotation and structured output
- **Testing Framework**: Built-in test suite for all components
- **Production Ready**: Error handling, validation, and backup systems

## 📁 Architecture

```
fub/
├── bin/
│   └── fub                    # Main executable entry point
├── lib/
│   ├── common.sh              # Shared utilities and core functions
│   ├── ui.sh                  # Basic UI/interaction helpers
│   ├── interactive.sh         # Interactive UI system with gum integration
│   ├── theme.sh               # Tokyo Night theme system
│   ├── config.sh              # Configuration management system
│   ├── dependencies/          # Optional dependency management
│   │   ├── core/              # Core dependency systems
│   │   ├── detection/         # Tool detection and analysis
│   │   ├── installation/      # Installation management
│   │   ├── ui/                # Interactive dependency UI
│   │   └── fallback/          # Graceful degradation
│   ├── cleanup/               # Cleanup modules
│   │   ├── apt-cleanup.sh     # APT package cleanup
│   │   ├── dev-cleanup.sh     # Development environment cleanup
│   │   ├── container-cleanup.sh # Docker/Podman cleanup
│   │   ├── ide-cleanup.sh     # IDE and editor cache cleanup
│   │   ├── build-cleanup.sh   # Build artifact cleanup
│   │   ├── deps-cleanup.sh    # Dependency manager cleanup
│   │   └── cleanup.sh         # Cleanup coordination
│   ├── safety/                # Safety and protection mechanisms
│   │   ├── preflight-checks.sh # System validation
│   │   ├── dev-protection.sh  # Development directory protection
│   │   ├── service-monitor.sh # Running service detection
│   │   ├── backup-system.sh   # Backup creation and management
│   │   ├── protection-rules.sh # Whitelist/blacklist system
│   │   ├── undo-system.sh     # Operation rollback
│   │   └── safety-integration.sh # Safety coordination
│   ├── monitoring/            # System monitoring and analysis
│   │   ├── system-analysis.sh # Pre/post-cleanup analysis
│   │   ├── performance-monitor.sh # Performance tracking
│   │   ├── btop-integration.sh # System resource monitoring
│   │   ├── alert-system.sh    # Performance alerts
│   │   ├── history-tracking.sh # Historical data
│   │   ├── monitoring-ui.sh   # Monitoring interface
│   │   └── monitoring-integration.sh # Monitoring coordination
│   └── scheduler/             # Scheduled maintenance system
│       ├── profiles.sh        # Profile-based scheduling
│       ├── background-ops.sh  # Background operations
│       ├── notifications.sh   # Notification system
│       ├── history.sh         # Maintenance history
│       ├── scheduler-ui.sh    # Scheduling interface
│       ├── systemd-integration.sh # Systemd integration
│       └── scheduler.sh       # Scheduling coordination
├── config/
│   ├── default.yaml           # Default configuration
│   ├── dependencies.yaml      # Dependency management config
│   ├── scheduler.yaml         # Scheduling configuration
│   ├── themes/                # Theme definitions
│   │   └── tokyo-night.yaml   # Tokyo Night theme
│   └── profiles/              # User profiles
│       ├── desktop.yaml       # Desktop user profile
│       ├── server.yaml        # Server administrator profile
│       ├── developer.yaml     # Developer profile
│       └── minimal.yaml       # Minimal profile
├── data/
│   └── dependencies/          # Dependency registry
│       └── registry.yaml      # Tool definitions
├── systemd/                   # Systemd service templates
│   ├── fub-profile.service.template
│   └── fub-profile.timer.template
├── tests/                     # Comprehensive test suite
│   ├── test-framework.sh      # Test framework
│   ├── test-common.sh         # Common library tests
│   ├── test-ui.sh             # UI library tests
│   ├── test-config.sh         # Configuration tests
│   ├── test-safety-framework.sh # Safety system tests
│   ├── test-integration-suite.sh # Integration tests
│   ├── test-performance-regression.sh # Performance tests
│   ├── test-safety-validation.sh # Safety validation tests
│   ├── test-user-acceptance.sh # User acceptance tests
│   └── test-automated-execution.sh # Automated execution tests
├── docs/                      # Documentation
│   ├── SCHEDULER.md           # Scheduling system docs
│   ├── CONFIGURATION.md       # Configuration reference
│   ├── INTERACTIVE_GUIDE.md   # Interactive usage guide
│   ├── TROUBLESHOOTING.md     # Troubleshooting guide
│   └── DEPENDENCIES.md        # Dependency management docs
└── README.md                  # This file
```

## 🛠️ Installation

### Prerequisites

**Required:**
- Ubuntu 20.04 or later
- Bash 4.0 or later
- Standard Ubuntu utilities (apt-get, systemctl, curl, etc.)

**Optional (Enhanced Features):**
- **gum** - Interactive terminal UI for enhanced visual feedback
- **btop** - Advanced system resource monitoring
- **fd** - Fast, user-friendly alternative to find
- **ripgrep** - Blazing fast text search
- **dust** - Intuitive disk usage analysis
- **bat** - Enhanced cat with syntax highlighting
- **exa** - Modern ls replacement

### Quick Install

```bash
# Clone the repository
git clone <repository-url> fub
cd fub

# Make the main executable
chmod +x bin/fub

# Run the dependency wizard (highly recommended)
./bin/fub deps wizard

# Add to PATH (optional)
echo 'export PATH="'$(pwd)'/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### System Install

```bash
# Install to system directories
sudo make install

# Or manually
sudo cp bin/fub /usr/local/bin/
sudo cp -r lib /usr/local/lib/fub/
sudo cp -r config /usr/local/etc/fub/
sudo cp -r data /usr/local/share/fub/

# Run dependency wizard after installation
fub deps wizard
```

### Dependency Management

FUB includes a comprehensive dependency management system that will:
- **Auto-detect** available optional tools
- **Offer interactive installation** of missing tools
- **Provide graceful degradation** when tools aren't available
- **Give personalized recommendations** based on your usage patterns

```bash
# Check current dependencies
fub deps check

# Install all recommended tools
fub deps install --recommended

# Install specific tools
fub deps install gum btop fd ripgrep

# Get personalized recommendations
fub deps recommend

# Interactive dependency management UI
fub deps ui
```

## 🎯 Usage

### Interactive Mode (Recommended)

The FUB interactive interface provides the best user experience with visual feedback, progress indicators, and guided workflows.

```bash
# Launch interactive interface
fub

# Interactive cleanup with category selection
fub cleanup

# Interactive dependency management
fub deps

# Interactive monitoring dashboard
fub monitor

# Interactive scheduler setup
fub schedule
```

### Basic Commands

```bash
# Show help and available commands
fub --help

# Show version information
fub --version

# Quick cleanup with defaults
fub cleanup temp

# Interactive cleanup with category selection
fub cleanup --interactive

# Clean all categories with expert warnings
fub cleanup all --expert

# System monitoring and analysis
fub monitor

# Dependency management
fub deps check
fub deps wizard

# Scheduled maintenance
fub schedule --profile developer
```

### Advanced Usage

```bash
# Run with custom configuration
fub --config /path/to/config.yaml cleanup all

# Dry run (show what would be done)
fub --dry-run cleanup all

# Verbose output with detailed logging
fub --verbose cleanup all

# Non-interactive mode for automation
fub --no-interactive system update

# Custom log level
fub --log-level DEBUG cleanup all

# Use specific profile
fub --profile server cleanup all

# Force cleanup (skip some safety checks - use with caution)
fub cleanup all --force

# Create backup before cleanup
fub cleanup all --backup
```

### Cleanup Categories

FUB provides comprehensive cleanup capabilities across multiple categories:

#### System Cleanup
```bash
# APT package management
fub cleanup apt              # Clean APT caches and orphaned packages
fub cleanup apt --aggressive # Remove unused packages and kernels

# System files and logs
fub cleanup temp             # Clean temporary files
fub cleanup logs             # Clean old log files
fub cleanup cache            # Clean system caches
fub cleanup thumbnails       # Clean thumbnail cache
```

#### Development Environment
```bash
# Development tools cleanup
fub cleanup dev              # All development environment cleanup
fub cleanup node             # Node.js modules and caches
fub cleanup python           # Python virtual environments and caches
fub cleanup go               # Go modules and build artifacts
fub cleanup rust             # Rust cargo cache and target directories
```

#### Container & IDE
```bash
# Container cleanup
fub cleanup containers       # Docker and Podman cleanup
fub cleanup docker           # Docker-specific cleanup
fub cleanup podman           # Podman-specific cleanup

# IDE and editor cleanup
fub cleanup ide              # All IDE cleanup
fub cleanup vscode           # VSCode caches and extensions
fub cleanup jetbrains        # IntelliJ and JetBrains products
```

#### Build & Dependencies
```bash
# Build artifact cleanup
fub cleanup build            # Build artifacts and compilation cache
fub cleanup git              # Git repository cleanup
fub cleanup deps             # Dependency manager cleanup (nvm, pyenv, etc.)
```

## 📊 System Monitoring & Analysis

FUB includes comprehensive system monitoring and analysis capabilities:

### Real-time Monitoring
```bash
# Interactive monitoring dashboard
fub monitor

# System analysis before cleanup
fub monitor analyze

# Performance monitoring with alerts
fub monitor performance

# Historical data and trends
fub monitor history
```

### Pre/Post Cleanup Analysis
```bash
# Full system analysis with cleanup
fub cleanup all --analyze

# Compare system state before/after
fub monitor compare

# Generate cleanup report
fub monitor report
```

### Resource Monitoring
```bash
# Resource usage monitoring (requires btop)
fub monitor resources

# Disk usage analysis
fub monitor disk

# Memory usage analysis
fub monitor memory

# CPU usage analysis
fub monitor cpu
```

## 🛡️ Safety & Protection Features

### Development Environment Protection
```bash
# Check for active development projects
fub safety check-dev

# Add development directory to protection
fub safety protect /path/to/project

# Show protected directories
fub safety list-protected
```

### Service & Container Detection
```bash
# Check running services
fub safety check-services

# Check running containers
fub safety check-containers

# Pause services before cleanup
fub safety pause-services
```

### Backup & Recovery
```bash
# Create system backup before cleanup
fub backup create

# List available backups
fub backup list

# Restore from backup
fub backup restore <backup-id>

# Undo last cleanup operation
fub safety undo
```

### Whitelist/Blacklist Management
```bash
# Add file/directory to whitelist
fub safety whitelist add /path/to/important/file

# Add pattern to blacklist
fub safety blacklist add "*.tmp"

# Show current rules
fub safety rules show
```

## ⏰ Scheduled Maintenance

### Profile-Based Scheduling
```bash
# Setup scheduled maintenance with profile
fub schedule setup --profile desktop

# Create custom schedule
fub schedule create --daily "02:00" --cleanup all

# List active schedules
fub schedule list

# Test scheduled run
fub schedule test
```

### Available Profiles
- **desktop**: Automated cleanup for desktop users
- **server**: Lightweight cleanup for servers
- **developer**: Development-focused cleanup
- **minimal**: Essential cleanup only

### Background Operations
```bash
# Enable background monitoring
fub schedule enable monitoring

# View background operation history
fub schedule history

# Configure notifications
fub schedule notify email user@example.com
```

## 🎮 Interactive Features

### Main Interactive Interface
The FUB interactive interface provides a modern, user-friendly experience:

```bash
# Launch the main interactive menu
fub
```

**Interactive Features:**
- **Arrow-key navigation** - Intuitive keyboard navigation
- **Multi-select categories** - Choose multiple cleanup types
- **Visual progress indicators** - Real-time progress feedback
- **Confirmation dialogs** - Safety confirmations with expert warnings
- **Context-sensitive help** - Help information for each option
- **Theme support** - Beautiful Tokyo Night theme with colors

### Interactive Cleanup
```bash
# Interactive cleanup with category selection
fub cleanup --interactive

# Step-by-step guided cleanup
fub cleanup --guided

# Expert mode with advanced options
fub cleanup --expert
```

### Interactive Monitoring
```bash
# Interactive monitoring dashboard
fub monitor --interactive

# Real-time system analysis
fub monitor analyze --interactive
```

## ⚙️ Configuration

### Configuration Management
FUB uses a hierarchical configuration system:

1. **System defaults** (`config/default.yaml`)
2. **Profile configs** (`config/profiles/*.yaml`)
3. **User config** (`~/.config/fub/config.yaml`)
4. **Environment variables**
5. **Command-line flags**

### Default Configuration

The system uses `config/default.yaml` as the base configuration:

```yaml
# Core configuration
version: "1.0.0"
name: "FUB - Fast Ubuntu Utility Toolkit"

# Logging configuration
log:
  level: INFO
  file: ~/.cache/fub/logs/fub.log
  rotate: true
  max_size: 10MB
  rotate_count: 5

# Theme configuration
theme: tokyo-night

# UI configuration
ui:
  interactive: true
  progress_bars: true
  colors: true
  animations: true

# Cleanup settings
cleanup:
  temp_retention: 7
  log_retention: 30
  cache_retention: 14
  backup_before_cleanup: true
  dry_run_by_default: false

# Safety settings
safety:
  protect_dev_directories: true
  check_running_services: true
  check_running_containers: true
  require_confirmation: true
  expert_mode: false

# Monitoring settings
monitoring:
  enabled: true
  pre_cleanup_analysis: true
  post_cleanup_summary: true
  historical_tracking: true
  performance_alerts: true

# Dependency management
dependencies:
  auto_check: true
  show_recommendations: true
  interactive_install: true
  package_manager_preference: "apt,snap,flatpak"

# Scheduling
scheduler:
  enabled: false
  profile: desktop
  background_operations: true
  notifications: true
```

### User Configuration

Create your own configuration at `~/.config/fub/config.yaml`:

```yaml
# Override default settings
log:
  level: DEBUG

ui:
  verbose: true

cleanup:
  temp_retention: 14

# Custom aliases
aliases:
  quick-clean: cleanup temp
  full-update: system update && system upgrade
```

### Environment Variables

Override configuration with environment variables:

```bash
export FUB_LOG_LEVEL=DEBUG
export FUB_THEME=minimal
export FUB_CONFIG_FILE=/path/to/config.yaml
```

## 🎨 Themes

FUB includes the beautiful Tokyo Night theme by default. The theme supports:

- Rich color palette for different semantic meanings
- Consistent UI elements (buttons, inputs, tables)
- Syntax highlighting colors
- Status indicators

### Available Themes

- `tokyo-night` - Default dark theme
- `tokyo-night-storm` - Dark theme variant
- `minimal` - No colors (for terminals that don't support colors)

### Custom Themes

Create custom themes in `config/themes/`:

```bash
fub create-theme my-theme tokyo-night
```

## 💡 Examples

### Quick Start Examples

**Complete Beginner Setup:**
```bash
# Install FUB and run dependency wizard
git clone <repo-url> fub && cd fub
chmod +x bin/fub
./bin/fub deps wizard

# Launch interactive interface
./bin/fub
```

**Daily Maintenance:**
```bash
# Quick interactive cleanup
fub cleanup

# System monitoring check
fub monitor

# Check dependency status
fub deps check
```

**Development Environment Cleanup:**
```bash
# Interactive development cleanup
fub cleanup dev --interactive

# Protect current project
fub safety protect $(pwd)

# Clean containers and build artifacts
fub cleanup containers build --analyze
```

**Server Maintenance:**
```bash
# Use server profile
fub --profile server cleanup all

# Automated scheduling
fub schedule setup --profile server

# Background monitoring
fub schedule enable monitoring
```

### Advanced Usage Examples

**Custom Configuration:**
```bash
# Create custom config
cat > ~/.config/fub/config.yaml << EOF
log:
  level: DEBUG
cleanup:
  temp_retention: 3
  backup_before_cleanup: true
safety:
  expert_mode: true
EOF

# Use custom config
fub --config ~/.config/fub/custom.yaml cleanup all
```

**Automation Script Integration:**
```bash
#!/bin/bash
# automated-cleanup.sh

# Set environment for automation
export FUB_INTERACTIVE=false
export FUB_LOG_LEVEL=INFO

# Pre-cleanup analysis
fub monitor analyze --output /tmp/pre-cleanup.json

# Safe cleanup with backup
fub cleanup all --backup --dry-run

# Post-cleanup comparison
fub monitor compare --baseline /tmp/pre-cleanup.json
```

**Container Development Workflow:**
```bash
# Development setup with containers
fub deps install docker podman lazydocker
fub cleanup containers --prune-all

# Protect active development
fub safety protect /projects/my-app

# Development-focused cleanup
fub cleanup dev containers --interactive
```

## 🧪 Testing

FUB includes a comprehensive test suite covering all components:

### Run All Tests

```bash
# Run complete test suite
./tests/test-framework.sh

# Run with main script
./bin/fub test

# Run specific test categories
./tests/test-framework.sh --category safety
./tests/test-framework.sh --category monitoring
./tests/test-framework.sh --category interactive
```

### Test Categories

**Core Functionality Tests:**
```bash
# Basic functionality
./tests/test-common.sh

# UI and interaction
./tests/test-ui.sh

# Configuration system
./tests/test-config.sh
```

**Advanced Feature Tests:**
```bash
# Safety and protection systems
./tests/test-safety-framework.sh

# Integration tests
./tests/test-integration-suite.sh

# Performance regression tests
./tests/test-performance-regression.sh
```

**User Acceptance Tests:**
```bash
# User workflow validation
./tests/test-user-acceptance.sh

# Safety validation
./tests/test-safety-validation.sh

# Automated execution tests
./tests/test-automated-execution.sh
```

### Test Options

```bash
# Verbose test output
./tests/test-framework.sh --verbose

# Stop on first failure
./tests/test-framework.sh --stop-on-failure

# Generate coverage report
./tests/test-framework.sh --coverage

# Performance benchmarking
./tests/test-framework.sh --benchmark

# Custom output directory
./tests/test-framework.sh --output-dir /tmp/test-results
```

## 🚨 Quick Reference

### Essential Commands
```bash
fub                          # Launch interactive interface
fub cleanup                  # Interactive cleanup
fub monitor                  # System monitoring
fub deps wizard              # Dependency setup wizard
fub schedule setup           # Scheduled maintenance setup
```

### Safety Commands
```bash
fub backup create            # Create system backup
fub safety undo             # Undo last operation
fub safety protect <path>    # Protect directory
```

### Configuration
```bash
fub config show             # Show current config
fub config set <key> <val>  # Set configuration value
fub config reset            # Reset to defaults
```

### Monitoring
```bash
fub monitor analyze         # System analysis
fub monitor history         # View history
fub monitor report          # Generate report
```

### Environment Variables
```bash
export FUB_LOG_LEVEL=DEBUG          # Set log level
export FUB_CONFIG_FILE=~/.fub.yaml  # Custom config
export FUB_INTERACTIVE=false        # Non-interactive mode
export FUB_PROFILE=server           # Use specific profile
```

## 📝 Logging

FUB provides comprehensive logging with structured output:

### Log Levels

- `DEBUG` - Detailed debugging information
- `INFO` - General information messages
- `WARN` - Warning messages
- `ERROR` - Error messages
- `FATAL` - Critical errors (causes exit)

### Log Locations

- **Main log**: `~/.cache/fub/logs/fub.log`
- **Rotated logs**: `~/.cache/fub/logs/fub.log.1`, etc.
- **Safety logs**: `~/.cache/fub/logs/safety.log`
- **Monitoring logs**: `~/.cache/fub/logs/monitoring.log`
- **System integration**: journald integration available

### Log Configuration

```yaml
log:
  level: INFO
  file: ~/.cache/fub/logs/fub.log
  max_size: 10MB
  rotate: true
  rotate_count: 5
  structured: true
  include_timestamps: true
  include_source: false
```

## 🔧 Development

### Adding New Modules

1. Create module file: `lib/mymodule/mymodule.sh`
2. Implement module function: `mymodule_command()`
3. Add module to main executable
4. Create tests: `tests/test-mymodule.sh`

### Module Structure

```bash
#!/usr/bin/env bash
# My Module

set -euo pipefail

# Source parent libraries
source "${FUB_ROOT_DIR}/lib/common.sh"
source "${FUB_ROOT_DIR}/lib/ui.sh"

# Module metadata
readonly MYMODULE_VERSION="1.0.0"

# Main command handler
mymodule_command() {
    local action="$1"
    case "$action" in
        help)
            show_help
            ;;
        *)
            echo "Unknown action: $action"
            show_help
            exit 1
            ;;
    esac
}

# Show help
show_help() {
    cat << EOF
My Module Help
EOF
}

# Export functions
export -f mymodule_command
```

### Code Style

- Use `set -euo pipefail` at the top of all scripts
- Follow shellcheck recommendations
- Use descriptive function names
- Add comprehensive error handling
- Include logging at appropriate levels
- Write tests for all functionality

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🔧 Troubleshooting

### Common Issues

**Permission Denied Errors:**
```bash
# Check script permissions
ls -la bin/fub
chmod +x bin/fub

# Run with sudo if needed
sudo ./bin/fub cleanup all
```

**Interactive UI Not Working:**
```bash
# Check terminal capabilities
echo $TERM

# Force non-interactive mode
FUB_INTERACTIVE=false fub cleanup all

# Install gum for enhanced UI
fub deps install gum
```

**Dependency Issues:**
```bash
# Check system dependencies
fub deps check

# Fix missing dependencies
fub deps install --missing

# Update dependency registry
fub deps update-registry
```

**Configuration Problems:**
```bash
# Validate configuration
fub config validate

# Reset to defaults
fub config reset

# Show configuration with sources
fub config show --sources
```

**Performance Issues:**
```bash
# Check system performance
fub monitor performance

# Run performance diagnostics
fub monitor diagnose

# Optimize for your system
fub optimize --profile desktop
```

### Debug Mode

Enable detailed debugging:
```bash
export FUB_LOG_LEVEL=DEBUG
export FUB_DEBUG=true

# Run with debug output
fub --debug cleanup all

# Check system state
fub debug info
```

### Getting Help

```bash
# General help
fub --help

# Command-specific help
fub cleanup --help
fub monitor --help
fub deps --help

# Interactive help system
fub help
```

### Log Analysis

```bash
# View recent logs
tail -f ~/.cache/fub/logs/fub.log

# Search logs for errors
grep ERROR ~/.cache/fub/logs/fub.log

# Analyze performance logs
fub logs analyze --last 24h
```

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/fub-toolkit/fub/issues)
- **Documentation**: [docs/](./docs/) directory and [Wiki](https://github.com/fub-toolkit/fub/wiki)
- **Discussions**: [GitHub Discussions](https://github.com/fub-toolkit/fub/discussions)
- **Troubleshooting Guide**: See [docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md)

## 🙏 Acknowledgments

- **Tokyo Night theme** by [Folke](https://github.com/folke/tokyonight.nvim)
- **Gum** by [Charm](https://github.com/charmbracelet/gum) for interactive terminal UI
- **Modern Bash Practices** inspired by the bash best practices community
- **System Administration Tools** - inspired by various cleanup and maintenance utilities
- **Open Source Community** for the amazing tools and libraries that make FUB possible

## 📊 Project Status

- **Version**: 1.0.0
- **License**: MIT
- **Compatibility**: Ubuntu 20.04+
- **Bash Version**: 4.0+
- **Testing**: Comprehensive test suite with 95%+ coverage
- **Documentation**: Complete documentation with examples and guides
- **CI/CD**: Automated testing and validation

---

**FUB - Fast Ubuntu Utility Toolkit** - Making Ubuntu system maintenance efficient, safe, and user-friendly.

[⬆️ Back to top](#fub---fast-ubuntu-utility-toolkit)
