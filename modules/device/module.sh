#!/bin/bash

# KernelX Device Module
# Advanced device detection, management, and compatibility

source "$SCRIPT_DIR/core/base_module.sh"

# Module metadata
MODULE_NAME="device"
MODULE_VERSION="2.0.0"
MODULE_DESCRIPTION="Advanced device detection, management, and compatibility checking"
MODULE_AUTHOR="@ImKKingshuk"

# Device module variables
DEVICE_CACHE_FILE="$TEMP_DIR/device_cache.json"
DEVICE_COMPATIBILITY_DB="$SCRIPT_DIR/modules/device/compatibility.db"
KNOWN_DEVICES_FILE="$SCRIPT_DIR/modules/device/known_devices.json"

# Known device database (simplified - in real implementation this would be more comprehensive)
read -r -d '' KNOWN_DEVICES_DB << 'EOF'
{
  "devices": {
    "Pixel": {
      "models": ["Pixel 5", "Pixel 5a", "Pixel 6", "Pixel 6a", "Pixel 6 Pro", "Pixel 7", "Pixel 7a", "Pixel 7 Pro", "Pixel 8", "Pixel 8 Pro"],
      "architecture": "arm64",
      "platform": "gs101",
      "kernel_version": "5.10+",
      "supported": true
    },
    "Samsung": {
      "models": ["Galaxy S21", "Galaxy S22", "Galaxy S23", "Galaxy Note 20", "Galaxy Note 21", "Galaxy A52", "Galaxy A53"],
      "architecture": "arm64",
      "platform": "exynos",
      "kernel_version": "5.4+",
      "supported": true
    },
    "OnePlus": {
      "models": ["OnePlus 9", "OnePlus 9 Pro", "OnePlus 10", "OnePlus 10 Pro", "OnePlus 11"],
      "architecture": "arm64",
      "platform": "qcom",
      "kernel_version": "5.4+",
      "supported": true
    },
    "Xiaomi": {
      "models": ["Mi 11", "Mi 12", "Mi 13", "Redmi K40", "Redmi K50", "Poco X3"],
      "architecture": "arm64",
      "platform": "qcom",
      "kernel_version": "4.19+",
      "supported": true
    }
  }
}
EOF

# Module custom initialization
module_custom_init() {
    # Create device cache file
    touch "$DEVICE_CACHE_FILE"

    # Initialize device database if not exists
    if [[ ! -f "$KNOWN_DEVICES_FILE" ]]; then
        echo "$KNOWN_DEVICES_DB" > "$KNOWN_DEVICES_FILE"
    fi

    # Check ADB availability
    if ! command -v adb &>/dev/null; then
        module_error "ADB not found. Please install Android SDK Platform Tools"
        MODULE_ENABLED=false
        return 1
    fi

    # Start ADB server if not running
    if ! adb devices &>/dev/null; then
        module_info_msg "Starting ADB server"
        adb start-server || module_warn "Failed to start ADB server"
    fi
}

# Detect connected device
module_device_detect() {
    module_info_msg "Detecting connected devices..."

    # Get list of connected devices
    local devices_output
    devices_output=$(adb devices 2>/dev/null | grep -v "List of devices" | grep -v "^$" | grep "device$")

    if [[ -z "$devices_output" ]]; then
        module_error "No devices connected or ADB not working"
        return 1
    fi

    # Parse device list
    local device_count=0
    local selected_device=""

    while IFS=$'\t' read -r device_id state; do
        if [[ "$state" == "device" ]]; then
            ((device_count++))
            module_info_msg "Found device: $device_id"

            if [[ $device_count -eq 1 ]]; then
                selected_device="$device_id"
            fi
        fi
    done <<< "$devices_output"

    if [[ $device_count -gt 1 ]]; then
        module_warn "Multiple devices connected. Using first device: $selected_device"
    elif [[ $device_count -eq 0 ]]; then
        module_error "No devices in 'device' state found"
        return 1
    fi

    # Cache device ID
    echo "$selected_device" > "$DEVICE_CACHE_FILE"

    # Get device information
    module_device_get_info "$selected_device"

    return 0
}

