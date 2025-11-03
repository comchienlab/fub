# FUB Interactive Usage Guide

A comprehensive guide to using FUB's modern interactive interface for efficient Ubuntu system maintenance.

## 📋 Table of Contents

- [Getting Started](#getting-started)
- [Interactive Interface Overview](#interactive-interface-overview)
- [Main Menu Navigation](#main-menu-navigation)
- [Interactive Cleanup](#interactive-cleanup)
- [System Monitoring](#system-monitoring)
- [Safety Management](#safety-management)
- [Dependency Management](#dependency-management)
- [Scheduled Maintenance](#scheduled-maintenance)
- [Configuration Management](#configuration-management)
- [Advanced Features](#advanced-features)
- [Common Workflows](#common-workflows)
- [Best Practices](#best-practices)
- [Tips & Tricks](#tips--tricks)

## 🚀 Getting Started

### First Launch

When you first run FUB, you'll be greeted with the interactive interface:

```bash
# Launch FUB
fub
```

**First-time Setup:**
1. Run the dependency wizard: `fub deps wizard`
2. Choose your user profile (desktop, server, developer)
3. Configure basic preferences
4. Launch the interactive interface

### Initial Configuration

The system will guide you through initial setup:

```
┌─ FUB First-Time Setup ──────────────────────────────────────┐
│                                                              │
│  Welcome to FUB! Let's configure your system.               │
│                                                              │
│  👤 User Profile:                                           │
│    ◉ Desktop User      ◉ Server Administrator               │
│    ◉ Developer         ◉ Minimal Setup                     │
│                                                              │
│  🔧 Optional Tools:                                          │
│    ☑ Install gum (enhanced UI)                             │
│    ☐ Install btop (system monitoring)                       │
│    ☐ Install fd (fast file search)                         │
│                                                              │
│  [Enter Continue] [↑↓ Navigate] [Space Select]               │
└──────────────────────────────────────────────────────────────┘
```

## 🖥️ Interactive Interface Overview

### The Main Interface

FUB's interactive interface provides a modern, intuitive experience:

```
┌─ FUB - Fast Ubuntu Utility Toolkit v1.0.0 ─────────────────────┐
│                                                              │
│  🎯 System Status: GOOD ● 💾 45.2 GB free ● ⚡ 12% CPU        │
│                                                              │
│  Main Menu                                                   │
│  ──────────────────────────────────────────────────────────── │
│                                                              │
│  🧹 System Cleanup        📊 System Monitoring              │
│    Clean system files,      Real-time monitoring and         │
│    caches, and packages     performance analysis              │
│                                                              │
│  🛡️  Safety Management     ⏰  Scheduled Maintenance         │
│    Protect important        Automate regular cleanup         │
│    files and directories    tasks with scheduling            │
│                                                              │
│  🔧 Dependency Setup      📈 Performance Analysis          │
│    Install optional tools   Detailed system analysis        │
│    and enhance FUB          and optimization                 │
│                                                              │
│  ⚙️  Configuration         📝  View Logs                     │
│    Customize settings       Browse system and               │
│    and preferences          operation logs                   │
│                                                              │
│  ──────────────────────────────────────────────────────────── │
│                                                              │
│  [↑↓ Navigate] [Enter Select] [q Quit] [? Help] [r Refresh]   │
│                                                              │
│  Last cleanup: 2 days ago ● Next scheduled: Tomorrow 02:00   │
└──────────────────────────────────────────────────────────────┘
```

### Interface Elements

**Navigation:**
- **↑↓ Arrow Keys** - Navigate menu options
- **Enter** - Select current option
- **Space** - Toggle selections in multi-select menus
- **Tab** - Navigate between interface sections
- **q/Escape** - Go back or quit
- **?** - Show context-sensitive help
- **r** - Refresh current view

**Status Indicators:**
- **● Colored dots** - System health status (🟢 Good, 🟡 Warning, 🔴 Critical)
- **Progress bars** - Operation progress with percentages
- **Counters** - Item counts, file sizes, time estimates

**Interactive Elements:**
- **Checkboxes** - Multi-select options with Space to toggle
- **Radio buttons** - Single selection options
- **Progress indicators** - Real-time operation progress
- **Input fields** - Text input with validation

## 🧹 Interactive Cleanup

### Category Selection

The interactive cleanup interface allows you to select exactly what to clean:

```
┌─ Select Cleanup Categories ─────────────────────────────────┐
│                                                              │
│  🎯 Estimated space to reclaim: ~2.3 GB                     │
│                                                              │
│  ☑ System Files        ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓   │
│  ☐ Development        ┃  System Files Analysis              ┃   │
│  ☐ Containers          ┃  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┃   │
│  ☐ IDE Caches          ┃  📁 Temporary files: 847 MB         ┃   │
│  ☐ Build Artifacts     ┃  📋 Log files: 234 MB              ┃   │
│  ☐ Package Deps        ┃  💾 Package caches: 1.2 GB          ┃   │
│                        ┃  🖼️  Thumbnail cache: 89 MB         ┃   │
│                        ┃  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┃   │
│                        ┃  ⚠️  Active services detected        ┃   │
│                        ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛   │
│                                                              │
│  [Space Toggle] [a Select All] [Enter Start] [Esc Cancel]    │
│  [i View Details] [Expert Mode] [Settings]                   │
│                                                              │
│  Protected: 3 directories ● Running services: 2              │
└──────────────────────────────────────────────────────────────┘
```

### Safety Confirmation

Before executing cleanup, FUB shows detailed confirmation:

```
┌─ Cleanup Confirmation ───────────────────────────────────────┐
│                                                              │
│  ⚠️  EXPERT WARNING: This operation will permanently delete   │
│  system files. A backup will be created automatically.        │
│                                                              │
│  Categories to clean:                                        │
│  ──────────────────────────────────────────────────────────── │
│  ☑ System Files (temp, logs, cache, thumbnails)             │
│    • Temporary files: 847 MB (older than 7 days)            │
│    • Log files: 234 MB (older than 30 days)                 │
│    • Package caches: 1.2 GB                                 │
│    • Thumbnail cache: 89 MB                                  │
│                                                              │
│  Safety protections:                                         │
│  ✅ Development directories protected                        │
│  ✅ Running services checked                                 │
│  ✅ Backup will be created: /tmp/fub-backup-2024-01-15       │
│                                                              │
│  Total space to reclaim: ~2.3 GB                            │
│  Estimated time: 3-5 minutes                                │
│                                                              │
│  [Enter Confirm] [c Cancel] [b Create Backup] [d Dry Run]    │
│  [Expert Mode] [Settings] [Details]                          │
└──────────────────────────────────────────────────────────────┘
```

### Progress Monitoring

During cleanup operations, you'll see real-time progress:

```
┌─ System Cleanup in Progress ─────────────────────────────────┐
│                                                              │
│  🧹 Cleaning System Files...                                 │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│  ████████████████████████████████████████░░░░░░░░░░░░░░░░░░░░  75% │
│                                                              │
│  Current: Removing old log files...                         │
│  Files processed: 1,247 / 1,658                             │
│  Space reclaimed: 1.7 GB / 2.3 GB                           │
│  Time elapsed: 2:34 / Estimated: 3:45                       │
│                                                              │
│  📊 Details:                                                 │
│  • Temporary files: ✅ Complete (847 MB reclaimed)           │
│  • Log files: 🔄 In progress (623 / 857 MB)                 │
│  • Package caches: ⏳ Pending (1.2 GB)                       │
│  • Thumbnails: ⏳ Pending (89 MB)                            │
│                                                              │
│  [p Pause] [c Cancel] [v Verbose] [s Show Details]           │
└──────────────────────────────────────────────────────────────┘
```

### Post-Cleanup Summary

After cleanup completes, you'll see a comprehensive summary:

```
┌─ Cleanup Complete! 🎉 ─────────────────────────────────────────┐
│                                                              │
│  ✅ Cleanup completed successfully                           │
│                                                              │
│  Summary:                                                    │
│  ──────────────────────────────────────────────────────────── │
│  💾 Total space reclaimed: 2.34 GB                           │
│  ⏱️  Time taken: 4 minutes 12 seconds                        │
│  📁 Files processed: 1,658                                   │
│                                                              │
│  Categories cleaned:                                         │
│  ✅ System Files: 2.34 GB reclaimed                          │
│  • Temporary files: 847 MB                                   │
│  • Log files: 234 MB                                         │
│  • Package caches: 1.2 GB                                    │
│  • Thumbnail cache: 89 MB                                    │
│                                                              │
│  System Impact:                                               │
│  ✅ No critical files removed                                 │
│  ✅ All running services intact                              │
│  ✅ Development directories protected                        │
│  ✅ Backup created: /tmp/fub-backup-2024-01-15               │
│                                                              │
│  📈 Performance Improvement:                                  │
│  • Disk space: +2.34 GB available                            │
│  • System startup: -3 seconds faster                         │
│  • Package operations: +15% faster                          │
│                                                              │
│  [View Details] [System Monitor] [Schedule Next] [Close]     │
└──────────────────────────────────────────────────────────────┘
```

## 📊 System Monitoring

### Main Monitoring Dashboard

The monitoring interface provides real-time system analysis:

```
┌─ System Monitoring Dashboard ────────────────────────────────┐
│                                                              │
│  📊 System Health: GOOD ● Last scan: 2 minutes ago          │
│                                                              │
│  💾 Storage: 45.2 GB / 256 GB (17.7%) ━━━━━━━━━━━━━━━━━━━━━━ │
│  ████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 18% │
│                                                              │
│  🧠 Memory: 8.1 GB / 16 GB (50.6%) ━━━━━━━━━━━━━━━━━━━━━━━━━ │
│  ████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 51% │
│                                                              │
│  ⚡ CPU Load: 1.2, 1.5, 1.8 (1m, 5m, 15m)                     │
│  🌡️  Temperature: 45°C (Normal)                             │
│  🔌 Network: 125 Mbps down, 42 Mbps up                       │
│                                                              │
│  📈 Performance Score: 92/100                                │
│  🔍 Cleanup Opportunities: 12 (estimated 1.8 GB)            │
│                                                              │
│  [Detailed Analysis] [Resource Monitor] [History] [Alerts]   │
│  [r Refresh] [Export Report] [Settings]                       │
└──────────────────────────────────────────────────────────────┘
```

### Detailed System Analysis

Get in-depth information about system components:

```
┌─ Detailed System Analysis ───────────────────────────────────┐
│                                                              │
│  🗂️  Filesystem Analysis                                     │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                              │
│  / (root)                                                    │
│  • Total: 256 GB ● Used: 210.8 GB ● Free: 45.2 GB           │
│  • Filesystem: ext4 ● Mount options: rw,relatime,errors...  │
│  • Health: GOOD ● Last check: 3 days ago                    │
│                                                              │
│  /home                                                       │
│  • Total: 512 GB ● Used: 167.3 GB ● Free: 344.7 GB          │
│  • Largest directories:                                      │
│    - /home/user/Documents: 45.2 GB                          │
│    - /home/user/Downloads: 23.7 GB                          │
│    - /home/user/.cache: 12.8 GB ⚠️                           │
│                                                              │
│  🗑️  Cleanup Opportunities:                                  │
│  • /home/user/.cache/node_modules: 4.2 GB                   │
│  • /home/user/.cache/pip: 1.8 GB                            │
│  • /tmp: 847 MB                                             │
│  • /var/log: 234 MB                                          │
│                                                              │
│  [Start Cleanup] [Schedule Cleanup] [Ignore] [Details]       │
└──────────────────────────────────────────────────────────────┘
```

### Historical Data Tracking

View trends and historical performance data:

```
┌─ System History & Trends ────────────────────────────────────┐
│                                                              │
│  📈 Performance Trends (Last 30 days)                        │
│                                                              │
│  Disk Usage:                                                 │
│  200GB ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 210.8GB │
│                                                              │
│  Memory Usage:                                               │
│  16GB  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 8.1GB   │
│                                                              │
│  Cleanup History:                                            │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│  Date        Type         Space Reclaimed    Time             │
│  2024-01-15  System       2.34 GB           4m 12s           │
│  2024-01-12  Development  1.8 GB            3m 45s           │
│  2024-01-10  Containers   5.2 GB            6m 23s           │
│  2024-01-08  System       1.2 GB            2m 56s           │
│                                                              │
│  Performance Score: 92/100 ⬆️ (+3 from last week)            │
│                                                              │
│  [Export Data] [Detailed View] [Compare] [Schedule]          │
└──────────────────────────────────────────────────────────────┘
```

## 🛡️ Safety Management

### Protection Rules Management

Configure and manage safety protection rules:

```
┌─ Safety & Protection Rules ──────────────────────────────────┐
│                                                              │
│  🛡️  Active Protections                                       │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                              │
│  ☑ Development Directory Protection                          │
│    • /home/user/projects/*                                   │
│    • /home/user/work/*                                       │
│    • /opt/development/*                                      │
│                                                              │
│  ☑ Running Service Detection                                 │
│    • nginx: ✅ Active (protected)                            │
│    • docker: ✅ Active (protected)                           │
│    • mysql: ⚠️ Stopped (can be cleaned)                      │
│                                                              │
│  ☑ Container Protection                                      │
│    • 3 running containers detected                           │
│    • Automatic container pause before cleanup                │
│                                                              │
│  📋 Custom Rules:                                            │
│  • + /home/user/important-data/*                             │
│  • - /home/user/temp/*                                       │
│  • +*.config, +*.json                                        │
│                                                              │
│  [Add Rule] [Edit Rule] [Test Rules] [Reset] [Advanced]       │
└──────────────────────────────────────────────────────────────┘
```

### Backup Management

Manage system backups and restore points:

```
┌─ Backup & Restore Management ────────────────────────────────┐
│                                                              │
│  💾 Available Backups                                         │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                              │
│  📅 2024-01-15 14:30  ID: bkp_20240115_1430                 │
│     Type: Pre-cleanup ● Size: 245 MB ● Status: ✅ Valid       │
│     Description: Before system cleanup                        │
│                                                              │
│  📅 2024-01-12 09:15  ID: bkp_20240112_0915                 │
│     Type: Manual ● Size: 1.2 GB ● Status: ✅ Valid             │
│     Description: Before package updates                      │
│                                                              │
│  📅 2024-01-10 16:45  ID: bkp_20240110_1645                 │
│     Type: Scheduled ● Size: 890 MB ● Status: ⚠️ Old           │
│     Description: Weekly scheduled backup                     │
│                                                              │
│  💽 Storage used: 2.3 GB / 5 GB (46%)                       │
│  ⏰ Auto-cleanup: Backups older than 30 days                 │
│                                                              │
│  [Create Backup] [Restore] [Delete] [Schedule] [Settings]    │
└──────────────────────────────────────────────────────────────┘
```

## 🔧 Dependency Management

### Interactive Dependency Setup

The dependency wizard helps you install optional tools:

```
┌─ Dependency Setup Wizard ────────────────────────────────────┐
│                                                              │
│  🔧 Enhance your FUB experience with optional tools          │
│                                                              │
│  Recommended Tools:                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                              │
│  ☑ gum - Interactive terminal UI                             │
│     Beautiful interfaces for shell scripts                   │
│     Enhances: All FUB interfaces                            │
│     Size: 15 MB ● Install time: <1 minute                   │
│                                                              │
│  ☑ btop - Advanced system monitor                           │
│     Real-time resource monitoring with graphs                │
│     Enhances: System monitoring dashboard                   │
│     Size: 2 MB ● Install time: <30 seconds                  │
│                                                              │
│  ☐ fd - Fast file search                                    │
│     User-friendly alternative to find                        │
│     Enhances: File search operations                        │
│     Size: 4 MB ● Install time: <30 seconds                  │
│                                                              │
│  ☐ ripgrep - Blazing fast text search                       │
│     Search tool like grep, but faster                        │
│     Enhances: Log analysis and file search                  │
│     Size: 8 MB ● Install time: <1 minute                   │
│                                                              │
│  [Install Selected] [Select All] [Skip] [Details]            │
└──────────────────────────────────────────────────────────────┘
```

### Tool Status Dashboard

Monitor installed tools and their capabilities:

```
┌─ Tool Status & Capabilities ─────────────────────────────────┐
│                                                              │
│  📊 Enhanced Features: 4/8 available                        │
│                                                              │
│  ✅ gum - Interactive terminal UI                            │
│     Version: 0.13.0 ● Status: Active                        │
│     Features: Enhanced menus, progress bars, confirmations   │
│                                                              │
│  ✅ btop - System monitoring                                 │
│     Version: 1.2.13 ● Status: Active                        │
│     Features: Real-time monitoring, resource graphs         │
│                                                              │
│  ❌ fd - Fast file search                                    │
│     Status: Not installed                                   │
│     [Install] [Learn More] [Alternative: find]              │
│                                                              │
│  ❌ ripgrep - Text search                                   │
│     Status: Not installed                                   │
│     [Install] [Learn More] [Alternative: grep]              │
│                                                              │
│  🎯 Enhancement Level: Intermediate                          │
│  💡 Recommendation: Install fd and ripgrep for full experience│
│                                                              │
│  [Install Missing] [Update All] [Configure] [Alternatives]   │
└──────────────────────────────────────────────────────────────┘
```

## ⏰ Scheduled Maintenance

### Schedule Configuration

Set up automated cleanup and maintenance:

```
┌─ Scheduled Maintenance Setup ────────────────────────────────┐
│                                                              │
│  📅 Configure automatic cleanup and maintenance tasks        │
│                                                              │
│  Profile: ◉ Desktop User                                    │
│          ◯ Server Administrator                              │
│          ◯ Developer                                         │
│          ◯ Custom                                           │
│                                                              │
│  Schedule:                                                   │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                              │
│  ☑ System Cleanup                                           │
│     Frequency: Daily ● Time: 02:00 ● Categories: System     │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                              │
│  ☑ Dependency Updates                                       │
│     Frequency: Weekly ● Day: Sunday ● Time: 03:00           │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                              │
│  ☑ System Monitoring                                        │
│     Frequency: Every 6 hours ● Alerts: Enabled              │
│     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                              │
│  🔔 Notifications:                                           │
│  ☑ Email: user@example.com                                   │
│  ☑ Desktop: Enabled                                         │
│  ☑ Logs: ~/.cache/fub/logs/scheduler.log                    │
│                                                              │
│  [Save Schedule] [Test Run] [Advanced Settings] [Help]       │
└──────────────────────────────────────────────────────────────┘
```

### Schedule History

Monitor scheduled task execution:

```
┌─ Maintenance History ────────────────────────────────────────┐
│                                                              │
│  📊 Scheduled Tasks Summary                                   │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                              │
│  Recent Executions:                                          │
│                                                              │
│  ✅ 2024-01-15 02:00 - System Cleanup                         │
│     Duration: 4m 23s ● Space reclaimed: 1.8 GB               │
│     Categories: System, Temporary files                      │
│     Result: Success ● No issues detected                     │
│                                                              │
│  ✅ 2024-01-14 02:00 - System Cleanup                         │
│     Duration: 3m 45s ● Space reclaimed: 2.1 GB               │
│     Categories: System, Cache                                 │
│     Result: Success ● Protected 3 directories               │
│                                                              │
│  ⚠️  2024-01-13 02:00 - Dependency Updates                   │
│     Duration: 12m 18s ● Packages updated: 15                  │
│     Result: Partial success ● 2 packages failed             │
│     Note: Manual intervention required                       │
│                                                              │
│  Statistics (Last 30 days):                                  │
│  • Tasks completed: 28/30 (93% success rate)                │
│  • Total space reclaimed: 45.2 GB                           │
│  • Average execution time: 5 minutes 42 seconds              │
│                                                              │
│  [View Logs] [Run Now] [Edit Schedule] [Settings]            │
└──────────────────────────────────────────────────────────────┘
```

## ⚙️ Configuration Management

### Interactive Configuration

Customize FUB settings through the interactive interface:

```
┌─ Configuration Management ───────────────────────────────────┐
│                                                              │
│  ⚙️  FUB Settings                                             │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                              │
│  🎨 Appearance                                               │
│  • Theme: ◉ Tokyo Night ◯ Minimal ◯ Custom                   │
│  • Colors: ✅ Enabled ● Animations: ✅ Enabled                │
│  • Progress bars: ✅ Enhanced ● Icons: ✅ Modern              │
│                                                              │
│  🧹 Cleanup Behavior                                         │
│  • Default retention: 7 days ● Backup before: ✅ Always      │
│  • Confirmation: ✅ Required ● Expert mode: ❌ Disabled        │
│  • Aggressive mode: ❌ Disabled ● Dry run: ❌ Disabled        │
│                                                              │
│  🛡️  Safety Settings                                          │
│  • Protect dev dirs: ✅ Enabled ● Service check: ✅ Enabled    │
│  • Container check: ✅ Enabled ● Custom rules: 3 active       │
│                                                              │
│  📊 Monitoring                                                │
│  • Pre-cleanup analysis: ✅ Enabled ● Historical: ✅ Enabled   │
│  • Performance alerts: ✅ Enabled ● Alert threshold: 85%      │
│                                                              │
│  [Save Changes] [Reset to Defaults] [Import] [Export] [Help]  │
└──────────────────────────────────────────────────────────────┘
```

### Profile Management

Switch between different usage profiles:

```
┌─ Profile Management ──────────────────────────────────────────┐
│                                                              │
│  👤 User Profiles                                             │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                              │
│  ◉ Desktop User (Current)                                    │
│     Optimized for desktop Ubuntu systems                      │
│     • Interactive cleanup with GUI feedback                   │
│     • User-friendly safety protections                        │
│     • Regular automated maintenance                           │
│     • Development tool support                               │
│                                                              │
│  ◯ Server Administrator                                       │
│     Optimized for server environments                         │
│     • Minimal resource usage                                  │
│     • Essential cleanup only                                  │
│     • Service-aware protection                               │
│     • Log-based monitoring                                   │
│                                                              │
│  ◯ Developer                                                 │
│     Optimized for development workflows                       │
│     • Development environment awareness                       │
│     • Container and build cleanup                             │
│     • IDE cache management                                   │
│     • Git repository protection                              │
│                                                              │
│  ◯ Minimal                                                   │
│     Essential features only                                   │
│     • Basic system cleanup                                   │
│     • No optional dependencies                               │
│     • Command-line interface only                            │
│                                                              │
│  [Switch Profile] [Customize] [Compare] [Reset]               │
└──────────────────────────────────────────────────────────────┘
```

## 🚀 Advanced Features

### Expert Mode

Enable expert mode for advanced users:

```
┌─ Expert Mode ─────────────────────────────────────────────────┐
│                                                              │
│  ⚠️  EXPERT MODE ENABLED                                     │
│  Advanced features available. Use with caution.              │
│                                                              │
│  🧹 Advanced Cleanup Options:                                 │
│  ☑ Aggressive package cleanup (remove unused kernels)        │
│  ☑ Deep system cache cleaning                                │
│  ☑ Old kernel removal                                        │
│  ☑ Container system cleanup (docker system prune -a)         │
│  ☑ Development environment cleanup (node_modules, etc.)      │
│  ☑ Build artifact removal                                    │
│                                                              │
│  🛡️  Advanced Safety:                                         │
│  ☑ Skip some safety checks                                   │
│  ☑ Override protected directories                            │
│  ☑ Force cleanup of running services                         │
│  ☐ Disable backup creation                                   │
│                                                              │
│  ⚙️  System Configuration:                                     │
│  ☑ System service management                                 │
│  ☑ Kernel parameter tuning                                   │
│  ☑ Filesystem optimization                                  │
│  ☑ Network configuration cleanup                            │
│                                                              │
│  🔧 Debug Options:                                            │
│  ☑ Verbose logging                                           │
│  ☑ Debug mode                                               │
│  ☑ Performance benchmarking                                  │
│  ☑ Dry run for all operations                               │
│                                                              │
│  [Save Settings] [Exit Expert Mode] [Help] [Reset]            │
└──────────────────────────────────────────────────────────────┘
```

### Batch Operations

Perform multiple operations in sequence:

```
┌─ Batch Operations ───────────────────────────────────────────┐
│                                                              │
│  📋 Create Custom Operation Sequence                         │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                              │
│  Queue:                                                      │
│  1. ✅ System Analysis                                       │
│  2. 🔄 System Cleanup (all categories)                       │
│  3. ⏳ Container Cleanup                                     │
│  4. ⏳ Dependency Updates                                     │
│  5. ⏳ Performance Optimization                               │
│                                                              │
│  Add Operations:                                             │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                              │
│  ☑ Create Backup                                            │
│  ☑ System Cleanup                                           │
│  ☑ Container Cleanup                                         │
│  ☑ Development Cleanup                                       │
│  ☑ Dependency Updates                                       │
│  ☑ Performance Check                                        │
│  ☑ Security Scan                                            │
│  ☑ Generate Report                                          │
│                                                              │
│  Configuration:                                               │
│  • Stop on error: ✅ ● Continue on warning: ✅                │
│  • Create log: ✅ ● Send notification: ✅                     │
│  • Schedule: ◉ Immediate ◯ Scheduled ◯ Custom               │
│                                                              │
│  [Start Batch] [Save Queue] [Load Queue] [Clear] [Help]      │
└──────────────────────────────────────────────────────────────┘
```

## 🔄 Common Workflows

### Daily Maintenance Workflow

**Step 1: Quick System Check**
```bash
# Launch interactive interface
fub

# Navigate to System Monitoring
# Press ↑↓ to select "📊 System Monitoring"
# Press Enter
```

**Step 2: Review System Status**
- Check disk space and memory usage
- Review cleanup opportunities
- Note any performance alerts

**Step 3: Quick Cleanup**
- Navigate back to main menu
- Select "🧹 System Cleanup"
- Choose appropriate categories
- Review confirmation and proceed

**Step 4: Schedule Next Maintenance**
- Navigate to "⏰ Scheduled Maintenance"
- Review upcoming tasks
- Adjust schedule if needed

### Development Environment Cleanup

**Step 1: Protect Active Projects**
```bash
# Navigate to Safety Management
fub safety protect $(pwd)  # Current project
fub safety protect /path/to/other/projects
```

**Step 2: Development-Specific Cleanup**
```bash
# Interactive development cleanup
fub cleanup dev --interactive

# Categories to select:
# ☑ Development Environment
# ☑ IDE Caches
# ☑ Build Artifacts
# ☑ Package Dependencies
```

**Step 3: Container Cleanup**
```bash
# If using Docker/containers
fub cleanup containers --interactive

# Options:
# ☑ Stop running containers (with confirmation)
# ☑ Remove unused images
# ☑ Remove unused volumes
# ☑ Clean build cache
```

### Server Maintenance Workflow

**Step 1: Switch to Server Profile**
```bash
# Use server profile for appropriate settings
fub --profile server
```

**Step 2: System Analysis**
```bash
# Comprehensive system check
fub monitor analyze --detailed

# Review:
# - Disk usage trends
# - Memory consumption
# - Service status
# - Security considerations
```

**Step 3: Safe Cleanup**
```bash
# Conservative cleanup for servers
fub cleanup system --conservative

# Typically only:
# ✅ System temp files
# ✅ Old log files
# ❌ Development files
# ❌ User caches
```

**Step 4: Schedule Regular Maintenance**
```bash
# Setup automated maintenance
fub schedule setup --profile server

# Configure:
# - Daily basic cleanup
# - Weekly log rotation
# - Monthly security updates
```

### Container Development Workflow

**Step 1: Container Environment Setup**
```bash
# Install container tools
fub deps install docker podman lazydocker

# Configure container protection
fub safety protect /var/lib/docker
fub safety protect /var/lib/containers
```

**Step 2: Development Cleanup**
```bash
# Comprehensive development cleanup
fub cleanup dev containers --interactive

# Include:
# ✅ Development caches
# ✅ Build artifacts
# ✅ Container cleanup
# ✅ IDE caches
```

**Step 3: Container Maintenance**
```bash
# Regular container maintenance
fub cleanup containers --prune-all

# This includes:
# - Stop unused containers
# - Remove unused images
# - Clean build cache
# - Remove unused volumes
```

## 💡 Best Practices

### Safety First

1. **Always Create Backups**
   ```bash
   # Enable automatic backups
   fub config set cleanup.backup_before_cleanup true

   # Manual backup before major operations
   fub backup create
   ```

2. **Protect Important Directories**
   ```bash
   # Protect active development
   fub safety protect /path/to/active/projects

   # Protect configuration files
   fub safety whitelist add /etc/important/config
   ```

3. **Use Dry Run Mode**
   ```bash
   # Preview operations before execution
   fub cleanup all --dry-run
   fub cleanup dev --dry-run --verbose
   ```

### Regular Maintenance

1. **Daily Quick Checks**
   ```bash
   # Quick system health check
   fub monitor quick

   # Clean temporary files
   fub cleanup temp
   ```

2. **Weekly Deep Cleaning**
   ```bash
   # Comprehensive cleanup
   fub cleanup all --analyze

   # Review system performance
   fub monitor performance
   ```

3. **Monthly System Maintenance**
   ```bash
   # Full system analysis
   fub monitor analyze --detailed

   # Dependency updates
   fub deps update

   # Security scan
   fub security scan
   ```

### Performance Optimization

1. **Monitor Trends**
   ```bash
   # Review performance trends
   fub monitor history --trends

   # Identify bottlenecks
   fub monitor analyze --bottlenecks
   ```

2. **Optimize Settings**
   ```bash
   # Use appropriate profile
   fub --profile server  # For servers
   fub --profile developer  # For development

   # Customize retention periods
   fub config set cleanup.temp_retention 3
   fub config set cleanup.log_retention 60
   ```

3. **Automate Where Possible**
   ```bash
   # Setup scheduled maintenance
   fub schedule setup --profile desktop

   # Enable background monitoring
   fub schedule enable monitoring
   ```

## 🎯 Tips & Tricks

### Navigation Shortcuts

- **?** - Show context-sensitive help
- **r** - Refresh current view
- **q** or **Escape** - Go back or quit
- **Ctrl+C** - Emergency exit (safe)
- **Tab** - Navigate between sections
- **Space** - Toggle selections
- **a** - Select all (in multi-select menus)
- **i** - View detailed information

### Hidden Features

1. **Quick Stats**
   ```bash
   # Quick system overview
   fub --stats

   # Quick dependency check
   fub deps --quick
   ```

2. **Export Functions**
   ```bash
   # Export configuration
   fub config export > my-fub-config.yaml

   # Export system report
   fub monitor report --export json > system-report.json
   ```

3. **Batch Operations**
   ```bash
   # Create custom batch file
   cat > cleanup-batch.txt << EOF
   system analyze
   cleanup temp
   cleanup cache
   monitor report
   EOF

   # Execute batch
   fub --batch cleanup-batch.txt
   ```

### Performance Tips

1. **Use Appropriate Profiles**
   - Server profile for minimal resource usage
   - Desktop profile for user-friendly features
   - Developer profile for development environments

2. **Optimize Cleanup Frequency**
   - Daily: temp files, basic cache
   - Weekly: development cleanup, containers
   - Monthly: deep system cleanup, dependency updates

3. **Monitor Resource Usage**
   - Enable performance alerts
   - Track historical trends
   - Adjust based on usage patterns

### Troubleshooting Quick Tips

1. **Reset Configuration**
   ```bash
   fub config reset
   ```

2. **Check Dependencies**
   ```bash
   fub deps check --verbose
   ```

3. **Enable Debug Mode**
   ```bash
   FUB_DEBUG=true fub cleanup all --verbose
   ```

4. **View System Logs**
   ```bash
   fub logs show --last 1h
   ```

---

This comprehensive interactive usage guide covers all aspects of using FUB's modern interface. For more specific documentation, see the other guides in the `docs/` directory or use the built-in help system with `fub help`.