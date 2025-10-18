#!/bin/bash

# KernelX Ramdisk Module
# Advanced ramdisk management with extraction, modification, and repacking

source "$SCRIPT_DIR/core/base_module.sh"

# Module metadata
MODULE_NAME="ramdisk"
MODULE_VERSION="2.0.0"
MODULE_DESCRIPTION="Advanced ramdisk management with extraction, modification, and repacking capabilities"
MODULE_AUTHOR="@ImKKingshuk"

# Ramdisk module variables
RAMDISK_WORKSPACE=""
RAMDISK_BACKUP_DIR="$TEMP_DIR/ramdisk_backups"

# Module custom initialization
module_custom_init() {
    # Create necessary directories
    mkdir -p "$RAMDISK_BACKUP_DIR"

    # Check for required tools
    local required_tools=("cpio" "gzip" "lz4" "xz" "bzip2")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        module_warn "Missing compression tools: ${missing_tools[*]}"
        module_warn "Some ramdisk formats may not be supported"
    fi
}

# Main ramdisk menu
module_ramdisk_menu() {
    while true; do
        echo
        echo "╔══════════════════════════════════════════════╗"
        echo "║            Ramdisk Management               ║"
        echo "╚══════════════════════════════════════════════╝"
        echo
        echo "1. Extract Ramdisk"
        echo "2. Repack Ramdisk"
        echo "3. Modify Ramdisk Files"
        echo "4. Show Ramdisk Information"
        echo "5. Validate Ramdisk"
        echo "6. Create Ramdisk Backup"
        echo "7. Restore Ramdisk from Backup"
        echo "8. Back to Main Menu"
        echo
        read -p "Select option (1-8): " choice

        case $choice in
            1) module_ramdisk_extract ;;
            2) module_ramdisk_repack ;;
            3) module_ramdisk_modify ;;
            4) module_ramdisk_info ;;
            5) module_ramdisk_validate ;;
            6) module_ramdisk_backup ;;
            7) module_ramdisk_restore ;;
            8) break ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

# Extract ramdisk
module_ramdisk_extract() {
    local ramdisk_path=$(core_get_config RAMDISK_PATH)

    if [[ -z "$ramdisk_path" ]]; then
        read -p "Enter ramdisk path: " ramdisk_path
        if [[ -z "$ramdisk_path" ]]; then
            module_error "No ramdisk path specified"
            return 1
        fi
    fi

    if [[ ! -f "$ramdisk_path" ]]; then
        module_error "Ramdisk file not found: $ramdisk_path"
        return 1
    fi

    # Create workspace
    RAMDISK_WORKSPACE=$(module_create_workspace "ramdisk_extract")

    module_info_msg "Extracting ramdisk: $(basename "$ramdisk_path")"

    # Detect compression format
    local compression
    compression=$(module_ramdisk_detect_compression "$ramdisk_path")

    if [[ -z "$compression" ]]; then
        module_error "Unable to detect ramdisk compression format"
        return 1
    fi

    module_info_msg "Detected compression: $compression"

    # Extract based on compression
    case "$compression" in
        "gzip")
            if [[ "$DRY_RUN" == "true" ]]; then
                module_info_msg "DRY RUN: Would extract gzip ramdisk"
                return 0
            fi

            cd "$RAMDISK_WORKSPACE" || return 1
            if ! gunzip -c "$ramdisk_path" | cpio -i -d -m; then
                module_error "Failed to extract gzip ramdisk"
                return 1
            fi
            ;;
        "lz4")
            if [[ "$DRY_RUN" == "true" ]]; then
                module_info_msg "DRY RUN: Would extract LZ4 ramdisk"
                return 0
            fi

            cd "$RAMDISK_WORKSPACE" || return 1
            if ! lz4 -d -c "$ramdisk_path" | cpio -i -d -m; then
                module_error "Failed to extract LZ4 ramdisk"
                return 1
            fi
            ;;
        "xz")
            if [[ "$DRY_RUN" == "true" ]]; then
                module_info_msg "DRY RUN: Would extract XZ ramdisk"
                return 0
            fi

            cd "$RAMDISK_WORKSPACE" || return 1
            if ! xz -d -c "$ramdisk_path" | cpio -i -d -m; then
                module_error "Failed to extract XZ ramdisk"
                return 1
            fi
            ;;
        "bzip2")
            if [[ "$DRY_RUN" == "true" ]]; then
                module_info_msg "DRY RUN: Would extract bzip2 ramdisk"
                return 0
            fi

            cd "$RAMDISK_WORKSPACE" || return 1
            if ! bzip2 -d -c "$ramdisk_path" | cpio -i -d -m; then
                module_error "Failed to extract bzip2 ramdisk"
                return 1
            fi
            ;;
        "uncompressed")
            if [[ "$DRY_RUN" == "true" ]]; then
                module_info_msg "DRY RUN: Would extract uncompressed ramdisk"
                return 0
            fi

            cd "$RAMDISK_WORKSPACE" || return 1
            if ! cpio -i -d -m < "$ramdisk_path"; then
                module_error "Failed to extract uncompressed ramdisk"
                return 1
            fi
            ;;
        *)
            module_error "Unsupported compression format: $compression"
            return 1
            ;;
    esac

    core_success "Ramdisk extracted to: $RAMDISK_WORKSPACE"
    module_ramdisk_show_contents "$RAMDISK_WORKSPACE"

    return 0
}

