#!/usr/bin/env bash

# FUB Configuration UI Module
# Interactive interface for managing user configuration, profiles, and themes

set -euo pipefail

# Source common utilities if not already loaded
if [[ -z "${FUB_SCRIPT_DIR:-}" ]]; then
    readonly FUB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly FUB_ROOT_DIR="$(cd "${FUB_ROOT_DIR}/.." && pwd)"
    source "${FUB_ROOT_DIR}/lib/common.sh"
    source "${FUB_ROOT_DIR}/lib/config.sh"
    source "${FUB_ROOT_DIR}/lib/user-config.sh"
    source "${FUB_ROOT_DIR}/lib/theme-manager.sh"
    source "${FUB_ROOT_DIR}/lib/config-validator.sh"
    source "${FUB_ROOT_DIR}/lib/interactive.sh"
fi

# UI state variables
FUB_CONFIG_UI_RUNNING=false

# Initialize configuration UI
init_config_ui() {
    log_debug "Initializing configuration UI..."

    # Initialize required modules
    init_user_config
    init_theme_manager
    init_config_validator

    FUB_CONFIG_UI_RUNNING=true
    log_debug "Configuration UI initialized"
}

# Show main configuration menu
show_config_menu() {
    while true; do
        local choice
        choice=$(gum choose \
            "🔧 System Configuration" \
            "👤 User Configuration" \
            "🎨 Theme Management" \
            "📋 Profile Management" \
            "✅ Configuration Validation" \
            "💾 Import/Export" \
            "🔙 Back to Main Menu" \
            --header="Configuration Management" \
            --height=8)

        case "$choice" in
            "🔧 System Configuration")
                show_system_config_menu
                ;;
            "👤 User Configuration")
                show_user_config_menu
                ;;
            "🎨 Theme Management")
                show_theme_menu
                ;;
            "📋 Profile Management")
                show_profile_menu
                ;;
            "✅ Configuration Validation")
                show_validation_menu
                ;;
            "💾 Import/Export")
                show_import_export_menu
                ;;
            "🔙 Back to Main Menu")
                break
                ;;
        esac
    done
}

# Show system configuration menu
show_system_config_menu() {
    while true; do
        local choice
        choice=$(gum choose \
            "📖 View Current Configuration" \
            "✏️ Edit Configuration" \
            "🔄 Reset to Defaults" \
            "💾 Save Configuration" \
            "📊 Configuration Status" \
            "🔙 Back" \
            --header="System Configuration" \
            --height=6)

        case "$choice" in
            "📖 View Current Configuration")
                show_current_config
                ;;
            "✏️ Edit Configuration")
                edit_configuration
                ;;
            "🔄 Reset to Defaults")
                reset_configuration
                ;;
            "💾 Save Configuration")
                save_configuration
                ;;
            "📊 Configuration Status")
                show_config_status
                ;;
            "🔙 Back")
                break
                ;;
        esac
    done
}

# Show user configuration menu
show_user_config_menu() {
    while true; do
        local choice
        choice=$(gum choose \
            "👤 User Profile Settings" \
            "🔧 Preferences" \
            "🛡️ Safety Settings" \
            "🔔 Notification Settings" \
            "⚡ Performance Settings" \
            "📊 User Configuration Status" \
            "🔙 Back" \
            --header="User Configuration" \
            --height=7)

        case "$choice" in
            "👤 User Profile Settings")
                edit_user_profile_settings
                ;;
            "🔧 Preferences")
                edit_user_preferences
                ;;
            "🛡️ Safety Settings")
                edit_safety_settings
                ;;
            "🔔 Notification Settings")
                edit_notification_settings
                ;;
            "⚡ Performance Settings")
                edit_performance_settings
                ;;
            "📊 User Configuration Status")
                show_user_config_status
                ;;
            "🔙 Back")
                break
                ;;
        esac
    done
}

