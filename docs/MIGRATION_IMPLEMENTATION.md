# FUB Migration and Backward Compatibility Implementation

This document describes the implementation of migration and backward compatibility features for FUB (Filesystem Utility and Cleaner).

## Overview

The migration and backward compatibility system ensures that existing FUB users can upgrade from the basic CLI version to the enhanced interactive version without disruption. The implementation includes:

1. **Legacy Compatibility Layer** - Maintains backward compatibility with existing CLI usage
2. **Configuration Migration System** - Automatically detects and migrates legacy configurations
3. **Legacy Mode** - Provides script compatibility with legacy output formats
4. **Rollback System** - Enables safe upgrades with rollback capabilities
5. **Migration Utilities** - Provides tools for manual migration and validation

## Implementation Architecture

### 1. Legacy Compatibility Layer (`/lib/legacy/compatibility.sh`)

**Purpose**: Provides backward compatibility for existing CLI commands and arguments.

**Key Features**:
- Legacy command mapping (e.g., `fub --clean` → `fub cleanup`)
- Legacy argument parsing and transformation
- Deprecation warning system
- Legacy exit code handling
- Configuration format detection and validation

**Core Functions**:
```bash
parse_legacy_args()           # Maps legacy arguments to new format
map_legacy_command()         # Maps legacy commands to new commands
show_deprecation_warning()    # Displays deprecation warnings
handle_legacy_exit()         # Handles legacy exit codes
detect_legacy_config()       # Detects legacy configuration files
migrate_legacy_config()      # Migrates legacy configurations
validate_legacy_script()     # Validates script compatibility
```

**Command Mappings**:
```bash
# Legacy commands → New commands
fub --clean          → fub cleanup
fub --temp           → fub cleanup temp
fub --cache          → fub cleanup cache
fub --logs           → fub cleanup logs
fub --all            → fub cleanup all
fub clean            → fub cleanup
fub update           → fub system update
fub install          → fub package install
```

### 2. Legacy Mode Implementation (`/lib/legacy/legacy-mode.sh`)

**Purpose**: Provides script compatibility environment with legacy output formats.

**Key Features**:
- Non-interactive execution mode
- Simple text output formatting
- Legacy progress indicators
- Automatic confirmation in scripts
- Performance characteristics matching old version
- JSON/CSV output options for script parsing

**Environment Variables**:
```bash
FUB_LEGACY_MODE=true           # Enable legacy mode
FUB_LEGACY_OUTPUT_FORMAT=text   # Output format (text/json/csv)
FUB_LEGACY_COLORS=false         # Disable colors
FUB_LEGACY_PROGRESS=simple      # Progress indicator style
FUB_LEGACY_CONFIRMATION=auto    # Automatic confirmations
```

**Output Formats**:
- **Text**: Simple plain text output (default)
- **JSON**: Structured JSON for script parsing
- **CSV**: CSV format for spreadsheet import

### 3. Configuration Migration System (`/lib/legacy/config-migration.sh`)

**Purpose**: Automatically detects and migrates legacy configuration files to new YAML format.

**Key Features**:
- Automatic detection of legacy configuration files
- Validation of legacy configuration syntax
- Conversion from key-value to YAML format
- Backup and rollback capabilities
- Migration logging and auditing

**Legacy Configuration Locations**:
```bash
~/.fubrc
~/.config/fub/config
~/.fub/config
/etc/fub/config
/etc/fub.conf
~/.fub.conf
```

**Configuration Mapping**:
```bash
# Legacy format → New YAML format
CLEANUP_RETENTION_DAYS=7    → cleanup_retention: 7
CLEANUP_VERBOSE=true        → ui:
                              verbose: true
FUB_THEME=tokyo-night       → theme: tokyo-night
FUB_LOG_LEVEL=INFO         → logging:
                              level: INFO
```

**Migration Process**:
1. Detect legacy configuration files
2. Validate legacy configuration syntax
3. Create backup of existing configuration
4. Convert to new YAML format
5. Validate new configuration
6. Log migration details

### 4. Rollback System (`/lib/legacy/rollback.sh`)

**Purpose**: Provides system rollback capabilities for safe upgrades and failed migrations.

**Key Features**:
- Automatic rollback point creation
- Complete system state backup
- Configuration restoration
- Package state restoration
- Service state restoration
- User data restoration
- Emergency rollback capabilities

**Rollback Components**:
- **Configuration files**: User and system configurations
- **Package state**: Installed packages and repositories
- **Service state**: System services and timers
- **FUB installation**: FUB binaries and files
- **User data**: User preferences and data

**Rollback Commands**:
```bash
fub rollback create-point           # Create rollback point
fub rollback list-points            # List rollback points
fub rollback rollback <id>          # Perform rollback
fub rollback emergency               # Emergency rollback
```

### 5. Migration Commands Integration (`/bin/fub`)

**Purpose**: Integrates migration and rollback utilities into the main FUB executable.

**Migration Commands**:
```bash
fub migration migrate-config        # Migrate configurations
fub migration validate-script       # Validate scripts
fub migration migrate-script        # Migrate scripts
fub migration detect-legacy         # Detect legacy configs
```

