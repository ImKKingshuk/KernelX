#!/bin/bash


print_banner() {
    local banner=(
        "******************************************"
        "*                 KernelX                *"
        "*        The Ultimate Kernel Kitchen     *"
        "*                  v1.0.0                *"
        "*      ----------------------------      *"
        "*                        by @ImKKingshuk *"
        "* Github- https://github.com/ImKKingshuk *"
        "******************************************"
    )
    local width=$(tput cols)
    for line in "${banner[@]}"; do
        printf "%*s\n" $(((${#line} + width) / 2)) "$line"
    done
    echo
}


source ./scripts/common.sh


prompt_for_config() {
    echo "KernelX Configuration Setup"
    echo "---------------------------"
    
    read -p "Enter Kernel Name [default: $KERNEL_NAME]: " input
    KERNEL_NAME=${input:-$KERNEL_NAME}
    
    read -p "Enter Kernel Version [default: $KERNEL_VERSION]: " input
    KERNEL_VERSION=${input:-$KERNEL_VERSION}
    
    read -p "Enter Ramdisk Path [default: $RAMDISK_PATH]: " input
    RAMDISK_PATH=${input:-$RAMDISK_PATH}
    
    read -p "Enter Patch Path [default: $PATCH_PATH]: " input
    PATCH_PATH=${input:-$PATCH_PATH}
    
    read -p "Enter Output Directory [default: $OUTPUT_DIR]: " input
    OUTPUT_DIR=${input:-$OUTPUT_DIR}
    
    echo "Configuration complete!"
    echo "Kernel Name: $KERNEL_NAME"
    echo "Kernel Version: $KERNEL_VERSION"
    echo "Ramdisk Path: $RAMDISK_PATH"
    echo "Patch Path: $PATCH_PATH"
    echo "Output Directory: $OUTPUT_DIR"
    echo
}


main() {
    print_banner
    
  
    load_config
    
   
    prompt_for_config
    
  
    source ./scripts/device_detection.sh
    detect_device
    
  
    source ./scripts/ramdisk_management.sh
    manage_ramdisk
    
   
    source ./scripts/kernel_patching.sh
    patch_kernel
    
  
    finalize
    
    echo "KernelX has successfully completed the process!"
}


main