# Show theme management menu
show_theme_menu() {
    while true; do
        local choice
        choice=$(gum choose \
            "🎨 List Available Themes" \
            "🖌️ Switch Theme" \
            "➕ Create Custom Theme" \
            "✏️ Customize Theme" \
            "🗑️ Delete Theme" \
            "🔍 Theme Preview" \
            "📊 Theme Status" \
            "🔙 Back" \
            --header="Theme Management" \
            --height=8)

        case "$choice" in
            "🎨 List Available Themes")
                list_themes
                ;;
            "🖌️ Switch Theme")
                switch_theme_interactive
                ;;
            "➕ Create Custom Theme")
                create_custom_theme_interactive
                ;;
            "✏️ Customize Theme")
                customize_theme_interactive
                ;;
            "🗑️ Delete Theme")
                delete_theme_interactive
                ;;
            "🔍 Theme Preview")
                show_theme_preview_interactive
                ;;
            "📊 Theme Status")
                show_theme_status
                ;;
            "🔙 Back")
                break
                ;;
        esac
    done
}

# Show profile management menu
show_profile_menu() {
    while true; do
        local choice
        choice=$(gum choose \
            "📋 List Available Profiles" \
            "🔄 Switch Profile" \
            "➕ Create Custom Profile" \
            "✏️ Edit Profile" \
            "🗑️ Delete Profile" \
            "📊 Profile Status" \
            "🔙 Back" \
            --header="Profile Management" \
            --height=7)

        case "$choice" in
            "📋 List Available Profiles")
                list_profiles
                ;;
            "🔄 Switch Profile")
                switch_profile_interactive
                ;;
            "➕ Create Custom Profile")
                create_custom_profile_interactive
                ;;
            "✏️ Edit Profile")
                edit_profile_interactive
                ;;
            "🗑️ Delete Profile")
                delete_profile_interactive
                ;;
            "📊 Profile Status")
                show_profile_status_interactive
                ;;
            "🔙 Back")
                break
                ;;
        esac
    done
}

# Show validation menu
show_validation_menu() {
    while true; do
        local choice
        choice=$(gum choose \
            "✅ Validate All Configuration" \
            "🔧 Validate System Config" \
            "👤 Validate User Config" \
            "📋 Validate Current Profile" \
            "🎨 Validate Current Theme" \
            "🔧 Auto-Fix Issues" \
            "📖 Validation Help" \
            "🔙 Back" \
            --header="Configuration Validation" \
            --height=8)

        case "$choice" in
            "✅ Validate All Configuration")
                validate_all_configs_interactive
                ;;
            "🔧 Validate System Config")
                validate_system_config_interactive
                ;;
            "👤 Validate User Config")
                validate_user_config_interactive
                ;;
            "📋 Validate Current Profile")
                validate_profile_interactive
                ;;
            "🎨 Validate Current Theme")
                validate_theme_interactive
                ;;
            "🔧 Auto-Fix Issues")
                auto_fix_config_interactive
                ;;
            "📖 Validation Help")
                show_validation_help
                ;;
            "🔙 Back")
                break
                ;;
        esac
    done
}

# Show import/export menu
show_import_export_menu() {
    while true; do
        local choice
        choice=$(gum choose \
            "💾 Export Configuration" \
            "📥 Import Configuration" \
            "💾 Export Theme" \
            "📥 Import Theme" \
            "💾 Export Profile" \
            "📥 Import Profile" \
            "🗂️ List Backups" \
            "🔄 Restore from Backup" \
            "🔙 Back" \
            --header="Import/Export Configuration" \
            --height=9)

        case "$choice" in
            "💾 Export Configuration")
                export_configuration_interactive
                ;;
            "📥 Import Configuration")
                import_configuration_interactive
                ;;
            "💾 Export Theme")
                export_theme_interactive
                ;;
            "📥 Import Theme")
                import_theme_interactive
                ;;
            "💾 Export Profile")
                export_profile_interactive
                ;;
            "📥 Import Profile")
                import_profile_interactive
                ;;
            "🗂️ List Backups")
                list_config_backups
                ;;
            "🔄 Restore from Backup")
                restore_backup_interactive
                ;;
            "🔙 Back")
                break
                ;;
        esac
    done
}

# Interactive functions
show_current_config() {
    gum style --foreground=212 --border=double --padding="1 2" --margin=1 \
        "Current System Configuration"

    echo ""
    show_config "all"
    echo ""

    gum confirm "Continue?" && return 0 || return 1
}

