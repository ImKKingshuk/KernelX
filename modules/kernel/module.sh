#!/bin/bash

# KernelX Kernel Module
# Advanced kernel patching, management, and operations

source "$SCRIPT_DIR/core/base_module.sh"

# Module metadata
MODULE_NAME="kernel"
MODULE_VERSION="2.0.0"
MODULE_DESCRIPTION="Advanced kernel patching, management, and operations with multiple format support"
MODULE_AUTHOR="@ImKKingshuk"

# Kernel module variables
KERNEL_WORKSPACE=""
PATCH_BACKUP_DIR="$TEMP_DIR/kernel_backups"

# Module custom initialization
module_custom_init() {
    # Create necessary directories
    mkdir -p "$PATCH_BACKUP_DIR"
}

# Patch kernel function (main entry point)
module_kernel_patch() {
    module_info_msg "Starting kernel patching process"

    # Validate requirements
    if ! module_kernel_validate_requirements; then
        return 1
    fi

    # Create workspace
    KERNEL_WORKSPACE=$(module_create_workspace "kernel_patch")
    cd "$KERNEL_WORKSPACE" || return 1

    # Setup kernel source
    if ! module_kernel_setup_source; then
        return 1
    fi

    # Apply patches
    if ! module_kernel_apply_patches; then
        return 1
    fi

    # Verify patches
    if ! module_kernel_verify_patches; then
        module_warn "Patch verification failed, but continuing..."
    fi

    # Cleanup
    module_clean_workspace "$KERNEL_WORKSPACE"

    core_success "Kernel patching completed successfully"
}

# Validate patching requirements
module_kernel_validate_requirements() {
    module_info_msg "Validating kernel patching requirements"

    # Check for kernel source
    local kernel_source=$(core_get_config KERNEL_SOURCE_URL)
    local kernel_dir=$(core_get_config KERNEL_SOURCE_DIR)

    if [[ -z "$kernel_source" && -z "$kernel_dir" ]]; then
        module_error "No kernel source specified. Set KERNEL_SOURCE_URL or KERNEL_SOURCE_DIR"
        return 1
    fi

    if [[ -n "$kernel_dir" && ! -d "$kernel_dir" ]]; then
        module_error "Kernel source directory does not exist: $kernel_dir"
        return 1
    fi

    # Check for patches
    local patch_dir=$(core_get_config PATCH_DIR)
    if [[ -n "$patch_dir" && ! -d "$patch_dir" ]]; then
        module_error "Patches directory does not exist: $patch_dir"
        return 1
    fi

    # Check patch command availability
    if ! command -v patch &>/dev/null; then
        module_error "patch command not found"
        return 1
    fi

    return 0
}

# Setup kernel source
module_kernel_setup_source() {
    local kernel_source=$(core_get_config KERNEL_SOURCE_URL)
    local kernel_dir=$(core_get_config KERNEL_SOURCE_DIR)
    local kernel_branch=$(core_get_config KERNEL_BRANCH "main")

    if [[ -n "$kernel_dir" ]]; then
        # Use existing directory
        if [[ ! -d "$kernel_dir" ]]; then
            module_error "Kernel directory does not exist: $kernel_dir"
            return 1
        fi

        module_info_msg "Using existing kernel source: $kernel_dir"
        cp -r "$kernel_dir" "$KERNEL_WORKSPACE/kernel_source"

    elif [[ -n "$kernel_source" ]]; then
        # Clone from repository
        module_info_msg "Cloning kernel source from: $kernel_source"

        if [[ "$DRY_RUN" == "true" ]]; then
            module_info_msg "DRY RUN: Would clone $kernel_source"
            mkdir -p "$KERNEL_WORKSPACE/kernel_source"
        else
            if ! git clone --depth 1 --branch "$kernel_branch" "$kernel_source" "$KERNEL_WORKSPACE/kernel_source"; then
                module_error "Failed to clone kernel source"
                return 1
            fi
        fi
    else
        module_error "No kernel source specified"
        return 1
    fi

    # Change to kernel directory
    cd "$KERNEL_WORKSPACE/kernel_source" || return 1

    core_success "Kernel source ready"
    return 0
}

