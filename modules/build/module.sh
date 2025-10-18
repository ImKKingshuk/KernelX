#!/bin/bash

# KernelX Build Module
# Advanced kernel build system with cross-compilation and toolchain management

source "$SCRIPT_DIR/core/base_module.sh"

# Module metadata
MODULE_NAME="build"
MODULE_VERSION="2.0.0"
MODULE_DESCRIPTION="Advanced kernel build system with cross-compilation, toolchain management, and verification"
MODULE_AUTHOR="@ImKKingshuk"

# Build module variables
BUILD_WORKSPACE=""
BUILD_LOG_FILE=""

# Module custom initialization
module_custom_init() {
    # Check for build tools
    local required_tools=("make" "gcc" "ld" "objcopy")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        module_warn "Missing build tools: ${missing_tools[*]}"
        module_warn "Cross-compilation toolchain may be required"
    fi
}

# Main build function
module_build_run() {
    module_info_msg "Starting kernel build process"

    # Validate build requirements
    if ! module_build_validate_requirements; then
        return 1
    fi

    # Setup build environment
    if ! module_build_setup_environment; then
        return 1
    fi

    # Configure kernel
    if ! module_build_configure; then
        return 1
    fi

    # Build kernel
    if ! module_build_kernel; then
        return 1
    fi

    # Post-build processing
    if ! module_build_post_process; then
        return 1
    fi

    # Verification
    if [[ "$(core_get_config SAFETY_VERIFY_BUILD)" == "true" ]]; then
        if ! module_build_verify; then
            module_warn "Build verification failed"
        fi
    fi

    core_success "Kernel build completed successfully"
}

# Validate build requirements
module_build_validate_requirements() {
    module_info_msg "Validating build requirements"

    # Check architecture
    local arch=$(core_get_config BUILD_ARCH)
    if [[ -z "$arch" ]]; then
        module_error "Build architecture not specified"
        return 1
    fi

    # Check cross-compile prefix
    local cross_compile=$(core_get_config BUILD_CROSS_COMPILE)
    if [[ -n "$cross_compile" ]]; then
        # Check if cross-compiler exists
        if ! command -v "${cross_compile}gcc" &>/dev/null; then
            module_error "Cross-compiler not found: ${cross_compile}gcc"
            return 1
        fi
    fi

    # Check kernel source
    local kernel_dir=$(core_get_config KERNEL_SOURCE_DIR)
    local kernel_url=$(core_get_config KERNEL_SOURCE_URL)

    if [[ -z "$kernel_dir" && -z "$kernel_url" ]]; then
        module_error "No kernel source specified"
        return 1
    fi

    if [[ -n "$kernel_dir" && ! -d "$kernel_dir" ]]; then
        module_error "Kernel source directory not found: $kernel_dir"
        return 1
    fi

    return 0
}

# Setup build environment
module_build_setup_environment() {
    # Create build workspace
    BUILD_WORKSPACE=$(module_create_workspace "kernel_build")
    BUILD_LOG_FILE="$BUILD_WORKSPACE/build.log"

    module_info_msg "Setting up build environment in: $BUILD_WORKSPACE"

    # Setup kernel source
    local kernel_dir=$(core_get_config KERNEL_SOURCE_DIR)
    local kernel_url=$(core_get_config KERNEL_SOURCE_URL)
    local kernel_branch=$(core_get_config KERNEL_BRANCH "main")

    if [[ -n "$kernel_dir" ]]; then
        # Copy existing kernel source
        module_info_msg "Copying kernel source from: $kernel_dir"
        if [[ "$DRY_RUN" == "true" ]]; then
            module_info_msg "DRY RUN: Would copy kernel source"
        else
            cp -r "$kernel_dir" "$BUILD_WORKSPACE/kernel"
        fi
    elif [[ -n "$kernel_url" ]]; then
        # Clone kernel source
        module_info_msg "Cloning kernel source from: $kernel_url"
        if [[ "$DRY_RUN" == "true" ]]; then
            module_info_msg "DRY RUN: Would clone kernel source"
            mkdir -p "$BUILD_WORKSPACE/kernel"
        else
            if ! git clone --depth 1 --branch "$kernel_branch" "$kernel_url" "$BUILD_WORKSPACE/kernel"; then
                module_error "Failed to clone kernel source"
                return 1
            fi
        fi
    fi

    # Change to kernel directory
    cd "$BUILD_WORKSPACE/kernel" || return 1

    # Setup build variables
    local arch=$(core_get_config BUILD_ARCH)
    local cross_compile=$(core_get_config BUILD_CROSS_COMPILE)
    local jobs=$(core_get_config BUILD_JOBS)

    export ARCH="$arch"
    if [[ -n "$cross_compile" ]]; then
        export CROSS_COMPILE="$cross_compile"
    fi

    core_success "Build environment ready"
    return 0
}