edit_configuration() {
    local sections=("log" "theme" "cleanup" "network" "all")
    local section
    section=$(gum choose "${sections[@]}" --header="Select configuration section to edit")

    case "$section" in
        "all")
            show_config "all"
            ;;
        *)
            show_config "$section"
            ;;
    esac

    if gum confirm "Edit this configuration section?"; then
        local key=$(gum input --placeholder="Enter configuration key to edit")
        local value=$(gum input --placeholder="Enter new value")

        if [[ -n "$key" && -n "$value" ]]; then
            set_config "$key" "$value" "user"
            gum style --foreground=10 "✓ Configuration updated: $key = $value"
        fi
    fi
}

reset_configuration() {
    gum style --foreground=208 --border=round --padding="1 2" --margin=1 \
        "⚠️  Warning: This will reset your configuration to defaults"

    if gum confirm "Are you sure you want to reset configuration?"; then
        local scopes=("runtime" "user")
        local scope
        scope=$(gum choose "${scopes[@]}" --header="Select reset scope")

        reset_config "$scope"
        gum style --foreground=10 "✓ Configuration reset to defaults ($scope scope)"
    fi
}

save_configuration() {
    local output_file
    output_file=$(gum file --file="$HOME/Downloads/fub-config.yaml")

    if [[ -n "$output_file" ]]; then
        export_config "$output_file" "yaml"
        gum style --foreground=10 "✓ Configuration exported to: $output_file"
    fi
}

show_config_status() {
    gum style --foreground=212 --border=double --padding="1 2" --margin=1 \
        "Configuration Status"

    echo ""
    echo "System Config Directory: $FUB_CONFIG_DIR"
    echo "User Config Directory: $FUB_USER_CONFIG_DIR"
    echo "System Config File: ${FUB_CONFIG_DIR}/default.yaml"
    echo "User Config File: $FUB_USER_CONFIG_FILE"
    echo "Current Profile: $(get_current_profile)"
    echo "Current Theme: $(get_user_config 'theme.name')"
    echo ""
}

edit_user_profile_settings() {
    gum style --foreground=212 --border=double --padding="1 2" --margin=1 \
        "User Profile Settings"

    echo ""
    echo "Current User Settings:"
    echo "Name: $(get_user_config 'user.name')"
    echo "Email: $(get_user_config 'user.email')"
    echo "Preferred Theme: $(get_user_config 'user.preferred_theme')"
    echo "Interactive Mode: $(get_user_config 'user.interactive_mode')"
    echo ""

    if gum confirm "Edit user profile settings?"; then
        local name=$(gum input --value="$(get_user_config 'user.name')" --placeholder="User name")
        local email=$(gum input --value="$(get_user_config 'user.email')" --placeholder="Email address")
        local preferred_theme=$(gum input --value="$(get_user_config 'user.preferred_theme')" --placeholder="Preferred theme")

        update_user_config_key "user.name" "$name"
        update_user_config_key "user.email" "$email"
        update_user_config_key "user.preferred_theme" "$preferred_theme"

        gum style --foreground=10 "✓ User profile settings updated"
    fi
}

edit_user_preferences() {
    gum style --foreground=212 --border=double --padding="1 2" --margin=1 \
        "User Preferences"

    local interactive=$(get_user_config 'user.interactive_mode')
    local advanced=$(get_user_config 'user.show_advanced_options')

    echo ""
    echo "Current Preferences:"
    echo "Interactive Mode: $interactive"
    echo "Show Advanced Options: $advanced"
    echo ""

    if gum confirm "Edit preferences?"; then
        interactive=$(gum choose "true" "false" --header="Interactive Mode" --selected="$interactive")
        advanced=$(gum choose "true" "false" --header="Show Advanced Options" --selected="$advanced")

        update_user_config_key "user.interactive_mode" "$interactive"
        update_user_config_key "user.show_advanced_options" "$advanced"

        gum style --foreground=10 "✓ User preferences updated"
    fi
}