# Apply patches
module_kernel_apply_patches() {
    local patch_dir=$(core_get_config PATCH_DIR)
    local patch_format=$(core_get_config PATCH_FORMAT "diff")
    local backup_orig=$(core_get_config PATCH_BACKUP_ORIG "true")

    if [[ -z "$patch_dir" || ! -d "$patch_dir" ]]; then
        module_warn "No patches directory specified or found"
        return 0
    fi

    module_info_msg "Applying patches from: $patch_dir"

    # Find patch files
    local patch_files=()
    case "$patch_format" in
        "diff")
            mapfile -t patch_files < <(find "$patch_dir" -name "*.diff" -o -name "*.patch" | sort)
            ;;
        "git")
            # Git format patches
            mapfile -t patch_files < <(find "$patch_dir" -name "*.patch" | sort)
            ;;
        *)
            module_error "Unsupported patch format: $patch_format"
            return 1
            ;;
    esac

    if [[ ${#patch_files[@]} -eq 0 ]]; then
        module_warn "No patch files found in $patch_dir"
        return 0
    fi

    module_info_msg "Found ${#patch_files[@]} patch files"

    # Create backup if requested
    local backup_created=false
    if [[ "$backup_orig" == "true" && "$DRY_RUN" != "true" ]]; then
        local backup_name="kernel_backup_$(date +%Y%m%d_%H%M%S)"
        if module_backup "$KERNEL_WORKSPACE/kernel_source" "$backup_name"; then
            backup_created=true
            module_info_msg "Created backup: $backup_name"
        fi
    fi

    # Apply patches
    local applied_count=0
    local failed_count=0

    for patch_file in "${patch_files[@]}"; do
        local patch_name=$(basename "$patch_file")
        module_info_msg "Applying patch: $patch_name"

        if [[ "$DRY_RUN" == "true" ]]; then
            module_info_msg "DRY RUN: Would apply $patch_name"
            ((applied_count++))
            continue
        fi

        # Apply patch based on format
        local patch_cmd=""
        case "$patch_format" in
            "diff")
                patch_cmd="patch -p1 < \"$patch_file\""
                ;;
            "git")
                patch_cmd="git apply \"$patch_file\""
                ;;
        esac

        core_log "DEBUG" "Running: $patch_cmd"

        if eval "$patch_cmd" 2>&1; then
            core_success "Applied: $patch_name"
            ((applied_count++))
        else
            module_error "Failed to apply: $patch_name"
            ((failed_count++))

            # Try to continue with other patches
            if [[ "$backup_created" == "true" ]]; then
                module_warn "Some patches failed. You may need to restore from backup"
            fi
        fi

        # Progress indicator
        core_progress "$((applied_count + failed_count))" "${#patch_files[@]}" "Applying patches"
    done

    echo # New line after progress

    # Summary
    core_success "Patch application complete"
    echo "Applied: $applied_count"
    echo "Failed: $failed_count"

    if [[ $failed_count -gt 0 ]]; then
        return 1
    fi

    return 0
}

# Verify patches
module_kernel_verify_patches() {
    module_info_msg "Verifying patch application"

    if [[ "$DRY_RUN" == "true" ]]; then
        module_info_msg "DRY RUN: Would verify patches"
        return 0
    fi

    # Basic verification - check if kernel can be configured
    if [[ -f "Makefile" ]]; then
        if make defconfig >/dev/null 2>&1; then
            core_success "Kernel configuration test passed"
            return 0
        else
            module_error "Kernel configuration test failed"
            return 1
        fi
    else
        module_warn "No Makefile found, skipping verification"
        return 0
    fi
}

# Create patch from git diff
module_kernel_create_patch() {
    local patch_name="$1"
    local commit_range="${2:-HEAD~1..HEAD}"
    local output_dir="${3:-$(core_get_config PATCH_DIR)}"

    if [[ -z "$patch_name" ]]; then
        module_error "Patch name not specified"
        return 1
    fi

    if [[ -z "$output_dir" ]]; then
        output_dir="$PATCH_BACKUP_DIR"
    fi

    mkdir -p "$output_dir"

    local patch_file="$output_dir/${patch_name}.patch"

    module_info_msg "Creating patch: $patch_name from $commit_range"

    if [[ "$DRY_RUN" == "true" ]]; then
        module_info_msg "DRY RUN: Would create patch $patch_file"
        return 0
    fi

    if git format-patch -1 --stdout "$commit_range" > "$patch_file" 2>/dev/null; then
        core_success "Patch created: $patch_file"
        return 0
    else
        module_error "Failed to create patch"
        return 1
    fi
}

