# FUB Migration Guide

This guide helps you migrate from basic FUB to the enhanced interactive version with backward compatibility.

## Table of Contents

1. [Overview](#overview)
2. [What's New](#whats-new)
3. [Breaking Changes](#breaking-changes)
4. [Migration Steps](#migration-steps)
5. [Configuration Migration](#configuration-migration)
6. [Script Migration](#script-migration)
7. [Command Reference](#command-reference)
8. [Troubleshooting](#troubleshooting)

## Overview

FUB has been enhanced from a basic CLI tool to a comprehensive interactive system maintenance toolkit while maintaining full backward compatibility with existing usage patterns.

### Key Changes

- **Interactive UI**: New arrow-key navigation and visual feedback
- **Enhanced Categories**: APT, development, containers, IDE, build artifacts, dependencies
- **Safety Features**: Pre-flight checks, backup system, undo functionality
- **Performance Monitoring**: Real-time system analysis and metrics
- **Scheduled Maintenance**: Profile-based automated maintenance
- **Legacy Mode**: Full backward compatibility for existing scripts

## What's New

### 1. Interactive Interface

```bash
# Launch interactive menu
fub

# Interactive cleanup with category selection
fub cleanup --interactive
```

### 2. Enhanced Cleanup Categories

```bash
# Enhanced APT cleanup (orphans, old kernels)
fub cleanup apt

# Development environment cleanup
fub cleanup dev

# Container runtime cleanup
fub cleanup containers

# IDE/editor cleanup
fub cleanup ide

# Build artifact cleanup (git-aware)
fub cleanup build

# Dependency manager cleanup
fub cleanup deps
```

### 3. System Monitoring

```bash
# Real-time system monitoring
fub monitor

# Performance analysis
fub performance

# System information
fub info
```

### 4. Scheduled Maintenance

```bash
# Initialize scheduler
fub scheduler init

# Enable maintenance profile
fub scheduler enable desktop

# Interactive scheduler management
fub scheduler ui-menu
```

## Breaking Changes

### Command Structure

Most old commands continue to work, but some have been reorganized:

| Old Command | New Command | Status |
|-------------|-------------|---------|
| `fub --clean` | `fub cleanup` | ✅ Compatible (with warning) |
| `fub --temp` | `fub cleanup temp` | ✅ Compatible (with warning) |
| `fub --cache` | `fub cleanup cache` | ✅ Compatible (with warning) |
| `fub --all` | `fub cleanup all` | ✅ Compatible (with warning) |
| `fub clean` | `fub cleanup` | ✅ Compatible (with warning) |
| `fub update` | `fub system update` | ✅ Compatible (with warning) |

### Configuration Format

Configuration has moved from simple key-value files to YAML format:

**Old Format:**
```bash
CLEANUP_RETENTION_DAYS=7
CLEANUP_VERBOSE=true
FUB_THEME=tokyo-night
```

**New Format:**
```yaml
cleanup_retention: 7
ui:
  verbose: true
theme: tokyo-night
```

## Migration Steps

### Step 1: Backup Current Configuration

```bash
# Backup existing configuration
cp ~/.fubrc ~/.fubrc.backup.$(date +%Y%m%d_%H%M%S)
cp -r ~/.config/fub ~/.config/fub.backup.$(date +%Y%m%d_%H%M%S)
```

### Step 2: Update FUB Installation

```bash
# Install new FUB version
sudo apt update
sudo apt install fub

# Or if installing from source
git clone https://github.com/fub-toolkit/fub.git
cd fub
sudo make install
```

### Step 3: Migrate Configuration

```bash
# Automatic configuration migration
fub migrate-config

# Manual migration (if needed)
fub migrate-config --from ~/.fubrc --to ~/.config/fub/config.yaml
```

### Step 4: Test Legacy Commands

```bash
# Test that old commands still work
fub --clean --dry-run
fub --temp --dry-run
fub --cache --dry-run
```

### Step 5: Update Scripts (Optional)

```bash
# Validate script compatibility
fub validate-script /path/to/your/script.sh

# Migrate scripts automatically
fub migrate-script /path/to/your/script.sh
```

## Configuration Migration

### Automatic Migration

FUB automatically detects and migrates legacy configuration files:

1. **Detection**: Searches for legacy config files
2. **Backup**: Creates backup of existing new config
3. **Migration**: Converts to new YAML format
4. **Validation**: Ensures migrated config is valid

### Manual Migration

If automatic migration fails, you can migrate manually:

```bash
# Create new configuration directory
mkdir -p ~/.config/fub

# Convert legacy configuration
cat > ~/.config/fub/config.yaml << 'EOF'
# Migrated from legacy FUB configuration
# Migration date: $(date)

cleanup_retention: 7
ui:
  verbose: false
theme: tokyo-night
logging:
  level: INFO
system:
  dry_run: false
EOF
```

### Configuration Options

| Legacy Option | New Option | Description |
|---------------|------------|-------------|
| `CLEANUP_RETENTION_DAYS` | `cleanup_retention` | Days to keep files |
| `CLEANUP_VERBOSE` | `ui.verbose` | Enable verbose output |
| `CLEANUP_DRY_RUN` | `system.dry_run` | Enable dry-run mode |
| `FUB_THEME` | `theme` | Color theme |
| `FUB_LOG_LEVEL` | `logging.level` | Logging level |

## Script Migration

### Script Compatibility

Existing scripts continue to work with legacy mode:

```bash
#!/bin/bash

# This script will work with the new FUB version
fub --clean --dry-run
fub --temp
fub --cache
```

### Script Validation

Validate your scripts for compatibility:

```bash
# Check script compatibility
fub validate-script my-maintenance-script.sh

# This will show warnings for deprecated patterns
```

### Script Migration

Update scripts to use new commands:

```bash
# Before (legacy)
fub --clean
fub --temp --force
fub --cache --verbose

# After (new)
fub cleanup
fub cleanup temp --force
fub cleanup cache --verbose
```

### Legacy Mode

Force scripts to run in legacy mode:

```bash
# Set environment variable
export FUB_LEGACY_MODE=true

# Or use command line flag
fub --legacy-mode cleanup
```

## Command Reference

### Legacy Commands (Deprecated)

These commands work but show deprecation warnings:

```bash
fub --clean [options]          # → fub cleanup [options]
fub --temp [options]           # → fub cleanup temp [options]
fub --cache [options]          # → fub cleanup cache [options]
fub --logs [options]           # → fub cleanup logs [options]
fub --all [options]            # → fub cleanup all [options]

fub --version                  # → fub --version
fub --help                     # → fub --help
fub --verbose                  # → fub --verbose
fub --quiet                    # → fub --quiet
```

### Current Commands

```bash
# System operations
fub cleanup [category] [options]
fub system [action] [options]
fub package [action] [options]
fub service [action] [options]
fub network [action] [options]
fub security [action] [options]

# Interactive operations
fub                            # Launch interactive menu
fub cleanup --interactive      # Interactive cleanup
fub scheduler ui-menu          # Interactive scheduler

# Monitoring
fub monitor                    # System monitoring
fub performance                # Performance analysis
fub info                       # System information

# Scheduler
fub scheduler [action] [options]
```

### Common Migration Patterns

| Pattern | Old Command | New Command |
|---------|-------------|-------------|
| Clean temp files | `fub --temp` | `fub cleanup temp` |
| Clean cache | `fub --cache` | `fub cleanup cache` |
| Clean logs | `fub --logs` | `fub cleanup logs` |
| Clean all | `fub --all` | `fub cleanup all` |
| Force clean | `fub --clean --force` | `fub cleanup --force` |
| Dry run | `fub --clean --dry` | `fub cleanup --dry-run` |
| Verbose output | `fub --clean --verbose` | `fub cleanup --verbose` |

## Troubleshooting

### Common Issues

#### 1. Configuration Not Found

**Problem**: FUB can't find your configuration

**Solution**:
```bash
# Check for legacy config
ls -la ~/.fubrc ~/.config/fub/

# Migrate automatically
fub migrate-config

# Or specify config location
fub --config ~/.fubrc cleanup
```

#### 2. Script Fails with Deprecation Warnings

**Problem**: Your script shows deprecation warnings

**Solution**:
```bash
# Enable legacy mode for the script
export FUB_LEGACY_MODE=true
./your-script.sh

# Or update the script
fub migrate-script your-script.sh
```

#### 3. Interactive Mode Not Working

**Problem**: Interactive mode doesn't work in scripts

**Solution**:
```bash
# Force non-interactive mode
fub --no-interactive cleanup

# Or set environment variable
export FUB_INTERACTIVE=false
fub cleanup
```

#### 4. Theme Issues

**Problem**: Colors don't display correctly

**Solution**:
```bash
# Use minimal theme for maximum compatibility
fub --theme minimal cleanup

# Or disable colors
export FUB_COLORS=false
fub cleanup
```

### Getting Help

```bash
# General help
fub --help

# Category-specific help
fub cleanup --help
fub scheduler --help

# Interactive help
fub help cleanup
```

### Reporting Issues

If you encounter migration issues:

1. Check this guide first
2. Run with verbose output: `fub --verbose`
3. Enable legacy mode: `FUB_LEGACY_MODE=true fub`
4. Report issues at: https://github.com/fub-toolkit/fub/issues

## Rollback

If you need to rollback to the previous version:

```bash
# Uninstall new version
sudo apt remove fub

# Restore old configuration
mv ~/.fubrc.backup.* ~/.fubrc
mv ~/.config/fub.backup.* ~/.config/fub

# Install old version (if available)
sudo apt install fub=1.0.0
```

## Next Steps

1. **Test**: Verify your existing scripts work
2. **Explore**: Try the new interactive interface
3. **Configure**: Customize your new configuration
4. **Migrate**: Update scripts to use new commands (optional)
5. **Schedule**: Set up automated maintenance

Welcome to the enhanced FUB experience! 🎉