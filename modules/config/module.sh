#!/bin/bash

# KernelX Config Module
# Advanced configuration management with profiles and validation

source "$SCRIPT_DIR/core/base_module.sh"

# Module metadata
MODULE_NAME="config"
MODULE_VERSION="2.0.0"
MODULE_DESCRIPTION="Advanced configuration management with profiles, presets, and validation"
MODULE_AUTHOR="@ImKKingshuk"

# Config module variables
CONFIG_PROFILES_DIR="$CONFIG_DIR/profiles"
CONFIG_DEVICES_DIR="$CONFIG_DIR/devices"
CONFIG_PRESETS_DIR="$CONFIG_DIR/presets"

# Default configuration template
read -r -d '' DEFAULT_CONFIG_TEMPLATE << 'EOF'
# KernelX Default Configuration
# Generated on: $(date)

# Kernel Settings
KERNEL_NAME=KernelX
KERNEL_VERSION=2.0.0
KERNEL_SOURCE_URL=
KERNEL_BRANCH=main

# Build Settings
BUILD_ARCH=arm64
BUILD_CROSS_COMPILE=aarch64-linux-gnu-
BUILD_JOBS=$(nproc)
BUILD_OUTPUT_DIR=output
BUILD_TOOLCHAIN_PATH=

# Device Settings
DEVICE_NAME=generic
DEVICE_ARCH=arm64
DEVICE_PLATFORM=generic

# Ramdisk Settings
RAMDISK_PATH=
RAMDISK_COMPRESSION=gzip
RAMDISK_FORMAT=cpio

# Patch Settings
PATCH_DIR=patches
PATCH_FORMAT=diff
PATCH_BACKUP_ORIG=true

# Safety Settings
SAFETY_BACKUP_BEFORE_PATCH=true
SAFETY_VERIFY_BUILD=true
SAFETY_DRY_RUN_DEFAULT=false

# Logging Settings
LOG_LEVEL=INFO
LOG_FILE=kernelx.log
LOG_MAX_SIZE=10MB

# Advanced Settings
ADVANCED_CUSTOM_MAKEFILE=
ADVANCED_CUSTOM_DEFCONFIG=
ADVANCED_EXTRA_CFLAGS=
EOF

# Module custom initialization
module_custom_init() {
    # Create necessary directories
    mkdir -p "$CONFIG_PROFILES_DIR" "$CONFIG_DEVICES_DIR" "$CONFIG_PRESETS_DIR"

    # Create default config if it doesn't exist
    if [[ ! -f "$CONFIG_DIR/default.config" ]]; then
        module_info_msg "Creating default configuration"
        eval "echo \"$DEFAULT_CONFIG_TEMPLATE\"" > "$CONFIG_DIR/default.config"
    fi

    # Load all configurations
    module_config_load_all
}

# Load all configuration files
module_config_load_all() {
    # Load default config first
    if [[ -f "$CONFIG_DIR/default.config" ]]; then
        core_load_config "$CONFIG_DIR/default.config"
    fi

    # Load profile if specified
    if [[ -n "$KERNELX_PROFILE" ]]; then
        local profile_file="$CONFIG_PROFILES_DIR/$KERNELX_PROFILE.config"
        if [[ -f "$profile_file" ]]; then
            core_load_config "$profile_file"
            module_info_msg "Loaded profile: $KERNELX_PROFILE"
        else
            module_warn "Profile not found: $KERNELX_PROFILE"
        fi
    fi

    # Load device config if device is specified
    if [[ -n "$TARGET_DEVICE" ]]; then
        local device_file="$CONFIG_DEVICES_DIR/$TARGET_DEVICE.config"
        if [[ -f "$device_file" ]]; then
            core_load_config "$device_file"
            module_info_msg "Loaded device config: $TARGET_DEVICE"
        fi
    fi
}