# List available patches
module_kernel_list_patches() {
    local patch_dir=$(core_get_config PATCH_DIR)

    echo "Available Patches:"
    echo "=================="

    if [[ -z "$patch_dir" || ! -d "$patch_dir" ]]; then
        echo "No patches directory configured"
        return 1
    fi

    local patch_files=()
    mapfile -t patch_files < <(find "$patch_dir" -name "*.diff" -o -name "*.patch" | sort)

    if [[ ${#patch_files[@]} -eq 0 ]]; then
        echo "No patch files found"
        return 0
    fi

    for patch_file in "${patch_files[@]}"; do
        local patch_name=$(basename "$patch_file")
        local patch_size=$(du -h "$patch_file" | cut -f1)
        local patch_date=$(stat -c %y "$patch_file" 2>/dev/null | cut -d. -f1)

        printf "%-30s %-8s %s\n" "$patch_name" "$patch_size" "$patch_date"
    done

    echo
    echo "Total patches: ${#patch_files[@]}"
}

# Show patch information
module_kernel_show_patch() {
    local patch_file="$1"

    if [[ -z "$patch_file" ]]; then
        module_error "Patch file not specified"
        return 1
    fi

    if [[ ! -f "$patch_file" ]]; then
        module_error "Patch file not found: $patch_file"
        return 1
    fi

    echo "Patch Information:"
    echo "=================="
    echo "File: $(basename "$patch_file")"
    echo "Path: $patch_file"
    echo "Size: $(du -h "$patch_file" | cut -f1)"
    echo "Modified: $(stat -c %y "$patch_file" 2>/dev/null | cut -d. -f1)"
    echo

    echo "Patch Preview:"
    echo "=============="
    head -20 "$patch_file"
    echo "..."
}

# Validate patch file
module_kernel_validate_patch() {
    local patch_file="$1"

    if [[ -z "$patch_file" ]]; then
        module_error "Patch file not specified"
        return 1
    fi

    if [[ ! -f "$patch_file" ]]; then
        module_error "Patch file not found: $patch_file"
        return 1
    fi

    module_info_msg "Validating patch: $(basename "$patch_file")"

    # Basic validation - check if it's a valid diff/patch format
    if head -1 "$patch_file" | grep -q "^diff --git"; then
        core_success "Valid git diff format"
        return 0
    elif head -1 "$patch_file" | grep -q "^--- "; then
        core_success "Valid unified diff format"
        return 0
    else
        module_error "Unknown or invalid patch format"
        return 1
    fi
}

# Backup kernel state
module_kernel_backup() {
    local backup_name="${1:-kernel_backup_$(date +%Y%m%d_%H%M%S)}"
    local kernel_dir="${2:-.}"

    module_info_msg "Creating kernel backup: $backup_name"

    if module_backup "$kernel_dir" "$backup_name"; then
        core_success "Kernel backup created: $backup_name"
        return 0
    else
        module_error "Failed to create kernel backup"
        return 1
    fi
}

# Restore kernel from backup
module_kernel_restore() {
    local backup_name="$1"
    local restore_dir="${2:-.}"

    if [[ -z "$backup_name" ]]; then
        module_error "Backup name not specified"
        return 1
    fi

    local backup_path="$PATCH_BACKUP_DIR/$backup_name"

    module_info_msg "Restoring kernel from backup: $backup_name"

    if module_restore "$backup_path" "$restore_dir"; then
        core_success "Kernel restored from backup"
        return 0
    else
        module_error "Failed to restore kernel from backup"
        return 1
    fi
}

# Export module functions
export -f module_kernel_patch
export -f module_kernel_validate_requirements
export -f module_kernel_setup_source
export -f module_kernel_apply_patches
export -f module_kernel_verify_patches
export -f module_kernel_create_patch
export -f module_kernel_list_patches
export -f module_kernel_show_patch
export -f module_kernel_validate_patch
export -f module_kernel_backup
export -f module_kernel_restore
