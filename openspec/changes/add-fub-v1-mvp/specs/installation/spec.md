# Installation System Specification

## ADDED Requirements

### Requirement: One-Command Installation

The system MUST provide one-command installation via curl pipe to bash, following the Mole installation pattern.

**Priority**: P0 (Critical)

#### Scenario: Desktop user installs FUB

**Given** a fresh Ubuntu 24.04 desktop system with internet access
**When** the user executes:
```bash
curl -fsSL https://raw.githubusercontent.com/[user]/fub/main/install.sh | bash
```
**Then** the installation MUST:
- Complete in <30 seconds
- Download the main `fub` executable
- Place it in `/usr/local/bin/fub`
- Create configuration directory `~/.config/fub/`
- Create log directory `~/.local/share/fub/logs/`
- Generate default configuration file
- Verify installation success
- Display welcome message with usage instructions

**And** the `fub` command MUST be immediately available without shell restart

#### Scenario: Server user installs with custom path

**Given** an Ubuntu 22.04 server system
**When** the user executes:
```bash
curl -fsSL https://raw.githubusercontent.com/[user]/fub/main/install.sh | bash -s -- --prefix=$HOME/.local
```
**Then** the installation MUST:
- Install to `$HOME/.local/bin/fub` instead of `/usr/local/bin/`
- Not require sudo privileges
- Instruct user to add `$HOME/.local/bin` to PATH if not present

---

### Requirement: Ubuntu Version Detection

**Priority**: P0 (Critical)

The installation script MUST detect Ubuntu version and validate compatibility before proceeding.

#### Scenario: Installing on supported Ubuntu version

**Given** Ubuntu 24.04, 22.04, or 20.04 LTS
**When** installation starts
**Then** the script MUST:
- Detect Ubuntu version using `lsb_release -rs` or `/etc/lsb-release`
- Display detected version
- Proceed with installation
- Log the Ubuntu version

#### Scenario: Installing on unsupported Ubuntu version

**Given** Ubuntu 18.04 (EOL) or Ubuntu 25.04 (untested)
**When** installation starts
**Then** the script MUST:
- Detect the version
- Display warning: "Ubuntu [version] not explicitly tested. Supported: 24.04, 22.04, 20.04"
- Prompt user: "Continue anyway? [y/N]"
- Proceed only if user confirms with 'y' or 'Y'
- Abort installation if user declines

#### Scenario: Installing on non-Ubuntu system

**Given** Debian, Fedora, or macOS
**When** installation starts
**Then** the script MUST:
- Detect non-Ubuntu system
- Display error: "FUB is designed for Ubuntu only. Detected: [system]"
- Exit with code 1
- Not create any files or directories

---

### Requirement: Fallback Installation Methods

**Priority**: P1 (High)

The installation script MUST support multiple installation methods with intelligent fallback.

#### Scenario: Primary installation via curl (online)

**Given** system with internet access and curl
**When** user runs the curl command
**Then** the script MUST:
- Download latest `fub` from GitHub repository
- Verify download integrity (non-zero size)
- Make executable with `chmod +x`
- Install to target directory

#### Scenario: Git-based installation

**Given** user has git installed
**When** user executes:
```bash
git clone https://github.com/[user]/fub.git
cd fub
sudo ./install.sh
```
**Then** the script MUST:
- Detect local `fub` executable in repository
- Use local copy instead of downloading
- Complete installation from local files

#### Scenario: Offline installation

**Given** system without internet access but with downloaded repository
**When** user runs `./install.sh` from repository directory
**Then** the script MUST:
- Detect offline mode (curl failure)
- Use local `fub` executable if present
- Display error if no local copy: "Cannot download (offline). Please use git clone method."

---

### Requirement: Post-Installation Verification

**Priority**: P1 (High)

The installation MUST verify successful installation and provide troubleshooting guidance if verification fails.

#### Scenario: Successful installation verification

**Given** installation completed
**When** verification runs
**Then** the script MUST:
- Check `fub` exists in target directory
- Check `fub` is executable (`test -x`)
- Check configuration directory exists
- Check log directory exists
- Execute `fub --version` to verify functionality
- Display success message with next steps

