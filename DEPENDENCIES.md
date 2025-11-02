# FUB Dependencies Management System

A comprehensive dependency management system for the FUB Ubuntu utility toolkit that provides seamless tool installation, detection, and management capabilities.

## Overview

The FUB Dependencies Management System is designed to enhance the user experience by:

- **Optional Dependency Detection**: Automatically detects presence of optional tools (gum, btop, fd, ripgrep, etc.)
- **Intelligent Installation**: Interactive installation prompts with detailed descriptions and benefits
- **Graceful Degradation**: Provides fallback implementations when tools are missing
- **Version Compatibility**: Checks tool versions and compatibility requirements
- **Context-Aware Recommendations**: Suggests tools based on user behavior and system context
- **Progressive Enhancement**: Core functionality works everywhere, enhanced features with tools

## Quick Start

### Installation

1. **Initialize the dependency system**:
   ```bash
   ./lib/dependencies/fub-deps.sh init
   ```

2. **Check current dependencies**:
   ```bash
   ./lib/dependencies/fub-deps.sh check
   ```

3. **Run the installation wizard**:
   ```bash
   ./lib/dependencies/fub-deps.sh wizard
   ```

4. **Launch the interactive UI**:
   ```bash
   ./lib/dependencies/fub-deps.sh ui
   ```

### Basic Usage

```bash
# Check system dependencies
fub-deps check

# Install a specific tool
fub-deps install gum

# Install all tools from a category
fub-deps install --category core

# Get personalized recommendations
fub-deps recommend

# View system status
fub-deps status

# List available tools
fub-deps list --missing
```

## Features

### 1. Optional Dependency Detection

The system automatically detects and analyzes optional tools:

- **Tool Presence**: Checks if tools are installed and accessible
- **Version Detection**: Determines installed tool versions
- **Capability Analysis**: Analyzes what each tool can do
- **Compatibility Checking**: Validates tool compatibility with system requirements
- **Performance Impact**: Minimized through intelligent caching

### 2. Tool Installation Management

Safe and user-friendly tool installation:

- **Interactive Prompts**: Beautiful, informative installation prompts using gum
- **Multiple Package Managers**: Support for apt, snap, flatpak, brew, and more
- **User Confirmation**: Always requires explicit user consent
- **Progress Tracking**: Real-time installation progress and status
- **Rollback Capabilities**: Automatic rollback if installation fails
- **Security Validation**: Package validation and trusted sources only

### 3. Graceful Degradation

System continues to work perfectly even without optional tools:

- **Fallback Implementations**: Built-in alternatives for missing tools
- **Alternative Functions**: Enhanced versions of standard commands
- **Reduced Functionality Modes**: Clear messaging about limited features
- **Core Functionality Guarantee**: Essential features always available
- **Progressive Enhancement**: More features as tools become available

### 4. Version Checking and Compatibility

Comprehensive version management:

- **Semantic Version Parsing**: Advanced version comparison and validation
- **Compatibility Matrices**: Tool version compatibility requirements
- **Update Detection**: Identifies available tool updates
- **Security Scanning**: Checks for known vulnerabilities
- **Dependency Conflicts**: Detects and resolves version conflicts

### 5. Context-Aware Recommendations

Smart tool suggestions based on usage patterns:

- **User Context Detection**: Analyzes development, system administration, and productivity patterns
- **Behavior Tracking**: Learns from user preferences and installations
- **Capability-Based Suggestions**: Recommends tools for specific capabilities
- **Priority Ranking**: Prioritizes recommendations by importance and benefit
- **Benefit Explanations**: Clear explanations of why each tool is useful

## Supported Tools

### Core Tools (Essential)
- **gum**: Interactive terminal UI for shell scripts
- **btop**: Advanced system resource monitor
- **fd**: Fast, user-friendly alternative to find
- **ripgrep**: Blazing fast text search

### Enhanced Tools (Productivity)
- **dust**: Intuitive disk usage analysis
- **duf**: Beautiful disk space display
- **procs**: Modern process viewer
- **bat**: Enhanced cat with syntax highlighting
- **exa**: Modern ls replacement
- **htop**: Interactive process viewer
- **tree**: Directory tree display

### Development Tools
- **git-delta**: Beautiful diff display
- **lazygit**: Intuitive git interface
- **tig**: Text-mode git interface
- **jq**: JSON processor

### System Tools
- **neofetch**: System information display
- **hwinfo**: Hardware information
- **netcat**: Network utility

### Optional Tools
- **docker**: Container platform
- **podman**: Daemonless containers
- **lazydocker**: Docker management UI
- **fzf**: Fuzzy finder

## Configuration

### Configuration File

The system is configured via `config/dependencies.yaml`:

```yaml
# Automatic checking and installation
auto_check: true
auto_install: false
show_recommendations: true

# Package management
package_manager_preference: "apt,snap,flatpak"
install_timeout: 300
backup_before_install: true

# Performance
cache_ttl: 3600
parallel_checks: true
max_parallel: 4

# User preferences
silent_mode: false
verbose_mode: false
interactive: true
```

### Environment Variables

Override configuration with environment variables:

```bash
export FUB_DEPS_AUTO_CHECK=true
export FUB_DEPS_SILENT=false
export FUB_DEPS_PACKAGE_MANAGER=apt
```

### Configuration Commands

