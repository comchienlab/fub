# FUB Safety System

Comprehensive safety and protection mechanisms for FUB (File & Utility Bront) cleanup operations.

## Overview

The FUB Safety System provides a multi-layered approach to ensuring safe cleanup operations while preventing accidental data loss. It combines pre-flight validation, development environment protection, service monitoring, backup capabilities, protection rules, and undo functionality.

## Architecture

### Core Modules

1. **Pre-flight System Checks** (`preflight-checks.sh`)
   - Ubuntu version compatibility validation
   - System stability assessment (load, memory, disk space)
   - Network connectivity verification
   - Power status monitoring (laptops)
   - Filesystem integrity checks

2. **Development Environment Protection** (`dev-protection.sh`)
   - Smart development directory detection
   - Active development session monitoring
   - Important file protection (.env, config files)
   - Unsaved work detection
   - Development backup creation

3. **Service and Container Monitoring** (`service-monitor.sh`)
   - Running service detection and protection
   - Docker/Podman container status monitoring
   - Database service identification
   - Development server detection
   - Service impact analysis

4. **Backup System** (`backup-system.sh`)
   - Configuration file backup
   - Package information preservation
   - Development environment snapshots
   - Compressed archive creation
   - Restoration capabilities

5. **Protection Rules** (`protection-rules.sh`)
   - Whitelist/blacklist configuration
   - User-defined protection patterns
   - Rule validation and management
   - Import/export capabilities
   - Category-based protection

6. **Undo Functionality** (`undo-system.sh`)
   - Operation logging and tracking
   - File backup before modification
   - One-click undo capabilities
   - Operation history management
   - Emergency recovery procedures

7. **Safety Integration** (`safety-integration.sh`)
   - Unified safety workflow
   - Safety level configuration
   - Comprehensive validation
   - Integration with existing FUB components

## Safety Levels

### Conservative (Maximum Safety)
- All safety checks enabled
- User confirmations required for all operations
- Automatic backup creation
- Verbose logging and reporting
- Recommended for production systems

### Standard (Balanced)
- Essential safety checks enabled
- Confirmations for destructive operations
- Automatic backup for important operations
- Moderate logging
- Default for most use cases

### Aggressive (Reduced Safety)
- Basic safety checks only
- Minimal confirmations
- Optional backup creation
- Reduced logging
- For automated cleanup scenarios

## Configuration

### Environment Variables

```bash
# Safety level (conservative, standard, aggressive)
export SAFETY_LEVEL="standard"

# Skip backup creation
export SAFETY_SKIP_BACKUP="false"

# Skip user confirmations
export SAFETY_SKIP_CONFIRMATIONS="false"

# Dry run mode (no actual changes)
export SAFETY_DRY_RUN="false"

# Verbose output
export SAFETY_VERBOSE="false"
```

### Protection Rules

Protection rules are stored in three locations with priority order:

1. **Global rules**: `/etc/fub/` (system-wide)
2. **User rules**: `~/.config/fub/` (user-specific)
3. **Local rules**: `.fub/` (project-specific)

#### Rule Categories

- **Files**: Individual file protection
- **Directories**: Directory path protection
- **Processes**: Running process protection
- **Services**: System service protection
- **Packages**: Software package protection
- **Patterns**: Pattern-based protection

#### Rule Format

```
# Category-specific rule
files:/home/user/.ssh
directories:/home/user/projects
processes:sshd
services:mysql
packages:ubuntu-minimal
patterns:node_modules

# Simple pattern (applies to all categories)
*.tmp
```

## Usage Examples

### Basic Safety Check

```bash
# Initialize safety system
source lib/safety/safety-integration.sh

# Run comprehensive safety checks
run_safety_checks "all" "/path/to/cleanup"
```

### Safety Workflow

```bash
# Conservative file deletion with full safety checks
SAFETY_LEVEL=conservative run_safety_workflow \
    "file_delete" \
    "Remove temporary files" \
    "/tmp/*.tmp" "/var/tmp/*.cache"

# Standard package removal with backup
SAFETY_LEVEL=standard SAFETY_VERBOSE=true run_safety_workflow \
    "package_remove" \
    "Remove unused package" \
    "old-package"

# Aggressive dry run for service management
SAFETY_LEVEL=aggressive SAFETY_DRY_RUN=true run_safety_workflow \
    "service_stop" \
    "Stop development service" \
    "my-dev-service"
```

### Individual Module Usage

