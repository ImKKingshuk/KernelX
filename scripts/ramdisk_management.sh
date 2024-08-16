#!/bin/bash

# KernelX
# Author: @ImKKingshuk

manage_ramdisk() {
    log "Managing ramdisk..."
    
   
    mkdir -p /tmp/kernelx/ramdisk
    cd /tmp/kernelx/ramdisk || error_exit "Failed to change directory"
    
    if ! cpio -i < /path/to/ramdisk.img; then
        error_exit "Failed to extract ramdisk!"
    fi
    
    log "Ramdisk extracted successfully!"
    
   
}