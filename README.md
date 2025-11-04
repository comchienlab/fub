# FUB - Filesystem Ubuntu Buddy

> Dig deep like a mole to clean your Ubuntu

FUB is a terminal-based cleanup utility for Ubuntu, inspired by [Mole](https://github.com/tw93/Mole) for macOS. It helps you reclaim disk space by cleaning caches, old kernels, logs, and temporary files.

## Features

- 🚀 One-command installation
- 🧹 Cleans 6 categories: APT cache, old kernels, systemd journal, browser caches, user caches, temp files
- 🔒 Dry-run mode for safe preview
- 📊 Interactive dashboard with up/down navigation
- 💾 Typical recovery: 2-5 GB
- 🛡️ Safety-first design (never removes current kernel)

## Quick Start

### Installation
```bash
curl -fsSL https://raw.githubusercontent.com/[user]/fub/main/install.sh | bash
```

### Usage
```bash
# Interactive dashboard
fub

# Preview cleanup (safe)
fub clean --dry-run

# Execute cleanup
fub clean

# Show version
fub --version

# Show help
fub --help
```

## Interactive Dashboard

FUB features an intuitive dashboard interface with up/down navigation:

```
=== FUB Dashboard ===
Ubuntu 24.04 LTS | Free space: 15.2 GB

1) 🧹 Clean System (with preview)
2) 📊 Analyze Disk Usage
3) ⚙️  Settings
4) ❓ Help
5) 🚪 Exit

Use ↑↓ arrows to navigate, Enter to select
```

## Cleanup Categories

- **APT Cache** - Old package files from `/var/cache/apt/archives/`
- **Old Kernels** - Previous kernel versions (keeps current + 1 previous)
- **systemd Journal** - System logs vacuumed to 100MB
- **Browser Caches** - Firefox, Chrome, Chromium cache files
- **User Caches** - Application caches in `~/.cache/`
- **Temp Files** - Old temporary files from `/tmp` and `/var/tmp`

## Safety Features

- ✅ Never removes current kernel
- ✅ Dry-run mode shows exactly what will be cleaned
- ✅ Explicit confirmations for all operations
- ✅ Skips cleanup if APT is locked
- ✅ Checks if browsers are running

## Tested On

- ✅ Ubuntu 24.04 LTS
- ✅ Ubuntu 22.04 LTS
- ✅ Ubuntu 20.04 LTS

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Inspired by Mole

FUB is inspired by [Mole](https://github.com/tw93/Mole), the beloved terminal cleanup tool for macOS with 4,000+ stars. FUB brings the same simplicity and effectiveness to Ubuntu.