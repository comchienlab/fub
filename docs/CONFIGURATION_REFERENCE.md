# FUB Complete Configuration Reference

A comprehensive guide to all configuration options, settings, and customization features in FUB.

## 📋 Table of Contents

- [Configuration Overview](#configuration-overview)
- [Configuration Files & Locations](#configuration-files--locations)
- [Core Application Settings](#core-application-settings)
- [User Interface Configuration](#user-interface-configuration)
- [Cleanup System Configuration](#cleanup-system-configuration)
- [Safety & Protection Configuration](#safety--protection-configuration)
- [Monitoring & Analysis Configuration](#monitoring--analysis-configuration)
- [Dependency Management Configuration](#dependency-management-configuration)
- [Scheduler Configuration](#scheduler-configuration)
- [Profile System Configuration](#profile-system-configuration)
- [Theme System Configuration](#theme-system-configuration)
- [Network Configuration](#network-configuration)
- [Logging Configuration](#logging-configuration)
- [Environment Variables](#environment-variables)
- [Command Line Options](#command-line-options)
- [Configuration Validation](#configuration-validation)
- [Custom Configuration Examples](#custom-configuration-examples)

## 🎯 Configuration Overview

FUB uses a hierarchical configuration system with multiple levels of customization:

### Configuration Hierarchy (Highest to Lowest Priority)

1. **Command-line arguments** - Direct command-line options
2. **Environment variables** - `FUB_*` environment variables
3. **User configuration** - `~/.config/fub/config.yaml`
4. **Profile configuration** - Selected profile (`config/profiles/*.yaml`)
5. **System defaults** - `config/default.yaml`
6. **Built-in defaults** - Hardcoded fallback values

### Configuration File Types

| Type | Location | Purpose | Override Order |
|------|----------|---------|----------------|
| System defaults | `config/default.yaml` | Base system configuration | 5 |
| User config | `~/.config/fub/config.yaml` | User customizations | 3 |
| Profile configs | `config/profiles/*.yaml` | Profile-specific settings | 4 |
| Dependency config | `config/dependencies.yaml` | Dependency management | 4 |
| Scheduler config | `config/scheduler.yaml` | Scheduling system | 4 |
| Theme configs | `config/themes/*.yaml` | Theme definitions | 4 |

## 📁 Configuration Files & Locations

### System Configuration Files

#### Default Configuration (`config/default.yaml`)

```yaml
# FUB Default Configuration
# Core application settings
version: "1.0.0"
name: "FUB - Fast Ubuntu Utility Toolkit"
description: "Comprehensive Ubuntu utility toolkit for system maintenance"

# Logging configuration
log:
  level: INFO                    # DEBUG, INFO, WARN, ERROR, FATAL
  file: ~/.cache/fub/logs/fub.log
  rotate: true
  max_size: 10MB
  rotate_count: 5
  structured: true
  include_timestamps: true
  include_source: false

# Theme configuration
theme: tokyo-night              # Default theme

# UI configuration
ui:
  interactive: true
  progress_bars: true
  colors: true
  animations: true
  confirmations: true
  expert_mode: false
  menu_height: 10
  scroll_threshold: 5

# Timeout settings
timeout: 30                     # Default operation timeout in seconds

# Network settings
network:
  timeout: 10                   # Network timeout in seconds
  retries: 3                    # Number of retry attempts

# Dry run mode
dry_run: false                  # Show what would be done without executing

# Cleanup settings
cleanup:
  temp_retention: 7             # Days to keep temporary files
  log_retention: 30             # Days to keep log files
  cache_retention: 14           # Days to keep cache files
  backup_before_cleanup: true   # Create backup before cleanup
  dry_run_by_default: false     # Default to dry run mode
  aggressive_mode: false        # Enable aggressive cleanup

# Safety settings
safety:
  protect_dev_directories: true # Protect development directories
  check_running_services: true  # Check for running services
  check_running_containers: true # Check for running containers
  require_confirmation: true    # Require confirmation for dangerous operations
  expert_mode: false            # Expert mode disables some safety checks

# Monitoring settings
monitoring:
  enabled: true                 # Enable system monitoring
  pre_cleanup_analysis: true    # Analyze system before cleanup
  post_cleanup_summary: true    # Show post-cleanup summary
  historical_tracking: true     # Track historical data
  performance_alerts: true      # Enable performance alerts
  alert_threshold: 85           # Alert threshold percentage

# Dependency management
dependencies:
  auto_check: true              # Automatically check for dependencies
  show_recommendations: true    # Show tool recommendations
  interactive_install: true     # Interactive installation prompts
  package_manager_preference: "apt,snap,flatpak"

# Scheduler settings
scheduler:
  enabled: false                # Enable scheduled maintenance
  profile: desktop              # Default profile for scheduling
  background_operations: true   # Enable background operations
  notifications: true           # Enable notifications
```

### User Configuration File

#### User Configuration (`~/.config/fub/config.yaml`)

```yaml
# FUB User Configuration
# Override system defaults with user preferences

# Logging preferences
log:
  level: INFO                   # Override log level
  file: ~/.local/share/fub/logs/fub.log  # Custom log location
  structured: true              # Use structured logging

# UI preferences
ui:
  interactive: true             # Enable interactive interface
  colors: true                  # Enable colors
  animations: true             # Enable animations
  theme_variant: "dark"         # Theme variant (dark/light/auto)
  show_icons: true             # Show icons in interface
  high_contrast: false         # High contrast mode
  large_text: false            # Large text mode

# Cleanup preferences
cleanup:
  temp_retention: 3             # Keep temp files for 3 days
  log_retention: 14             # Keep logs for 14 days
  cache_retention: 7            # Keep cache for 7 days
  backup_before_cleanup: true   # Always create backup
  require_confirmation: true    # Require confirmation

# Safety preferences
safety:
  expert_mode: false            # Keep safety protections
  protect_dev_directories: true # Protect development directories
  protected_directories:        # Additional protected directories
    - "~/projects/*"
    - "~/work/*"
    - "~/git/*"

# Monitoring preferences
monitoring:
  enabled: true                 # Enable monitoring
  performance_alerts: true      # Enable performance alerts
  alert_threshold: 85           # Alert threshold
  historical_tracking: true     # Track historical data

# User preferences
preferences:
  default_profile: desktop      # Default user profile
  auto_check_dependencies: true # Auto-check dependencies
  show_recommendations: true    # Show recommendations
  notifications: true          # Enable notifications
  startup_wizard: false        # Don't show startup wizard

# Custom rules and patterns
custom_rules:
  preserve_patterns:            # File patterns to never delete
    - "*.important"
    - "*.keep"
    - ".*.swp"
    - "*.config"

  exclude_patterns:             # File patterns to exclude from cleanup
    - "*.tmp"
    - "*.bak"
    - "*~"
    - ".DS_Store"
    - "*.log.*"

# Performance settings
performance:
  max_workers: 4                # Maximum parallel operations
  memory_limit: "1G"            # Memory usage limit
  io_priority: 7                # I/O priority (0-7, lower is higher priority)
  parallel_operations: true     # Enable parallel operations
```

## ⚙️ Core Application Settings

### Application Configuration

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `version` | string | "1.0.0" | Application version |
| `name` | string | "FUB - Fast Ubuntu Utility Toolkit" | Application name |
| `description` | string | "Comprehensive Ubuntu utility toolkit" | Application description |
| `data_dir` | string | "~/.local/share/fub" | Data storage directory |
| `cache_dir` | string | "~/.cache/fub" | Cache directory |
| `config_dir` | string | "~/.config/fub" | Configuration directory |
| `runtime_dir` | string | "/tmp/fub" | Runtime directory |
| `timeout` | integer | 30 | Default operation timeout (seconds) |

### Directory Configuration

```yaml
# Directory structure configuration
directories:
  data_dir: ~/.local/share/fub    # Data files, backups, history
  cache_dir: ~/.cache/fub         # Cache files, temporary data
  config_dir: ~/.config/fub       # User configuration files
  log_dir: ~/.cache/fub/logs      # Log files
  runtime_dir: /tmp/fub           # Runtime files and locks
  backup_dir: ~/.local/share/fub/backups  # Backup storage
  profile_dir: ~/.config/fub/profiles     # User profiles
  theme_dir: ~/.config/fub/themes         # User themes

# Runtime configuration
runtime:
  lock_file: ~/.cache/fub/fub.lock      # Operation lock file
  pid_file: ~/.cache/fub/fub.pid        # PID file
  socket_file: ~/.cache/fub/fub.sock    # Unix socket for IPC
  temp_dir: /tmp/fub                    # Temporary working directory

# User agent and identification
identification:
  user_agent: "FUB/1.0.0"              # User agent for network requests
  instance_id: "auto"                   # Unique instance identifier
  session_id: "auto"                    # Session identifier
```

## 🎨 User Interface Configuration

### UI Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `ui.interactive` | boolean | true | Enable interactive interface |
| `ui.colors` | boolean | true | Enable colors in output |
| `ui.animations` | boolean | true | Enable interface animations |
| `ui.progress_bars` | boolean | true | Show progress bars |
| `ui.confirmations` | boolean | true | Require confirmations |
| `ui.expert_mode` | boolean | false | Enable expert mode features |
| `ui.theme_variant` | string | "dark" | Theme variant (dark/light/auto) |
| `ui.menu_height` | integer | 10 | Menu height for interactive interfaces |
| `ui.scroll_threshold` | integer | 5 | Scroll threshold for long lists |
| `ui.show_icons` | boolean | true | Show icons in interfaces |
| `ui.unicode_symbols` | boolean | true | Use Unicode symbols |

### Complete UI Configuration

```yaml
# User interface configuration
ui:
  # Basic interface settings
  interactive: true               # Enable interactive menus and prompts
  colors: true                    # Use colors in terminal output
  animations: true                # Enable smooth animations
  progress_bars: true             # Show progress bars for operations
  confirmations: true             # Require confirmation for dangerous operations

  # Advanced interface settings
  expert_mode: false              # Disable expert mode by default
  theme_variant: "dark"           # Theme variant: dark, light, auto
  menu_height: 10                 # Height of interactive menus
  scroll_threshold: 5             # When to enable scrolling in long lists

  # Visual elements
  show_icons: true                # Show icons in interfaces
  unicode_symbols: true           # Use Unicode symbols for better visuals
  compact_mode: false             # Compact display mode
  wide_mode: false                # Wide display mode for large screens

  # Accessibility settings
  high_contrast: false            # High contrast mode for accessibility
  large_text: false               # Large text mode for better readability
  screen_reader: false            # Screen reader compatible output
  reduced_motion: false           # Reduce animations for accessibility

  # Interaction settings
  timeout: 60                     # Auto-timeout for interactive prompts (seconds)
  default_action: "prompt"        # Default action when ambiguous
  remember_choices: true          # Remember user choices across sessions
  auto_select_defaults: false     # Auto-select default options

  # Help and documentation
  show_tips: true                 # Show usage tips and hints
  context_help: true              # Show context-sensitive help
  welcome_message: true           # Show welcome message on startup
  show_shortcuts: true            # Show keyboard shortcuts

  # Sound settings
  enable_sounds: false            # Enable sound effects
  completion_sound: false         # Play sound on completion
  error_sound: false              # Play sound on errors

  # Advanced UI features
  multi_select: true              # Enable multi-selection in menus
  search_in_menus: true           # Enable search in menu navigation
  filter_options: true            # Enable option filtering
  preview_mode: true              # Enable preview mode for selections

  # Performance settings
  max_fps: 30                     # Maximum frames per second for animations
  animation_speed: "normal"       # Animation speed: slow, normal, fast
  render_ahead: true              # Pre-render UI elements
  cache_ui_elements: true         # Cache UI elements for performance
```

## 🧹 Cleanup System Configuration

### Cleanup Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `cleanup.temp_retention` | integer | 7 | Days to keep temporary files |
| `cleanup.log_retention` | integer | 30 | Days to keep log files |
| `cleanup.cache_retention` | integer | 14 | Days to keep cache files |
| `cleanup.backup_before_cleanup` | boolean | true | Create backup before cleanup |
| `cleanup.dry_run_by_default` | boolean | false | Default to dry run mode |
| `cleanup.aggressive_mode` | boolean | false | Enable aggressive cleanup |
| `cleanup.follow_symlinks` | boolean | false | Follow symbolic links |
| `cleanup.respect_permissions` | boolean | true | Respect file permissions |

### Complete Cleanup Configuration

```yaml
# Cleanup system configuration
cleanup:
  # Retention periods (in days)
  temp_retention: 7               # Keep temporary files for 7 days
  log_retention: 30               # Keep log files for 30 days
  cache_retention: 14             # Keep cache files for 14 days
  backup_retention: 7             # Keep backups for 7 days
  thumbnail_retention: 30         # Keep thumbnails for 30 days

  # Safety and confirmation
  backup_before_cleanup: true     # Create backup before cleanup operations
  dry_run_by_default: false       # Don't default to dry run mode
  require_confirmation: true      # Require user confirmation for dangerous ops
  expert_warnings: true           # Show expert warnings for dangerous operations
  show_preview: true              # Show preview of files to be deleted

  # Cleanup behavior
  aggressive_mode: false          # Don't enable aggressive cleanup by default
  follow_symlinks: false          # Don't follow symbolic links during cleanup
  respect_permissions: true       # Respect file permissions during cleanup
  check_mountpoints: true         # Check filesystem mount points before cleanup
  preserve_hardlinks: true        # Preserve hard links during cleanup

  # File handling
  preserve_patterns:              # Patterns to never delete
    - "*.important"
    - "*.keep"
    - ".*.swp"
    - "*.lock"
    - "*.pid"

  exclude_patterns:               # Patterns to exclude from cleanup
    - "*.tmp"
    - "*.bak"
    - "*~"
    - ".DS_Store"
    - "Thumbs.db"
    - "*.log.*"

  include_patterns:               # Patterns to include (overrides exclude)
    - "*.temp"
    - "*.cache"

  # Category-specific settings
  categories:
    # System files cleanup
    system:
      enabled: true
      temp_dirs:
        - /tmp
        - /var/tmp
        - "~/.cache"
        - "~/.local/share/Trash"
      log_dirs:
        - /var/log
        - "~/.local/share/logs"
        - "~/.cache/logs"
      cache_dirs:
        - "~/.cache"
        - /var/cache
      max_file_age: 30            # Maximum file age in days
      min_file_size: "1KB"        # Minimum file size to consider

    # Development environment cleanup
    development:
      enabled: true
      node_modules_retention: 30   # Days to keep unused node_modules
      python_cache_retention: 7    # Days to keep Python cache files
      go_cache_retention: 7        # Days to keep Go cache
      rust_cache_retention: 14     # Days to keep Rust cache
      java_cache_retention: 14     # Days to keep Java cache
      maven_cache_retention: 30    # Days to keep Maven cache
      gradle_cache_retention: 30   # Days to keep Gradle cache

    # Container cleanup
    containers:
      enabled: true
      docker_cleanup: true         # Clean Docker resources
      podman_cleanup: true         # Clean Podman resources
      stop_containers: false       # Don't stop running containers
      remove_volumes: false        # Don't remove volumes by default
      remove_networks: false       # Don't remove networks by default
      prune_images: false          # Don't prune unused images by default

    # IDE and editor cleanup
    ide:
      enabled: true
      vscode_cache: true           # Clean VSCode cache
      jetbrains_cache: true        # Clean JetBrains IDE cache
      vim_cache: true              # Clean Vim cache
      emacs_cache: true            # Clean Emacs cache
      sublime_cache: true          # Clean Sublime Text cache
      editor_backup: false         # Don't clean editor backup files

    # Build artifact cleanup
    build:
      enabled: true
      cmake_cache: true            # Clean CMake cache
      make_artifacts: true         # Clean make artifacts
      cargo_target: true           # Clean Rust cargo target directory
      npm_dist: true              # Clean npm dist directories
      python_build: true           # Clean Python build directories
      maven_target: true          # Clean Maven target directories

    # Package dependency cleanup
    dependencies:
      enabled: true
      npm_cleanup: true            # Clean npm dependencies
      pip_cleanup: true            # Clean pip cache and packages
      conda_cleanup: true          # Clean conda packages
      gem_cleanup: true            # Clean Ruby gems
      composer_cleanup: true       # Clean Composer packages

  # Performance settings
  performance:
    parallel_operations: true     # Run cleanup operations in parallel
    max_workers: 4                # Maximum number of parallel workers
    io_priority: 7                # I/O priority for cleanup operations (0-7)
    memory_limit: "512M"          # Memory limit for cleanup operations
    chunk_size: "1M"              # File operation chunk size
    max_file_size: "100M"         # Maximum file size to process in memory

  # Reporting and logging
  reporting:
    show_summary: true            # Show cleanup summary
    detailed_output: false         # Don't show detailed file lists by default
    export_metrics: true          # Export cleanup metrics
    log_statistics: true          # Log cleanup statistics
    generate_report: false        # Don't generate HTML report by default
    report_format: "text"         # Report format: text, json, html, csv

  # Validation and verification
  validation:
    check_disk_space: true        # Check available disk space
    min_free_space: "1G"          # Minimum free space required
    validate_paths: true          # Validate file paths before operations
    checksum_verification: false  # Don't verify file checksums
    backup_verification: true     # Verify backup integrity
```

## 🛡️ Safety & Protection Configuration

### Safety Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `safety.protect_dev_directories` | boolean | true | Protect development directories |
| `safety.check_running_services` | boolean | true | Check for running services |
| `safety.check_running_containers` | boolean | true | Check for running containers |
| `safety.require_confirmation` | boolean | true | Require confirmation for dangerous operations |
| `safety.expert_mode` | boolean | false | Disable some safety checks |
| `safety.backup_before_major_operations` | boolean | true | Create backups before major operations |
| `safety.rollback_on_failure` | boolean | true | Rollback on operation failure |

### Complete Safety Configuration

```yaml
# Safety and protection configuration
safety:
  # Protection mechanisms
  protect_dev_directories: true   # Protect development directories
  check_running_services: true    # Check for running services
  check_running_containers: true  # Check for running containers
  require_confirmation: true      # Require confirmation for dangerous operations
  validate_system_state: true     # Validate system state before operations

  # Expert mode settings
  expert_mode: false              # Don't enable expert mode by default
  skip_safety_checks: false       # Don't skip safety checks
  override_protections: false     # Don't override file protections
  ignore_warnings: false          # Don't ignore safety warnings

  # Backup and recovery
  backup_before_major_operations: true  # Create backup before major operations
  rollback_on_failure: true       # Rollback on operation failure
  auto_backup_retention: 7        # Keep auto-backups for 7 days
  backup_verification: true       # Verify backup integrity
  incremental_backups: true       # Use incremental backups

  # Directory protection
  protected_directories:          # Directories to protect by default
    - "~/*projects*"
    - "~/work"
    - "~/development"
    - "~/git"
    - "/etc/fub"
    - "/usr/local/etc/fub"

  protected_patterns:             # File patterns to protect
    - "*.config"
    - "*.conf"
    - "*.key"
    - "*.pem"
    - "*.crt"
    - "*.p12"
    - "*.jks"
    - "id_rsa*"
    - "id_ed25519*"

  # Service protection
  protected_services:             # Services to never stop
    - "ssh"
    - "sshd"
    - "networking"
    - "cron"
    - "systemd"
    - "dbus"

  critical_services:              # Services that require special handling
    - "mysql"
    - "postgresql"
    - "nginx"
    - "apache2"
    - "docker"

  # Container protection
  protected_containers:           # Container patterns to protect
    - "*database*"
    - "*production*"
    - "*critical*"
    - "*prod*"

  # User-defined protection rules
  custom_protection_rules:
    - name: "Important Documents"
      paths:
        - "~/Documents/important"
        - "~/work/critical"
      patterns:
        - "*.important"
        - "*.critical"
      action: "protect"

    - name: "Development Projects"
      paths:
        - "~/projects/*"
        - "~/git/*"
      conditions:
        - "contains_git_repo"
        - "has_recent_commits"
      action: "protect"

  # Safety validation
  validate_operations: true       # Validate operations before execution
  check_disk_space: true         # Check available disk space
  check_system_load: true         # Check system load before operations
  check_battery_level: true       # Check battery level on laptops
  check_network_connectivity: false # Don't check network by default

  # Thresholds and limits
  thresholds:
    min_free_space: "1G"          # Minimum free space required
    max_system_load: 2.0          # Maximum system load for operations
    min_battery_level: 20         # Minimum battery level percentage
    max_memory_usage: 80          # Maximum memory usage percentage

  # Emergency settings
  emergency_stop: true            # Enable emergency stop functionality
  emergency_key: "Ctrl+C"         # Emergency stop key combination
  max_operation_time: 3600        # Maximum operation time in seconds
  auto_stop_on_error: true        # Automatically stop on critical errors

  # Logging and auditing
  log_all_operations: true        # Log all safety operations
  audit_file: "~/.cache/fub/logs/safety.log"  # Safety audit log file
  detailed_audit: false           # Don't log every file by default
  audit_retention_days: 90        # Keep audit logs for 90 days

  # Notification settings
  notify_on_protection: true      # Notify when protection rules are triggered
  notify_on_rollback: true        # Notify on rollback operations
  emergency_notifications: true   # Send emergency notifications

  # Recovery and undo
  enable_undo: true               # Enable undo functionality
  undo_retention_days: 7          # Keep undo information for 7 days
  max_undo_operations: 50         # Maximum number of undo operations
  quick_undo: true               # Enable quick undo for recent operations
```

## 📊 Monitoring & Analysis Configuration

### Monitoring Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `monitoring.enabled` | boolean | true | Enable system monitoring |
| `monitoring.pre_cleanup_analysis` | boolean | true | Analyze system before cleanup |
| `monitoring.post_cleanup_summary` | boolean | true | Show post-cleanup summary |
| `monitoring.historical_tracking` | boolean | true | Track historical data |
| `monitoring.performance_alerts` | boolean | true | Enable performance alerts |
| `monitoring.alert_threshold` | integer | 85 | Alert threshold percentage |

### Complete Monitoring Configuration

```yaml
# System monitoring configuration
monitoring:
  # Enable/disable monitoring features
  enabled: true                   # Enable monitoring system
  pre_cleanup_analysis: true      # Analyze system before cleanup
  post_cleanup_summary: true      # Show summary after cleanup
  historical_tracking: true       # Track historical data
  performance_alerts: true        # Enable performance alerts

  # Data collection settings
  collect_system_metrics: true    # Collect system metrics
  collect_disk_usage: true        # Collect disk usage data
  collect_memory_usage: true      # Collect memory usage data
  collect_cpu_usage: true         # Collect CPU usage data
  collect_network_stats: false    # Don't collect network stats by default
  collect_process_info: false     # Don't collect process info by default

  # Metrics collection frequency
  collection_interval: 300        # Collect metrics every 5 minutes
  detailed_interval: 3600         # Detailed analysis every hour
  historical_interval: 86400      # Historical data every day

  # Alerting configuration
  performance_alerts: true        # Enable performance alerts
  alert_threshold: 85             # Alert at 85% usage
  disk_space_alert: 90            # Alert at 90% disk usage
  memory_alert: 90                # Alert at 90% memory usage
  cpu_alert: 95                   # Alert at 95% CPU usage
  load_average_alert: 2.0         # Alert at load average > 2.0

  # Alert delivery methods
  alert_methods:
    desktop: true                 # Desktop notifications
    email: false                  # Email notifications
    log: true                     # Log alerts
    webhook: false                # Webhook notifications

  # Historical data management
  history_retention_days: 90      # Keep 90 days of history
  history_compression: true       # Compress old history data
  history_cleanup: true           # Clean up old history
  max_history_size: "100M"        # Maximum history database size

  # Analysis settings
  analysis_depth: "detailed"      # Analysis depth: basic, detailed, comprehensive
  cleanup_opportunities: true     # Identify cleanup opportunities
  optimization_suggestions: true  # Provide optimization suggestions
  trend_analysis: true            # Analyze trends over time
  anomaly_detection: true         # Detect anomalous behavior

  # Performance monitoring
  performance_benchmarks: true    # Run performance benchmarks
  benchmark_frequency: 7          # Run benchmarks every 7 days
  performance_trends: true        # Track performance trends
  baseline_comparison: true       # Compare against baseline

  # Integration with external tools
  integrate_btop: true            # Integrate with btop if available
  integrate_sysstat: false        # Don't integrate with sysstat by default
  integrate_prometheus: false     # Don't export to Prometheus by default
  integrate_grafana: false        # Don't integrate with Grafana

  # Export and reporting
  export_metrics: true            # Export metrics to external systems
  metrics_format: "json"          # Export format: json, csv, prometheus
  auto_reports: false             # Don't generate auto-reports by default
  report_frequency: 7             # Report frequency in days
  report_recipients: []           # Report recipients (email addresses)
  report_format: "html"           # Report format: html, text, json

  # Real-time monitoring
  real_time_monitoring: false     # Don't enable real-time monitoring by default
  monitoring_interval: 300        # Monitoring interval in seconds
  alert_cooldown: 1800            # Alert cooldown period (30 minutes)
  max_alerts_per_hour: 10        # Maximum alerts per hour

  # Database settings
  database_type: "sqlite"         # Database type: sqlite, mysql, postgresql
  database_path: "~/.local/share/fub/monitoring.db"  # SQLite database path
  database_host: "localhost"      # Database host for MySQL/PostgreSQL
  database_port: 5432            # Database port
  database_name: "fub_monitoring" # Database name
  database_user: "fub"           # Database username

  # Custom metrics
  custom_metrics: []              # Custom metrics to collect
  metric_collectors: []           # Custom metric collectors

  # Notifications
  notifications:
    enabled: true                 # Enable monitoring notifications
    desktop: true                 # Desktop notifications
    email: false                  # Email notifications
    webhook: false                # Webhook notifications

    # Email settings
    email_smtp: "localhost"       # SMTP server
    email_port: 587               # SMTP port
    email_user: ""                # SMTP username
    email_password: ""            # SMTP password
    email_from: "fub@$(hostname)" # From email address
    email_to: []                  # To email addresses

    # Webhook settings
    webhook_url: ""               # Webhook URL
    webhook_method: "POST"        # HTTP method
    webhook_headers: {}           # Custom headers
    webhook_timeout: 30           # Webhook timeout in seconds
```

## 🔧 Dependency Management Configuration

### Dependency Settings

The dependency management system is configured through `config/dependencies.yaml`:

```yaml
# Automatic checking and installation
auto_check: true                 # Automatically check for dependencies on startup
auto_install: false              # Never auto-install without explicit permission
show_recommendations: true        # Show tool recommendations to users

# User interface settings
silent_mode: false               # Suppress non-critical messages
verbose_mode: false              # Show detailed operation information
interactive: true                # Enable interactive prompts

# Performance settings
cache_ttl: 3600                  # Cache dependency status for 1 hour
parallel_checks: true            # Check multiple tools in parallel
max_parallel: 4                  # Maximum number of parallel checks

# Package management
package_manager_preference: "apt,snap,flatpak"  # Preferred package managers
install_timeout: 300             # Installation timeout in seconds
backup_before_install: true      # Create backup before installing tools
allow_external_sources: false    # Only install from trusted sources

# Update checking
update_check_interval: 86400     # Check for tool updates every 24 hours
min_disk_space: "100MB"          # Minimum free space required

# User preferences
skip_tools: ""                   # Comma-separated list of tools to skip
only_category: ""                # Only check tools in this category
install_all_recommended: false   # Install all recommended tools without prompting
preferred_package_manager: ""    # Force specific package manager

# Logging and debugging
log_level: "INFO"                # DEBUG, INFO, WARN, ERROR, FATAL
enable_debug_mode: false         # Enable debug logging
track_user_behavior: true        # Track user patterns for better recommendations

# Security settings
require_confirmation: true       # Require user confirmation before installation
validate_signatures: false       # Validate package signatures (when available)
sandbox_installations: false     # Run installations in sandbox when possible

# Integration settings
integrate_with_shell: true       # Add tool aliases and functions to shell
create_desktop_entries: true     # Create desktop entries for GUI tools
update_path_environment: true    # Update PATH environment variable if needed

# Backup and rollback
enable_rollback: true            # Enable installation rollback
backup_retention_days: 7        # Keep backups for 7 days
auto_cleanup_backups: true       # Automatically clean up old backups

# Notification settings
notification_level: "important"  # all, important, critical
enable_desktop_notifications: true  # Show desktop notifications when available
notify_on_updates: true          # Notify when tool updates are available
```

## ⏰ Scheduler Configuration

### Scheduler Settings

The scheduling system is configured through `config/scheduler.yaml`:

```yaml
# Global scheduler settings
scheduler:
  version: "1.0.0"
  auto_cleanup: true
  global_notifications: true

# Default resource limits for background operations
resource_limits:
  default_memory: "512M"
  default_cpu: "50%"
  default_io_priority: 7
  default_nice_level: 10
  default_timeout: 1800  # 30 minutes

# Background operation conditions
conditions:
  default: "ac_power,system_load"
  strict: "ac_power,system_load,idle_time,disk_space"
  minimal: "system_load"

# History and analytics settings
history:
  retention_days: 90
  analysis_enabled: true
  auto_report: false
  report_interval: 7  # days

# Notification settings
notifications:
  level: "INFO"
  desktop_enabled: true
  email_enabled: false
  email_to: ""
  email_from: "fub@$(hostname)"

# Maintenance settings
maintenance:
  auto_retry: true
  max_retries: 3
  retry_delay: 300  # seconds
  conflict_detection: true
  emergency_stop: true

# System integration
systemd:
  user_services: true
  auto_reload: true
  timer_persistence: true

# Safety features
safety:
  backup_before_major_operations: true
  rollback_on_failure: true
  validate_system_state: true

# Performance tuning
performance:
  parallel_operations: false
  priority_adjustment: true
  load_balancing: false
```

## 👤 Profile System Configuration

### Built-in Profiles

#### Desktop Profile
```yaml
# Desktop user profile
profile:
  name: "Desktop User"
  description: "Optimized for desktop Ubuntu systems"
  target: "desktop"
  priority: 1

# UI settings
ui:
  interactive: true
  colors: true
  animations: true
  show_icons: true
  confirmations: true

# Cleanup settings
cleanup:
  aggressive_mode: false
  temp_retention: 7
  log_retention: 30
  cache_retention: 14
  backup_before_cleanup: true

# Categories enabled
categories:
  - system
  - development
  - containers
  - ide

# Monitoring
monitoring:
  enabled: true
  performance_alerts: true
  historical_tracking: true

# Scheduler
scheduler:
  enabled: true
  daily_cleanup: true
  weekly_analysis: true
  notifications: true

# Dependencies
dependencies:
  auto_check: true
  show_recommendations: true
  preferred_tools:
    - "gum"
    - "btop"
    - "fd"
    - "ripgrep"
```

#### Server Profile
```yaml
# Server administrator profile
profile:
  name: "Server Administrator"
  description: "Optimized for server environments"
  target: "server"
  priority: 2

# UI settings
ui:
  interactive: false
  colors: true
  animations: false
  show_icons: false
  confirmations: false

# Cleanup settings
cleanup:
  aggressive_mode: false
  temp_retention: 3
  log_retention: 14
  cache_retention: 7
  backup_before_cleanup: true

# Categories enabled
categories:
  - system
  - logs

# Monitoring
monitoring:
  enabled: true
  performance_alerts: true
  alert_threshold: 90

# Scheduler
scheduler:
  enabled: true
  daily_cleanup: true
  time: "02:00"
  notifications: false

# Dependencies
dependencies:
  auto_check: false
  show_recommendations: false
```

#### Developer Profile
```yaml
# Developer profile
profile:
  name: "Developer"
  description: "Optimized for development workflows"
  target: "developer"
  priority: 3

# UI settings
ui:
  interactive: true
  colors: true
  animations: true
  show_icons: true
  confirmations: true

# Cleanup settings
cleanup:
  aggressive_mode: false
  temp_retention: 3
  log_retention: 7
  cache_retention: 7
  backup_before_cleanup: true

# Categories enabled
categories:
  - system
  - development
  - containers
  - ide
  - build
  - dependencies

# Monitoring
monitoring:
  enabled: true
  performance_alerts: true
  detailed_analysis: true

# Scheduler
scheduler:
  enabled: true
  manual_mode: true
  notifications: true

# Dependencies
dependencies:
  auto_check: true
  show_recommendations: true
  preferred_tools:
    - "git"
    - "docker"
    - "node"
    - "python"
    - "vscode"
```

## 🎨 Theme System Configuration

### Theme Configuration Structure

```yaml
# Theme definition
theme:
  name: "Theme Name"
  variant: "dark"                # dark, light
  version: "1.0.0"
  author: "Author Name"
  description: "Theme description"

# Color palette
colors:
  # Basic ANSI colors
  foreground: "#ffffff"
  background: "#000000"
  cursor: "#ffffff"

  # ANSI 16-color palette
  black: "#000000"
  red: "#ff0000"
  green: "#00ff00"
  yellow: "#ffff00"
  blue: "#0000ff"
  magenta: "#ff00ff"
  cyan: "#00ffff"
  white: "#ffffff"

  # Bright colors
  bright_black: "#808080"
  bright_red: "#ff8080"
  bright_green: "#80ff80"
  bright_yellow: "#ffff80"
  bright_blue: "#8080ff"
  bright_magenta: "#ff80ff"
  bright_cyan: "#80ffff"
  bright_white: "#ffffff"

  # Semantic colors
  primary: "#0000ff"
  secondary: "#00ff00"
  success: "#00ff00"
  warning: "#ffff00"
  error: "#ff0000"
  info: "#00ffff"
  muted: "#808080"

# UI element colors
ui:
  # Menu colors
  menu_border: "#808080"
  menu_background: "#000000"
  menu_foreground: "#ffffff"
  menu_highlight: "#333333"
  menu_selected: "#0000ff"

  # Progress bar colors
  progress_bar: "#0000ff"
  progress_background: "#333333"
  progress_complete: "#00ff00"
  progress_remaining: "#808080"

  # Status indicators
  status_good: "#00ff00"
  status_warning: "#ffff00"
  status_error: "#ff0000"
  status_info: "#00ffff"
  status_neutral: "#808080"

  # Input colors
  input_text: "#ffffff"
  input_background: "#000000"
  input_border: "#808080"
  input_placeholder: "#808080"
  input_cursor: "#ffffff"

  # Button colors
  button_primary: "#0000ff"
  button_secondary: "#00ff00"
  button_danger: "#ff0000"
  button_warning: "#ffff00"
  button_info: "#00ffff"

  # Text colors
  text_primary: "#ffffff"
  text_secondary: "#cccccc"
  text_muted: "#808080"
  text_inverse: "#000000"

# Style settings
styles:
  # Text styles
  bold: true
  italic: false
  underline: false
  strikethrough: false

  # Border styles
  border_style: "rounded"        # rounded, single, double, thick, dotted
  border_width: 1
  corner_radius: 2

  # Icon set
  icon_set: "nerd-fonts"         # nerd-fonts, unicode, ascii, custom
  custom_icons: {}               # Custom icon definitions

  # Animation settings
  animations: true
  animation_speed: "normal"      # slow, normal, fast
  animation_duration: 300        # Animation duration in milliseconds

  # Spacing and layout
  padding: 1
  margin: 0
  line_height: 1

# Syntax highlighting colors
syntax:
  comment: "#808080"
  keyword: "#0000ff"
  string: "#00ff00"
  number: "#ffff00"
  operator: "#ffffff"
  function: "#00ffff"
  variable: "#ffffff"
  type: "#ff00ff"
  constant: "#ffff80"
  error: "#ff0000"
  warning: "#ffff00"

# File type colors
file_types:
  directory: "#0000ff"
  executable: "#00ff00"
  symlink: "#ffff00"
  image: "#ff00ff"
  video: "#00ffff"
  audio: "#ffff80"
  document: "#ffffff"
  archive: "#ff8080"
  code: "#80ff80"
  config: "#ffff00"
  log: "#808080"
```

## 🌐 Network Configuration

### Network Settings

```yaml
# Network configuration
network:
  # Basic settings
  timeout: 10                    # Network timeout in seconds
  retries: 3                     # Number of retry attempts
  user_agent: "FUB/1.0.0"        # HTTP user agent string

  # Proxy settings
  proxy: ""                      # Proxy server URL
  proxy_auth: ""                 # Proxy authentication
  no_proxy: ""                   # Comma-separated list of hosts to bypass proxy
  proxy_ca_cert: ""              # Proxy CA certificate path

  # SSL/TLS settings
  verify_ssl: true               # Verify SSL certificates
  ca_bundle: ""                  # Custom CA bundle path
  client_cert: ""                # Client certificate path
  client_key: ""                 # Client private key path

  # Connection settings
  max_connections: 10             # Maximum concurrent connections
  keep_alive: true               # Enable keep-alive connections
  keep_alive_timeout: 30         # Keep-alive timeout in seconds
  compression: true              # Enable compression
  follow_redirects: true         # Follow HTTP redirects
  max_redirects: 5               # Maximum number of redirects

  # DNS settings
  dns_servers: []                # Custom DNS servers
  dns_timeout: 5                 # DNS timeout in seconds
  dns_attempts: 3                # Number of DNS attempts
  dns_cache: true                # Enable DNS caching
  dns_cache_ttl: 300             # DNS cache TTL in seconds

  # Download settings
  max_download_size: "100MB"     # Maximum download size
  chunk_size: "1MB"              # Download chunk size
  resume_downloads: true         # Resume interrupted downloads
  download_timeout: 300          # Download timeout in seconds
  download_retries: 3            # Download retry attempts

  # Upload settings
  max_upload_size: "50MB"        # Maximum upload size
  upload_chunk_size: "1MB"       # Upload chunk size
  upload_timeout: 600            # Upload timeout in seconds

  # Rate limiting
  rate_limit_enabled: false      # Don't enable rate limiting by default
  rate_limit: "1MB/s"            # Rate limit
  rate_limit_burst: "5MB"        # Rate limit burst size

  # Connectivity checks
  check_connectivity: true       # Check network connectivity
  connectivity_timeout: 5        # Connectivity check timeout
  connectivity_hosts:            # Hosts to check for connectivity
    - "8.8.8.8"
    - "1.1.1.1"
    - "google.com"

  # API settings
  api_timeout: 30                # API request timeout
  api_retries: 3                 # API retry attempts
  api_backoff: "exponential"     # Backoff strategy: linear, exponential

  # Security settings
  allowed_hosts: []              # Allowed hosts for connections
  blocked_hosts: []              # Blocked hosts
  max_response_size: "10MB"      # Maximum response size
  sanitize_headers: true         # Sanitize HTTP headers

  # Performance settings
  connection_pool: true          # Use connection pooling
  pool_size: 5                   # Connection pool size
  pool_timeout: 30               # Pool timeout
  enable_pipelining: false       # Don't enable HTTP pipelining
```

## 📝 Logging Configuration

### Logging Settings

```yaml
# Logging configuration
log:
  # Basic logging settings
  level: INFO                     # Logging level: DEBUG, INFO, WARN, ERROR, FATAL
  file: ~/.cache/fub/logs/fub.log  # Main log file path
  format: "structured"           # Log format: structured, simple, json

  # Log rotation
  rotate: true                   # Enable log rotation
  max_size: 10MB                # Maximum log file size
  rotate_count: 5                # Number of rotated log files to keep
  compress_rotated: true         # Compress rotated log files
  rotation_interval: "daily"     # Rotation interval: hourly, daily, weekly

  # Log format settings
  structured: true               # Use structured logging format (JSON)
  include_timestamps: true       # Include timestamps in log entries
  include_source: false          # Include source file and line number
  include_level: true            # Include log level
  include_thread: false          # Include thread ID
  include_process: false         # Include process ID

  # Component-specific logs
  component_logs:                # Component-specific log files
    safety: ~/.cache/fub/logs/safety.log
    monitoring: ~/.cache/fub/logs/monitoring.log
    scheduler: ~/.cache/fub/logs/scheduler.log
    dependencies: ~/.cache/fub/logs/dependencies.log
    cleanup: ~/.cache/fub/logs/cleanup.log
    config: ~/.cache/fub/logs/config.log

  # Log filtering
  filter_patterns: []            # Log patterns to filter out
  sensitive_data_filter: true    # Filter out sensitive data
  anonymize_ips: false           # Don't anonymize IP addresses
  filter_patterns:
    - "password"
    - "token"
    - "secret"
    - "key"

  # Performance logging
  performance_logging: true      # Log performance metrics
  slow_query_threshold: 1000     # Slow operation threshold in milliseconds
  log_memory_usage: false        # Don't log memory usage by default
  log_cpu_usage: false           # Don't log CPU usage by default

  # Debug settings
  debug_to_file: true            # Write debug output to file
  debug_console: false           # Don't show debug output on console
  trace_operations: false        # Don't trace all operations
  debug_modules: []              # Specific modules to debug

  # External logging
  syslog_enabled: false          # Don't send logs to syslog by default
  syslog_facility: "user"        # Syslog facility
  syslog_host: ""                # Remote syslog host
  syslog_port: 514               # Syslog port
  syslog_protocol: "udp"         # Syslog protocol: udp, tcp

  # Database logging
  database_logging: false        # Don't log to database by default
  database_type: "sqlite"        # Database type: sqlite, mysql, postgresql
  database_path: "~/.local/share/fub/logs.db"  # Database path
  database_table: "logs"         # Log table name

  # Log analysis
  auto_analyze: false            # Don't auto-analyze logs by default
  analysis_interval: 86400       # Log analysis interval in seconds
  alert_on_errors: true          # Send alerts on error logs
  error_threshold: 10            # Error threshold for alerts
  analysis_retention_days: 30    # Keep analysis results for 30 days

  # Log forwarding
  forward_logs: false            # Don't forward logs by default
  forward_destination: ""        # Forwarding destination
  forward_format: "json"         # Forwarding format
  forward_buffer_size: 1000      # Forwarding buffer size

  # File settings
  file_permissions: "600"        # Log file permissions
  directory_permissions: "700"   # Log directory permissions
  create_directories: true       # Create log directories if they don't exist
  backup_logs: true              # Create backups before rotation

  # Output formatting
  color_output: true             # Use colors in console output
  json_pretty_print: false      # Don't pretty-print JSON logs
  field_separator: "|"           # Field separator for simple format
  date_format: "2006-01-02 15:04:05"  # Date format

  # Log retention and cleanup
  retention_days: 30             # Keep logs for 30 days
  cleanup_interval: 86400       # Cleanup interval in seconds
  max_log_dir_size: "1GB"        # Maximum log directory size
  cleanup_old_logs: true         # Clean up old logs

  # Integration
  integrate_with_journald: false # Don't integrate with journald by default
  journald_priority: "info"      # Journald priority level
  log_to_stdout: false           # Don't log to stdout by default
  log_to_stderr: true            # Log errors to stderr
```

## 🔧 Environment Variables

### Core Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FUB_CONFIG_FILE` | "~/.config/fub/config.yaml" | Path to configuration file |
| `FUB_LOG_LEVEL` | "INFO" | Logging level |
| `FUB_DATA_DIR` | "~/.local/share/fub" | Data directory |
| `FUB_CACHE_DIR` | "~/.cache/fub" | Cache directory |
| `FUB_CONFIG_DIR` | "~/.config/fub" | Configuration directory |
| `FUB_THEME` | "tokyo-night" | Theme name |
| `FUB_PROFILE` | "desktop" | User profile |
| `FUB_VERSION` | "1.0.0" | FUB version |

### UI Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FUB_INTERACTIVE` | "true" | Enable interactive interface |
| `FUB_COLORS` | "true" | Enable colors in output |
| `FUB_ANIMATIONS` | "true" | Enable animations |
| `FUB_EXPERT_MODE` | "false" | Enable expert mode |
| `FUB_MENU_HEIGHT` | "10" | Menu height |
| `FUB_PROGRESS_BARS` | "true" | Show progress bars |
| `FUB_CONFIRMATIONS` | "true" | Require confirmations |
| `FUB_ICONS` | "true" | Show icons |

### Operation Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FUB_DRY_RUN` | "false" | Enable dry run mode |
| `FUB_TIMEOUT` | "30" | Operation timeout in seconds |
| `FUB_BACKUP_BEFORE_CLEANUP` | "true" | Create backup before cleanup |
| `FUB_REQUIRE_CONFIRMATION` | "true" | Require confirmation for operations |
| `FUB_AGGRESSIVE_MODE` | "false" | Enable aggressive cleanup |
| `FUB_PARALLEL_JOBS` | "4" | Number of parallel jobs |
| `FUB_MEMORY_LIMIT` | "1G" | Memory usage limit |

### Dependency Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FUB_DEPS_AUTO_CHECK` | "true" | Auto-check dependencies |
| `FUB_DEPS_AUTO_INSTALL` | "false" | Auto-install dependencies |
| `FUB_DEPS_SILENT_MODE` | "false" | Silent mode for dependencies |
| `FUB_DEPS_PACKAGE_MANAGER` | "" | Preferred package manager |
| `FUB_DEPS_SHOW_RECOMMENDATIONS` | "true" | Show recommendations |
| `FUB_DEPS_INSTALL_TIMEOUT` | "300" | Installation timeout |

### Network Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FUB_NETWORK_TIMEOUT` | "10" | Network timeout in seconds |
| `FUB_NETWORK_RETRIES` | "3" | Number of retry attempts |
| `FUB_NETWORK_PROXY` | "" | Proxy server URL |
| `FUB_NETWORK_NO_PROXY` | "" | Hosts to bypass proxy |
| `FUB_NETWORK_VERIFY_SSL` | "true" | Verify SSL certificates |
| `FUB_NETWORK_USER_AGENT` | "FUB/1.0.0" | HTTP user agent |

### Monitoring Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FUB_MONITORING_ENABLED` | "true" | Enable monitoring |
| `FUB_MONITORING_INTERVAL` | "300" | Monitoring interval in seconds |
| `FUB_ALERT_THRESHOLD` | "85" | Alert threshold percentage |
| `FUB_PERFORMANCE_ALERTS` | "true" | Enable performance alerts |
| `FUB_HISTORICAL_TRACKING` | "true" | Track historical data |

### Usage Examples

```bash
# Set log level to debug
export FUB_LOG_LEVEL=DEBUG

# Use non-interactive mode
export FUB_INTERACTIVE=false

# Enable expert mode
export FUB_EXPERT_MODE=true

# Use custom configuration file
export FUB_CONFIG_FILE=/path/to/custom/config.yaml

# Use specific profile
export FUB_PROFILE=server

# Enable dry run mode
export FUB_DRY_RUN=true

# Set custom theme
export FUB_THEME=minimal

# Configure proxy
export FUB_NETWORK_PROXY=http://proxy.example.com:8080
export FUB_NETWORK_NO_PROXY=localhost,127.0.0.1

# Set custom data directory
export FUB_DATA_DIR=/custom/data/dir

# Disable colors
export FUB_COLORS=false

# Set parallel jobs
export FUB_PARALLEL_JOBS=8

# Set memory limit
export FUB_MEMORY_LIMIT=2G
```

## ⚡ Command Line Options

### Global Options

| Option | Default | Description |
|--------|---------|-------------|
| `--config <file>` | - | Use specific configuration file |
| `--profile <name>` | - | Use specific profile |
| `--theme <name>` | - | Use specific theme |
| `--log-level <level>` | - | Set logging level |
| `--verbose` | - | Enable verbose output |
| `--debug` | - | Enable debug mode |
| `--quiet` | - | Suppress non-error output |
| `--version` | - | Show version information |
| `--help` | - | Show help information |

### Operation Options

| Option | Default | Description |
|--------|---------|-------------|
| `--dry-run` | - | Show what would be done without executing |
| `--interactive` | - | Enable interactive mode |
| `--no-interactive` | - | Disable interactive mode |
| `--force` | - | Skip confirmation prompts |
| `--expert` | - | Enable expert mode |
| `--timeout <seconds>` | - | Set operation timeout |
| `--parallel <jobs>` | - | Set number of parallel jobs |
| `--memory-limit <size>` | - | Set memory usage limit |

### Cleanup Options

| Option | Default | Description |
|--------|---------|-------------|
| `--aggressive` | - | Enable aggressive cleanup |
| `--backup` | - | Create backup before cleanup |
| `--no-backup` | - | Skip backup creation |
| `--categories <list>` | - | Specify cleanup categories |
| `--exclude <patterns>` | - | Exclude file patterns |
| `--retention <days>` | - | Set retention period |

### Monitoring Options

| Option | Default | Description |
|--------|---------|-------------|
| `--analyze` | - | Run system analysis |
| `--detailed` | - | Show detailed output |
| `--export <format>` | - | Export results (json, csv, html) |
| `--alert-threshold <percent>` | - | Set alert threshold |
| `--history <days>` | - | Show historical data |

### Usage Examples

```bash
# Use custom configuration
fub --config /path/to/config.yaml cleanup all

# Use specific profile
fub --profile server cleanup all

# Enable dry run mode
fub --dry-run cleanup all

# Enable expert mode
fub --expert cleanup all

# Set log level
fub --log-level DEBUG cleanup all

# Force operation without confirmation
fub --force cleanup all

# Set custom timeout
fub --timeout 600 cleanup all

# Set parallel jobs
fub --parallel 8 cleanup all

# Export monitoring results
fub monitor --export json --output system-report.json

# Custom categories and retention
fub cleanup --categories system,development --retention 3

# Exclude specific patterns
fub cleanup --exclude "*.important,*.keep"

# Enable aggressive cleanup with backup
fub cleanup --aggressive --backup

# Detailed analysis with export
fub monitor --analyze --detailed --export html
```

## ✅ Configuration Validation

### Validation Commands

```bash
# Validate current configuration
fub config validate

# Validate specific configuration file
fub config validate --file /path/to/config.yaml

# Validate configuration with strict mode
fub config validate --strict

# Show configuration with validation
fub config show --validate

# Check configuration syntax
fub config check-syntax

# Validate all configuration files
fub config validate-all

# Validate specific sections
fub config validate --section cleanup
fub config validate --section safety
fub config validate --section monitoring
```

### Validation Rules

#### Syntax Validation
- **YAML Syntax**: Valid YAML structure and formatting
- **Data Types**: Correct data types for all values
- **Required Fields**: All required configuration fields present
- **File Paths**: Valid and accessible file paths

#### Semantic Validation
- **Value Ranges**: Values within acceptable ranges
- **Logical Consistency**: Configuration values make sense together
- **Dependency Validation**: Required dependencies available
- **Permission Checks**: Read/write permissions for configured paths

#### Performance Validation
- **Resource Limits**: Reasonable resource limits
- **Timeout Values**: Appropriate timeout values
- **Concurrency Settings**: Safe parallel operation settings

### Common Validation Issues

#### File Permission Errors
```bash
# Check configuration file permissions
ls -la ~/.config/fub/config.yaml

# Fix permissions
chmod 600 ~/.config/fub/config.yaml
chmod 755 ~/.config/fub/

# Check directory permissions
ls -ld ~/.config/fub/
```

#### Syntax Errors
```bash
# Check YAML syntax
python -c "import yaml; yaml.safe_load(open('~/.config/fub/config.yaml'))"

# Or use FUB's built-in syntax checker
fub config check-syntax

# Validate specific file
fub config validate-syntax --file ~/.config/fub/config.yaml
```

#### Path Resolution
```bash
# Check if paths are accessible
fub config check-paths

# Expand paths in configuration
fub config expand-paths

# Validate specific paths
fub config validate-paths --section cleanup
```

### Auto-Fix Configuration

```bash
# Auto-fix common configuration issues
fub config fix

# Fix specific issues
fub config fix --permissions
fub config fix --syntax
fub config fix --paths

# Fix with backup
fub config fix --backup

# Dry run fix
fub config fix --dry-run
```

## 🎨 Custom Configuration Examples

### Developer Workstation Configuration

```yaml
# ~/.config/fub/config.yaml - Developer workstation setup
log:
  level: DEBUG
  file: ~/.local/share/fub/logs/fub-dev.log
  structured: true

ui:
  interactive: true
  colors: true
  animations: true
  expert_mode: false
  show_icons: true
  theme_variant: "dark"

cleanup:
  temp_retention: 3
  log_retention: 7
  cache_retention: 7
  backup_before_cleanup: true
  aggressive_mode: false

  categories:
    development:
      enabled: true
      node_modules_retention: 14
      python_cache_retention: 3
      go_cache_retention: 3
      rust_cache_retention: 7

    containers:
      enabled: true
      stop_containers: false
      remove_volumes: false

safety:
  protect_dev_directories: true
  protected_directories:
    - "~/projects/*"
    - "~/work/*"
    - "~/git/*"
  require_confirmation: true

monitoring:
  enabled: true
  pre_cleanup_analysis: true
  performance_alerts: true
  historical_tracking: true
  alert_threshold: 85

dependencies:
  auto_check: true
  show_recommendations: true
  preferred_tools:
    - "git"
    - "docker"
    - "node"
    - "python"
    - "vscode"
    - "gum"
    - "btop"

scheduler:
  enabled: true
  daily_cleanup: false
  manual_mode: true
  notifications: true

performance:
  parallel_operations: true
  max_workers: 6
  memory_limit: "2G"
```

### Server Configuration

```yaml
# ~/.config/fub/config.yaml - Server setup
log:
  level: INFO
  file: /var/log/fub/fub.log
  structured: true
  rotate: true
  max_size: 50MB
  rotate_count: 10

ui:
  interactive: false
  colors: false
  animations: false
  expert_mode: true
  show_icons: false

cleanup:
  temp_retention: 1
  log_retention: 7
  cache_retention: 3
  backup_before_cleanup: true
  aggressive_mode: false
  require_confirmation: false

  categories:
    system:
      enabled: true
    development:
      enabled: false
    containers:
      enabled: false

safety:
  protect_dev_directories: false
  check_running_services: true
  require_confirmation: false
  expert_mode: true

monitoring:
  enabled: true
  pre_cleanup_analysis: true
  performance_alerts: true
  alert_threshold: 90
  historical_tracking: true

dependencies:
  auto_check: false
  show_recommendations: false

scheduler:
  enabled: true
  daily_cleanup: true
  time: "02:00"
  notifications: false
  background_operations: true

performance:
  parallel_operations: false
  max_workers: 2
  memory_limit: "512M"
  io_priority: 7
```

### Minimal Resource Configuration

```yaml
# ~/.config/fub/config.yaml - Minimal resource usage
log:
  level: WARN
  file: ~/.cache/fub/fub.log
  rotate: false
  structured: false

ui:
  interactive: false
  colors: false
  animations: false
  progress_bars: false
  confirmations: true

cleanup:
  temp_retention: 14
  log_retention: 30
  backup_before_cleanup: false
  require_confirmation: true

safety:
  protect_dev_directories: false
  require_confirmation: true

monitoring:
  enabled: false

dependencies:
  auto_check: false
  show_recommendations: false

scheduler:
  enabled: false

performance:
  parallel_operations: false
  max_workers: 1
  memory_limit: "256M"
```

### Automation/CI Configuration

```yaml
# ~/.config/fub/config.yaml - Automation/CI setup
log:
  level: ERROR
  file: /tmp/fub.log
  structured: true
  include_timestamps: false

ui:
  interactive: false
  colors: false
  confirmations: false
  expert_mode: true

cleanup:
  temp_retention: 0
  log_retention: 0
  backup_before_cleanup: false
  dry_run_by_default: false
  require_confirmation: false
  aggressive_mode: true

safety:
  protect_dev_directories: false
  require_confirmation: false
  expert_mode: true
  backup_before_major_operations: false

monitoring:
  enabled: false

dependencies:
  auto_check: false
  show_recommendations: false
  install_all_recommended: false

scheduler:
  enabled: false

performance:
  parallel_operations: true
  max_workers: 8
  memory_limit: "4G"

# CI-specific settings
ci:
  fail_on_error: true
  exit_code_on_error: 1
  junit_report: false
  artifacts_dir: "/tmp/fub-artifacts"
```

### High Security Configuration

```yaml
# ~/.config/fub/config.yaml - High security setup
log:
  level: INFO
  file: ~/.local/share/fub/logs/fub.log
  structured: true
  sensitive_data_filter: true

ui:
  interactive: true
  colors: true
  confirmations: true
  expert_mode: false

cleanup:
  temp_retention: 1
  log_retention: 7
  backup_before_cleanup: true
  require_confirmation: true
  validate_operations: true

safety:
  protect_dev_directories: true
  protected_directories:
    - "~/secure/*"
    - "~/keys/*"
    - "~/certificates/*"
  require_confirmation: true
  backup_before_major_operations: true
  enable_rollback: true

monitoring:
  enabled: true
  performance_alerts: true
  alert_threshold: 80
  log_all_operations: true

network:
  verify_ssl: true
  proxy: ""
  allowed_hosts:
    - "updates.ubuntu.com"
    - "security.ubuntu.com"

dependencies:
  auto_check: true
  require_confirmation: true
  validate_signatures: true
  trusted_sources_only: true
```

---

This comprehensive configuration reference covers all aspects of FUB's configuration system. For specific use cases and examples, see the configuration files in the `config/` directory and the built-in help system with `fub config --help`.