# Interactive setup
module_config_setup() {
    echo
    echo "╔══════════════════════════════════════════════╗"
    echo "║         KernelX Configuration Setup         ║"
    echo "╚══════════════════════════════════════════════╝"
    echo

    # Kernel Settings
    echo "🛠️  Kernel Settings:"
    echo "────────────────────"
    read -p "Enter Kernel Name [$(core_get_config KERNEL_NAME)]: " input
    [[ -n "$input" ]] && core_set_config KERNEL_NAME "$input"

    read -p "Enter Kernel Version [$(core_get_config KERNEL_VERSION)]: " input
    [[ -n "$input" ]] && core_set_config KERNEL_VERSION "$input"

    read -p "Enter Kernel Source URL (optional): " input
    [[ -n "$input" ]] && core_set_config KERNEL_SOURCE_URL "$input"

    read -p "Enter Kernel Branch [$(core_get_config KERNEL_BRANCH)]: " input
    [[ -n "$input" ]] && core_set_config KERNEL_BRANCH "$input"

    echo

    # Build Settings
    echo "🔨 Build Settings:"
    echo "──────────────────"
    read -p "Enter Build Architecture [$(core_get_config BUILD_ARCH)]: " input
    [[ -n "$input" ]] && core_set_config BUILD_ARCH "$input"

    read -p "Enter Cross Compile Prefix [$(core_get_config BUILD_CROSS_COMPILE)]: " input
    [[ -n "$input" ]] && core_set_config BUILD_CROSS_COMPILE "$input"

    read -p "Enter Build Jobs [$(core_get_config BUILD_JOBS)]: " input
    [[ -n "$input" ]] && core_set_config BUILD_JOBS "$input"

    read -p "Enter Toolchain Path (optional): " input
    [[ -n "$input" ]] && core_set_config BUILD_TOOLCHAIN_PATH "$input"

    echo

    # Device Settings
    echo "📱 Device Settings:"
    echo "───────────────────"
    read -p "Enter Device Name [$(core_get_config DEVICE_NAME)]: " input
    [[ -n "$input" ]] && core_set_config DEVICE_NAME "$input"

    read -p "Enter Device Architecture [$(core_get_config DEVICE_ARCH)]: " input
    [[ -n "$input" ]] && core_set_config DEVICE_ARCH "$input"

    echo

    # Ramdisk Settings
    echo "💾 Ramdisk Settings:"
    echo "────────────────────"
    read -p "Enter Ramdisk Path (optional): " input
    [[ -n "$input" ]] && core_set_config RAMDISK_PATH "$input"

    read -p "Enter Ramdisk Compression [$(core_get_config RAMDISK_COMPRESSION)]: " input
    [[ -n "$input" ]] && core_set_config RAMDISK_COMPRESSION "$input"

    echo

    # Patch Settings
    echo "🩹 Patch Settings:"
    echo "──────────────────"
    read -p "Enter Patches Directory [$(core_get_config PATCH_DIR)]: " input
    [[ -n "$input" ]] && core_set_config PATCH_DIR "$input"

    echo

    # Safety Settings
    echo "🛡️  Safety Settings:"
    echo "────────────────────"
    read -p "Create backups before patching? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        core_set_config SAFETY_BACKUP_BEFORE_PATCH true
    else
        core_set_config SAFETY_BACKUP_BEFORE_PATCH false
    fi

    read -p "Verify builds after completion? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        core_set_config SAFETY_VERIFY_BUILD true
    else
        core_set_config SAFETY_VERIFY_BUILD false
    fi

    echo

    # Save configuration
    echo "💾 Saving Configuration:"
    echo "────────────────────────"

    # Ask if user wants to save as profile
    read -p "Save as profile? (enter profile name or leave empty): " profile_name
    if [[ -n "$profile_name" ]]; then
        module_config_save_profile "$profile_name"
    else
        # Save to default config
        module_config_save_default
    fi

    echo
    core_success "Configuration setup completed!"
    echo
}

# Save configuration as profile
module_config_save_profile() {
    local profile_name="$1"
    local profile_file="$CONFIG_PROFILES_DIR/${profile_name}.config"

    module_info_msg "Saving profile: $profile_name"

    {
        echo "# KernelX Profile: $profile_name"
        echo "# Generated on: $(date)"
        echo
        for key in "${!CONFIG_CACHE[@]}"; do
            echo "$key=${CONFIG_CACHE[$key]}"
        done
    } > "$profile_file"

    core_success "Profile saved: $profile_file"
}

# Save as default configuration
module_config_save_default() {
    module_info_msg "Saving default configuration"

    {
        echo "# KernelX Default Configuration"
        echo "# Generated on: $(date)"
        echo
        for key in "${!CONFIG_CACHE[@]}"; do
            echo "$key=${CONFIG_CACHE[$key]}"
        done
    } > "$CONFIG_DIR/default.config"

    core_success "Default configuration saved"
}