# Repack ramdisk
module_ramdisk_repack() {
    if [[ -z "$RAMDISK_WORKSPACE" || ! -d "$RAMDISK_WORKSPACE" ]]; then
        module_error "No extracted ramdisk found. Extract a ramdisk first."
        return 1
    fi

    local output_file="${1:-ramdisk_new.img}"
    local compression=$(core_get_config RAMDISK_COMPRESSION "gzip")

    module_info_msg "Repacking ramdisk with $compression compression"

    if [[ "$DRY_RUN" == "true" ]]; then
        module_info_msg "DRY RUN: Would repack ramdisk to $output_file"
        return 0
    fi

    cd "$RAMDISK_WORKSPACE" || return 1

    # Create new ramdisk
    case "$compression" in
        "gzip")
            if ! (find . -mindepth 1 | cpio -o -H newc | gzip > "$output_file"); then
                module_error "Failed to create gzip ramdisk"
                return 1
            fi
            ;;
        "lz4")
            if ! (find . -mindepth 1 | cpio -o -H newc | lz4 > "$output_file"); then
                module_error "Failed to create LZ4 ramdisk"
                return 1
            fi
            ;;
        "xz")
            if ! (find . -mindepth 1 | cpio -o -H newc | xz > "$output_file"); then
                module_error "Failed to create XZ ramdisk"
                return 1
            fi
            ;;
        "bzip2")
            if ! (find . -mindepth 1 | cpio -o -H newc | bzip2 > "$output_file"); then
                module_error "Failed to create bzip2 ramdisk"
                return 1
            fi
            ;;
        "none"|"uncompressed")
            if ! (find . -mindepth 1 | cpio -o -H newc > "$output_file"); then
                module_error "Failed to create uncompressed ramdisk"
                return 1
            fi
            ;;
        *)
            module_error "Unsupported compression format: $compression"
            return 1
            ;;
    esac

    # Move to output directory
    local output_dir=$(core_get_config BUILD_OUTPUT_DIR "output")
    mkdir -p "$output_dir"
    mv "$output_file" "$output_dir/"

    core_success "Ramdisk repacked: $output_dir/$output_file"
    module_info_msg "Size: $(du -h "$output_dir/$output_file" | cut -f1)"

    return 0
}

# Modify ramdisk files
module_ramdisk_modify() {
    if [[ -z "$RAMDISK_WORKSPACE" || ! -d "$RAMDISK_WORKSPACE" ]]; then
        module_error "No extracted ramdisk found. Extract a ramdisk first."
        return 1
    fi

    echo "Ramdisk Modification Options:"
    echo "============================="
    echo "1. Add file"
    echo "2. Remove file"
    echo "3. Edit file"
    echo "4. Show file contents"
    echo "5. List files"
    echo "6. Back to ramdisk menu"
    echo

    read -p "Select option (1-6): " choice

    case $choice in
        1) module_ramdisk_add_file ;;
        2) module_ramdisk_remove_file ;;
        3) module_ramdisk_edit_file ;;
        4) module_ramdisk_show_file ;;
        5) module_ramdisk_show_contents "$RAMDISK_WORKSPACE" ;;
        6) return 0 ;;
        *) echo "Invalid option." ;;
    esac
}

# Add file to ramdisk
module_ramdisk_add_file() {
    read -p "Enter source file path: " source_file
    read -p "Enter destination path in ramdisk: " dest_path

    if [[ ! -f "$source_file" ]]; then
        module_error "Source file not found: $source_file"
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        module_info_msg "DRY RUN: Would copy $source_file to $RAMDISK_WORKSPACE/$dest_path"
        return 0
    fi

    # Create destination directory if needed
    mkdir -p "$RAMDISK_WORKSPACE/$(dirname "$dest_path")"

    if cp "$source_file" "$RAMDISK_WORKSPACE/$dest_path"; then
        core_success "File added to ramdisk: $dest_path"
    else
        module_error "Failed to add file to ramdisk"
    fi
}

