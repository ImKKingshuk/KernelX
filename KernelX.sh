#!/bin/bash

# KernelX: The Ultimate Kernel Kitchen v2.0
# Author: @ImKKingshuk
# GitHub: https://github.com/ImKKingshuk/KernelX

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Load core framework
source "$SCRIPT_DIR/core/framework.sh"

# Load base module template
source "$SCRIPT_DIR/core/base_module.sh"

# ASCII Art Banner
print_banner() {
    local banner=(
        "╔══════════════════════════════════════════════════════════════════════════╗"
        "║                           KernelX v2.0                                   ║"
        "║                      The Ultimate Kernel Kitchen                         ║"
        "║                                                                          ║"
        "║  🛠️  Advanced Kernel Management & Patching Tool                          ║"
        "║  📱 Multi-Device Support with Intelligent Detection                      ║"
        "║  🔧 Modular Architecture with Plugin System                              ║"
        "║  🛡️  Safety Features & Backup/Restore Capabilities                       ║"
        "║  📊 Comprehensive Logging & Diagnostics                                  ║"
        "║                                                                          ║"
        "║                    Developed by @ImKKingshuk                             ║"
        "║                 GitHub: https://github.com/ImKKingshuk                   ║"
        "╚══════════════════════════════════════════════════════════════════════════╝"
    )

    echo -e "\033[0;36m"
    for line in "${banner[@]}"; do
        printf "%s\n" "$line"
    done
    echo -e "\033[0m"
    echo
}

# Show usage information
show_usage() {
    cat << EOF
KernelX v$KERNELX_VERSION - The Ultimate Kernel Kitchen

USAGE:
    $0 [OPTIONS] [COMMAND]

COMMANDS:
    setup           Interactive setup and configuration
    build           Build custom kernel
    patch           Apply patches to kernel
    ramdisk         Manage ramdisk files
    device          Device management and detection
    backup          Create backups
    restore         Restore from backups
    test            Run tests and validations
    clean           Clean temporary files
    info            Show system and module information

OPTIONS:
    -p, --profile PROFILE    Use specific configuration profile
    -d, --device DEVICE      Target specific device
    -v, --verbose            Enable verbose logging
    --dry-run                Show what would be done without executing
    --log-file FILE          Specify log file (default: temp/kernelx.log)
    -h, --help               Show this help message

EXAMPLES:
    $0 setup                    # Interactive setup
    $0 --profile myprofile build # Build with custom profile
    $0 --device pixel5 patch    # Patch for Pixel 5
    $0 --dry-run build          # Preview build process
    $0 --verbose info           # Detailed system info

For more information, visit: https://github.com/ImKKingshuk/KernelX
EOF
}

# Parse command line arguments
parse_args() {
    COMMAND=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--profile)
                KERNELX_PROFILE="$2"
                shift 2
                ;;
            -d|--device)
                TARGET_DEVICE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                LOG_LEVEL="DEBUG"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --log-file)
                LOG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            setup|build|patch|ramdisk|device|backup|restore|test|clean|info)
                COMMAND="$1"
                shift
                break
                ;;
            *)
                core_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Default command
    if [[ -z "$COMMAND" ]]; then
        COMMAND="setup"
    fi
}

# Load required modules
load_modules() {
    local required_modules=("config" "device" "kernel" "ramdisk" "build" "utils")

    core_info "Loading core modules..."
    for module in "${required_modules[@]}"; do
        if ! core_load_module "$module"; then
            core_error "Failed to load required module: $module"
            exit 1
        fi
    done

    # Load plugins
    core_load_plugins
}

# Command handlers
cmd_setup() {
    core_info "Starting interactive setup..."

    # Load config module for setup
    if core_module_loaded "config"; then
        module_config_setup
    else
        core_error "Config module not loaded"
        exit 1
    fi
}

cmd_build() {
    core_info "Starting kernel build process..."

    if core_module_loaded "build"; then
        module_build_run
    else
        core_error "Build module not loaded"
        exit 1
    fi
}

