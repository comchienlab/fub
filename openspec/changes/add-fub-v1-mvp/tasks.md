# FUB v1.0 MVP - Implementation Tasks (Simplified Mole-Clone Approach)

## Overview

**Philosophy**: Build a working Mole clone for Ubuntu in 3-4 weeks. Ship fast, gather users, iterate to v1.1 based on feedback.

**Scope**: Just `fub clean` and `fub clean --dry-run` for v1.0. No config files, no profiles, no advanced features.

**Timeline**: 3-4 weeks (not 6+ weeks)

---

## Week 1-2: Core Functionality

### 1.1 Project Setup (1 day)

- [ ] Create GitHub repository `fub`
- [ ] Add LICENSE (MIT, like Mole)
- [ ] Create basic README.md with tagline: "Dig deep like a mole to clean your Ubuntu"
- [ ] Add `.gitignore`
- [ ] Create directory structure:
  ```
  /
  ├── fub (main executable)
  ├── install.sh
  └── README.md
  ```

**Validation**: Repository exists, can clone it

---

### 1.2 Installation Script (2-3 days)

- [ ] Create `install.sh` with strict error handling (`set -Eeuo pipefail`)
- [ ] Implement Ubuntu version detection (`lsb_release -rs` or `/etc/lsb-release`)
- [ ] Validate Ubuntu 24.04, 22.04, 20.04 (warn on others)
- [ ] Implement curl download from GitHub (with fallback to local if in repo)
- [ ] Install to `/usr/local/bin/fub` (or custom `--prefix` path)
- [ ] Make executable (`chmod +x`)
- [ ] Test installation with: `fub --version`
- [ ] Add uninstall support: `./install.sh --uninstall`
- [ ] Test one-line install: `curl -fsSL ... | bash`

**Validation**:
- Fresh Ubuntu 24.04: Install completes in <30s
- `fub --version` works after install
- Install on 22.04, 20.04
- Uninstall removes `/usr/local/bin/fub`

---

### 1.3 Main Executable Structure (2 days)

- [ ] Create `fub` main script with shebang `#!/usr/bin/env bash`
- [ ] Add strict error handling (`set -Eeuo pipefail`)
- [ ] Implement version: `VERSION="1.0.0"`
- [ ] Add argument parsing:
  - `fub` → interactive menu
  - `fub clean` → run cleanup
  - `fub clean --dry-run` → preview only
  - `fub --version` → show version
  - `fub --help` → show usage
- [ ] Create help text (usage examples)
- [ ] Validate Ubuntu (exit if not Ubuntu)
- [ ] Add global error trap for debugging

**Validation**:
- `fub --version` outputs "FUB v1.0.0"
- `fub --help` shows clear usage
- `fub` without args shows help or starts interactive mode
- Error on non-Ubuntu system

---

### 1.4 Cleanup Functions Skeleton (1 day)

- [ ] Create cleanup function template
- [ ] Implement dry-run global flag (`DRY_RUN=false`)
- [ ] Create space calculation helper (`calculate_size`)
- [ ] Create human-readable formatter (bytes → MB/GB)
- [ ] Add confirmation prompt function
- [ ] Add basic logging (stdout, stderr)

**Validation**:
- Functions defined, can be called
- Dry-run flag works
- Space calculation returns correct MB/GB

---

### 1.5 Cleanup Module: APT Cache (1 day)

- [ ] Implement APT lock check (`fuser /var/lib/dpkg/lock-frontend`)
- [ ] Calculate APT cache size (`du -sb /var/cache/apt/archives/`)
- [ ] Implement dry-run: Show size, list packages
- [ ] Implement cleanup: `sudo apt-get clean`
- [ ] Display: "Cleaning APT cache... 347 MB"
- [ ] Handle errors gracefully (locked → skip with message)

**Validation**:
- Dry-run shows accurate size
- Cleanup removes cache
- Skips gracefully when APT locked
- Test on Ubuntu 24.04, 22.04, 20.04

---

### 1.6 Cleanup Module: Old Kernels ⚠️ CRITICAL (3-4 days)

**Safety is paramount - extensive testing required**