**Rollback Commands**:
```bash
fub rollback create-point           # Create rollback point
fub rollback list-points            # List rollback points
fub rollback rollback <id>          # Perform rollback
fub rollback emergency               # Emergency rollback
```

**Legacy Mode Options**:
```bash
fub --legacy-mode                   # Enable legacy mode
export FUB_LEGACY_MODE=true        # Environment variable
```

## Usage Examples

### Basic Migration

```bash
# Detect legacy configurations
fub migration detect-legacy

# Migrate all legacy configurations
fub migration migrate-config

# Validate existing scripts
fub migration validate-script ./cleanup.sh

# Migrate a specific script
fub migration migrate-script ./cleanup.sh
```

### Legacy Mode Usage

```bash
# Enable legacy mode for a single command
fub --legacy-mode cleanup --force

# Enable legacy mode for all commands
export FUB_LEGACY_MODE=true
fub cleanup --force
fub system update
```

### Rollback Operations

```bash
# Create a rollback point before major changes
fub rollback create-point

# List available rollback points
fub rollback list-points

# Rollback to a specific point
fub rollback rollback auto-20231201_143022

# Emergency rollback
fub rollback emergency
```

### Script Compatibility

```bash
#!/bin/bash
# Legacy script continues to work

# Set legacy mode for the entire script
export FUB_LEGACY_MODE=true

# Use legacy commands
fub --clean --dry-run
fub --temp --force
fub --cache --verbose

# Or use new commands in legacy mode
fub cleanup --dry-run
fub cleanup temp --force
fub cleanup cache --verbose
```

## Testing

The implementation includes comprehensive test coverage in `/tests/test-migration-compatibility.sh`:

- **Unit Tests**: Test individual components
- **Integration Tests**: Test complete migration scenarios
- **Performance Tests**: Ensure migration speed
- **Compatibility Tests**: Verify script compatibility

**Run Tests**:
```bash
cd /path/to/fub
./tests/test-migration-compatibility.sh
```

## Safety Considerations

### Configuration Migration
- Automatic backup of existing configurations
- Validation of both legacy and new configurations
- Rollback capability for failed migrations
- Detailed logging of all migration operations

### Rollback System
- Complete system state backup
- Atomic rollback operations
- Emergency rollback for critical failures
- Validation of rollback integrity

### Legacy Mode
- Non-breaking behavior for existing scripts
- Performance characteristics matching old version
- Graceful degradation when dependencies are missing
- Clear deprecation warnings for obsolete features

## File Structure

```
fub/
├── bin/
│   └── fub                              # Main executable with migration integration
├── lib/
│   └── legacy/
│       ├── compatibility.sh             # Legacy compatibility layer
│       ├── legacy-mode.sh               # Legacy mode implementation
│       ├── config-migration.sh          # Configuration migration system
│       └── rollback.sh                  # Rollback system
├── tests/
│   └── test-migration-compatibility.sh  # Test suite
└── docs/
    ├── MIGRATION_GUIDE.md              # User migration guide
    └── MIGRATION_IMPLEMENTATION.md     # This document
```

## Dependencies

The migration system has minimal dependencies:

- **Required**: bash 4.0+, coreutils
- **Optional**:
  - `bc` for performance timing
  - `yq` for YAML validation (fallback validation available)
  - System commands being migrated (apt, systemctl, etc.)

## Troubleshooting

### Common Issues

1. **Legacy configuration not detected**
   - Check file permissions
   - Verify configuration file location
   - Run `fub migration detect-legacy`

2. **Migration fails**
   - Check migration log: `~/.local/share/fub/logs/migration.log`
   - Validate legacy configuration syntax
   - Manually backup and retry migration

3. **Legacy mode not working**
   - Set environment variable: `export FUB_LEGACY_MODE=true`
   - Check for script compatibility with `fub migration validate-script`
   - Use command-line flag: `fub --legacy-mode`

4. **Rollback fails**
   - Check rollback permissions
   - Verify rollback point exists
   - Use emergency rollback: `fub rollback emergency`

### Debug Mode

Enable debug logging:
```bash
export FUB_LOG_LEVEL=DEBUG
fub migration migrate-config
```

## Future Enhancements

Potential improvements for future versions:

1. **Enhanced script migration**: More sophisticated script analysis and automatic updates
2. **Configuration validation**: Advanced validation with schema checking
3. **Performance optimization**: Faster migration for large configurations
4. **GUI migration tool**: Visual migration assistant
5. **Cloud integration**: Remote configuration backup and sync

## Conclusion

The migration and backward compatibility implementation provides a comprehensive solution for upgrading FUB from basic CLI to enhanced interactive version while ensuring:

- **Zero disruption** for existing users
- **Automatic migration** of configurations
- **Script compatibility** with legacy mode
- **Safe upgrades** with rollback capabilities
- **Clear migration path** with comprehensive documentation

This implementation maintains the FUB principle of providing powerful system utilities while ensuring a smooth transition for all users.