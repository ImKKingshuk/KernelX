#!/bin/bash

# KernelX
# Author: @ImKKingshuk


load_config() {
    if [ -f ./config/default.config ]; then
        source ./config/default.config
    else
        echo "Default configuration not found!"
        exit 1
    fi
}


log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}


error_exit() {
    log "ERROR: $1"
    exit 1
}


KERNEL_NAME="KernelX"
KERNEL_VERSION="1.0.0"
RAMDISK_PATH="/path/to/ramdisk.img"
PATCH_PATH="/path/to/patches/"
OUTPUT_DIR="/path/to/output/"
LOG_LEVEL="INFO"