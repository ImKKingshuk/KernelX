#!/bin/bash

# KernelX
# Author: @ImKKingshuk

patch_kernel() {
    log "Patching kernel..."
    
   
    patch -p1 < /path/to/patch.diff || error_exit "Failed to apply kernel patch!"
    
    log "Kernel patched successfully!"
    
    
}