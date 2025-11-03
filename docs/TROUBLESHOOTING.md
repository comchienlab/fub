# FUB Troubleshooting Guide

A comprehensive guide to diagnosing and resolving issues with FUB's advanced features.

## 📋 Table of Contents

- [Getting Help](#getting-help)
- [Common Issues](#common-issues)
- [Installation Issues](#installation-issues)
- [Interactive UI Issues](#interactive-ui-issues)
- [Dependency Management Issues](#dependency-management-issues)
- [Cleanup Operation Issues](#cleanup-operation-issues)
- [Safety System Issues](#safety-system-issues)
- [Monitoring Issues](#monitoring-issues)
- [Scheduler Issues](#scheduler-issues)
- [Performance Issues](#performance-issues)
- [Configuration Issues](#configuration-issues)
- [Network Issues](#network-issues)
- [Permission Issues](#permission-issues)
- [Debug Mode & Diagnostics](#debug-mode--diagnostics)
- [Log Analysis](#log-analysis)
- [Recovery Procedures](#recovery-procedures)
- [Advanced Troubleshooting](#advanced-troubleshooting)

## 🆘 Getting Help

### Built-in Help System

```bash
# General help
fub --help

# Command-specific help
fub cleanup --help
fub monitor --help
fub deps --help
fub config --help

# Interactive help
fub help                    # Interactive help system
fub help <topic>            # Help on specific topic
```

### Quick Diagnostics

```bash
# System health check
fub doctor                  # Comprehensive system diagnostics

# Configuration check
fub config status           # Check configuration status
fub config validate         # Validate configuration

# Dependency check
fub deps check              # Check dependency status
fub deps doctor             # Dependency diagnostics

# Service status
fub status                  # Overall system status
```

## 🔧 Common Issues

### FUB Won't Start

**Symptoms:**
- Command not found errors
- Permission denied errors
- Script execution failures

**Solutions:**

1. **Check Installation:**
   ```bash
   # Verify FUB is installed
   which fub
   ls -la $(which fub)

   # Check script permissions
   chmod +x bin/fub

   # Verify directory structure
   ls -la lib/
   ls -la config/
   ```

2. **Check Environment:**
   ```bash
   # Check bash version
   bash --version  # Should be 4.0+

   # Check required directories
   ls -la ~/.config/fub/
   ls -la ~/.cache/fub/
   ls -la ~/.local/share/fub/

   # Create missing directories
   mkdir -p ~/.config/fub
   mkdir -p ~/.cache/fub/logs
   mkdir -p ~/.local/share/fub
   ```

3. **Run in Debug Mode:**
   ```bash
   # Enable debug output
   export FUB_LOG_LEVEL=DEBUG
   export FUB_DEBUG=true

   # Run with debug
   bash -x bin/fub --help
   ```

### Interactive Interface Not Working

**Symptoms:**
- Terminal displays garbled text
- Arrow keys not working
- Colors not displaying
- Interface freezes

**Solutions:**

1. **Check Terminal Capabilities:**
   ```bash
   # Check terminal type
   echo $TERM

   # Check terminal supports colors
   tput colors

   # Test terminal capabilities
   tput setaf 1; echo "Red text"; tput sgr0

   # Reset terminal
   reset
   ```

2. **Force Non-Interactive Mode:**
   ```bash
   # Use non-interactive mode
   export FUB_INTERACTIVE=false
   fub cleanup all

   # Or use command-line flag
   fub --no-interactive cleanup all
   ```

3. **Install Optional Dependencies:**
   ```bash
   # Install gum for enhanced UI
   fub deps install gum

   # Verify gum is working
   gum --version
   gum confirm "Test prompt"
   ```

4. **Terminal Configuration:**
   ```bash
   # Set appropriate terminal type
   export TERM=xterm-256color

   # Or for specific terminals
   export TERM=screen-256color  # For tmux/screen
   export TERM=alacritty         # For Alacritty
   ```

## 🚀 Installation Issues

### Permission Denied Errors

**Symptoms:**
- Permission denied when running FUB
- Unable to create directories
- Cannot write log files

**Solutions:**

1. **Check File Permissions:**
   ```bash
   # Check FUB executable permissions
   ls -la bin/fub
   chmod +x bin/fub

   # Check directory permissions
   ls -la ~/.config/
   ls -la ~/.cache/
   ls -la ~/.local/share/

   # Fix permissions
   chmod 755 ~/.config/fub
   chmod 755 ~/.cache/fub
   chmod 755 ~/.local/share/fub
   ```

2. **System-wide Installation:**
   ```bash
   # Install system-wide with sudo
   sudo cp bin/fub /usr/local/bin/
   sudo cp -r lib /usr/local/lib/fub/
   sudo cp -r config /usr/local/etc/fub/
   sudo cp -r data /usr/local/share/fub/

   # Set appropriate permissions
   sudo chmod 755 /usr/local/bin/fub
   sudo chmod -R 644 /usr/local/lib/fub/
   sudo chmod -R 644 /usr/local/etc/fub/
   ```

### Missing Dependencies

**Symptoms:**
- Commands not found
- Feature not available
- Error messages about missing tools

**Solutions:**

1. **Run Dependency Check:**
   ```bash
   # Check system dependencies
   fub deps check

   # Run dependency wizard
   fub deps wizard

   # Install missing dependencies
   fub deps install --missing
   ```

2. **Manual Installation:**
   ```bash
   # Install core dependencies
   sudo apt update
   sudo apt install -y curl wget git

   # Install optional tools
   sudo apt install -y gum btop fd-find ripgrep

   # For Ubuntu versions with old packages
   # Install gum from latest release
   curl -L https://github.com/charmbracelet/gum/releases/latest/download/gum_linux_amd64.tar.gz | tar xz
   sudo mv gum /usr/local/bin/
   ```

3. **Check Package Managers:**
   ```bash
   # Check available package managers
   which apt
   which snap
   which flatpak

   # Try alternative installation methods
   sudo snap install gum
   flatpak install flathub com.github.charmbracelet.gum
   ```

## 🖥️ Interactive UI Issues

### Garbled Display

**Symptoms:**
- Text overlapping
- Lines not properly formatted
- Unicode characters not displaying

**Solutions:**

1. **Terminal Settings:**
   ```bash
   # Check terminal encoding
   echo $LANG

   # Set UTF-8 encoding
   export LANG=en_US.UTF-8
   export LC_ALL=en_US.UTF-8

   # Reset terminal
   stty sane
   reset
   ```

2. **Disable Problematic Features:**
   ```bash
   # Disable colors
   export FUB_COLORS=false

   # Disable Unicode symbols
   export FUB_UNICODE_SYMBOLS=false

   # Use simple theme
   fub --theme minimal
   ```

3. **Terminal Compatibility:**
   ```bash
   # Try different terminal types
   export TERM=xterm
   export TERM=vt100
   export TERM=ansi

   # Test basic display
   echo -e "\033[31mRed\033[0m \033[32mGreen\033[0m \033[34mBlue\033[0m"
   ```

### Arrow Keys Not Working

**Symptoms:**
- Arrow keys produce characters instead of navigation
- Cannot navigate menus
- Keyboard input not recognized

**Solutions:**

1. **Check Terminal Input:**
   ```bash
   # Test arrow key input
   cat -v  # Press arrow keys, should show ^[[A etc.
   # Press Ctrl+C to exit

   # Check terminal application mode
   tput smkx  # Set application keypad mode
   ```

2. **Use Alternative Navigation:**
   ```bash
   # Use hjkl navigation (vim-style)
   # Use Tab/Shift+Tab for navigation
   # Use number keys for quick selection

   # Check help for navigation shortcuts
   fub help navigation
   ```

3. **Terminal Configuration:**
   ```bash
   # For specific terminals
   # In ~/.bashrc or ~/.zshrc:
   case "$TERM" in
       xterm*|rxvt*|screen*)
           # Enable application mode
           printf '\e[?1h\e=' >/dev/tty
           ;;
   esac
   ```

## 🔧 Dependency Management Issues

### Tools Not Installing

**Symptoms:**
- Installation failures
- Permission denied during installation
- Package not found errors

**Solutions:**

1. **Check Package Manager:**
   ```bash
   # Check which package manager is being used
   fub deps config show

   # Set preferred package manager
   fub deps config set package_manager_preference "apt"

   # Test package manager manually
   apt search gum
   apt show gum
   ```

2. **Fix Permission Issues:**
   ```bash
   # Install with sudo
   sudo fub deps install gum

   # Or configure to use sudo
   fub deps config set use_sudo true
   ```

3. **Update Package Lists:**
   ```bash
   # Update package lists
   sudo apt update

   # Fix broken packages
   sudo apt --fix-broken install

   # Clean package cache
   sudo apt clean
   sudo apt autoremove
   ```

4. **Alternative Installation Methods:**
   ```bash
   # Download and install manually
   wget https://github.com/charmbracelet/gum/releases/latest/download/gum_linux_amd64.tar.gz
   tar xzf gum_linux_amd64.tar.gz
   sudo mv gum /usr/local/bin/

   # Use installation script
   curl -sSL https://install.goreleaser.com/github.com/charmbracelet/gum | sh
   ```

### Dependency Conflicts

**Symptoms:**
- Multiple versions of tools
- Conflicting packages
- Tool not working after installation

**Solutions:**

1. **Check Tool Versions:**
   ```bash
   # Check installed versions
   gum --version
   btop --version
   fd --version
   ripgrep --version

   # Check which versions are being used
   which gum
   ls -la /usr/local/bin/gum
   ls -la /usr/bin/gum
   ```

2. **Resolve Conflicts:**
   ```bash
   # Remove conflicting versions
   sudo apt remove gum
   sudo rm /usr/local/bin/gum

   # Reinstall clean version
   fub deps install gum

   # Update PATH to prefer correct version
   export PATH="/usr/local/bin:$PATH"
   ```

3. **Use Container/Sandbox:**
   ```bash
   # Install in user directory
   mkdir -p ~/.local/bin
   wget https://github.com/charmbracelet/gum/releases/latest/download/gum_linux_amd64.tar.gz
   tar xzf gum_linux_amd64.tar.gz
   mv gum ~/.local/bin/

   # Update PATH
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
   ```

## 🧹 Cleanup Operation Issues

### Cleanup Not Running

**Symptoms:**
- Cleanup exits immediately
- No files are cleaned
- Operation appears to hang

**Solutions:**

1. **Check Configuration:**
   ```bash
   # Check cleanup configuration
   fub config show --section cleanup

   # Validate configuration
   fub config validate --section cleanup

   # Check if cleanup is enabled
   fub config get cleanup.enabled
   ```

2. **Run with Debug Output:**
   ```bash
   # Enable debug logging
   export FUB_LOG_LEVEL=DEBUG
   export FUB_DEBUG=true

   # Run cleanup with debug
   fub cleanup temp --debug

   # Check logs
   tail -f ~/.cache/fub/logs/fub.log
   ```

3. **Check Safety Rules:**
   ```bash
   # Check safety protections
   fub safety check

   # See what's being protected
   fub safety list-protected

   # Temporarily disable safety (with caution)
   fub cleanup temp --expert
   ```

4. **Dry Run Mode:**
   ```bash
   # See what would be cleaned
   fub cleanup all --dry-run --verbose

   # Check specific categories
   fub cleanup temp --dry-run
   fub cleanup cache --dry-run
   ```

### Cleanup Deleting Wrong Files

**Symptoms:**
- Important files deleted
- Unexpected file removal
- Data loss

**Solutions:**

1. **Emergency Stop:**
   ```bash
   # Stop current operation
   # Press Ctrl+C immediately

   # Check if backup was created
   fub backup list
   ```

2. **Restore from Backup:**
   ```bash
   # List available backups
   fub backup list

   # Restore from backup
   fub backup restore <backup-id>

   # Or use undo functionality
   fub safety undo
   ```

3. **Review Safety Configuration:**
   ```bash
   # Check protection rules
   fub safety rules show

   # Add protection for important directories
   fub safety protect /path/to/important/files

   # Review protected patterns
   fub safety list-protected
   ```

4. **Prevent Future Issues:**
   ```bash
   # Enable backup before cleanup
   fub config set cleanup.backup_before_cleanup true

   # Require confirmation for all operations
   fub config set safety.require_confirmation true

   # Disable expert mode
   fub config set ui.expert_mode false
   ```

## 🛡️ Safety System Issues

### Overly Protective Safety Rules

**Symptoms:**
- Cleanup not removing anything
- Everything marked as protected
- Cannot clean expected files

**Solutions:**

1. **Review Protection Rules:**
   ```bash
   # Show current protection rules
   fub safety rules show

   # Check protected directories
   fub safety list-protected

   # Check what's preventing cleanup
   fub safety analyze /path/to/clean
   ```

2. **Adjust Protection Rules:**
   ```bash
   # Remove overly broad protection
   fub safety unprotect /path/to/less/critical/directory

   # Modify protection patterns
   fub safety rules remove "*.tmp"  # Remove temp file protection

   # Create more specific rules
   fub safety protect /path/to/truly/important/files
   ```

3. **Use Expert Mode Carefully:**
   ```bash
   # Temporarily use expert mode
   fub cleanup temp --expert

   # Or adjust expert mode settings
   fub config set safety.expert_mode true

   # Remember to disable expert mode after use
   fub config set safety.expert_mode false
   ```

### Backup/Restore Issues

**Symptoms:**
- Backup creation fails
- Cannot restore from backup
- Backup files corrupted

**Solutions:**

1. **Check Backup Configuration:**
   ```bash
   # Check backup settings
   fub config show --section backup

   # Verify backup directory
   ls -la ~/.local/share/fub/backups/

   # Check available space
   df -h ~/.local/share/fub/
   ```

2. **Fix Backup Issues:**
   ```bash
   # Create backup manually
   fub backup create --force

   # Check backup integrity
   fub backup verify <backup-id>

   # Clean up corrupted backups
   fub backup cleanup
   ```

3. **Alternative Backup Location:**
   ```bash
   # Set custom backup directory
   fub config set backup.directory /custom/backup/path

   # Use external storage
   fub backup create --directory /mnt/backups
   ```

4. **Manual Restore:**
   ```bash
   # Extract backup manually
   cd /tmp
   tar xzf ~/.local/share/fub/backups/backup.tar.gz

   # Restore files manually
   cp -r restored/files/* /original/location/
   ```

## 📊 Monitoring Issues

### Monitoring Not Working

**Symptoms:**
- No monitoring data collected
- Charts not displaying
- Analysis not running

**Solutions:**

1. **Check Monitoring Configuration:**
   ```bash
   # Check if monitoring is enabled
   fub config get monitoring.enabled

   # Validate monitoring config
   fub config validate --section monitoring

   # Check monitoring components
   fub monitor status
   ```

2. **Install Monitoring Tools:**
   ```bash
   # Install btop for system monitoring
   fub deps install btop

   # Verify btop installation
   btop --version

   # Test monitoring
   fub monitor test
   ```

3. **Check Database:**
   ```bash
   # Check monitoring database
   ls -la ~/.local/share/fub/monitoring.db

   # Recreate database
   rm ~/.local/share/fub/monitoring.db
   fub monitor init
   ```

4. **Run Manual Analysis:**
   ```bash
   # Force system analysis
   fub monitor analyze --force

   # Generate manual report
   fub monitor report --output /tmp/monitoring-report.html
   ```

### Performance Alerts Not Working

**Symptoms:**
- No alerts generated
- Alerts not sent
- Alert thresholds not triggering

**Solutions:**

1. **Check Alert Configuration:**
   ```bash
   # Check alert settings
   fub config show --section monitoring.alerts

   # Verify thresholds
   fub config get monitoring.alert_threshold
   ```

2. **Test Alert System:**
   ```bash
   # Test alert generation
   fub monitor test-alert

   # Test specific thresholds
   fub monitor test-threshold disk_space 90
   fub monitor test-threshold memory 85
   ```

3. **Check Notification System:**
   ```bash
   # Test notifications
   fub notify test "Test notification"

   # Check notification settings
   fub config show --section notifications
   ```

4. **Manually Trigger Alerts:**
   ```bash
   # Simulate high usage
   fub monitor simulate-alert disk_space 95

   # Check alert logs
   grep ALERT ~/.cache/fub/logs/monitoring.log
   ```

## ⏰ Scheduler Issues

### Scheduled Tasks Not Running

**Symptoms:**
- Scheduled tasks not executing
- Timer not firing
- Background operations not working

**Solutions:**

1. **Check Systemd Integration:**
   ```bash
   # Check if timers are active
   systemctl --user list-timers | grep fub

   # Check timer status
   systemctl --user status fub-cleanup.timer
   systemctl --user status fub-cleanup.service

   # Enable timers
   systemctl --user enable fub-cleanup.timer
   systemctl --user start fub-cleanup.timer
   ```

2. **Check Scheduler Configuration:**
   ```bash
   # Check scheduler settings
   fub config show --section scheduler

   # Validate configuration
   fub config validate --section scheduler

   # Check schedule
   fub schedule list
   ```

3. **Manual Scheduling:**
   ```bash
   # Test manual execution
   fub schedule run --test

   # Force scheduled execution
   fub schedule run --force

   # Check schedule status
   fub schedule status
   ```

4. **Alternative Scheduling:**
   ```bash
   # Use cron instead
   crontab -e

   # Add to crontab:
   # 0 2 * * * /path/to/fub cleanup all
   ```

### Background Operations Failing

**Symptoms:**
- Background tasks failing
- Operations not completing
- Resource conflicts

**Solutions:**

1. **Check Resource Limits:**
   ```bash
   # Check resource limits
   fub config show --section scheduler.resource_limits

   # Adjust limits if needed
   fub config set scheduler.resource_limits.default_memory "1G"
   fub config set scheduler.resource_limits.max_workers 2
   ```

2. **Check System Conditions:**
   ```bash
   # Check if conditions are met
   fub schedule check-conditions

   # See why operations are not running
   fub schedule diagnose
   ```

3. **Run in Foreground:**
   ```bash
   # Run scheduled task in foreground for debugging
   fub schedule run --foreground

   # Check logs
   journalctl --user -u fub-cleanup.service
   ```

## ⚡ Performance Issues

### FUB Running Slowly

**Symptoms:**
- Operations take too long
- High resource usage
- System becomes unresponsive

**Solutions:**

1. **Check Resource Usage:**
   ```bash
   # Monitor FUB resource usage
   top -p $(pgrep fub)
   htop -p $(pgrep fub)

   # Check memory usage
   ps aux | grep fub
   ```

2. **Optimize Configuration:**
   ```bash
   # Reduce parallel operations
   fub config set performance.max_workers 2

   # Lower memory limits
   fub config set performance.memory_limit "512M"

   # Adjust I/O priority
   fub config set performance.io_priority 5
   ```

3. **Use Performance Mode:**
   ```bash
   # Enable performance optimizations
   fub config set performance.parallel_operations true
   fub config set performance.cache_results true

   # Use specific performance profile
   fub --profile performance cleanup all
   ```

4. **System Optimization:**
   ```bash
   # Check system load
   uptime
   iostat 1 5

   # Optimize system settings
   echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
   sudo sysctl -p
   ```

### High Memory Usage

**Symptoms:**
- FUB consuming excessive memory
- System swapping
- Out of memory errors

**Solutions:**

1. **Reduce Memory Usage:**
   ```bash
   # Lower memory limits
   fub config set performance.memory_limit "256M"

   # Disable memory-intensive features
   fub config set ui.animations false
   fub config set monitoring.real_time_monitoring false
   ```

2. **Enable Memory Optimization:**
   ```bash
   # Enable memory optimization
   fub config set performance.memory_optimization true

   # Use streaming for large operations
   fub config set cleanup.stream_large_files true
   ```

3. **Monitor Memory Usage:**
   ```bash
   # Monitor memory in real-time
   watch -n 1 'ps aux | grep fub | grep -v grep'

   # Check memory usage by component
   fub monitor memory --detailed
   ```

## ⚙️ Configuration Issues

### Configuration Not Loading

**Symptoms:**
- Default settings being used
- Custom configuration ignored
- Configuration errors

**Solutions:**

1. **Check Configuration Files:**
   ```bash
   # Check configuration file exists
   ls -la ~/.config/fub/config.yaml

   # Validate configuration syntax
   fub config validate

   # Check configuration loading
   fub config show --sources
   ```

2. **Fix Configuration Syntax:**
   ```bash
   # Check YAML syntax
   python -c "import yaml; yaml.safe_load(open('~/.config/fub/config.yaml'))"

   # Fix common syntax errors
   fub config fix-syntax

   # Use configuration validator
   fub config validate --strict
   ```

3. **Reset Configuration:**
   ```bash
   # Backup current configuration
   cp ~/.config/fub/config.yaml ~/.config/fub/config.yaml.backup

   # Reset to defaults
   fub config reset

   # Reconfigure using wizard
   fub config setup
   ```

### Profile Issues

**Symptoms:**
- Profile not applying
- Profile not found
- Profile settings not working

**Solutions:**

1. **Check Available Profiles:**
   ```bash
   # List available profiles
   fub profile list

   # Check current profile
   fub profile current

   # Validate profile
   fub profile validate <profile-name>
   ```

2. **Fix Profile Issues:**
   ```bash
   # Switch to different profile
   fub profile switch desktop

   # Recreate profile
   fub profile create custom "Custom profile"
   ```

3. **Profile Debugging:**
   ```bash
   # Show profile details
   fub profile show <profile-name>

   # Check profile merging
   fub config show --show-profile-merging
   ```

## 🌐 Network Issues

### Network Operations Failing

**Symptoms:**
- Cannot download tools
- Network timeouts
- Proxy connection issues

**Solutions:**

1. **Check Network Connectivity:**
   ```bash
   # Test basic connectivity
   ping -c 3 google.com
   curl -I https://github.com

   # Check DNS resolution
   nslookup github.com
   dig github.com
   ```

2. **Configure Proxy:**
   ```bash
   # Set proxy environment variables
   export http_proxy=http://proxy.example.com:8080
   export https_proxy=http://proxy.example.com:8080
   export no_proxy=localhost,127.0.0.1

   # Configure FUB proxy
   fub config set network.proxy http://proxy.example.com:8080
   ```

3. **Adjust Network Settings:**
   ```bash
   # Increase timeout
   fub config set network.timeout 30

   # Increase retries
   fub config set network.retries 5

   # Disable SSL verification (for testing only)
   fub config set network.verify_ssl false
   ```

### Dependency Download Issues

**Symptoms:**
- Cannot download dependency tools
- Download failures
- Corrupted downloads

**Solutions:**

1. **Check Download URLs:**
   ```bash
   # Test download manually
   curl -L https://github.com/charmbracelet/gum/releases/latest/download/gum_linux_amd64.tar.gz

   # Check file integrity
   wget https://github.com/charmbracelet/gum/releases/latest/download/gum_linux_amd64.tar.gz
   sha256sum gum_linux_amd64.tar.gz
   ```

2. **Alternative Download Methods:**
   ```bash
   # Use different mirror
   fub config set dependencies.mirror "https://mirror.example.com"

   # Use local installation
   fub deps install --local /path/to/local/package
   ```

3. **Manual Installation:**
   ```bash
   # Download and install manually
   wget https://github.com/charmbracelet/gum/releases/latest/download/gum_linux_amd64.tar.gz
   tar xzf gum_linux_amd64.tar.gz
   sudo mv gum /usr/local/bin/

   # Mark as manually installed
   fub deps mark-manual gum
   ```

## 🔒 Permission Issues

### Permission Denied Errors

**Symptoms:**
- Permission denied when accessing files
- Cannot create directories
- Cannot write log files

**Solutions:**

1. **Check File Permissions:**
   ```bash
   # Check FUB directory permissions
   ls -la ~/.config/fub/
   ls -la ~/.cache/fub/
   ls -la ~/.local/share/fub/

   # Fix permissions
   chmod 755 ~/.config/fub
   chmod 755 ~/.cache/fub
   chmod 755 ~/.local/share/fub
   chmod 644 ~/.config/fub/config.yaml
   ```

2. **Check User Permissions:**
   ```bash
   # Check current user and groups
   id
   groups

   # Check if user can write to directories
   touch ~/.cache/fub/test
   rm ~/.cache/fub/test
   ```

3. **Use Appropriate User:**
   ```bash
   # Run with correct user
   sudo -u username fub cleanup all

   # Or fix ownership
   sudo chown -R username:username ~/.config/fub/
   sudo chown -R username:username ~/.cache/fub/
   sudo chown -R username:username ~/.local/share/fub/
   ```

### Sudo Issues

**Symptoms:**
- Sudo command not working
- Password prompts failing
- Sudoers configuration issues

**Solutions:**

1. **Check Sudo Configuration:**
   ```bash
   # Test sudo access
   sudo whoami

   # Check sudoers file (requires root)
   sudo visudo -c
   ```

2. **Fix Sudo Issues:**
   ```bash
   # Reset sudo timestamp
   sudo -k

   # Check sudo logs
   sudo cat /var/log/auth.log | grep sudo

   # Use alternative methods
   pkexec fub cleanup all
   ```

## 🔍 Debug Mode & Diagnostics

### Enabling Debug Mode

```bash
# Set debug environment variables
export FUB_LOG_LEVEL=DEBUG
export FUB_DEBUG=true

# Enable debug for specific components
export FUB_DEBUG_CLEANUP=true
export FUB_DEBUG_SAFETY=true
export FUB_DEBUG_MONITORING=true

# Run with debug output
fub cleanup all --debug

# Check debug information
fub debug info
fub debug system
fub debug config
```

### Diagnostic Commands

```bash
# Comprehensive system diagnostics
fub doctor

# Component-specific diagnostics
fub doctor cleanup
fub doctor safety
fub doctor monitoring
fub doctor dependencies
fub doctor scheduler

# Configuration diagnostics
fub config diagnose
fub config validate --strict

# System checks
fub system check
fub system info
fub system health
```

### Performance Diagnostics

```bash
# Performance benchmarks
fub benchmark

# Component performance
fub benchmark cleanup
fub benchmark monitoring
fub benchmark dependencies

# Resource usage analysis
fub analyze resources
fub analyze performance
```

## 📝 Log Analysis

### Log File Locations

```bash
# Main log file
~/.cache/fub/logs/fub.log

# Component-specific logs
~/.cache/fub/logs/safety.log
~/.cache/fub/logs/monitoring.log
~/.cache/fub/logs/scheduler.log
~/.cache/fub/logs/dependencies.log
~/.cache/fub/logs/cleanup.log
```

### Log Analysis Commands

```bash
# View recent logs
tail -f ~/.cache/fub/logs/fub.log

# Search for errors
grep ERROR ~/.cache/fub/logs/fub.log

# Search for warnings
grep WARN ~/.cache/fub/logs/fub.log

# Search for specific operations
grep "cleanup" ~/.cache/fub/logs/fub.log

# Analyze log patterns
fub logs analyze
fub logs errors
fub logs warnings
fub logs trends

# Log statistics
fub logs stats
fub logs summary
```

### Log Rotation and Management

```bash
# Check log rotation
ls -la ~/.cache/fub/logs/

# Manually rotate logs
fub logs rotate

# Clean old logs
fub logs cleanup

# Compress logs
fub logs compress
```

## 🔄 Recovery Procedures

### Configuration Recovery

```bash
# Backup current configuration
fub config backup

# Reset to defaults
fub config reset

# Restore from backup
fub config restore <backup-id>

# Import configuration
fub config import /path/to/config.yaml
```

### System Recovery

```bash
# Complete system reset
fub system reset

# Reinitialize FUB
fub system init

# Repair installation
fub system repair

# Reinstall FUB
./install.sh --force
```

### Data Recovery

```bash
# Restore from backup
fub backup restore <backup-id>

# Undo last operation
fub safety undo

# Recover deleted files
fub recover --path /path/to/lost/files

# System restore point
fub restore-point create
fub restore-point restore <point-id>
```

## 🔬 Advanced Troubleshooting

### Deep System Analysis

```bash
# Complete system analysis
fub analyze --deep

# Component analysis
fub analyze cleanup --verbose
fub analyze safety --detailed
fub analyze monitoring --comprehensive

# Performance analysis
fub analyze performance --baseline
fub analyze resources --historical
```

### Custom Diagnostics

```bash
# Create custom diagnostic script
cat > diagnostic.sh << 'EOF'
#!/bin/bash
echo "=== FUB Diagnostic Report ==="
echo "Date: $(date)"
echo "System: $(uname -a)"
echo ""

echo "=== FUB Status ==="
fub status
echo ""

echo "=== Configuration ==="
fub config show
echo ""

echo "=== Dependencies ==="
fub deps check
echo ""

echo "=== System Resources ==="
df -h
free -h
uptime
echo ""

echo "=== Recent Logs ==="
tail -20 ~/.cache/fub/logs/fub.log
EOF

chmod +x diagnostic.sh
./diagnostic.sh
```

### Issue Reporting

```bash
# Generate bug report
fub bug-report

# Include system information
fub bug-report --include-system

# Include configuration
fub bug-report --include-config

# Include logs
fub bug-report --include-logs

# Generate full report
fub bug-report --full
```

### Performance Profiling

```bash
# Profile cleanup operations
fub profile cleanup

# Profile monitoring
fub profile monitoring

# Generate performance report
fub profile report
```

---

This troubleshooting guide covers the most common issues and solutions for FUB. For additional help, use the built-in help system with `fub help` or check the log files in `~/.cache/fub/logs/`. If you continue to experience issues, consider running `fub doctor` for comprehensive diagnostics.