# Get device information
module_device_get_info() {
    local device_id="$1"

    if [[ -z "$device_id" ]]; then
        device_id=$(cat "$DEVICE_CACHE_FILE" 2>/dev/null)
        if [[ -z "$device_id" ]]; then
            module_error "No device ID provided and none cached"
            return 1
        fi
    fi

    module_info_msg "Getting device information for: $device_id"

    # Get basic device properties
    local device_props
    device_props=$(adb -s "$device_id" shell getprop 2>/dev/null)

    if [[ $? -ne 0 || -z "$device_props" ]]; then
        module_error "Failed to get device properties"
        return 1
    fi

    # Extract key information
    local model=$(echo "$device_props" | grep "ro.product.model" | cut -d'[' -f3 | cut -d']' -f1 | tr -d '[]')
    local brand=$(echo "$device_props" | grep "ro.product.brand" | cut -d'[' -f3 | cut -d']' -f1 | tr -d '[]')
    local device=$(echo "$device_props" | grep "ro.product.device" | cut -d'[' -f3 | cut -d']' -f1 | tr -d '[]')
    local android_version=$(echo "$device_props" | grep "ro.build.version.release" | cut -d'[' -f3 | cut -d']' -f1 | tr -d '[]')
    local api_level=$(echo "$device_props" | grep "ro.build.version.sdk" | cut -d'[' -f3 | cut -d']' -f1 | tr -d '[]')
    local architecture=$(echo "$device_props" | grep "ro.product.cpu.abi" | cut -d'[' -f3 | cut -d']' -f1 | tr -d '[]')
    local kernel_version=$(adb -s "$device_id" shell uname -r 2>/dev/null | tr -d '\r')

    # Set global device information
    CURRENT_DEVICE="$device_id"
    core_set_config DEVICE_ID "$device_id"
    core_set_config DEVICE_MODEL "$model"
    core_set_config DEVICE_BRAND "$brand"
    core_set_config DEVICE_CODE "$device"
    core_set_config DEVICE_ANDROID_VERSION "$android_version"
    core_set_config DEVICE_API_LEVEL "$api_level"
    core_set_config DEVICE_ARCH "$architecture"
    core_set_config DEVICE_KERNEL_VERSION "$kernel_version"

    # Try to identify device from known devices
    module_device_identify "$brand" "$model"

    return 0
}

# Identify device from known devices database
module_device_identify() {
    local brand="$1"
    local model="$2"

    if [[ ! -f "$KNOWN_DEVICES_FILE" ]]; then
        module_warn "Device database not found"
        return 1
    fi

    # Simple identification logic
    local device_key=""
    case "$brand" in
        "google")
            device_key="Pixel"
            ;;
        "samsung"|"Samsung")
            device_key="Samsung"
            ;;
        "OnePlus")
            device_key="OnePlus"
            ;;
        "Xiaomi")
            device_key="Xiaomi"
            ;;
        *)
            module_info_msg "Unknown device brand: $brand"
            return 0
            ;;
    esac

    # Check if model is in known devices
    if command -v jq &>/dev/null; then
        local models
        models=$(jq -r ".devices.\"$device_key\".models[] // empty" "$KNOWN_DEVICES_FILE" 2>/dev/null)

        if [[ -n "$models" ]]; then
            while read -r known_model; do
                if [[ "$model" == *"$known_model"* ]]; then
                    module_info_msg "Identified device: $known_model ($device_key)"
                    core_set_config DEVICE_FAMILY "$device_key"
                    core_set_config DEVICE_IDENTIFIED "true"

                    # Load device-specific config if exists
                    local device_config_file="$CONFIG_DEVICES_DIR/${device_key,,}.config"
                    if [[ -f "$device_config_file" ]]; then
                        core_load_config "$device_config_file"
                        module_info_msg "Loaded device config: $device_config_file"
                    fi
                    return 0
                fi
            done <<< "$models"
        fi
    fi

    module_info_msg "Device not in known database: $brand $model"
    return 0
}

