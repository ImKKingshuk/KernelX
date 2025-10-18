#!/bin/bash

# KernelX Core Framework
# Ultimate Kernel Kitchen v2.0
# Author: @ImKKingshuk

# Core constants
readonly KERNELX_VERSION="2.0.0"
readonly KERNELX_NAME="KernelX: The Ultimate Kernel Kitchen"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Core paths
readonly CORE_DIR="$SCRIPT_DIR/core"
readonly MODULES_DIR="$SCRIPT_DIR/modules"
readonly PLUGINS_DIR="$SCRIPT_DIR/plugins"
readonly CONFIG_DIR="$SCRIPT_DIR/config"
readonly TEMP_DIR="$SCRIPT_DIR/temp"
declare -a MODULES_LOADED_KEYS
declare -a MODULES_LOADED_VALUES
declare -a CONFIG_CACHE_KEYS
declare -a CONFIG_CACHE_VALUES
DRY_RUN=false
VERBOSE=false
LOG_LEVEL="INFO"
CURRENT_DEVICE=""
WORKSPACE_DIR=""
LOG_FILE=""

# Core logging function
core_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')

    # Log level hierarchy
    local current_level
    case "$LOG_LEVEL" in
        "DEBUG") current_level=0 ;;
        "INFO") current_level=1 ;;
        "WARN") current_level=2 ;;
        "ERROR") current_level=3 ;;
        *) current_level=1 ;;
    esac

    local msg_level
    case "$level" in
        "DEBUG") msg_level=0 ;;
        "INFO") msg_level=1 ;;
        "WARN") msg_level=2 ;;
        "ERROR") msg_level=3 ;;
        *) msg_level=1 ;;
    esac

    if (( msg_level >= current_level )); then
        echo "[$timestamp] [$level] $message" >&2
        if [[ -n "$LOG_FILE" && "$LOG_FILE" != "" ]]; then
            echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
        fi
    fi
}

# Core error handling
core_error() {
    local message="$1"
    local exit_code="${2:-1}"
    core_log "ERROR" "$message"
    exit "$exit_code"
}

# Core success message
core_success() {
    local message="$1"
    echo -e "\033[0;32m✓\033[0m $message"
}

# Core warning message
core_warn() {
    local message="$1"
    echo -e "\033[0;33m⚠\033[0m $message"
}

# Core info message
core_info() {
    local message="$1"
    echo -e "\033[0;34mℹ\033[0m $message"
}

# Load configuration from file
core_load_config() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            # Remove quotes and spaces
            key=$(echo "$key" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^"//' | sed 's/"$//' | sed "s/^'//" | sed "s/'$//")
            core_set_config "$key" "$value"
        done < "$config_file"
        core_log "DEBUG" "Loaded configuration from $config_file"
        return 0
    else
        core_log "WARN" "Configuration file not found: $config_file"
        return 1
    fi
}

# Get configuration value
core_get_config() {
    local key="$1"
    local default="${2:-}"

    # Find key in array
    for i in "${!CONFIG_CACHE_KEYS[@]}"; do
        if [[ "${CONFIG_CACHE_KEYS[$i]}" == "$key" ]]; then
            echo "${CONFIG_CACHE_VALUES[$i]}"
            return 0
        fi
    done

    echo "$default"
}

# Set configuration value
core_set_config() {
    local key="$1"
    local value="$2"

    # Check if key exists
    for i in "${!CONFIG_CACHE_KEYS[@]}"; do
        if [[ "${CONFIG_CACHE_KEYS[$i]}" == "$key" ]]; then
            CONFIG_CACHE_VALUES[$i]="$value"
            core_log "DEBUG" "Set config $key=$value"
            return 0
        fi
    done

    # Add new key-value pair
    CONFIG_CACHE_KEYS+=("$key")
    CONFIG_CACHE_VALUES+=("$value")
    core_log "DEBUG" "Set config $key=$value"
}

# Load module
core_load_module() {
    local module_name="$1"
    local module_path="$MODULES_DIR/$module_name/module.sh"

    if [[ -f "$module_path" ]]; then
        # Check if module is already loaded
        local is_loaded=false
        for i in "${!MODULES_LOADED_KEYS[@]}"; do
            if [[ "${MODULES_LOADED_KEYS[$i]}" == "$module_name" ]]; then
                is_loaded=true
                break
            fi
        done

        if [[ "$is_loaded" == "false" ]]; then
            core_log "INFO" "Loading module: $module_name"
            source "$module_path"
            MODULES_LOADED_KEYS+=("$module_name")
            MODULES_LOADED_VALUES+=("true")
            # Call module init if it exists
            if type "module_${module_name}_init" &>/dev/null; then
                "module_${module_name}_init"
            fi
            core_log "INFO" "Module loaded: $module_name"
            return 0
        else
            core_log "DEBUG" "Module already loaded: $module_name"
            return 0
        fi
    else
        core_log "ERROR" "Module not found: $module_path"
        return 1
    fi
}

# Check if module is loaded
core_module_loaded() {
    local module_name="$1"
    for i in "${!MODULES_LOADED_KEYS[@]}"; do
        if [[ "${MODULES_LOADED_KEYS[$i]}" == "$module_name" ]]; then
            return 0
        fi
    done
    return 1
}

# Load all enabled plugins
core_load_plugins() {
    local plugins_enabled_dir="$PLUGINS_DIR/enabled"

    if [[ -d "$plugins_enabled_dir" ]]; then
        for plugin_file in "$plugins_enabled_dir"/*.sh; do
            if [[ -f "$plugin_file" ]]; then
                local plugin_name=$(basename "$plugin_file" .sh)
                core_log "INFO" "Loading plugin: $plugin_name"
                source "$plugin_file"
                # Call plugin init if it exists
                if type "plugin_${plugin_name}_init" &>/dev/null; then
                    "plugin_${plugin_name}_init"
                fi
            fi
        done
    fi
}

# Initialize core framework
core_init() {
    # Create necessary directories
    mkdir -p "$TEMP_DIR" "$CONFIG_DIR/profiles" "$CONFIG_DIR/devices"

    # Set up logging
    if [[ -z "$LOG_FILE" ]]; then
        LOG_FILE="$TEMP_DIR/kernelx.log"
    fi

    # Load base configuration
    core_load_config "$CONFIG_DIR/default.config" || core_warn "No default config found"

    # Load user profile if specified
    if [[ -n "$KERNELX_PROFILE" ]]; then
        core_load_config "$CONFIG_DIR/profiles/$KERNELX_PROFILE.config" || core_warn "Profile not found: $KERNELX_PROFILE"
    fi

    # Set log level from config
    LOG_LEVEL=$(core_get_config "LOG_LEVEL" "INFO")

    core_log "INFO" "KernelX Core Framework v$KERNELX_VERSION initialized"
}

# Cleanup function
core_cleanup() {
    core_log "INFO" "Cleaning up temporary files"
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"/*
    fi
}

# Progress indicator
core_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Processing}"
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))

    printf "\r%s [%s%s] %d%%" "$message" "$(printf '%.0s#' {1..$completed})" "$(printf '%.0s-' $((completed+1))..$width)" "$percentage"
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# Export core functions for modules
export -f core_log core_error core_success core_warn core_info
export -f core_load_config core_get_config core_set_config
export -f core_load_module core_module_loaded
export -f core_progress