# Configure kernel
module_build_configure() {
    module_info_msg "Configuring kernel"

    local defconfig=$(core_get_config ADVANCED_CUSTOM_DEFCONFIG)
    local custom_makefile=$(core_get_config ADVANCED_CUSTOM_MAKEFILE)

    if [[ "$DRY_RUN" == "true" ]]; then
        module_info_msg "DRY RUN: Would configure kernel"
        return 0
    fi

    # Use custom defconfig if specified
    if [[ -n "$defconfig" ]]; then
        if [[ -f "arch/$ARCH/configs/$defconfig" ]]; then
            module_info_msg "Using defconfig: $defconfig"
            if ! make "$defconfig" >> "$BUILD_LOG_FILE" 2>&1; then
                module_error "Failed to apply defconfig: $defconfig"
                return 1
            fi
        else
            module_warn "Defconfig not found: $defconfig, using default"
            if ! make defconfig >> "$BUILD_LOG_FILE" 2>&1; then
                module_error "Failed to create default configuration"
                return 1
            fi
        fi
    else
        # Use default defconfig
        module_info_msg "Using default defconfig"
        if ! make defconfig >> "$BUILD_LOG_FILE" 2>&1; then
            module_error "Failed to create default configuration"
            return 1
        fi
    fi

    # Apply custom makefile if specified
    if [[ -n "$custom_makefile" && -f "$custom_makefile" ]]; then
        module_info_msg "Applying custom makefile: $custom_makefile"
        cat "$custom_makefile" >> Makefile
    fi

    core_success "Kernel configuration complete"
    return 0
}

# Build kernel
module_build_kernel() {
    module_info_msg "Building kernel"

    local jobs=$(core_get_config BUILD_JOBS)
    local extra_cflags=$(core_get_config ADVANCED_EXTRA_CFLAGS)

    if [[ "$DRY_RUN" == "true" ]]; then
        module_info_msg "DRY RUN: Would build kernel with $jobs jobs"
        return 0
    fi

    # Set extra CFLAGS if specified
    if [[ -n "$extra_cflags" ]]; then
        export KCFLAGS="$extra_cflags"
        module_info_msg "Using extra CFLAGS: $extra_cflags"
    fi

    # Build kernel image
    module_info_msg "Building kernel image with $jobs jobs"

    local start_time=$(date +%s)
    if make -j"$jobs" Image >> "$BUILD_LOG_FILE" 2>&1; then
        local end_time=$(date +%s)
        local build_time=$((end_time - start_time))
        core_success "Kernel image built successfully in ${build_time}s"
    else
        module_error "Kernel build failed"
        module_info_msg "Check build log: $BUILD_LOG_FILE"
        return 1
    fi

    # Build modules if needed
    if [[ -f "Module.symvers" ]] || make -n modules >/dev/null 2>&1; then
        module_info_msg "Building kernel modules"

        if make -j"$jobs" modules >> "$BUILD_LOG_FILE" 2>&1; then
            core_success "Kernel modules built successfully"
        else
            module_warn "Kernel modules build failed"
        fi
    fi

    # Build device tree if available
    if [[ -d "arch/$ARCH/boot/dts" ]]; then
        module_info_msg "Building device tree blobs"

        if make -j"$jobs" dtbs >> "$BUILD_LOG_FILE" 2>&1; then
            core_success "Device tree blobs built successfully"
        else
            module_warn "Device tree build failed"
        fi
    fi

    return 0
}