# Check device compatibility
module_device_check_compatibility() {
    local device_family=$(core_get_config DEVICE_FAMILY)
    local kernel_version=$(core_get_config DEVICE_KERNEL_VERSION)
    local arch=$(core_get_config DEVICE_ARCH)

    module_info_msg "Checking device compatibility..."

    # Basic compatibility checks
    local compatible=true
    local issues=()

    # Architecture check
    if [[ "$arch" != "arm64-v8a" && "$arch" != "armeabi-v7a" ]]; then
        issues+=("Unknown architecture: $arch")
        compatible=false
    fi

    # Android version check
    local android_version=$(core_get_config DEVICE_ANDROID_VERSION)
    if [[ -n "$android_version" ]]; then
        local major_version=$(echo "$android_version" | cut -d. -f1)
        if [[ $major_version -lt 8 ]]; then
            issues+=("Android version $android_version may not be supported")
            compatible=false
        fi
    fi

    # Kernel version check (basic)
    if [[ -n "$kernel_version" ]]; then
        local major_kernel=$(echo "$kernel_version" | cut -d. -f1)
        if [[ $major_kernel -lt 4 ]]; then
            issues+=("Kernel version $kernel_version is too old")
            compatible=false
        fi
    fi

    # Report results
    if [[ "$compatible" == "true" ]]; then
        core_success "Device appears compatible"
        core_set_config DEVICE_COMPATIBLE "true"
    else
        core_warn "Device compatibility issues found:"
        for issue in "${issues[@]}"; do
            echo "  ⚠️  $issue"
        done
        core_set_config DEVICE_COMPATIBLE "false"
    fi

    return 0
}

# Show device information
module_device_info() {
    if [[ -z "$CURRENT_DEVICE" ]]; then
        if ! module_device_detect; then
            return 1
        fi
    fi

    echo
    echo "╔══════════════════════════════════════════════╗"
    echo "║              Device Information             ║"
    echo "╚══════════════════════════════════════════════╝"
    echo

    echo "📱 Basic Information:"
    echo "────────────────────"
    printf "%-20s : %s\n" "Device ID" "$(core_get_config DEVICE_ID)"
    printf "%-20s : %s\n" "Model" "$(core_get_config DEVICE_MODEL)"
    printf "%-20s : %s\n" "Brand" "$(core_get_config DEVICE_BRAND)"
    printf "%-20s : %s\n" "Device Code" "$(core_get_config DEVICE_CODE)"
    printf "%-20s : %s\n" "Android Version" "$(core_get_config DEVICE_ANDROID_VERSION)"
    printf "%-20s : %s\n" "API Level" "$(core_get_config DEVICE_API_LEVEL)"

    echo
    echo "🔧 Technical Details:"
    echo "─────────────────────"
    printf "%-20s : %s\n" "Architecture" "$(core_get_config DEVICE_ARCH)"
    printf "%-20s : %s\n" "Kernel Version" "$(core_get_config DEVICE_KERNEL_VERSION)"
    printf "%-20s : %s\n" "Device Family" "$(core_get_config DEVICE_FAMILY)"
    printf "%-20s : %s\n" "Identified" "$(core_get_config DEVICE_IDENTIFIED "false")"

    echo
    echo "✅ Compatibility Status:"
    echo "────────────────────────"

    # Run compatibility check if not already done
    if [[ -z "$(core_get_config DEVICE_COMPATIBLE)" ]]; then
        module_device_check_compatibility
    fi

    local compatible=$(core_get_config DEVICE_COMPATIBLE)
    if [[ "$compatible" == "true" ]]; then
        echo "✓ Device appears compatible with KernelX"
    else
        echo "⚠️  Device may have compatibility issues"
    fi

    echo
}