# List available profiles
module_config_list_profiles() {
    echo "Available Profiles:"
    echo "==================="

    if [[ -d "$CONFIG_PROFILES_DIR" ]]; then
        local count=0
        for profile_file in "$CONFIG_PROFILES_DIR"/*.config; do
            if [[ -f "$profile_file" ]]; then
                local profile_name=$(basename "$profile_file" .config)
                echo "• $profile_name"
                ((count++))
            fi
        done

        if [[ $count -eq 0 ]]; then
            echo "No profiles found. Create one with 'kernelx setup'"
        fi
    else
        echo "No profiles directory found"
    fi
    echo
}

# List available device configs
module_config_list_devices() {
    echo "Available Device Configurations:"
    echo "==============================="

    if [[ -d "$CONFIG_DEVICES_DIR" ]]; then
        local count=0
        for device_file in "$CONFIG_DEVICES_DIR"/*.config; do
            if [[ -f "$device_file" ]]; then
                local device_name=$(basename "$device_file" .config)
                echo "• $device_name"
                ((count++))
            fi
        done

        if [[ $count -eq 0 ]]; then
            echo "No device configs found"
        fi
    else
        echo "No device configs directory found"
    fi
    echo
}

# Validate configuration
module_config_validate() {
    local errors=()
    local warnings=()

    # Required fields validation
    local required_fields=("KERNEL_NAME" "KERNEL_VERSION" "BUILD_ARCH")
    for field in "${required_fields[@]}"; do
        if [[ -z "$(core_get_config "$field")" ]]; then
            errors+=("Missing required field: $field")
        fi
    done

    # Path validation
    local path_fields=("RAMDISK_PATH" "PATCH_DIR" "BUILD_TOOLCHAIN_PATH")
    for field in "${path_fields[@]}"; do
        local path=$(core_get_config "$field")
        if [[ -n "$path" && ! -e "$path" ]]; then
            warnings+=("Path does not exist: $field=$path")
        fi
    done

    # Architecture validation
    local arch=$(core_get_config "BUILD_ARCH")
    case "$arch" in
        arm|arm64|x86|x86_64)
            ;;
        *)
            if [[ -n "$arch" ]]; then
                warnings+=("Unknown architecture: $arch")
            fi
            ;;
    esac

    # Report results
    if [[ ${#errors[@]} -gt 0 ]]; then
        module_error "Configuration validation failed:"
        for error in "${errors[@]}"; do
            echo "  ❌ $error"
        done
        return 1
    fi

    if [[ ${#warnings[@]} -gt 0 ]]; then
        module_warn "Configuration warnings:"
        for warning in "${warnings[@]}"; do
            echo "  ⚠️  $warning"
        done
    fi

    return 0
}

# Show current configuration
module_config_show() {
    echo "Current Configuration:"
    echo "======================"

    # Group configurations
    local groups=(
        "Kernel:KERNEL_NAME,KERNEL_VERSION,KERNEL_SOURCE_URL,KERNEL_BRANCH"
        "Build:BUILD_ARCH,BUILD_CROSS_COMPILE,BUILD_JOBS,BUILD_OUTPUT_DIR,BUILD_TOOLCHAIN_PATH"
        "Device:DEVICE_NAME,DEVICE_ARCH,DEVICE_PLATFORM"
        "Ramdisk:RAMDISK_PATH,RAMDISK_COMPRESSION,RAMDISK_FORMAT"
        "Patches:PATCH_DIR,PATCH_FORMAT,PATCH_BACKUP_ORIG"
        "Safety:SAFETY_BACKUP_BEFORE_PATCH,SAFETY_VERIFY_BUILD,SAFETY_DRY_RUN_DEFAULT"
        "Logging:LOG_LEVEL,LOG_FILE,LOG_MAX_SIZE"
    )

    for group_info in "${groups[@]}"; do
        local group_name=$(echo "$group_info" | cut -d: -f1)
        local group_keys=$(echo "$group_info" | cut -d: -f2)

        echo
        echo "$group_name Settings:"
        echo "$(printf '%.0s─' {1..20})"

        IFS=',' read -ra keys <<< "$group_keys"
        for key in "${keys[@]}"; do
            local value=$(core_get_config "$key")
            if [[ -z "$value" ]]; then
                value="(not set)"
            fi
            printf "%-25s : %s\n" "$key" "$value"
        done
    done

    echo
}

# Export module functions
export -f module_config_setup
export -f module_config_save_profile
export -f module_config_save_default
export -f module_config_load_all
export -f module_config_list_profiles
export -f module_config_list_devices
export -f module_config_validate
export -f module_config_show
