# FUB Configuration Management System

This document describes the comprehensive configuration management system implemented for FUB (Filesystem Utility and Cleaner).

## Overview

The FUB configuration management system provides:

- **Centralized Configuration**: User-friendly configuration stored in `~/.fub/`
- **Profile Management**: Pre-configured profiles for desktop, server, and developer use cases
- **Theme Customization**: Full theming system with Tokyo Night as default
- **Import/Export**: Easy configuration backup and sharing
- **Validation**: Comprehensive configuration validation with error detection
- **Interactive UI**: Gum-based interactive configuration interface

## Directory Structure

```
~/.fub/                          # User configuration directory
├── config.yaml                  # Main user configuration
├── current_profile              # Active profile indicator
├── profiles/                    # Custom user profiles
├── themes/                      # Custom user themes
└── backups/                     # Configuration backups

config/                          # System configuration
├── default.yaml                 # Default system configuration
├── profiles/                    # System profiles
│   ├── desktop.yaml
│   ├── server.yaml
│   ├── developer.yaml
│   └── minimal.yaml
├── themes/                      # System themes
│   └── tokyo-night.yaml
└── schemas/                     # Configuration validation schemas
    ├── config-schema.yaml
    ├── profile-schema.yaml
    └── theme-schema.yaml
```

## Configuration Files

### User Configuration (`~/.fub/config.yaml`)

```yaml
# FUB User Configuration
user:
  name: "username"
  email: "user@example.com"
  preferred_theme: "tokyo-night"
  interactive_mode: true
  show_advanced_options: false

profile:
  current: "desktop"
  auto_switch: false
  custom_operations: []

theme:
  name: "tokyo-night"
  custom_colors: {}
  enable_animations: true
  high_contrast: false

safety:
  backup_before_cleanup: true
  confirm_dangerous_operations: true
  protected_directories:
    - "$HOME/Documents"
    - "$HOME/Projects"
  exclude_patterns:
    - "*.important"
    - ".git"

notifications:
  enabled: true
  desktop_notifications: true
  email_notifications: false
  completion_sound: false

performance:
  parallel_jobs: 4
  max_memory_usage: "1G"
  nice_level: 10
  io_priority: 7
```

### System Configuration (`config/default.yaml`)

```yaml
# FUB Default Configuration
log.level: INFO
log.file: ~/.cache/fub/logs/fub.log
theme: tokyo-night
interactive: true
timeout: 30
dry_run: false

cleanup.temp_retention: 7
cleanup.log_retention: 30
cleanup.cache_retention: 14

network.timeout: 10
network.retries: 3
```

## Profiles

### Desktop Profile
- **Purpose**: Desktop users with GUI applications
- **Schedule**: Daily at 18:00
- **Operations**: temp, cache, thumbnails
- **Features**: User notifications, system load checks

### Server Profile
- **Purpose**: Server environments with minimal resource usage
- **Schedule**: Daily at 02:00 (off-peak)
- **Operations**: logs, temp, system cache
- **Features**: Low resource usage, background operation

### Developer Profile
- **Purpose**: Development environments
- **Schedule**: Manual or on-demand
- **Operations**: build artifacts, dependencies, development tools
- **Features**: Git-aware cleanup, IDE cache management

## Themes

### Tokyo Night Theme (Default)
Based on the popular Tokyo Night color scheme with comprehensive color definitions for:

- **ANSI Colors**: 16-color palette
- **UI Elements**: Buttons, inputs, dialogs, menus
- **Semantic Colors**: Success, warning, error, info
- **Syntax Highlighting**: Code highlighting colors
- **File Type Colors**: Visual indicators for different file types

### Custom Themes
Create custom themes by copying an existing theme and modifying colors:

```bash
# Create custom theme
fub theme create my-theme "My Custom Theme"

# Customize colors
fub theme customize my-theme background "#1e1e2e"
fub theme customize my-theme success "#a6e3a1"

# Switch to custom theme
fub theme switch my-theme
```