- [ ] Detect current kernel (`uname -r`)
- [ ] List installed kernels (`dpkg -l | grep linux-image`)
- [ ] Implement version-aware sorting (`sort -V`)
- [ ] Enforce minimum 2 kernels (current + 1 previous)
- [ ] If only 2 kernels: Display message, skip cleanup
- [ ] If 3+ kernels: Mark oldest for removal (keep current + 1)
- [ ] Find all kernel packages (image, headers, modules)
- [ ] Implement dry-run: Show what stays vs what goes
- [ ] Implement cleanup: Remove old kernels via `apt-get remove --purge`
- [ ] **CONFIRMATION**: Explicit prompt with warning before removal
- [ ] Update GRUB after removal (`update-grub`)
- [ ] Handle errors (locked, failed removal)

**Safety Checks** (ALL REQUIRED):
- ✅ Current kernel NEVER in removal list
- ✅ Minimum 2 kernels always maintained
- ✅ Explicit confirmation required
- ✅ GRUB updated successfully

**Validation** (CRITICAL TESTING):
- Test with 2 kernels: Refuses cleanup ✓
- Test with 3 kernels: Removes only oldest ✓
- Test with 5+ kernels: Removes all but current + 1 ✓
- Current kernel never appears in removal candidates ✓
- Dry-run matches actual execution ✓
- Test on Ubuntu 24.04, 22.04, 20.04 ✓
- **Reboot test**: System boots after cleanup ✓ (CRITICAL!)

---

### 1.7 Cleanup Module: systemd Journal (1 day)

- [ ] Detect journal size (`journalctl --disk-usage`)
- [ ] Implement dry-run: Show current size
- [ ] Implement cleanup: `sudo journalctl --vacuum-size=100M`
- [ ] Calculate space freed (before/after)
- [ ] Display: "Vacuuming journal to 100M... 1.2 GB freed"

**Validation**:
- Shows current journal size
- Vacuums to 100M successfully
- Calculates space freed accurately

---

### 1.8 Cleanup Module: Browser Caches (1-2 days)

- [ ] Detect Firefox process (`pgrep firefox`)
- [ ] If Firefox running: Skip with message
- [ ] If not running: Clean `~/.cache/mozilla/firefox/*/cache2/`
- [ ] Repeat for Chrome (`~/.cache/google-chrome/Default/Cache/`)
- [ ] Repeat for Chromium (`~/.cache/chromium/Default/Cache/`)
- [ ] Handle missing browsers gracefully (not an error)
- [ ] Calculate space freed per browser

**Validation**:
- Skips Firefox cache when Firefox is running
- Cleans when browser closed
- Handles missing browsers
- Test all 3 browsers (Firefox, Chrome, Chromium)

---

### 1.9 Cleanup Module: User Caches (0.5 day)

- [ ] Clean `~/.cache/*` (except preserve browsers if handled separately)
- [ ] Calculate size
- [ ] Implement dry-run and cleanup
- [ ] Handle permission errors

**Validation**:
- Cleans user cache directory
- Doesn't break system

---

### 1.10 Cleanup Module: Temp Files (1 day)

- [ ] Clean `/tmp` (files older than 7 days)
- [ ] Clean `/var/tmp` (files older than 7 days)
- [ ] Implement age filtering
- [ ] Handle permission errors gracefully
- [ ] Skip system-critical files

**Validation**:
- Only removes old files (>7 days)
- Preserves recent files
- No system breakage

---

## Week 3: Safety, Polish & Interactive UX

### 3.1 Interactive Menu (1-2 days)

- [ ] Implement bash `select` menu (like Mole)
- [ ] Show options:
  ```
  1) Clean (with dry-run preview)
  2) Clean (skip preview)
  3) Dry-run only
  4) Quit
  ```
