#!/bin/bash

# KernelX Utils Module
# Utility functions for backups, testing, cleanup, and diagnostics

source "$SCRIPT_DIR/core/base_module.sh"

# Module metadata
MODULE_NAME="utils"
MODULE_VERSION="2.0.0"
MODULE_DESCRIPTION="Utility functions for backups, testing, cleanup, and diagnostics"
MODULE_AUTHOR="@ImKKingshuk"

# Utils module variables
BACKUP_DIR="$TEMP_DIR/backups"
TEST_RESULTS_DIR="$TEMP_DIR/test_results"

# Module custom initialization
module_custom_init() {
    # Create necessary directories
    mkdir -p "$BACKUP_DIR" "$TEST_RESULTS_DIR"
}

# Backup all system components
module_utils_backup_all() {
    module_info_msg "Creating comprehensive system backup"

    local backup_name="kernelx_full_backup_$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"

    mkdir -p "$backup_path"

    # Backup configuration
    if [[ -d "$CONFIG_DIR" ]]; then
        cp -r "$CONFIG_DIR" "$backup_path/"
        module_info_msg "Configuration backed up"
    fi

    # Backup kernel sources if available
    local kernel_dir=$(core_get_config KERNEL_SOURCE_DIR)
    if [[ -n "$kernel_dir" && -d "$kernel_dir" ]]; then
        mkdir -p "$backup_path/kernel_source"
        cp -r "$kernel_dir" "$backup_path/kernel_source/"
        module_info_msg "Kernel source backed up"
    fi

    # Backup ramdisk if available
    local ramdisk_path=$(core_get_config RAMDISK_PATH)
    if [[ -n "$ramdisk_path" && -f "$ramdisk_path" ]]; then
        cp "$ramdisk_path" "$backup_path/"
        module_info_msg "Ramdisk backed up"
    fi

    # Backup patches
    local patch_dir=$(core_get_config PATCH_DIR)
    if [[ -n "$patch_dir" && -d "$patch_dir" ]]; then
        cp -r "$patch_dir" "$backup_path/"
        module_info_msg "Patches backed up"
    fi

    # Create backup manifest
    {
        echo "KernelX Full Backup Manifest"
        echo "============================"
        echo "Created: $(date)"
        echo "Backup Name: $backup_name"
        echo "KernelX Version: $KERNELX_VERSION"
        echo
        echo "Contents:"
        find "$backup_path" -type f | while read -r file; do
            echo "  ${file#$backup_path/}"
        done
    } > "$backup_path/manifest.txt"

    core_success "Full backup created: $backup_name"
    module_info_msg "Backup location: $backup_path"
}

