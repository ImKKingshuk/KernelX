#!/bin/bash

# KernelX Base Module Template
# All modules should source this file and implement the required functions

# Module metadata
MODULE_NAME=""
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION=""
MODULE_AUTHOR="@ImKKingshuk"

# Module state
MODULE_INITIALIZED=false
MODULE_ENABLED=true

# Base module functions that can be overridden

# Initialize module
module_init() {
    if [[ "$MODULE_ENABLED" != "true" ]]; then
        core_log "DEBUG" "Module $MODULE_NAME is disabled"
        return 0
    fi

    core_log "INFO" "Initializing module: $MODULE_NAME v$MODULE_VERSION"
    MODULE_INITIALIZED=true

    # Call custom init if defined
    if type "module_custom_init" &>/dev/null; then
        module_custom_init
    fi
}

# Cleanup module
module_cleanup() {
    if [[ "$MODULE_INITIALIZED" == "true" ]]; then
        core_log "DEBUG" "Cleaning up module: $MODULE_NAME"

        # Call custom cleanup if defined
        if type "module_custom_cleanup" &>/dev/null; then
            module_custom_cleanup
        fi

        MODULE_INITIALIZED=false
    fi
}

# Check if module is ready
module_is_ready() {
    [[ "$MODULE_INITIALIZED" == "true" && "$MODULE_ENABLED" == "true" ]]
}

# Get module info
module_info() {
    cat << EOF
Module: $MODULE_NAME
Version: $MODULE_VERSION
Description: $MODULE_DESCRIPTION
Author: $MODULE_AUTHOR
Status: $(module_is_ready && echo "Ready" || echo "Not Ready")
Enabled: $MODULE_ENABLED
EOF
}

# Validate module requirements
module_validate_requirements() {
    # Default implementation - override in specific modules
    return 0
}

# Base error handling for modules
module_error() {
    local message="$1"
    core_log "ERROR" "[$MODULE_NAME] $message"
}

# Base warning for modules
module_warn() {
    local message="$1"
    core_log "WARN" "[$MODULE_NAME] $message"
}

# Base info for modules
module_info_msg() {
    local message="$1"
    core_log "INFO" "[$MODULE_NAME] $message"
}

# Check dependencies
module_check_dependencies() {
    local deps=("$@")
    local missing_deps=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        module_error "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi

    return 0
}

# Create temporary workspace for module
module_create_workspace() {
    local workspace_name="${1:-$MODULE_NAME}"
    WORKSPACE_DIR="$TEMP_DIR/$workspace_name"
    mkdir -p "$WORKSPACE_DIR"
    core_log "DEBUG" "Created workspace: $WORKSPACE_DIR"
    echo "$WORKSPACE_DIR"
}

# Clean module workspace
module_clean_workspace() {
    local workspace_dir="${1:-$WORKSPACE_DIR}"
    if [[ -d "$workspace_dir" ]]; then
        rm -rf "$workspace_dir"
        core_log "DEBUG" "Cleaned workspace: $workspace_dir"
    fi
}

# Backup file/directory
module_backup() {
    local source="$1"
    local backup_suffix="${2:-$(date +%Y%m%d_%H%M%S)}"
    local backup_dir="$TEMP_DIR/backups"

    mkdir -p "$backup_dir"

    if [[ -e "$source" ]]; then
        local backup_path="$backup_dir/$(basename "$source").$backup_suffix"
        cp -r "$source" "$backup_path"
        core_log "INFO" "Created backup: $backup_path"
        echo "$backup_path"
    else
        module_warn "Cannot backup: $source does not exist"
        return 1
    fi
}

# Restore from backup
module_restore() {
    local backup_path="$1"
    local target="$2"

    if [[ -e "$backup_path" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            module_info_msg "DRY RUN: Would restore $backup_path to $target"
            return 0
        fi

        cp -r "$backup_path" "$target"
        core_log "INFO" "Restored from backup: $backup_path to $target"
    else
        module_error "Backup not found: $backup_path"
        return 1
    fi
}

# Validate file exists
module_validate_file() {
    local file_path="$1"
    local file_desc="${2:-file}"

    if [[ ! -f "$file_path" ]]; then
        module_error "$file_desc not found: $file_path"
        return 1
    fi

    if [[ ! -r "$file_path" ]]; then
        module_error "$file_desc not readable: $file_path"
        return 1
    fi

    return 0
}

# Validate directory exists
module_validate_dir() {
    local dir_path="$1"
    local dir_desc="${2:-directory}"

    if [[ ! -d "$dir_path" ]]; then
        module_error "$dir_desc not found: $dir_path"
        return 1
    fi

    return 0
}

# Run command with error handling
module_run_cmd() {
    local cmd="$1"
    local error_msg="${2:-Command failed}"

    if [[ "$DRY_RUN" == "true" ]]; then
        module_info_msg "DRY RUN: $cmd"
        return 0
    fi

    core_log "DEBUG" "Running: $cmd"

    if ! eval "$cmd"; then
        module_error "$error_msg: $cmd"
        return 1
    fi

    return 0
}

# Export base module functions
export -f module_init module_cleanup module_is_ready module_info
export -f module_validate_requirements module_error module_warn module_info_msg
export -f module_check_dependencies module_create_workspace module_clean_workspace
export -f module_backup module_restore module_validate_file module_validate_dir
export -f module_run_cmd