edit_safety_settings() {
    gum style --foreground=212 --border=double --padding="1 2" --margin=1 \
        "Safety Settings"

    local backup=$(get_user_config 'safety.backup_before_cleanup')
    local confirm=$(get_user_config 'safety.confirm_dangerous_operations')

    echo ""
    echo "Current Safety Settings:"
    echo "Backup Before Cleanup: $backup"
    echo "Confirm Dangerous Operations: $confirm"
    echo ""

    if gum confirm "Edit safety settings?"; then
        backup=$(gum choose "true" "false" --header="Backup Before Cleanup" --selected="$backup")
        confirm=$(gum choose "true" "false" --header="Confirm Dangerous Operations" --selected="$confirm")

        update_user_config_key "safety.backup_before_cleanup" "$backup"
        update_user_config_key "safety.confirm_dangerous_operations" "$confirm"

        gum style --foreground=10 "✓ Safety settings updated"
    fi
}

edit_notification_settings() {
    gum style --foreground=212 --border=double --padding="1 2" --margin=1 \
        "Notification Settings"

    local enabled=$(get_user_config 'notifications.enabled')
    local desktop=$(get_user_config 'notifications.desktop_notifications')
    local email=$(get_user_config 'notifications.email_notifications')
    local sound=$(get_user_config 'notifications.completion_sound')

    echo ""
    echo "Current Notification Settings:"
    echo "Enabled: $enabled"
    echo "Desktop Notifications: $desktop"
    echo "Email Notifications: $email"
    echo "Completion Sound: $sound"
    echo ""

    if gum confirm "Edit notification settings?"; then
        enabled=$(gum choose "true" "false" --header="Notifications Enabled" --selected="$enabled")
        desktop=$(gum choose "true" "false" --header="Desktop Notifications" --selected="$desktop")
        email=$(gum choose "true" "false" --header="Email Notifications" --selected="$email")
        sound=$(gum choose "true" "false" --header="Completion Sound" --selected="$sound")

        update_user_config_key "notifications.enabled" "$enabled"
        update_user_config_key "notifications.desktop_notifications" "$desktop"
        update_user_config_key "notifications.email_notifications" "$email"
        update_user_config_key "notifications.completion_sound" "$sound"

        gum style --foreground=10 "✓ Notification settings updated"
    fi
}

edit_performance_settings() {
    gum style --foreground=212 --border=double --padding="1 2" --margin=1 \
        "Performance Settings"

    local jobs=$(get_user_config 'performance.parallel_jobs')
    local memory=$(get_user_config 'performance.max_memory_usage')
    local nice=$(get_user_config 'performance.nice_level')
    local io=$(get_user_config 'performance.io_priority')

    echo ""
    echo "Current Performance Settings:"
    echo "Parallel Jobs: $jobs"
    echo "Max Memory Usage: $memory"
    echo "Nice Level: $nice"
    echo "I/O Priority: $io"
    echo ""

    if gum confirm "Edit performance settings?"; then
        jobs=$(gum input --value="$jobs" --placeholder="Number of parallel jobs")
        memory=$(gum input --value="$memory" --placeholder="Max memory usage (e.g., 1G, 512M)")
        nice=$(gum input --value="$nice" --placeholder="Nice level (-20 to 19)")
        io=$(gum input --value="$io" --placeholder="I/O priority (0-7)")

        update_user_config_key "performance.parallel_jobs" "$jobs"
        update_user_config_key "performance.max_memory_usage" "$memory"
        update_user_config_key "performance.nice_level" "$nice"
        update_user_config_key "performance.io_priority" "$io"

        gum style --foreground=10 "✓ Performance settings updated"
    fi
}