# Post-build processing
module_build_post_process() {
    module_info_msg "Post-build processing"

    if [[ "$DRY_RUN" == "true" ]]; then
        module_info_msg "DRY RUN: Would process build output"
        return 0
    fi

    # Create output directory
    local output_dir=$(core_get_config BUILD_OUTPUT_DIR "output")
    output_dir="$BUILD_WORKSPACE/$output_dir"
    mkdir -p "$output_dir"

    # Copy build artifacts
    local arch=$(core_get_config BUILD_ARCH)

    # Kernel image
    if [[ -f "arch/$arch/boot/Image" ]]; then
        cp "arch/$arch/boot/Image" "$output_dir/"
        module_info_msg "Kernel image: $output_dir/Image"
    elif [[ -f "arch/$arch/boot/zImage" ]]; then
        cp "arch/$arch/boot/zImage" "$output_dir/"
        module_info_msg "Kernel image: $output_dir/zImage"
    elif [[ -f "arch/$arch/boot/uImage" ]]; then
        cp "arch/$arch/boot/uImage" "$output_dir/"
        module_info_msg "Kernel image: $output_dir/uImage"
    else
        module_warn "Kernel image not found in expected locations"
    fi

    # Device tree blobs
    if [[ -d "arch/$arch/boot/dts" ]]; then
        mkdir -p "$output_dir/dtb"
        find "arch/$arch/boot/dts" -name "*.dtb" -exec cp {} "$output_dir/dtb/" \;
        module_info_msg "Device trees copied to: $output_dir/dtb/"
    fi

    # Kernel modules
    if [[ -d "modules" ]]; then
        cp -r "modules" "$output_dir/"
        module_info_msg "Modules copied to: $output_dir/modules/"
    fi

    # Build log
    cp "$BUILD_LOG_FILE" "$output_dir/"
    module_info_msg "Build log: $output_dir/build.log"

    # Create build summary
    module_build_create_summary "$output_dir"

    core_success "Build artifacts ready in: $output_dir"
    return 0
}

# Create build summary
module_build_create_summary() {
    local output_dir="$1"
    local summary_file="$output_dir/build_summary.txt"

    {
        echo "KernelX Build Summary"
        echo "===================="
        echo "Build Date: $(date)"
        echo "KernelX Version: $KERNELX_VERSION"
        echo "Build Profile: $(core_get_config KERNELX_PROFILE "default")"
        echo "Device: $(core_get_config DEVICE_NAME "unknown")"
        echo "Architecture: $(core_get_config BUILD_ARCH)"
        echo "Cross Compile: $(core_get_config BUILD_CROSS_COMPILE "native")"
        echo
        echo "Kernel Source:"
        echo "  $(core_get_config KERNEL_SOURCE_URL "$(core_get_config KERNEL_SOURCE_DIR)")"
        echo
        echo "Build Output:"
        ls -la "$output_dir" | grep -v "^total"
        echo
        echo "Build Log: build.log"
    } > "$summary_file"

    module_info_msg "Build summary created: $summary_file"
}