- [ ] Execute selected option
- [ ] Return to menu after completion (or exit)
- [ ] Make menu look clean and simple (like Mole's)

**Validation**:
- Menu displays correctly
- Options work as expected
- User-friendly experience

---

### 3.2 Dry-Run Mode (1 day)

- [ ] Orchestrate all cleanup modules in dry-run mode
- [ ] Display preview:
  ```
  === FUB Cleanup Preview (DRY-RUN) ===

  [✓] APT cache: 347 MB
  [✓] Old kernels: 520 MB (removing 2 old kernels)
  [✓] systemd journal: 1.2 GB
  [✓] Browser caches: 890 MB (Firefox, Chrome)
  [✓] User caches: 450 MB
  [✓] Temp files: 180 MB

  Total potential recovery: 3.6 GB

  This is a DRY-RUN. No changes made.
  Run 'fub clean' to execute cleanup.
  ```
- [ ] Ensure accuracy (dry-run ≈ actual execution)

**Validation**:
- Dry-run shows accurate preview
- No filesystem changes during dry-run
- Output is clear and helpful

---

### 3.3 Actual Cleanup Execution (1 day)

- [ ] Run all cleanup modules in sequence
- [ ] Show progress: "[1/6] Cleaning APT cache..."
- [ ] Skip modules on error (don't abort entire cleanup)
- [ ] Display summary at end:
  ```
  === Cleanup Complete ===

  APT cache: 347 MB freed
  Old kernels: 520 MB freed
  systemd journal: 1.2 GB freed
  Browser caches: 890 MB freed
  User caches: 450 MB freed
  Temp files: 180 MB freed

  Total: 3.6 GB freed
  ```
- [ ] Handle partial failures gracefully

**Validation**:
- Cleanup executes all categories
- Progress clear
- Summary accurate
- Partial failures handled

---

### 3.4 Confirmation Prompts (0.5 day)

- [ ] Add confirmation before cleanup:
  ```
  Ready to clean your Ubuntu system?
  This will free approximately 3.6 GB.

  Continue? [y/N]:
  ```
- [ ] Kernel-specific confirmation (extra warning):
  ```
  WARNING: About to remove old kernels.
  Current kernel (protected): 6.8.0-48
  Will remove: 6.8.0-46, 5.15.0-91

  Proceed? [y/N]:
  ```
- [ ] Require 'y' or 'Y' to proceed
- [ ] Abort on any other input

**Validation**:
- Confirmations display correctly
- 'y' proceeds, anything else aborts
- Kernel confirmation extra clear

---

## Week 4: Testing & Release

### 4.1 Platform Testing (3-4 days)

**Test Matrix**:
- [ ] Ubuntu 24.04 LTS (fresh install)
- [ ] Ubuntu 24.04 LTS (with many kernels)
- [ ] Ubuntu 22.04 LTS (fresh install)
- [ ] Ubuntu 22.04 LTS (with HWE kernels)
- [ ] Ubuntu 20.04 LTS

**For each platform**:
- [ ] Installation (curl method)
- [ ] `fub --version`, `fub --help`
- [ ] Dry-run (`fub clean --dry-run`)
- [ ] Actual cleanup (`fub clean`)
- [ ] Verify space freed
- [ ] **Reboot after kernel cleanup** (CRITICAL!)
- [ ] System still bootable ✓
- [ ] No errors, no data loss

**Edge Cases**:
- [ ] System with only 2 kernels (should refuse)
- [ ] System with APT locked (should skip gracefully)
- [ ] System with browser running (should skip browser cache)
- [ ] System with minimal disk space (<100MB free)

**Validation**: All tests pass, zero critical bugs

---

### 4.2 Code Quality (1 day)

- [ ] Run ShellCheck on all scripts
- [ ] Fix all errors and warnings
- [ ] Ensure consistent style
- [ ] Add comments to complex sections
- [ ] Verify all error messages are clear

**Validation**: ShellCheck passes with 0 errors

---

### 4.3 Documentation (1-2 days)

**README.md**:
- [ ] Add tagline: "Dig deep like a mole to clean your Ubuntu"
- [ ] Add quick description
- [ ] Add installation instructions (one-line curl)
- [ ] Add usage examples:
  ```bash
  # Preview cleanup
  fub clean --dry-run

  # Execute cleanup
  fub clean

  # Interactive menu
  fub
  ```
- [ ] Add safety features section
- [ ] Add FAQ (at least 5 questions)
- [ ] Add "Inspired by Mole" section with link

**INSTALLATION.md** (optional, can defer):
- [ ] Detailed installation guide
- [ ] Troubleshooting

**Validation**: README clear to new users

---

### 4.4 Release Preparation (0.5 day)

- [ ] Update version to `1.0.0` in code
- [ ] Create CHANGELOG.md for v1.0.0
- [ ] Replace placeholder GitHub URLs with actual repo URL
- [ ] Final commit: "Release v1.0.0"
- [ ] Tag: `git tag v1.0.0`
- [ ] Push: `git push && git push --tags`

---

### 4.5 GitHub Release (0.5 day)

- [ ] Create GitHub Release v1.0.0
- [ ] Write release notes:
  ```
  # FUB v1.0.0 - Initial Release

  "Dig deep like a mole to clean your Ubuntu"

  FUB is a terminal-based cleanup tool for Ubuntu, inspired by Mole for macOS.

  ## Features
  - One-command installation
  - Cleans: APT cache, old kernels, systemd journal, browser caches, user caches, temp files
  - Dry-run mode for safe preview
  - Interactive menu
  - Typical recovery: 2-5 GB

  ## Installation
  curl -fsSL https://raw.githubusercontent.com/[user]/fub/main/install.sh | bash

  ## Tested On
  - Ubuntu 24.04 LTS
  - Ubuntu 22.04 LTS
  - Ubuntu 20.04 LTS
  ```
- [ ] Attach `fub` binary (or note it's downloaded via install.sh)
- [ ] Attach SHA256 checksums

**Validation**: Release is live and downloadable

---

### 4.6 Community Announcement (1 day)

- [ ] Post to Ubuntu Discourse (https://discourse.ubuntu.com/)
- [ ] Post to Reddit r/Ubuntu
- [ ] Post to Reddit r/linux (if relevant)
- [ ] Tweet about release (if applicable)
- [ ] Set up GitHub Issues for bug reports

**Message Template**:
```
🎉 Introducing FUB v1.0: "Dig deep like a mole to clean your Ubuntu"

A terminal-based cleanup tool inspired by Mole (the popular macOS cleaner).

✨ Features:
- One-command installation
- Cleans APT cache, old kernels, systemd journal, browser caches, and more
- Dry-run mode for safe preview
- Typical recovery: 2-5 GB

Install: curl -fsSL ... | bash
GitHub: [link]

Feedback welcome!
```

---

## Post-Release: v1.1 Planning

### 5.1 Gather User Feedback (Ongoing)

- [ ] Monitor GitHub Issues daily (first 2 weeks)
- [ ] Respond to bug reports <24 hours
- [ ] Collect feature requests
- [ ] Identify most requested features

---

### 5.2 Plan v1.1 Features (After 1 month)

Based on user feedback, consider adding:
- [ ] App uninstallation (`fub uninstall`) - Mole has this
- [ ] Disk analyzer (`fub analyze`) - Mole has this
- [ ] Configuration file (`~/.config/fub/fub.conf`)
- [ ] Category selection (`--only`, `--skip` flags)
- [ ] Snap/Flatpak cleanup
- [ ] systemd timer setup
- [ ] Whitelist system

**Prioritize based on actual user needs, not speculation.**

---

## Success Criteria

**v1.0 is complete when:**

✅ All Week 1-4 tasks completed
✅ Works on Ubuntu 24.04, 22.04, 20.04
✅ ShellCheck passes (0 errors)
✅ **Zero system failures** (no unbootable systems)
✅ README clear and helpful
✅ GitHub release v1.0.0 published
✅ Installation works via one-command curl
✅ At least 5 people successfully use it

**Then**: Ship it, gather feedback, plan v1.1!

---

## Task Summary

**Total Tasks**: ~60 (vs 246 in original over-engineered plan)
**Timeline**: 3-4 weeks
**Philosophy**: Ship fast, iterate, match Mole's simple evolution

---

**Last Updated**: 2025-11-04 (simplified to Mole-clone approach)
**Status**: Ready for Implementation
**Estimated Effort**: 3-4 weeks (1 developer)