```bash
# Show current configuration
fub-deps config show

# Set configuration value
fub-deps config set auto_check true

# Reset to defaults
fub-deps config reset
```

## Integration

### Shell Integration

The system automatically creates shell aliases and functions:

```bash
# Enhanced commands that use available tools
ls      # Uses exa if available
grep    # Uses ripgrep if available
find    # Uses fd if available
cat     # Uses bat if available
monitor # Uses btop/htop/top
diskusage # Uses dust/ncdu/du
```

### FUB Integration

Integrates seamlessly with existing FUB components:

- **Theme System**: Uses FUB themes for consistent appearance
- **Configuration System**: Extends FUB configuration framework
- **Logging**: Integrates with FUB logging infrastructure
- **Error Handling**: Follows FUB error handling patterns

### Programmatic API

Use the dependency system in other scripts:

```bash
#!/bin/bash
source "lib/dependencies/fub-deps.sh"

# Initialize the system
init_fub_deps

# Ensure required tools are available
ensure_dependencies "gum" "ripgrep"

# Check if a capability is available
if is_capability_available "gum" "interactive-ui"; then
    gum confirm "Continue?"
fi

# Get recommendations
recommendations=$(get_priority_recommendations 80 5)
```

## Architecture

### Modular Design

The system is organized into modular components:

```
lib/dependencies/
├── core/                    # Core systems (config, registry, cache)
├── detection/               # Detection and analysis
├── installation/            # Installation management
├── ui/                     # Interactive user interface
└── fallback/               # Degradation and alternatives
```

### Key Components

1. **Core System** (`core/`):
   - `dependencies.sh` - Main integration point
   - `config.sh` - Configuration management
   - `registry.sh` - Tool registry and metadata
   - `cache.sh` - Caching and performance

2. **Detection System** (`detection/`):
   - `detection.sh` - Tool detection and analysis
   - `capability.sh` - Capability detection and analysis
   - `version-check.sh` - Version checking and compatibility

3. **Installation System** (`installation/`):
   - `installation.sh` - Installation management
   - `prompts.sh` - Interactive prompts and UI
   - `recommendations.sh` - Context-aware recommendations

4. **Fallback System** (`fallback/`):
   - `degradation.sh` - Graceful degradation handling
   - `alternatives.sh` - Alternative implementations

### Data Flow

1. **Initialization**: Load configuration, registry, and cache
2. **Detection**: Scan system for installed tools and capabilities
3. **Analysis**: Determine missing tools and compatibility
4. **Recommendation**: Generate context-aware suggestions
5. **Installation**: Safe, user-confirmed tool installation
6. **Integration**: Create shell aliases and fallbacks

## Testing

### Run Test Suite

```bash
# Run all tests
./test-dependencies-system.sh

# Test specific components
./test-dependencies-system.sh | grep "Testing.*Initialization"
```

### Test Coverage

The test suite covers:
- System initialization and configuration
- Tool detection and capability analysis
- Installation and validation
- Error handling and edge cases
- Performance and integration
- Fallback mechanisms

## Security

### Security Features

- **User Consent**: Never installs without explicit permission
- **Trusted Sources**: Only installs from official package repositories
- **Package Validation**: Validates package integrity when possible
- **Backup Before Install**: Creates system backups before changes
- **Rollback Capabilities**: Automatic rollback if installation fails
- **Sandbox Execution**: Runs installations in isolated environment when possible

### Security Best Practices

1. **Review Installations**: Always review what will be installed
2. **Use Official Sources**: Stick to official package repositories
3. **Regular Updates**: Keep tools updated for security
4. **Minimal Privileges**: Install with minimum required permissions
5. **Backup System**: Regular system backups before major changes

## Troubleshooting

### Common Issues

1. **Permission Denied**:
   ```bash
   sudo fub-deps install <tool>
   ```

2. **Package Manager Not Found**:
   ```bash
   fub-deps config set package_manager_preference "apt,snap"
   ```

3. **Cache Issues**:
   ```bash
   fub-deps check --force
   ```

4. **Installation Failures**:
   ```bash
   fub-deps status  # Check system status
   fub-deps config show  # Review configuration
   ```

### Debug Mode

Enable verbose logging:

```bash
export FUB_LOG_LEVEL=DEBUG
fub-deps check --verbose
```

### Getting Help

```bash
# General help
fub-deps help

# Command-specific help
fub-deps install --help

# Check system status
fub-deps status

# View logs
cat ~/.cache/fub/logs/fub.log
```

## Contributing

### Adding New Tools

1. Add to registry: `data/dependencies/registry.yaml`
2. Update detection logic if needed
3. Add fallback implementation if appropriate
4. Test with: `./test-dependencies-system.sh`

### Development Setup

```bash
# Clone repository
git clone <repository-url>
cd fub

# Run tests
./test-dependencies-system.sh

# Test specific functionality
./lib/dependencies/fub-deps.sh check
./lib/dependencies/fub-deps.sh wizard
```

## License

This project is part of the FUB Ubuntu utility toolkit. See the main project license for details.

## Changelog

### Version 1.0.0
- Initial release
- Core dependency detection and installation
- Interactive UI and recommendations
- Graceful degradation and fallbacks
- Version checking and compatibility
- Complete integration with FUB system

---

**FUB Dependencies Manager** - Making optional tool management seamless and secure.