switch_theme_interactive() {
    local themes=()
    local theme_files=()

    # Get available themes
    for theme_file in "${FUB_THEMES_DIR}"/*.yaml "${FUB_USER_THEMES_DIR}"/*.yaml; do
        if [[ -f "$theme_file" ]]; then
            local theme_name=$(basename "$theme_file" .yaml)
            themes+=("$theme_name")
            theme_files+=("$theme_file")
        fi
    done

    if [[ ${#themes[@]} -eq 0 ]]; then
        gum style --foreground=208 "No themes found"
        return 1
    fi

    local current_theme=$(get_user_config 'theme.name')
    local selected_theme
    selected_theme=$(gum choose "${themes[@]}" --header="Select theme" --selected="$current_theme")

    if [[ -n "$selected_theme" ]]; then
        set_theme "$selected_theme"
        gum style --foreground=10 "✓ Theme switched to: $selected_theme"
    fi
}

create_custom_theme_interactive() {
    local theme_name=$(gum input --placeholder="Enter theme name")
    local theme_description=$(gum input --placeholder="Enter theme description")
    local base_theme="tokyo-night"

    if [[ -n "$theme_name" && -n "$theme_description" ]]; then
        create_theme "$theme_name" "$theme_description" "$base_theme"
        gum style --foreground=10 "✓ Theme created: $theme_name"
    fi
}

customize_theme_interactive() {
    local current_theme=$(get_user_config 'theme.name')
    local theme_file="${FUB_USER_THEMES_DIR}/${current_theme}.yaml"

    if [[ ! -f "$theme_file" ]]; then
        gum style --foreground=208 "Cannot customize system theme. Create a user theme first."
        return 1
    fi

    local color_key=$(gum input --placeholder="Enter color key to customize (e.g., background, success)")
    local color_value=$(gum input --placeholder="Enter color value (e.g., #1a1b26)")

    if [[ -n "$color_key" && -n "$color_value" ]]; then
        customize_theme "$current_theme" "$color_key" "$color_value"
        gum style --foreground=10 "✓ Theme color updated: $color_key = $color_value"
    fi
}

delete_theme_interactive() {
    local themes=()

    # Get user themes only
    for theme_file in "${FUB_USER_THEMES_DIR}"/*.yaml; do
        if [[ -f "$theme_file" ]]; then
            local theme_name=$(basename "$theme_file" .yaml)
            themes+=("$theme_name")
        fi
    done

    if [[ ${#themes[@]} -eq 0 ]]; then
        gum style --foreground=208 "No user themes found"
        return 1
    fi

    local selected_theme
    selected_theme=$(gum choose "${themes[@]}" --header="Select theme to delete")

    if [[ -n "$selected_theme" ]]; then
        if gum confirm "Delete theme '$selected_theme'?"; then
            delete_theme "$selected_theme"
            gum style --foreground=10 "✓ Theme deleted: $selected_theme"
        fi
    fi
}

show_theme_preview_interactive() {
    local themes=()
    local theme_files=()

    # Get available themes
    for theme_file in "${FUB_THEMES_DIR}"/*.yaml "${FUB_USER_THEMES_DIR}"/*.yaml; do
        if [[ -f "$theme_file" ]]; then
            local theme_name=$(basename "$theme_file" .yaml)
            themes+=("$theme_name")
            theme_files+=("$theme_file")
        fi
    done

    if [[ ${#themes[@]} -eq 0 ]]; then
        gum style --foreground=208 "No themes found"
        return 1
    fi

    local selected_theme
    selected_theme=$(gum choose "${themes[@]}" --header="Select theme to preview")

    if [[ -n "$selected_theme" ]]; then
        local output_file="$HOME/Downloads/fub-theme-preview-${selected_theme}.md"
        generate_theme_preview "$selected_theme" "$output_file"
        gum style --foreground=10 "✓ Theme preview generated: $output_file"
    fi
}

switch_profile_interactive() {
    local profiles=()
    local profile_files=()

    # Get available profiles
    for profile_file in "${FUB_CONFIG_DIR}/profiles"/*.yaml "${FUB_USER_PROFILES_DIR}"/*.yaml; do
        if [[ -f "$profile_file" ]]; then
            local profile_name=$(basename "$profile_file" .yaml)
            profiles+=("$profile_name")
            profile_files+=("$profile_file")
        fi
    done

    if [[ ${#profiles[@]} -eq 0 ]]; then
        gum style --foreground=208 "No profiles found"
        return 1
    fi

    local current_profile=$(get_current_profile)
    local selected_profile
    selected_profile=$(gum choose "${profiles[@]}" --header="Select profile" --selected="$current_profile")

    if [[ -n "$selected_profile" ]]; then
        set_current_profile "$selected_profile"
        gum style --foreground=10 "✓ Profile switched to: $selected_profile"
    fi
}

create_custom_profile_interactive() {
    local profile_name=$(gum input --placeholder="Enter profile name")
    local profile_description=$(gum input --placeholder="Enter profile description")
    local base_profile="desktop"

    if [[ -n "$profile_name" && -n "$profile_description" ]]; then
        create_profile "$profile_name" "$profile_description" "$base_profile"
        gum style --foreground=10 "✓ Profile created: $profile_name"
    fi
}

edit_profile_interactive() {
    local profiles=()

    # Get user profiles only
    for profile_file in "${FUB_USER_PROFILES_DIR}"/*.yaml; do
        if [[ -f "$profile_file" ]]; then
            local profile_name=$(basename "$profile_file" .yaml)
            profiles+=("$profile_name")
        fi
    done

    if [[ ${#profiles[@]} -eq 0 ]]; then
        gum style --foreground=208 "No user profiles found"
        return 1
    fi

    local selected_profile
    selected_profile=$(gum choose "${profiles[@]}" --header="Select profile to edit")

    if [[ -n "$selected_profile" ]]; then
        local profile_file="${FUB_USER_PROFILES_DIR}/${selected_profile}.yaml"
        gum style --foreground=212 "Opening profile for editing: $profile_file"

        # Open in default editor
        ${EDITOR:-nano} "$profile_file"

        gum style --foreground=10 "✓ Profile updated: $selected_profile"
    fi
}

delete_profile_interactive() {
    local profiles=()

    # Get user profiles only
    for profile_file in "${FUB_USER_PROFILES_DIR}"/*.yaml; do
        if [[ -f "$profile_file" ]]; then
            local profile_name=$(basename "$profile_file" .yaml)
            profiles+=("$profile_name")
        fi
    done

    if [[ ${#profiles[@]} -eq 0 ]]; then
        gum style --foreground=208 "No user profiles found"
        return 1
    fi

    local selected_profile
    selected_profile=$(gum choose "${profiles[@]}" --header="Select profile to delete")

    if [[ -n "$selected_profile" ]]; then
        if gum confirm "Delete profile '$selected_profile'?"; then
            delete_profile "$selected_profile"
            gum style --foreground=10 "✓ Profile deleted: $selected_profile"
        fi
    fi
}

show_profile_status_interactive() {
    gum style --foreground=212 --border=double --padding="1 2" --margin=1 \
        "Profile Status"

    echo ""
    echo "Current Profile: $(get_current_profile)"
    echo "System Profiles Directory: $FUB_CONFIG_DIR/profiles"
    echo "User Profiles Directory: $FUB_USER_PROFILES_DIR"
    echo ""

    local system_profiles=$(find "${FUB_CONFIG_DIR}/profiles" -name "*.yaml" -type f 2>/dev/null | wc -l)
    local user_profiles=$(find "${FUB_USER_PROFILES_DIR}" -name "*.yaml" -type f 2>/dev/null | wc -l)

    echo "Available Profiles:"
    echo "  System: $system_profiles"
    echo "  User: $user_profiles"
    echo ""
}

validate_all_configs_interactive() {
    local strict=$(gum choose "false" "true" --header="Use strict validation?" --selected="false")

    gum style --foreground=212 --border=double --padding="1 2" --margin=1 \
        "Validating All Configuration Files"

    echo ""

    if validate_all_configs "$strict"; then
        gum style --foreground=10 "✓ All configuration files are valid"
    else
        gum style --foreground=208 "✗ Configuration validation failed"
    fi

    echo ""
    gum confirm "Continue?" && return 0 || return 1
}

validate_system_config_interactive() {
    local config_file="${FUB_CONFIG_DIR}/default.yaml"
    local schema_file="${FUB_SCHEMA_DIR}/config-schema.yaml"
    local strict=$(gum choose "false" "true" --header="Use strict validation?" --selected="false")

    if validate_config_file "$config_file" "$schema_file" "$strict"; then
        gum style --foreground=10 "✓ System configuration is valid"
    else
        gum style --foreground=208 "✗ System configuration validation failed"
    fi
}

validate_user_config_interactive() {
    if [[ ! -f "$FUB_USER_CONFIG_FILE" ]]; then
        gum style --foreground=208 "No user configuration file found"
        return 1
    fi

    local schema_file="${FUB_SCHEMA_DIR}/config-schema.yaml"
    local strict=$(gum choose "false" "true" --header="Use strict validation?" --selected="false")

    if validate_config_file "$FUB_USER_CONFIG_FILE" "$schema_file" "$strict"; then
        gum style --foreground=10 "✓ User configuration is valid"
    else
        gum style --foreground=208 "✗ User configuration validation failed"
    fi
}

validate_profile_interactive() {
    local current_profile=$(get_current_profile)
    local profile_file="${FUB_CONFIG_DIR}/profiles/${current_profile}.yaml"

    if [[ ! -f "$profile_file" ]]; then
        profile_file="${FUB_USER_PROFILES_DIR}/${current_profile}.yaml"
    fi

    if [[ ! -f "$profile_file" ]]; then
        gum style --foreground=208 "Profile file not found: $current_profile"
        return 1
    fi

    local schema_file="${FUB_SCHEMA_DIR}/profile-schema.yaml"
    local strict=$(gum choose "false" "true" --header="Use strict validation?" --selected="false")

    if validate_config_file "$profile_file" "$schema_file" "$strict"; then
        gum style --foreground=10 "✓ Profile '$current_profile' is valid"
    else
        gum style --foreground=208 "✗ Profile '$current_profile' validation failed"
    fi
}

validate_theme_interactive() {
    local current_theme=$(get_user_config 'theme.name')
    local theme_file="${FUB_THEMES_DIR}/${current_theme}.yaml"

    if [[ ! -f "$theme_file" ]]; then
        theme_file="${FUB_USER_THEMES_DIR}/${current_theme}.yaml"
    fi

    if [[ ! -f "$theme_file" ]]; then
        gum style --foreground=208 "Theme file not found: $current_theme"
        return 1
    fi

    local schema_file="${FUB_SCHEMA_DIR}/theme-schema.yaml"
    local strict=$(gum choose "false" "true" --header="Use strict validation?" --selected="false")

    if validate_config_file "$theme_file" "$schema_file" "$strict"; then
        gum style --foreground=10 "✓ Theme '$current_theme' is valid"
    else
        gum style --foreground=208 "✗ Theme '$current_theme' validation failed"
    fi
}

auto_fix_config_interactive() {
    local config_files=(
        "${FUB_CONFIG_DIR}/default.yaml"
        "$FUB_USER_CONFIG_FILE"
    )

    local selected_file
    selected_file=$(gum choose "${config_files[@]}" --header="Select configuration file to auto-fix")

    if [[ -n "$selected_file" && -f "$selected_file" ]]; then
        if auto_fix_config "$selected_file"; then
            gum style --foreground=10 "✓ Configuration auto-fixed: $selected_file"
        else
            gum style --foreground=208 "✗ No auto-fixable issues found in: $selected_file"
        fi
    fi
}

export_configuration_interactive() {
    local output_file
    output_file=$(gum file --file="$HOME/Downloads/fub-config-export.yaml")

    if [[ -n "$output_file" ]]; then
        local include_profiles=$(gum choose "false" "true" --header="Include custom profiles?" --selected="false")
        export_user_config "$output_file" "$include_profiles"
        gum style --foreground=10 "✓ User configuration exported to: $output_file"
    fi
}

import_configuration_interactive() {
    local input_file
    input_file=$(gum file --directory="$HOME/Downloads")

    if [[ -n "$input_file" ]]; then
        local replace_existing=$(gum choose "false" "true" --header="Replace existing configuration?" --selected="false")
        import_user_config "$input_file" "$replace_existing"
        gum style --foreground=10 "✓ User configuration imported from: $input_file"
    fi
}

export_theme_interactive() {
    local themes=()

    # Get available themes
    for theme_file in "${FUB_THEMES_DIR}"/*.yaml "${FUB_USER_THEMES_DIR}"/*.yaml; do
        if [[ -f "$theme_file" ]]; then
            local theme_name=$(basename "$theme_file" .yaml)
            themes+=("$theme_name")
        fi
    done

    if [[ ${#themes[@]} -eq 0 ]]; then
        gum style --foreground=208 "No themes found"
        return 1
    fi

    local selected_theme
    selected_theme=$(gum choose "${themes[@]}" --header="Select theme to export")

    if [[ -n "$selected_theme" ]]; then
        local output_file="$HOME/Downloads/fub-theme-${selected_theme}.yaml"
        export_theme "$selected_theme" "$output_file"
        gum style --foreground=10 "✓ Theme exported to: $output_file"
    fi
}

import_theme_interactive() {
    local input_file
    input_file=$(gum file --directory="$HOME/Downloads")

    if [[ -n "$input_file" ]]; then
        local theme_name
        theme_name=$(gum input --placeholder="Enter theme name (leave empty to auto-detect)")

        import_theme "$input_file" "$theme_name"
        gum style --foreground=10 "✓ Theme imported from: $input_file"
    fi
}

export_profile_interactive() {
    local profiles=()

    # Get available profiles
    for profile_file in "${FUB_CONFIG_DIR}/profiles"/*.yaml "${FUB_USER_PROFILES_DIR}"/*.yaml; do
        if [[ -f "$profile_file" ]]; then
            local profile_name=$(basename "$profile_file" .yaml)
            profiles+=("$profile_name")
        fi
    done

    if [[ ${#profiles[@]} -eq 0 ]]; then
        gum style --foreground=208 "No profiles found"
        return 1
    fi

    local selected_profile
    selected_profile=$(gum choose "${profiles[@]}" --header="Select profile to export")

    if [[ -n "$selected_profile" ]]; then
        local output_file="$HOME/Downloads/fub-profile-${selected_profile}.yaml"

        # Find the profile file
        local profile_file="${FUB_CONFIG_DIR}/profiles/${selected_profile}.yaml"
        if [[ ! -f "$profile_file" ]]; then
            profile_file="${FUB_USER_PROFILES_DIR}/${selected_profile}.yaml"
        fi

        if [[ -f "$profile_file" ]]; then
            cp "$profile_file" "$output_file"
            gum style --foreground=10 "✓ Profile exported to: $output_file"
        fi
    fi
}

import_profile_interactive() {
    local input_file
    input_file=$(gum file --directory="$HOME/Downloads")

    if [[ -n "$input_file" ]]; then
        local profile_name
        profile_name=$(gum input --placeholder="Enter profile name (leave empty to auto-detect)")

        if [[ -z "$profile_name" ]]; then
            profile_name=$(basename "$input_file" .yaml)
        fi

        local output_file="${FUB_USER_PROFILES_DIR}/${profile_name}.yaml"

        if [[ -f "$output_file" ]]; then
            if ! gum confirm "Profile '$profile_name' already exists. Overwrite?"; then
                return 1
            fi
        fi

        ensure_dir "$FUB_USER_PROFILES_DIR"
        cp "$input_file" "$output_file"
        gum style --foreground=10 "✓ Profile imported: $profile_name"
    fi
}

restore_backup_interactive() {
    local backup_files=()

    # Get available backup files
    for backup_file in "${FUB_USER_BACKUP_DIR}"/*.tar.gz; do
        if [[ -f "$backup_file" ]]; then
            backup_files+=("$backup_file")
        fi
    done

    if [[ ${#backup_files[@]} -eq 0 ]]; then
        gum style --foreground=208 "No configuration backups found"
        return 1
    fi

    local selected_backup
    selected_backup=$(gum choose "${backup_files[@]}" --header="Select backup to restore")

    if [[ -n "$selected_backup" ]]; then
        if gum confirm "Restore configuration from backup? This will replace current settings."; then
            restore_user_config "$selected_backup"
            gum style --foreground=10 "✓ Configuration restored from: $selected_backup"
        fi
    fi
}

# Export functions for use in other modules
export -f init_config_ui show_config_menu
export -f show_system_config_menu show_user_config_menu show_theme_menu
export -f show_profile_menu show_validation_menu show_import_export_menu

# Initialize configuration UI if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_config_ui
    show_config_menu
fi