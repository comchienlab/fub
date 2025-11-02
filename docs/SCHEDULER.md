# FUB Scheduler Documentation

The FUB Scheduler is a comprehensive scheduled maintenance system that provides automated cleanup operations with profile-based scheduling, systemd integration, and robust safety features.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Profiles](#profiles)
- [Commands](#commands)
- [Integration](#integration)
- [Safety Features](#safety-features)
- [Troubleshooting](#troubleshooting)
- [API Reference](#api-reference)

## Overview

The FUB Scheduler provides automated system maintenance with the following capabilities:

- **Profile-based Scheduling**: Different scheduling profiles for desktop, server, and developer environments
- **Systemd Integration**: User-level systemd timers and services for reliable scheduling
- **Background Operations**: Non-interactive execution with proper resource limits
- **Comprehensive Logging**: Detailed logging with desktop/email notifications
- **History Tracking**: Historical data about scheduled operations with analytics
- **Safety Integration**: Integration with FUB's safety system for reliable operations

## Features

### Core Features

- **Automated Scheduling**: Schedule cleanup operations using systemd timers
- **Multiple Profiles**: Pre-configured profiles for different use cases
- **Resource Management**: CPU, memory, and I/O limits for background operations
- **Condition-based Execution**: Execute operations only when system conditions are favorable
- **Comprehensive Monitoring**: Track operation success, duration, and space savings
- **Rollback Capabilities**: Automatic rollback on operation failure

### Advanced Features

- **Predictive Maintenance**: AI-powered suggestions based on historical data
- **Performance Analytics**: Trend analysis and performance optimization
- **Notification System**: Desktop notifications, email reports, and systemd journal integration
- **Custom Profiles**: Create custom scheduling profiles
- **Integration Hooks**: Integration with monitoring and safety systems

## Architecture

```
FUB Scheduler Architecture
├── Core Components
│   ├── scheduler.sh              - Main scheduler functionality
│   ├── systemd-integration.sh    - Systemd timer management
│   ├── profiles.sh               - Profile-based scheduling
│   ├── background-ops.sh         - Background operations
│   ├── notifications.sh          - Logging and notifications
│   ├── history.sh                - Maintenance history tracking
│   └── scheduler-integration.sh  - Safety system integration
├── User Interface
│   └── scheduler-ui.sh           - Interactive management interface
├── Configuration
│   ├── scheduler.yaml            - Main scheduler configuration
│   └── profiles/                 - Profile-specific configurations
├── System Integration
│   └── systemd/                  - Systemd unit templates
└── Data Storage
    ├── ~/.local/share/fub/       - State and history data
    ├── ~/.config/fub/            - User configuration
    └── ~/.cache/fub/             - Logs and cache
```

## Installation

### Prerequisites

- Ubuntu 20.04 or later
- Bash 4.0 or later
- Systemd user services enabled
- Standard Ubuntu utilities

### Installation Steps

1. **Ensure FUB is installed**:
   ```bash
   # FUB should already be installed in /usr/local/bin/fub
   fub --version
   ```

2. **Initialize scheduler**:
   ```bash
   fub scheduler init
   ```

3. **Verify systemd user services**:
   ```bash
   systemctl --user list-units --type=timer
   ```

4. **Test scheduler functionality**:
   ```bash
   fub scheduler test
   ```

## Quick Start

### Basic Usage

1. **View available profiles**:
   ```bash
   fub scheduler profiles
   ```

2. **Enable a profile**:
   ```bash
   fub scheduler enable desktop
   ```

3. **Check scheduler status**:
   ```bash
   fub scheduler status
   ```

4. **View active timers**:
   ```bash
   fub scheduler list
   ```

### Interactive Management

1. **Launch scheduler UI**:
   ```bash
   fub scheduler-ui menu
   ```

2. **Run maintenance manually**:
   ```bash
   fub scheduler run desktop --force
   ```

## Configuration

### Main Configuration

The main scheduler configuration is located at `~/.config/fub/scheduler.yaml`:

```yaml
# Global scheduler settings
scheduler:
  version: "1.0.0"
  auto_cleanup: true
  global_notifications: true

# Resource limits
resource_limits:
  default_memory: "512M"
  default_cpu: "50%"
  default_io_priority: 7
  default_nice_level: 10
  default_timeout: 1800

# Background conditions
conditions:
  default: "ac_power,system_load"
  strict: "ac_power,system_load,idle_time,disk_space"
  minimal: "system_load"

# History settings
history:
  retention_days: 90
  analysis_enabled: true
  auto_report: false
  report_interval: 7
```

### Environment Variables

Override configuration with environment variables:

```bash
export FUB_NOTIFICATION_LEVEL=DEBUG
export FUB_SCHEDULER_AUTO_CLEANUP=true
export FUB_HISTORY_RETENTION_DAYS=180
```

## Profiles

### Built-in Profiles

#### Desktop Profile
- **Schedule**: Daily at 6:00 PM
- **Operations**: temp, cache, thumbnails
- **Notifications**: Enabled
- **Conditions**: AC power, system idle for 5 minutes

```yaml
name: desktop
schedule: daily 18:00
operations:
  - temp
  - cache
  - thumbnails
notifications: true
conditions:
  - ac_power: true
  - idle_time: 300
```

#### Server Profile
- **Schedule**: Daily at 2:00 AM
- **Operations**: temp, cache, logs
- **Notifications**: Disabled
- **Conditions**: System load < 0.8

```yaml
name: server
schedule: daily 02:00
operations:
  - temp
  - cache
  - logs
notifications: false
conditions:
  - system_load: < 0.8
```

#### Developer Profile
- **Schedule**: Hourly
- **Operations**: temp, build_cache, npm_cache, docker_cache
- **Notifications**: Enabled
- **Conditions**: No active git operations or compilation

```yaml
name: developer
schedule: hourly
operations:
  - temp
  - build_cache
  - npm_cache
  - docker_cache
conditions:
  - no_git_operations: true
  - no_active_compilation: true
```

### Custom Profiles

Create custom profiles:

```bash
# Interactive profile creation
fub scheduler-ui menu
# Select "Create Custom Profile"

# Or programmatically
fub profiles create my-profile \
  --description "My custom maintenance profile" \
  --schedule "daily 20:00" \
  --operations "temp cache logs"
```

Custom profile configuration:

```yaml
name: my-profile
description: My custom maintenance profile
schedule: daily 20:00
operations:
  - temp
  - cache
  - logs
notifications: true
resource_limits:
  memory: 1G
  cpu: 40%
conditions:
  - ac_power: true
  - system_load: < 1.2
```

## Commands

### Scheduler Commands

```bash
# Initialize scheduler
fub scheduler init

# Show scheduler status
fub scheduler status

# Enable a profile
fub scheduler enable <profile-name>

# Disable a profile
fub scheduler disable <profile-name>

# Run maintenance manually
fub scheduler run <profile-name> [--force]

# List active timers
fub scheduler list

# View maintenance history
fub scheduler history [--days N] [--profile <profile>]

# View statistics
fub scheduler stats [--days N]

# Generate report
fub scheduler report

# Test scheduler
fub scheduler test

# Perform maintenance
fub scheduler maintenance

# Get suggestions
fub scheduler suggest
```

### Interactive UI Commands

```bash
# Launch main menu
fub scheduler-ui menu

# Show status directly
fub scheduler-ui status

# Launch profile management
fub scheduler-ui profiles
```

### Profile Management Commands

```bash
# List profiles
fub profiles list

# Create profile
fub profiles create <name> --description "desc" --schedule "daily" --operations "temp cache"

# Delete profile
fub profiles delete <name>

# Show profile status
fub profiles status <name>

# Suggest profile
fub profiles suggest
```

## Integration

### Systemd Integration

The scheduler integrates with systemd user services:

```bash
# List FUB timers
systemctl --user list-timers fub-*

# Check timer status
systemctl --user status fub-desktop.timer

# View timer logs
journalctl --user -u fub-desktop.service

# Enable/disable timers
systemctl --user enable fub-desktop.timer
systemctl --user disable fub-desktop.timer
```

### Safety System Integration

The scheduler integrates with FUB's safety system:

```bash
# Check safety integration status
fub scheduler-integration status

# Run safe maintenance
fub scheduler safe-run desktop --safety-level conservative
```

### Monitoring Integration

Integrate with monitoring systems:

```bash
# Export metrics
fub scheduler export-metrics --format prometheus

# Health check
fub scheduler health-check
```

## Safety Features

### Pre-operation Checks

- **System Load**: Verify system load is within acceptable limits
- **Disk Space**: Ensure sufficient disk space for operations
- **Power Management**: Check AC power status for laptops
- **Service Conflicts**: Detect conflicts with system maintenance
- **Development Environment**: Check for active development work

### Resource Limits

- **Memory Limits**: Prevent memory exhaustion
- **CPU Limits**: Limit CPU usage percentage
- **I/O Priority**: Set I/O scheduling priority
- **Nice Level**: Adjust process priority
- **Timeout**: Maximum execution time

### Rollback Capabilities

- **Backup Points**: Automatic backup before major operations
- **Undo System**: Undo changes on failure
- **Service Recovery**: Automatic service recovery
- **Emergency Stop**: Immediate operation termination

### Safety Levels

- **Conservative**: Maximum safety, minimal automation
- **Standard**: Balanced safety and automation (default)
- **Aggressive**: Maximum automation, minimal safety checks

## Troubleshooting

### Common Issues

#### Timer Not Running

```bash
# Check systemd user services
systemctl --user status

# Enable user services
loginctl enable-linger $(whoami)

# Restart user session
systemctl --user daemon-reload
```

#### Operations Failing

```bash
# Check logs
fub scheduler history --days 1 --profile desktop

# Check systemd logs
journalctl --user -u fub-desktop.service

# Run with debug
fub scheduler run desktop --debug
```

#### High Resource Usage

```bash
# Check background operations
fub background list-running

# Stop operation
fub background stop <operation-name>

# Adjust resource limits
fub config set resource_limits.memory 256M
```

#### Configuration Issues

```bash
# Validate configuration
fub scheduler test

# Reset configuration
rm ~/.config/fub/scheduler.yaml
fub scheduler init
```

### Debug Mode

Enable debug logging:

```bash
export FUB_LOG_LEVEL=DEBUG
fub scheduler status
```

### Log Files

Check log files for detailed information:

```bash
# Main scheduler log
tail -f ~/.cache/fub/logs/fub.log

# Background operations log
tail -f ~/.cache/fub/logs/background/*.log

# Notification log
tail -f ~/.cache/fub/logs/notifications.log
```

## API Reference

### Core Functions

#### `init_scheduler()`
Initialize the scheduler system.

#### `scheduler_command(action, ...)`
Main command handler for scheduler operations.

#### `execute_safe_scheduled_maintenance(profile, force, operations)`
Execute scheduled maintenance with safety checks.

#### `enable_profile(profile_name)`
Enable a maintenance profile.

#### `disable_profile(profile_name)`
Disable a maintenance profile.

### Integration Functions

#### `init_scheduler_integration()`
Initialize scheduler integration with safety systems.

#### `perform_pre_operation_checks(profile, operations)`
Perform safety checks before operations.

#### `handle_maintenance_failure(profile, backup_id, error_details)`
Handle operation failures with rollback.

### Background Operations

#### `execute_background_operation(name, command, conditions, memory_limit, timeout)`
Execute operation in background with resource limits.

#### `check_background_conditions(conditions)`
Check if conditions are favorable for background execution.

### History and Analytics

#### `record_maintenance_operation(...)`
Record maintenance operation in history.

#### `get_operation_statistics(days)`
Get maintenance operation statistics.

#### `generate_maintenance_suggestions()`
Generate predictive maintenance suggestions.

### Notifications

#### `send_notification(level, title, message, operation)`
Send notification with specified level.

#### `init_notifications()`
Initialize notification system.

## License

The FUB Scheduler is part of the FUB project and is licensed under the MIT License.

## Support

- **Issues**: [GitHub Issues](https://github.com/fub-toolkit/fub/issues)
- **Documentation**: [FUB Wiki](https://github.com/fub-toolkit/fub/wiki)
- **Discussions**: [GitHub Discussions](https://github.com/fub-toolkit/fub/discussions)