# Verify build
module_build_verify() {
    module_info_msg "Verifying build output"

    if [[ "$DRY_RUN" == "true" ]]; then
        module_info_msg "DRY RUN: Would verify build"
        return 0
    fi

    local output_dir="$BUILD_WORKSPACE/$(core_get_config BUILD_OUTPUT_DIR "output")"
    local errors=()

    # Check for kernel image
    if [[ ! -f "$output_dir/Image" && ! -f "$output_dir/zImage" && ! -f "$output_dir/uImage" ]]; then
        errors+=("No kernel image found in output directory")
    fi

    # Check kernel image size
    local kernel_file=""
    if [[ -f "$output_dir/Image" ]]; then
        kernel_file="$output_dir/Image"
    elif [[ -f "$output_dir/zImage" ]]; then
        kernel_file="$output_dir/zImage"
    elif [[ -f "$output_dir/uImage" ]]; then
        kernel_file="$output_dir/uImage"
    fi

    if [[ -n "$kernel_file" ]]; then
        local size
        size=$(stat -c %s "$kernel_file" 2>/dev/null || stat -f %z "$kernel_file" 2>/dev/null)
        if [[ $size -lt 1000000 ]]; then
            errors+=("Kernel image seems too small: $size bytes")
        fi

        # Basic file format check
        if ! file "$kernel_file" | grep -q "Linux kernel"; then
            errors+=("Kernel image format verification failed")
        fi
    fi

    # Check build log for errors
    if [[ -f "$output_dir/build.log" ]]; then
        local error_count
        error_count=$(grep -c "error:" "$output_dir/build.log" 2>/dev/null || echo "0")
        if [[ $error_count -gt 0 ]]; then
            errors+=("$error_count errors found in build log")
        fi
    fi

    # Report results
    if [[ ${#errors[@]} -gt 0 ]]; then
        module_error "Build verification failed:"
        for error in "${errors[@]}"; do
            echo "  ❌ $error"
        done
        return 1
    else
        core_success "Build verification passed"
        return 0
    fi
}

# Clean build artifacts
module_build_clean() {
    if [[ -n "$BUILD_WORKSPACE" && -d "$BUILD_WORKSPACE" ]]; then
        module_info_msg "Cleaning build workspace: $BUILD_WORKSPACE"

        if [[ "$DRY_RUN" == "true" ]]; then
            module_info_msg "DRY RUN: Would clean build workspace"
        else
            rm -rf "$BUILD_WORKSPACE"
            core_success "Build workspace cleaned"
        fi
    else
        module_info_msg "No build workspace to clean"
    fi
}

# Show build information
module_build_info() {
    echo "Build Information:"
    echo "=================="

    if [[ -n "$BUILD_WORKSPACE" && -d "$BUILD_WORKSPACE" ]]; then
        echo "Active Build Workspace: $BUILD_WORKSPACE"

        if [[ -f "$BUILD_LOG_FILE" ]]; then
            echo "Build Log: $BUILD_LOG_FILE"
            echo "Build Status: $(grep -q "Kernel build failed" "$BUILD_LOG_FILE" && echo "Failed" || echo "In Progress/Completed")"
        fi

        local output_dir="$BUILD_WORKSPACE/$(core_get_config BUILD_OUTPUT_DIR "output")"
        if [[ -d "$output_dir" ]]; then
            echo "Output Directory: $output_dir"
            echo "Output Contents:"
            ls -la "$output_dir" 2>/dev/null | tail -n +2 | head -10
        fi
    else
        echo "No active build workspace"
    fi

    echo
    echo "Build Configuration:"
    echo "  Architecture: $(core_get_config BUILD_ARCH)"
    echo "  Cross Compile: $(core_get_config BUILD_CROSS_COMPILE "native")"
    echo "  Jobs: $(core_get_config BUILD_JOBS)"
    echo "  Output Dir: $(core_get_config BUILD_OUTPUT_DIR "output")"
}

# Export module functions
export -f module_build_run
export -f module_build_validate_requirements
export -f module_build_setup_environment
export -f module_build_configure
export -f module_build_kernel
export -f module_build_post_process
export -f module_build_verify
export -f module_build_clean
export -f module_build_info
export -f module_build_create_summary
