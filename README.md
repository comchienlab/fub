# FUB - Fast Ubuntu Utility Toolkit

A comprehensive modular bash-based utility toolkit for Ubuntu system maintenance, cleanup, and development tasks.

## 🚀 Features

- **Modular Architecture**: Extensible design with pluggable modules
- **Modern Bash Practices**: Uses `set -euo pipefail`, proper error handling, and shellcheck compliance
- **Beautiful UI**: Tokyo Night theme with rich color support and interactive elements
- **Configuration Management**: YAML-based configuration with validation
- **Comprehensive Logging**: Multi-level logging with file rotation
- **Testing Framework**: Built-in test suite for all components
- **Production Ready**: Error handling, validation, and backup systems

## 📁 Architecture

```
fub/
├── bin/
│   └── fub                    # Main executable entry point
├── lib/
│   ├── common.sh              # Shared utilities and core functions
│   ├── ui.sh                  # UI/interaction helpers
│   ├── config.sh              # Configuration management system
│   ├── theme.sh               # Tokyo Night theme system
│   └── cleanup/               # Cleanup modules
│       └── cleanup.sh         # System cleanup utilities
├── config/
│   ├── default.yaml           # Default configuration
│   └── themes/
│       └── tokyo-night.yaml   # Theme definition
├── tests/
│   ├── test-framework.sh      # Test framework
│   ├── test-common.sh         # Common library tests
│   ├── test-ui.sh             # UI library tests
│   └── test-config.sh         # Configuration tests
└── README.md                  # This file
```

## 🛠️ Installation

### Prerequisites

- Ubuntu 20.04 or later
- Bash 4.0 or later
- Standard Ubuntu utilities (apt-get, systemctl, curl, etc.)

### Quick Install

```bash
# Clone the repository
git clone <repository-url> fub
cd fub

# Make the main executable
chmod +x bin/fub

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
```

## 🎯 Usage

### Basic Commands

```bash
# Show help
fub --help

# Show version
fub --version

# Clean temporary files
fub cleanup temp

# Clean all caches and temporary files
fub cleanup all

# Update system packages
fub system update

# Check system status
fub system status

# Install a package
fub package install git

# Check service status
fub service status nginx

# Test network connectivity
fub network test
```

### Advanced Usage

```bash
# Run with custom configuration
fub --config /path/to/config.yaml cleanup all

# Dry run (show what would be done)
fub --dry-run cleanup all

# Verbose output
fub --verbose cleanup all

# Non-interactive mode
fub --no-interactive system update

# Custom log level
fub --log-level DEBUG cleanup all
```

## 🧹 Cleanup Operations

FUB provides comprehensive cleanup capabilities:

### Temporary Files
```bash
fub cleanup temp           # Clean temporary files
fub cleanup temp --retention 14  # Custom retention period
```

### System Caches
```bash
fub cleanup cache          # Clean package and system caches
fub cleanup packages       # Clean package caches specifically
```

### Log Files
```bash
fub cleanup logs           # Clean old log files
fub cleanup logs --retention 60  # Custom retention
```

### Thumbnails
```bash
fub cleanup thumbnails     # Clean thumbnail cache
```

### Complete Cleanup
```bash
fub cleanup all            # Clean everything
fub cleanup all --force    # Skip confirmation prompts
```

## ⚙️ Configuration

### Default Configuration

The system uses `config/default.yaml` as the base configuration:

```yaml
# Logging configuration
log:
  level: INFO
  file: ~/.cache/fub/logs/fub.log
  rotate: true

# Theme configuration
theme: tokyo-night

# Cleanup settings
cleanup:
  temp_retention: 7
  log_retention: 30
  cache_retention: 14

# Network settings
network:
  timeout: 10
  retries: 3
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

## 🧪 Testing

FUB includes a comprehensive test suite:

### Run All Tests

```bash
# Run all test suites
./tests/test-framework.sh

# Or use the main script
./bin/fub test
```

### Run Individual Test Suites

```bash
# Test common library
./tests/test-common.sh

# Test UI library
./tests/test-ui.sh

# Test configuration system
./tests/test-config.sh
```

### Test Options

```bash
# Verbose test output
./tests/test-framework.sh --verbose

# Stop on first failure
./tests/test-framework.sh --stop-on-failure

# Custom output directory
./tests/test-framework.sh --output-dir /tmp/test-results
```

## 🛡️ Safety Features

### Backup System

FUB automatically creates backups before major operations:

```bash
# Configuration is backed up to ~/.local/share/fub/backups/
# Cleanup operations create system restore points
# Package changes are logged and can be reversed
```

### Dry Run Mode

Preview operations without executing:

```bash
fub --dry-run cleanup all
fub --dry-run system update
```

### Validation

All operations include validation:

- Configuration validation
- Input validation
- Permission checks
- Dependency verification

## 📝 Logging

FUB provides comprehensive logging:

### Log Levels

- `DEBUG` - Detailed debugging information
- `INFO` - General information messages
- `WARN` - Warning messages
- `ERROR` - Error messages
- `FATAL` - Critical errors (causes exit)

### Log Locations

- Main log: `~/.cache/fub/logs/fub.log`
- Rotated logs: `~/.cache/fub/logs/fub.log.1`, etc.
- System logs: Integration with system journald

### Log Configuration

```yaml
log:
  level: INFO
  file: ~/.cache/fub/logs/fub.log
  max_size: 10MB
  rotate: true
  rotate_count: 5
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

## 🆘 Support

- Issues: [GitHub Issues](https://github.com/fub-toolkit/fub/issues)
- Documentation: [Wiki](https://github.com/fub-toolkit/fub/wiki)
- Discussions: [GitHub Discussions](https://github.com/fub-toolkit/fub/discussions)

## 🙏 Acknowledgments

- Tokyo Night theme by [Folke](https://github.com/folke/tokyonight.nvim)
- Inspired by various system administration tools
- Built with modern bash best practices