# Remove file from ramdisk
module_ramdisk_remove_file() {
    read -p "Enter file path to remove from ramdisk: " file_path

    local full_path="$RAMDISK_WORKSPACE/$file_path"

    if [[ ! -e "$full_path" ]]; then
        module_error "File not found in ramdisk: $file_path"
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        module_info_msg "DRY RUN: Would remove $file_path from ramdisk"
        return 0
    fi

    if rm -f "$full_path"; then
        core_success "File removed from ramdisk: $file_path"
    else
        module_error "Failed to remove file from ramdisk"
    fi
}

# Edit file in ramdisk
module_ramdisk_edit_file() {
    read -p "Enter file path to edit in ramdisk: " file_path

    local full_path="$RAMDISK_WORKSPACE/$file_path"

    if [[ ! -f "$full_path" ]]; then
        module_error "File not found in ramdisk: $file_path"
        return 1
    fi

    # Use available editor
    local editor="${EDITOR:-nano}"
    if ! command -v "$editor" &>/dev/null; then
        editor="vi"
        if ! command -v "$editor" &>/dev/null; then
            module_error "No text editor found. Please set EDITOR environment variable."
            return 1
        fi
    fi

    module_info_msg "Opening $file_path with $editor"

    if [[ "$DRY_RUN" == "true" ]]; then
        module_info_msg "DRY RUN: Would edit $file_path"
        return 0
    fi

    "$editor" "$full_path"
    core_success "File edited: $file_path"
}

# Show file contents
module_ramdisk_show_file() {
    read -p "Enter file path to view in ramdisk: " file_path

    local full_path="$RAMDISK_WORKSPACE/$file_path"

    if [[ ! -f "$full_path" ]]; then
        module_error "File not found in ramdisk: $file_path"
        return 1
    fi

    echo
    echo "Contents of $file_path:"
    echo "======================="
    cat "$full_path"
    echo
}

# Show ramdisk information
module_ramdisk_info() {
    local ramdisk_path=$(core_get_config RAMDISK_PATH)

    if [[ -n "$ramdisk_path" && -f "$ramdisk_path" ]]; then
        echo "Ramdisk Information:"
        echo "==================="
        echo "Path: $ramdisk_path"
        echo "Size: $(du -h "$ramdisk_path" | cut -f1)"
        echo "Modified: $(stat -c %y "$ramdisk_path" 2>/dev/null | cut -d. -f1)"

        local compression
        compression=$(module_ramdisk_detect_compression "$ramdisk_path")
        echo "Compression: ${compression:-unknown}"
        echo

        if [[ -n "$RAMDISK_WORKSPACE" && -d "$RAMDISK_WORKSPACE" ]]; then
            echo "Extracted Workspace: $RAMDISK_WORKSPACE"
            module_ramdisk_show_contents "$RAMDISK_WORKSPACE"
        else
            echo "Not extracted yet. Use option 1 to extract."
        fi
    else
        echo "No ramdisk configured or file not found."
        echo "Set RAMDISK_PATH in configuration or extract a ramdisk first."
    fi
}

# Show ramdisk contents
module_ramdisk_show_contents() {
    local ramdisk_dir="$1"

    if [[ ! -d "$ramdisk_dir" ]]; then
        module_error "Ramdisk directory not found: $ramdisk_dir"
        return 1
    fi

    echo "Ramdisk Contents ($ramdisk_dir):"
    echo "================================="

    # Count files and directories
    local file_count=$(find "$ramdisk_dir" -type f | wc -l)
    local dir_count=$(find "$ramdisk_dir" -type d | wc -l)
    local total_size=$(du -sh "$ramdisk_dir" | cut -f1)

    echo "Files: $file_count"
    echo "Directories: $dir_count"
    echo "Total Size: $total_size"
    echo

    echo "Key Files and Directories:"
    echo "=========================="
    find "$ramdisk_dir" -maxdepth 2 -type f -name "init*" -o -name "*.rc" -o -name "default.prop" | head -10 | while read -r file; do
        echo "• ${file#$ramdisk_dir/}"
    done
}

# Detect ramdisk compression
module_ramdisk_detect_compression() {
    local ramdisk_file="$1"

    if [[ ! -f "$ramdisk_file" ]]; then
        return 1
    fi

    # Read first few bytes to detect compression
    local header
    header=$(od -c "$ramdisk_file" | head -1 | awk '{print $2 $3 $4 $5}')

    case "$header" in
        '037213') echo "gzip" ;;
        '004004002') echo "lz4" ;;
        '377213') echo "xz" ;;
        '425a68') echo "bzip2" ;;
        '070701'|'070702') echo "uncompressed" ;;
        *) echo "unknown" ;;
    esac
}

