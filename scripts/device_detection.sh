#!/bin/bash


detect_device() {
    log "Detecting device..."
    DEVICE=$(getprop ro.product.device)
    
    if [ -z "$DEVICE" ]; then
        error_exit "Device detection failed!"
    fi
    
    log "Device detected: $DEVICE"
    
    
    if [ -f ./config/device_configs/$DEVICE.config ]; then
        source ./config/device_configs/$DEVICE.config
        log "Loaded configuration for $DEVICE"
    else
        log "No specific configuration found for $DEVICE, using default settings."
    fi
}