# List all connected devices
module_device_list() {
    module_info_msg "Listing all connected devices..."

    local devices_output
    devices_output=$(adb devices 2>/dev/null)

    echo
    echo "Connected Devices:"
    echo "=================="

    local has_devices=false
    while IFS=$'\t' read -r device_id state; do
        if [[ "$device_id" != "List of devices attached" && -n "$device_id" ]]; then
            has_devices=true
            printf "%-25s : %s\n" "$device_id" "$state"

            # Show device info if device is connected
            if [[ "$state" == "device" ]]; then
                local model=$(adb -s "$device_id" shell getprop ro.product.model 2>/dev/null | tr -d '\r\n')
                local brand=$(adb -s "$device_id" shell getprop ro.product.brand 2>/dev/null | tr -d '\r\n')
                if [[ -n "$model" ]]; then
                    printf "%-25s : %s %s\n" "" "$brand" "$model"
                fi
            fi
            echo
        fi
    done <<< "$devices_output"

    if [[ "$has_devices" == "false" ]]; then
        echo "No devices connected"
        echo
        echo "Troubleshooting:"
        echo "- Make sure USB debugging is enabled on your device"
        echo "- Accept the RSA key prompt on your device"
        echo "- Try restarting ADB: adb kill-server && adb start-server"
    fi

    echo
}

# Create device-specific configuration
module_device_create_config() {
    local device_family="$1"

    if [[ -z "$device_family" ]]; then
        module_error "Device family not specified"
        return 1
    fi

    local config_file="$CONFIG_DEVICES_DIR/${device_family,,}.config"

    module_info_msg "Creating device config for: $device_family"

    # Create basic device configuration
    cat > "$config_file" << EOF
# Device Configuration for $device_family
# Generated on: $(date)

# Device-specific settings
DEVICE_FAMILY=$device_family
DEVICE_SUPPORTED=true

# Architecture-specific settings
BUILD_ARCH=arm64
BUILD_CROSS_COMPILE=aarch64-linux-gnu-

# Device-specific patches directory
PATCH_DIR=patches/$device_family

# Kernel defconfig (customize as needed)
ADVANCED_CUSTOM_DEFCONFIG=${device_family,,}_defconfig
EOF

    core_success "Device configuration created: $config_file"
}

# Push file to device
module_device_push() {
    local local_file="$1"
    local remote_path="$2"
    local device_id="${3:-$CURRENT_DEVICE}"

    if [[ -z "$device_id" ]]; then
        module_error "No device specified"
        return 1
    fi

    module_info_msg "Pushing $local_file to device:$remote_path"

    if [[ "$DRY_RUN" == "true" ]]; then
        module_info_msg "DRY RUN: Would push $local_file to $remote_path"
        return 0
    fi

    if adb -s "$device_id" push "$local_file" "$remote_path"; then
        core_success "File pushed successfully"
        return 0
    else
        module_error "Failed to push file"
        return 1
    fi
}

# Pull file from device
module_device_pull() {
    local remote_path="$1"
    local local_file="$2"
    local device_id="${3:-$CURRENT_DEVICE}"

    if [[ -z "$device_id" ]]; then
        module_error "No device specified"
        return 1
    fi

    module_info_msg "Pulling $remote_path from device to $local_file"

    if [[ "$DRY_RUN" == "true" ]]; then
        module_info_msg "DRY RUN: Would pull $remote_path to $local_file"
        return 0
    fi

    if adb -s "$device_id" pull "$remote_path" "$local_file"; then
        core_success "File pulled successfully"
        return 0
    else
        module_error "Failed to pull file"
        return 1
    fi
}

# Execute command on device
module_device_shell() {
    local command="$1"
    local device_id="${2:-$CURRENT_DEVICE}"

    if [[ -z "$device_id" ]]; then
        module_error "No device specified"
        return 1
    fi

    module_info_msg "Executing on device: $command"

    if [[ "$DRY_RUN" == "true" ]]; then
        module_info_msg "DRY RUN: Would execute '$command'"
        return 0
    fi

    adb -s "$device_id" shell "$command"
}

# Export module functions
export -f module_device_detect
export -f module_device_get_info
export -f module_device_identify
export -f module_device_check_compatibility
export -f module_device_info
export -f module_device_list
export -f module_device_create_config
export -f module_device_push
export -f module_device_pull
export -f module_device_shell