```bash
# Pre-flight checks only
source lib/safety/preflight-checks.sh
perform_preflight_checks

# Development environment protection
source lib/safety/dev-protection.sh
perform_dev_protection

# Service monitoring
source lib/safety/service-monitor.sh
perform_service_monitoring

# Backup creation
source lib/safety/backup-system.sh
perform_backup "full"

# Protection rules management
source lib/safety/protection-rules.sh
perform_rule_management "show" "all" "user"

# Undo operations
source lib/safety/undo-system.sh
list_undo_operations 5
perform_undo "op_20231102_143022_12345"
```

## Integration with Existing FUB

The safety system integrates seamlessly with existing FUB components:

### Enhanced Safety Checks

The existing `lib/cleanup/safety-checks.sh` has been enhanced to automatically detect and use the new safety system when available, while maintaining backward compatibility.

### Cleanup Integration

Safety checks are automatically applied to all FUB cleanup operations, including:

- File and directory cleanup
- Package removal operations
- Service management
- Container cleanup
- Development environment cleanup

## Testing

### Comprehensive Test Suite

Run the complete test suite:

```bash
chmod +x test-safety-system.sh
./test-safety-system.sh
```

The test suite validates:

- Safety system initialization
- Configuration management
- Pre-flight checks
- Development detection
- Service monitoring
- Backup functionality
- Protection rules
- Undo operations
- Error handling
- Integration workflows

### Individual Module Testing

Test individual modules:

```bash
# Test pre-flight checks
source lib/safety/preflight-checks.sh
perform_preflight_checks

# Test backup system
source lib/safety/backup-system.sh
perform_backup "config" && echo "Backup test passed"

# Test protection rules
source lib/safety/protection-rules.sh
perform_rule_management "validate" "all" "user"
```

## Emergency Procedures

### System Recovery

If FUB cleanup operations cause system issues:

1. **Check undo operations**:
   ```bash
   source lib/safety/undo-system.sh
   list_undo_operations 10
   ```

2. **Restore from backup**:
   ```bash
   source lib/safety/backup-system.sh
   list_backups
   restore_backup "/path/to/backup.tar.gz"
   ```

3. **Restore packages**:
   ```bash
   # If packages were accidentally removed
   cd /path/to/backup/packages
   ./restore_packages.sh
   ```

### Configuration Recovery

If protection rules or configurations are corrupted:

1. **Restore default rules**:
   ```bash
   source lib/safety/protection-rules.sh
   perform_rule_management "create-default" "all" "user"
   ```

2. **Import from backup**:
   ```bash
   perform_rule_management "import" "protect" "user" "/path/to/rules.txt"
   ```

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**
   - Ensure running with appropriate privileges
   - Check sudo access for system-level operations

2. **Backup Creation Failed**
   - Verify sufficient disk space
   - Check backup directory permissions
   - Ensure backup tools (tar, gzip) are available

3. **Service Detection Issues**
   - Verify systemctl is available
   - Check user permissions for service queries

4. **Rule Validation Failures**
   - Check rule syntax and format
   - Validate file permissions for rule files
   - Ensure proper category usage

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
export SAFETY_VERBOSE="true"
export LOG_LEVEL="debug"

# Run operations with verbose output
run_safety_checks "all" "/path/to/cleanup"
```

### Log Files

Safety system logs are stored in:

- Undo operations: `/tmp/fub_undo_logs/`
- Backup metadata: Included in backup archives
- Configuration: Respective configuration directories

## Best Practices

1. **Use Conservative Safety Level**
   - For production systems
   - When dealing with critical data
   - For initial cleanup runs

2. **Create Regular Backups**
   - Before major cleanup operations
   - For important configuration changes
   - Before package removal operations

3. **Test Protection Rules**
   - Validate rule syntax
   - Test rule effectiveness
   - Review rule coverage

4. **Monitor Undo Operations**
   - Regular cleanup of old operations
   - Review operation history
   - Verify backup availability

5. **Document Custom Rules**
   - Maintain rule documentation
   - Share rules across team members
   - Version control rule files

## Contributing

To extend the safety system:

1. **Add New Modules**
   - Follow existing module patterns
   - Include comprehensive error handling
   - Add appropriate logging

2. **Extend Protection Rules**
   - Define new categories as needed
   - Maintain backward compatibility
   - Add validation for new rule types

3. **Enhance Safety Levels**
   - Consider use cases for new levels
   - Maintain clear security boundaries
   - Document level behaviors

4. **Improve Testing**
   - Add test cases for new functionality
   - Maintain high test coverage
   - Test edge cases and error conditions

## License

This safety system is part of the FUB project and follows the same licensing terms.