cmd_patch() {
    core_info "Starting kernel patching..."

    if core_module_loaded "kernel"; then
        module_kernel_patch
    else
        core_error "Kernel module not loaded"
        exit 1
    fi
}

cmd_ramdisk() {
    core_info "Ramdisk management..."

    if core_module_loaded "ramdisk"; then
        module_ramdisk_menu
    else
        core_error "Ramdisk module not loaded"
        exit 1
    fi
}

cmd_device() {
    core_info "Device management..."

    if core_module_loaded "device"; then
        module_device_info
    else
        core_error "Device module not loaded"
        exit 1
    fi
}

cmd_backup() {
    core_info "Creating backups..."

    if core_module_loaded "utils"; then
        module_utils_backup_all
    else
        core_error "Utils module not loaded"
        exit 1
    fi
}

cmd_restore() {
    core_info "Restoring from backups..."

    if core_module_loaded "utils"; then
        module_utils_restore_menu
    else
        core_error "Utils module not loaded"
        exit 1
    fi
}

cmd_test() {
    core_info "Running tests..."

    if core_module_loaded "utils"; then
        module_utils_run_tests
    else
        core_error "Utils module not loaded"
        exit 1
    fi
}

cmd_clean() {
    core_info "Cleaning temporary files..."
    core_cleanup

    if core_module_loaded "utils"; then
        module_utils_clean_all
    fi

    core_success "Cleanup completed"
}

cmd_info() {
    echo
    print_banner

    echo "System Information:"
    echo "==================="
    echo "KernelX Version: $KERNELX_VERSION"
    echo "Script Directory: $SCRIPT_DIR"
    echo "Project Root: $PROJECT_ROOT"
    echo "Log Level: $LOG_LEVEL"
    echo "Dry Run: $DRY_RUN"
    echo "Verbose: $VERBOSE"
    if [[ -n "$KERNELX_PROFILE" ]]; then
        echo "Active Profile: $KERNELX_PROFILE"
    fi
    echo

    echo "Loaded Modules:"
    echo "==============="
    for module in "${!MODULES_LOADED[@]}"; do
        echo "✓ $module"
    done
    echo

    echo "Core Directories:"
    echo "================="
    echo "Core: $CORE_DIR"
    echo "Modules: $MODULES_DIR"
    echo "Plugins: $PLUGINS_DIR"
    echo "Config: $CONFIG_DIR"
    echo "Temp: $TEMP_DIR"
    echo

    if [[ "$VERBOSE" == "true" ]]; then
        echo "Configuration Cache:"
        echo "===================="
        for key in "${!CONFIG_CACHE[@]}"; do
            echo "$key = ${CONFIG_CACHE[$key]}"
        done
        echo
    fi

    echo "Dependencies Check:"
    echo "==================="
    local deps=("adb" "cpio" "patch" "git" "make")
    for dep in "${deps[@]}"; do
        if command -v "$dep" &>/dev/null; then
            echo "✓ $dep"
        else
            echo "✗ $dep (missing)"
        fi
    done
    echo
}

# Main function
main() {
    # Initialize core framework
    core_init

    # Parse command line arguments
    parse_args "$@"

    # Load modules
    load_modules

    # Execute command
    case "$COMMAND" in
        setup)
            cmd_setup
            ;;
        build)
            cmd_build
            ;;
        patch)
            cmd_patch
            ;;
        ramdisk)
            cmd_ramdisk
            ;;
        device)
            cmd_device
            ;;
        backup)
            cmd_backup
            ;;
        restore)
            cmd_restore
            ;;
        test)
            cmd_test
            ;;
        clean)
            cmd_clean
            ;;
        info)
            cmd_info
            ;;
        *)
            core_error "Unknown command: $COMMAND"
            show_usage
            exit 1
            ;;
    esac

    core_log "INFO" "KernelX operation completed successfully"
}

# Cleanup on exit
trap core_cleanup EXIT

# Run main function
main "$@"