## Configuration Management

### Using the Interactive UI

```bash
# Launch configuration interface
fub config

# Direct access to specific areas
fub config system
fub config user
fub config themes
fub config profiles
fub config validate
```

### Command Line Interface

```bash
# Configuration status
fub config status

# Switch profiles
fub profile switch desktop
fub profile list

# Theme management
fub theme list
fub theme switch tokyo-night
fub theme create my-theme "Description"

# Configuration validation
fub config validate
fub config validate --strict

# Import/Export
fub config export ~/backup/fub-config.yaml
fub config import ~/backup/fub-config.yaml
```

### Programmatic API

```bash
# Source the configuration library
source lib/config-integration.sh

# Initialize configuration system
init_fub_config

# Get configuration values
log_level=$(get_fub_config "log.level" "INFO")
current_profile=$(get_fub_config "profile.current")

# Set configuration values
set_fub_config "log.level" "DEBUG" "user"
set_fub_config "theme.name" "light" "user"

# Validate configuration
validate_all_configs "false"
```

## Configuration Validation

The system includes comprehensive validation with:

### Schema-Based Validation
- **Configuration Schemas**: YAML schemas define valid structure
- **Type Checking**: Validates data types and formats
- **Range Validation**: Ensures values are within acceptable ranges
- **Pattern Matching**: Validates strings against regex patterns

### Validation Levels
- **Errors**: Critical issues that must be fixed
- **Warnings**: Non-critical issues that should be reviewed
- **Suggestions**: Recommendations for improvement

### Auto-Fix
Automatically fixes common configuration issues:
- Log level capitalization
- Boolean value formatting
- Indentation consistency
- Basic syntax errors

## Import/Export Functionality

### Export Configuration

```bash
# Export user configuration
fub config export ~/backup/fub-user-config.yaml

# Export complete configuration
fub config export --complete ~/backup/fub-full-config.yaml

# Export with profiles and themes
fub config export --include-profiles --include-themes ~/backup/fub-complete.yaml
```

### Import Configuration

```bash
# Import configuration (merge)
fub config import ~/backup/fub-config.yaml

# Import configuration (replace)
fub config import --replace ~/backup/fub-config.yaml

# Import specific components
fub theme import ~/backup/custom-theme.yaml
fub profile import ~/backup/custom-profile.yaml
```

### Backup and Restore

```bash
# Create configuration backup
fub config backup

# List available backups
fub config list-backups

# Restore from backup
fub config restore ~/fub/backups/user_config_20231101_120000.tar.gz
```

## Configuration API

### Core Functions

```bash
# Initialize configuration system
init_fub_config()

# Get configuration values
get_fub_config(key, default_value)
get_user_config(key, default_value)
get_config(key, default_value)

# Set configuration values
set_fub_config(key, value, scope)
update_user_config_key(key, value)
set_config(key, value, scope)

# Profile management
get_current_profile()
set_current_profile(profile_name)
list_profiles()
create_profile(name, description, base_profile)

# Theme management
get_theme_color(color_key, default_value)
set_theme(color_name)
list_themes()
create_theme(name, description, base_theme)
```

### Validation Functions

```bash
# Validate configuration
validate_config_file(config_file, schema_file, strict)
validate_all_configs(strict)
validate_user_config()
validate_theme(theme_name)

# Auto-fix configuration
auto_fix_config(config_file)
```

### Import/Export Functions

```bash
# Export configuration
export_fub_config(output_file, format, include_options)
export_user_config(output_file, include_profiles)
export_theme(theme_name, output_file)

# Import configuration
import_fub_config(input_file, replace_existing, backup_before)
import_user_config(input_file, replace_existing)
import_theme(input_file, theme_name)
```

## Configuration Precedence

Configuration values are loaded in the following order (later values override earlier ones):