#### Scenario: Installation verification failure

**Given** installation failed (e.g., permission error)
**When** verification runs
**Then** the script MUST:
- Detect failure (missing executable or non-executable)
- Display specific error message
- Provide troubleshooting guidance:
  - Check permissions
  - Try sudo for system install
  - Try `--prefix=$HOME/.local` for user install
- Exit with non-zero code
- Clean up partial installation

---

### Requirement: Profile Detection During Installation

**Priority**: P2 (Medium)

The installation script SHALL detect desktop vs server environment and pre-configure appropriate profile.

#### Scenario: Desktop environment detection

**Given** Ubuntu desktop installation with GNOME/KDE/XFCE
**When** installation runs
**Then** the script SHOULD:
- Detect desktop via `systemctl get-default | grep graphical.target`
- Or detect via `$DISPLAY` environment variable
- Set `profile = desktop` in generated configuration
- Display: "Desktop environment detected. Configured for desktop profile."

#### Scenario: Server environment detection

**Given** Ubuntu server installation without GUI
**When** installation runs
**Then** the script SHOULD:
- Detect server via `systemctl get-default | grep multi-user.target`
- Set `profile = server` in generated configuration
- Display: "Server environment detected. Configured for server profile."

#### Scenario: Uncertain environment

**Given** unable to detect environment reliably
**When** installation runs
**Then** the script SHOULD:
- Set `profile = auto` in configuration
- Display: "Environment auto-detection enabled. FUB will detect at runtime."

---

### Requirement: Uninstallation Support

**Priority**: P2 (Medium)

The installation script MUST support clean uninstallation when run with `--uninstall` flag.

#### Scenario: Uninstalling FUB

**Given** FUB is installed
**When** user executes:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/[user]/fub/main/install.sh) --uninstall
```
**Or** runs from local repository:
```bash
./install.sh --uninstall
```
**Then** the script MUST:
- Detect existing FUB installation
- Display what will be removed:
  - `/usr/local/bin/fub` (or custom path)
  - Configuration in `~/.config/fub/` (ask to preserve)
  - Logs in `~/.local/share/fub/logs/` (ask to preserve)
- Prompt: "Remove configuration? [y/N]"
- Prompt: "Remove logs? [y/N]"
- Remove selected items
- Display confirmation: "FUB uninstalled successfully"

#### Scenario: Uninstalling when not installed

**Given** FUB is not installed
**When** user runs `./install.sh --uninstall`
**Then** the script MUST:
- Detect FUB is not present
- Display: "FUB is not installed. Nothing to remove."
- Exit with code 0 (success, as end state is achieved)

---

### Requirement: Installation Logging

**Priority**: P2 (Medium)

The installation script SHALL log installation process for debugging.

#### Scenario: Installation log creation

**Given** installation is running
**When** any installation step executes
**Then** the script SHOULD:
- Create log at `/tmp/fub-install-[timestamp].log`
- Log all major steps:
  - Ubuntu version detection
  - Download/copy operation
  - File placement
  - Configuration generation
  - Verification results
- Display log location at end: "Installation log: /tmp/fub-install-YYYY-MM-DD-HH-MM-SS.log"

#### Scenario: Installation failure with log

**Given** installation fails
**When** error occurs
**Then** the script MUST:
- Log error details
- Display: "Installation failed. Check log: [path]"
- Preserve log file for debugging

---

### Requirement: Non-Interactive Installation

**Priority**: P2 (Medium)

The installation script SHALL support non-interactive mode for automation.

#### Scenario: CI/CD or automated installation

**Given** automated environment
**When** user executes:
```bash
curl -fsSL ... | bash -s -- --yes
```
**Then** the script MUST:
- Skip all confirmation prompts
- Use defaults for all choices
- Proceed with installation automatically
- Exit with 0 on success, non-zero on failure

---

## Cross-References

**Related Specifications**:
- `cli-interface`: Installation creates executable for CLI
- `configuration`: Installation generates default config
- `safety-system`: Installation validates system compatibility

**Dependencies**:
- Ubuntu 20.04+ with bash 4.0+
- Either curl or git for download
- Permissions to write to target directory