# Validate ramdisk
module_ramdisk_validate() {
    local ramdisk_path=$(core_get_config RAMDISK_PATH)

    if [[ -z "$ramdisk_path" ]]; then
        module_error "No ramdisk path configured"
        return 1
    fi

    if [[ ! -f "$ramdisk_path" ]]; then
        module_error "Ramdisk file not found: $ramdisk_path"
        return 1
    fi

    module_info_msg "Validating ramdisk: $(basename "$ramdisk_path")"

    # Check file size
    local size
    size=$(stat -c %s "$ramdisk_path" 2>/dev/null || stat -f %z "$ramdisk_path" 2>/dev/null)
    if [[ $size -lt 1000 ]]; then
        module_error "Ramdisk file seems too small: $size bytes"
        return 1
    fi

    # Try to detect compression
    local compression
    compression=$(module_ramdisk_detect_compression "$ramdisk_path")
    if [[ "$compression" == "unknown" ]]; then
        module_warn "Unable to detect compression format"
    else
        core_success "Compression format: $compression"
    fi

    # Try basic extraction test (if not dry run)
    if [[ "$DRY_RUN" != "true" ]]; then
        local test_dir="$TEMP_DIR/ramdisk_test"
        mkdir -p "$test_dir"

        if module_ramdisk_test_extract "$ramdisk_path" "$test_dir" >/dev/null 2>&1; then
            core_success "Ramdisk extraction test passed"
            rm -rf "$test_dir"
        else
            module_error "Ramdisk extraction test failed"
            rm -rf "$test_dir"
            return 1
        fi
    fi

    core_success "Ramdisk validation completed"
    return 0
}

# Test extraction (internal function)
module_ramdisk_test_extract() {
    local ramdisk_file="$1"
    local test_dir="$2"

    local compression
    compression=$(module_ramdisk_detect_compression "$ramdisk_file")

    cd "$test_dir" || return 1

    case "$compression" in
        "gzip") gunzip -c "$ramdisk_file" | cpio -t >/dev/null ;;
        "lz4") lz4 -d -c "$ramdisk_file" | cpio -t >/dev/null ;;
        "xz") xz -d -c "$ramdisk_file" | cpio -t >/dev/null ;;
        "bzip2") bzip2 -d -c "$ramdisk_file" | cpio -t >/dev/null ;;
        "uncompressed") cpio -t < "$ramdisk_file" >/dev/null ;;
        *) return 1 ;;
    esac
}

# Backup ramdisk
module_ramdisk_backup() {
    local ramdisk_path=$(core_get_config RAMDISK_PATH)

    if [[ -z "$ramdisk_path" || ! -f "$ramdisk_path" ]]; then
        module_error "No valid ramdisk path configured"
        return 1
    fi

    local backup_name="ramdisk_backup_$(date +%Y%m%d_%H%M%S)"

    if module_backup "$ramdisk_path" "$backup_name"; then
        core_success "Ramdisk backup created: $backup_name"
        return 0
    else
        module_error "Failed to create ramdisk backup"
        return 1
    fi
}

# Restore ramdisk from backup
module_ramdisk_restore() {
    echo "Available Ramdisk Backups:"
    echo "=========================="

    if [[ ! -d "$RAMDISK_BACKUP_DIR" ]]; then
        echo "No backups found"
        return 1
    fi

    local backups=()
    local i=1
    for backup in "$RAMDISK_BACKUP_DIR"/*; do
        if [[ -d "$backup" ]]; then
            local backup_name=$(basename "$backup")
            echo "$i. $backup_name"
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
    local ramdisk_path=$(core_get_config RAMDISK_PATH)

    if [[ -z "$ramdisk_path" ]]; then
        read -p "Enter restore destination: " ramdisk_path
    fi

    if module_restore "$selected_backup" "$ramdisk_path"; then
        core_success "Ramdisk restored from backup"
        return 0
    else
        module_error "Failed to restore ramdisk from backup"
        return 1
    fi
}

# Export module functions
export -f module_ramdisk_menu
export -f module_ramdisk_extract
export -f module_ramdisk_repack
export -f module_ramdisk_modify
export -f module_ramdisk_info
export -f module_ramdisk_validate
export -f module_ramdisk_backup
export -f module_ramdisk_restore
export -f module_ramdisk_detect_compression