1. **System Defaults**: Built-in default values
2. **System Configuration**: `config/default.yaml`
3. **User Configuration**: `~/.fub/config.yaml`
4. **Profile Configuration**: Active profile settings
5. **Environment Variables**: `FUB_*` environment variables
6. **Runtime Overrides**: Temporary runtime changes

## Environment Variables

The following environment variables can override configuration:

```bash
# Logging
export FUB_LOG_LEVEL=DEBUG
export FUB_LOG_FILE=/custom/path/fub.log

# Theme
export FUB_THEME=light

# Behavior
export FUB_INTERACTIVE=false
export FUB_TIMEOUT=60
export FUB_DRY_RUN=true
```

## Configuration Migration

The system supports configuration migration between versions:

```bash
# Migrate configuration
fub config migrate 0.1.0 1.0.0

# Reset configuration
fub config reset user    # Reset user configuration
fub config reset system  # Reset system configuration (requires sudo)
fub config reset all     # Reset all configuration
```

## Troubleshooting

### Common Issues

1. **Configuration not loading**
   ```bash
   # Check configuration status
   fub config status

   # Validate configuration
   fub config validate --strict
   ```

2. **Theme not applying**
   ```bash
   # Check theme file exists
   ls -la ~/.fub/themes/
   ls -la config/themes/

   # Validate theme
   fub config validate-theme tokyo-night
   ```

3. **Profile not found**
   ```bash
   # List available profiles
   fub profile list

   # Check current profile
   cat ~/.fub/current_profile
   ```

### Debug Mode

Enable debug logging to troubleshoot configuration issues:

```bash
export FUB_LOG_LEVEL=DEBUG
fub config status
```

### Reset Configuration

If configuration becomes corrupted, reset to defaults:

```bash
# Backup current configuration
fub config backup

# Reset user configuration
fub config reset user

# Run setup wizard
fub config setup
```

## File Format Reference

### YAML Configuration Format

All configuration files use YAML format with the following conventions:

- **Key-Value Pairs**: `key: value`
- **Sections**: `section_name:`
- **Lists**:
  ```yaml
  operations:
    - temp
    - cache
    - logs
  ```
- **Nested Objects**:
  ```yaml
  performance:
    parallel_jobs: 4
    max_memory_usage: "1G"
  ```

### Data Types

- **String**: `"text value"` or `text_value`
- **Integer**: `42`
- **Boolean**: `true` or `false`
- **Array**: List of values with `-` prefix
- **Object**: Nested key-value pairs

### Validation Patterns

- **Log Level**: `DEBUG|INFO|WARN|ERROR|FATAL`
- **Theme Name**: `[a-zA-Z0-9_-]+`
- **File Path**: Valid filesystem path
- **Color Code**: `^#[0-9a-fA-F]{6}$`
- **Memory Size**: `^[0-9]+[KMGT]?B$`
- **Timeout**: Positive integer (seconds)

## Integration with Other Modules

The configuration system integrates with:

- **Scheduler**: Profile-based scheduling configuration
- **Interactive UI**: Theme and preference integration
- **Safety Systems**: User-defined protection rules
- **Logging**: Configurable logging levels and destinations
- **Performance**: User-configurable resource limits

## Best Practices

1. **Regular Backups**: Create regular configuration backups
2. **Validation**: Validate configuration after changes
3. **Profiles**: Use profiles for different environments
4. **Themes**: Create custom themes for better visibility
5. **Documentation**: Document custom configurations
6. **Version Control**: Track configuration changes for teams
7. **Testing**: Test configuration changes in non-production environments

## Support

For configuration-related issues:

1. Check configuration status: `fub config status`
2. Validate configuration: `fub config validate --strict`
3. Review logs: `tail -f ~/.cache/fub/logs/fub.log`
4. Reset configuration: `fub config reset user`
5. Run setup wizard: `fub config setup`

For more help, use `fub config --help` or consult the main FUB documentation.