# Restore from backup menu
module_utils_restore_menu() {
    echo "Available Backups:"
    echo "=================="

    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "No backups found"
        return 1
    fi

    local backups=()
    local i=1
    for backup in "$BACKUP_DIR"/*; do
        if [[ -d "$backup" ]]; then
            local backup_name=$(basename "$backup")
            local backup_date=$(stat -c %y "$backup" 2>/dev/null | cut -d. -f1 || echo "unknown")
            echo "$i. $backup_name (created: $backup_date)"
            backups+=("$backup")
            ((i++))
        fi
    done

    if [[ ${#backups[@]} -eq 0 ]]; then
        echo "No backups found"
        return 1
    fi

    echo
    read -p "Select backup to restore (1-${#backups[@]}): " choice

    if [[ $choice -lt 1 || $choice -gt ${#backups[@]} ]]; then
        module_error "Invalid choice"
        return 1
    fi

    local selected_backup="${backups[$((choice-1))]}"
    local backup_name=$(basename "$selected_backup")

    echo
    echo "Restore Options for $backup_name:"
    echo "================================="
    echo "1. Restore configuration only"
    echo "2. Restore kernel source only"
    echo "3. Restore ramdisk only"
    echo "4. Restore patches only"
    echo "5. Restore everything"
    echo "6. Cancel"
    echo

    read -p "Select restore option (1-6): " restore_choice

    case $restore_choice in
        1) module_utils_restore_config "$selected_backup" ;;
        2) module_utils_restore_kernel "$selected_backup" ;;
        3) module_utils_restore_ramdisk "$selected_backup" ;;
        4) module_utils_restore_patches "$selected_backup" ;;
        5) module_utils_restore_full "$selected_backup" ;;
        6) return 0 ;;
        *) echo "Invalid option" ;;
    esac
}

# Restore configuration
module_utils_restore_config() {
    local backup_path="$1"
    local config_backup="$backup_path/config"

    if [[ ! -d "$config_backup" ]]; then
        module_error "Configuration backup not found in: $backup_path"
        return 1
    fi

    module_info_msg "Restoring configuration from backup"

    if [[ "$DRY_RUN" == "true" ]]; then
        module_info_msg "DRY RUN: Would restore configuration"
        return 0
    fi

    cp -r "$config_backup"/* "$CONFIG_DIR/" 2>/dev/null || true
    core_success "Configuration restored"
}

# Restore kernel source
module_utils_restore_kernel() {
    local backup_path="$1"
    local kernel_backup="$backup_path/kernel_source"

    if [[ ! -d "$kernel_backup" ]]; then
        module_error "Kernel source backup not found in: $backup_path"
        return 1
    fi

    module_info_msg "Restoring kernel source from backup"

    if [[ "$DRY_RUN" == "true" ]]; then
        module_info_msg "DRY RUN: Would restore kernel source"
        return 0
    fi

    local kernel_dir=$(core_get_config KERNEL_SOURCE_DIR)
    if [[ -z "$kernel_dir" ]]; then
        read -p "Enter kernel source restore directory: " kernel_dir
    fi

    if [[ -z "$kernel_dir" ]]; then
        module_error "No kernel directory specified"
        return 1
    fi

    mkdir -p "$kernel_dir"
    cp -r "$kernel_backup"/* "$kernel_dir/" 2>/dev/null || true
    core_success "Kernel source restored to: $kernel_dir"
}

# Restore ramdisk
module_utils_restore_ramdisk() {
    local backup_path="$1"
    local ramdisk_file=$(find "$backup_path" -name "*.img" | head -1)

    if [[ -z "$ramdisk_file" ]]; then
        module_error "Ramdisk backup not found in: $backup_path"
        return 1
    fi

    module_info_msg "Restoring ramdisk from backup"

    if [[ "$DRY_RUN" == "true" ]]; then
        module_info_msg "DRY RUN: Would restore ramdisk"
        return 0
    fi

    local ramdisk_path=$(core_get_config RAMDISK_PATH)
    if [[ -z "$ramdisk_path" ]]; then
        read -p "Enter ramdisk restore path: " ramdisk_path
    fi

    if [[ -z "$ramdisk_path" ]]; then
        module_error "No ramdisk path specified"
        return 1
    fi

    cp "$ramdisk_file" "$ramdisk_path"
    core_success "Ramdisk restored to: $ramdisk_path"
}

# Restore patches
module_utils_restore_patches() {
    local backup_path="$1"
    local patches_backup="$backup_path/patches"

    if [[ ! -d "$patches_backup" ]]; then
        module_error "Patches backup not found in: $backup_path"
        return 1
    fi

    module_info_msg "Restoring patches from backup"

    if [[ "$DRY_RUN" == "true" ]]; then
        module_info_msg "DRY RUN: Would restore patches"
        return 0
    fi

    local patch_dir=$(core_get_config PATCH_DIR)
    if [[ -z "$patch_dir" ]]; then
        read -p "Enter patches restore directory: " patch_dir
    fi

    if [[ -z "$patch_dir" ]]; then
        module_error "No patches directory specified"
        return 1
    fi

    mkdir -p "$patch_dir"
    cp -r "$patches_backup"/* "$patch_dir/" 2>/dev/null || true
    core_success "Patches restored to: $patch_dir"
}

# Full restore
module_utils_restore_full() {
    local backup_path="$1"

    module_info_msg "Performing full system restore from: $(basename "$backup_path")"

    if [[ "$DRY_RUN" == "true" ]]; then
        module_info_msg "DRY RUN: Would perform full restore"
        return 0
    fi

    # Restore in order
    module_utils_restore_config "$backup_path"
    module_utils_restore_kernel "$backup_path"
    module_utils_restore_ramdisk "$backup_path"
    module_utils_restore_patches "$backup_path"

    core_success "Full system restore completed"
}

# Run tests
module_utils_run_tests() {
    module_info_msg "Running KernelX test suite"

    local test_results="$TEST_RESULTS_DIR/test_run_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$test_results"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    echo "KernelX Test Suite Results" > "$test_results/summary.txt"
    echo "=========================" >> "$test_results/summary.txt"
    echo "Test Run: $(date)" >> "$test_results/summary.txt"
    echo >> "$test_results/summary.txt"

    # Test 1: Core framework
    ((total_tests++))
    if module_utils_test_core; then
        ((passed_tests++))
        echo "✓ Core Framework Test" >> "$test_results/summary.txt"
    else
        ((failed_tests++))
        echo "✗ Core Framework Test" >> "$test_results/summary.txt"
    fi

    # Test 2: Configuration system
    ((total_tests++))
    if module_utils_test_config; then
        ((passed_tests++))
        echo "✓ Configuration System Test" >> "$test_results/summary.txt"
    else
        ((failed_tests++))
        echo "✗ Configuration System Test" >> "$test_results/summary.txt"
    fi

    # Test 3: Device detection (if device connected)
    ((total_tests++))
    if module_utils_test_device; then
        ((passed_tests++))
        echo "✓ Device Detection Test" >> "$test_results/summary.txt"
    else
        ((failed_tests++))
        echo "✗ Device Detection Test" >> "$test_results/summary.txt"
    fi

    # Test 4: Build system validation
    ((total_tests++))
    if module_utils_test_build; then
        ((passed_tests++))
        echo "✓ Build System Test" >> "$test_results/summary.txt"
    else
        ((failed_tests++))
        echo "✗ Build System Test" >> "$test_results/summary.txt"
    fi

    # Test 5: Module loading
    ((total_tests++))
    if module_utils_test_modules; then
        ((passed_tests++))
        echo "✓ Module Loading Test" >> "$test_results/summary.txt"
    else
        ((failed_tests++))
        echo "✗ Module Loading Test" >> "$test_results/summary.txt"
    fi

    # Summary
    {
        echo
        echo "Summary:"
        echo "  Total Tests: $total_tests"
        echo "  Passed: $passed_tests"
        echo "  Failed: $failed_tests"
        echo "  Success Rate: $((passed_tests * 100 / total_tests))%"
        echo
        echo "Test completed: $(date)"
    } >> "$test_results/summary.txt"

    # Display results
    echo
    cat "$test_results/summary.txt"

    if [[ $failed_tests -eq 0 ]]; then
        core_success "All tests passed!"
    else
        module_warn "$failed_tests test(s) failed. Check: $test_results"
    fi

    # Save detailed results
    echo "$total_tests $passed_tests $failed_tests" > "$test_results/results.txt"
}

# Test core framework
module_utils_test_core() {
    # Test logging functions
    core_log "DEBUG" "Test debug message" >/dev/null 2>&1
    core_log "INFO" "Test info message" >/dev/null 2>&1
    core_log "WARN" "Test warning message" >/dev/null 2>&1
    core_log "ERROR" "Test error message" >/dev/null 2>&1

    # Test config functions
    core_set_config "test_key" "test_value"
    local value=$(core_get_config "test_key")
    [[ "$value" == "test_value" ]]
}

# Test configuration system
module_utils_test_config() {
    # Test config loading
    echo "test_config_key=test_config_value" > "$TEMP_DIR/test_config.conf"
    core_load_config "$TEMP_DIR/test_config.conf"
    local value=$(core_get_config "test_config_key")
    [[ "$value" == "test_config_value" ]]
}

# Test device detection
module_utils_test_device() {
    # This test only runs if ADB is available and a device is connected
    if command -v adb &>/dev/null; then
        local devices
        devices=$(adb devices 2>/dev/null | grep -c "device$")
        [[ $devices -gt 0 ]]
    else
        # If ADB not available, test passes (not a failure condition)
        true
    fi
}

# Test build system
module_utils_test_build() {
    # Test build requirement validation
    local original_arch=$(core_get_config BUILD_ARCH)
    core_set_config BUILD_ARCH "arm64"

    if module_build_validate_requirements; then
        core_set_config BUILD_ARCH "$original_arch"
        true
    else
        core_set_config BUILD_ARCH "$original_arch"
        false
    fi
}

# Test module loading
module_utils_test_modules() {
    # Test if all core modules are loaded
    core_module_loaded "config" && \
    core_module_loaded "device" && \
    core_module_loaded "kernel" && \
    core_module_loaded "ramdisk" && \
    core_module_loaded "build" && \
    core_module_loaded "utils"
}

# Clean all temporary files
module_utils_clean_all() {
    module_info_msg "Cleaning all temporary files and workspaces"

    # Clean temp directory
    if [[ -d "$TEMP_DIR" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            module_info_msg "DRY RUN: Would clean temp directory: $TEMP_DIR"
        else
            find "$TEMP_DIR" -mindepth 1 -delete 2>/dev/null || true
            core_success "Temporary files cleaned"
        fi
    fi

    # Clean build workspaces
    if [[ -n "$BUILD_WORKSPACE" && -d "$BUILD_WORKSPACE" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            module_info_msg "DRY RUN: Would clean build workspace: $BUILD_WORKSPACE"
        else
            rm -rf "$BUILD_WORKSPACE"
            core_success "Build workspace cleaned"
        fi
    fi

    # Clean ramdisk workspace
    if [[ -n "$RAMDISK_WORKSPACE" && -d "$RAMDISK_WORKSPACE" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            module_info_msg "DRY RUN: Would clean ramdisk workspace: $RAMDISK_WORKSPACE"
        else
            rm -rf "$RAMDISK_WORKSPACE"
            core_success "Ramdisk workspace cleaned"
        fi
    fi
}

# Show system diagnostics
module_utils_diagnostics() {
    echo "KernelX System Diagnostics"
    echo "=========================="
    echo

    # System information
    echo "System Information:"
    echo "  OS: $(uname -s) $(uname -r)"
    echo "  Architecture: $(uname -m)"
    echo "  User: $(whoami)"
    echo "  Date: $(date)"
    echo

    # KernelX information
    echo "KernelX Information:"
    echo "  Version: $KERNELX_VERSION"
    echo "  Script Directory: $SCRIPT_DIR"
    echo "  Temp Directory: $TEMP_DIR"
    echo "  Config Directory: $CONFIG_DIR"
    echo

    # Module status
    echo "Module Status:"
    for module in config device kernel ramdisk build utils; do
        if core_module_loaded "$module"; then
            echo "  ✓ $module"
        else
            echo "  ✗ $module (not loaded)"
        fi
    done
    echo

    # Dependency check
    echo "Dependencies:"
    local deps=("adb" "make" "gcc" "cpio" "patch" "git")
    for dep in "${deps[@]}"; do
        if command -v "$dep" &>/dev/null; then
            echo "  ✓ $dep"
        else
            echo "  ✗ $dep (missing)"
        fi
    done
    echo

    # Directory permissions
    echo "Directory Permissions:"
    for dir in "$TEMP_DIR" "$CONFIG_DIR" "$SCRIPT_DIR/modules" "$SCRIPT_DIR/plugins"; do
        if [[ -d "$dir" ]]; then
            local perms
            perms=$(stat -c %a "$dir" 2>/dev/null || echo "unknown")
            echo "  $dir: $perms"
        fi
    done
    echo

    # Disk space
    echo "Disk Space:"
    df -h "$SCRIPT_DIR" | tail -1 | awk '{print "  " $1 ": " $4 " available"}'
    echo

    # Recent logs
    echo "Recent Log Activity:"
    if [[ -f "$TEMP_DIR/kernelx.log" ]]; then
        tail -5 "$TEMP_DIR/kernelx.log" 2>/dev/null | sed 's/^/  /'
    else
        echo "  No recent logs found"
    fi
    echo
}

# Show help
module_utils_help() {
    echo "KernelX Utils Module Help"
    echo "========================="
    echo
    echo "Available utility functions:"
    echo "  backup     - Create comprehensive system backups"
    echo "  restore    - Restore from backups with options"
    echo "  test       - Run complete test suite"
    echo "  clean      - Clean all temporary files"
    echo "  diagnostics- Show system diagnostics"
    echo "  help       - Show this help message"
    echo
}

# Export module functions
export -f module_utils_backup_all
export -f module_utils_restore_menu
export -f module_utils_restore_config
export -f module_utils_restore_kernel
export -f module_utils_restore_ramdisk
export -f module_utils_restore_patches
export -f module_utils_restore_full
export -f module_utils_run_tests
export -f module_utils_test_core
export -f module_utils_test_config
export -f module_utils_test_device
export -f module_utils_test_build
export -f module_utils_test_modules
export -f module_utils_clean_all
export -f module_utils_diagnostics
export -f module_utils_help
