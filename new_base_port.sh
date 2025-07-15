#!/bin/bash

#################################################################
# CryoSPARC Manager Script
# 
# Description: This script combines shutdown, free port finding, and 
#              base port configuration updating for CryoSPARC
#
# Author: Himi Yadav
# Date: July 15, 2025
# Version: 1.0
#
# Usage: ./new_base_port.sh
#
# Requirements:
#   - CryoSPARC installation
#   - ss command for port checking
#   - Appropriate permissions for config file access
#################################################################

# Define the port range and block size for port search
START_PORT=39100
END_PORT=39500
BLOCK_SIZE=10

# Function to stop CryoSPARC
stop_cryosparc() {
    echo "=========================================="
    echo "STOPPING CRYOSPARC"
    echo "=========================================="
    
    # Stop CryoSPARC using the official command
    echo "Stopping CryoSPARC..."
    cryosparcm stop

    # Function to find and kill processes
    kill_processes() {
        local process_name=$1
        echo "Checking for $process_name processes..."
        
        # Find PIDs for the process (filtered by current user)
        pids=$(ps -ax | grep "$USER" | grep "$process_name" | grep -v grep | awk '{print $1}')
        
        if [ -n "$pids" ]; then
            echo "Found $process_name processes with PIDs: $pids"
            for pid in $pids; do
                echo "Killing PID $pid..."
                kill "$pid"
            done
        else
            echo "No $process_name processes found"
        fi
    }

    # Wait a moment for graceful shutdown
    sleep 2

    # Kill remaining processes
    kill_processes "supervisord"
    kill_processes "cryosparc"
    kill_processes "mongod"

    echo "CryoSPARC shutdown complete"
    echo ""
}

# Function to find free port block
find_free_port_block() {
    echo "=========================================="
    echo "FINDING FREE PORT BLOCK"
    echo "=========================================="
    
    echo "Searching for $BLOCK_SIZE consecutive free ports between $START_PORT and $END_PORT..."
    echo "Note: This script checks for ports not currently in use by processes visible to the current user."

    # Loop through the port range, incrementing by the block size
    for (( current_block_start=$START_PORT; current_block_start<=$((END_PORT - BLOCK_SIZE + 1)); current_block_start+=BLOCK_SIZE ))
    do
        is_block_free=true
        current_block_end=$((current_block_start + BLOCK_SIZE - 1))

        echo "  Checking block: $current_block_start - $current_block_end"

        # Check each port within the current block
        for (( port=$current_block_start; port<=$current_block_end; port++ ))
        do
            if ss -tuln | grep -qE "(0\.0\.0\.0:$port|[\[\]:]:$port)"; then
                echo "    Port $port is in use. This block is not entirely free."
                is_block_free=false
                break
            fi
        done

        # If the inner loop completed without finding any used ports, the block is free
        if $is_block_free; then
            echo ""
            echo "****************************************************************"
            echo "Found $BLOCK_SIZE consecutive free ports starting from $current_block_start:"
            for (( p=$current_block_start; p<=$current_block_end; p++ ))
            do
                echo "  - $p"
            done
            echo "****************************************************************"
            echo ""
            FOUND_FREE_PORT=$current_block_start
            return 0
        fi
    done

    echo ""
    echo "----------------------------------------------------------------"
    echo "No block of $BLOCK_SIZE consecutive free ports found in the range $START_PORT-$END_PORT."
    echo "----------------------------------------------------------------"
    FOUND_FREE_PORT=-1
    return 1
}

# Function to update config
update_config() {
    local pi_cnetid=$1
    local user_cnetid=$2
    local base_port=$3
    
    echo "=========================================="
    echo "UPDATING CONFIGURATION"
    echo "=========================================="
    
    # Construct the config file path
    config_file="/beagle3/${pi_cnetid}/cryosparc_${user_cnetid}/master/config.sh"

    # Check if config file exists
    if [ ! -f "$config_file" ]; then
        echo "Error: Config file not found at $config_file"
        return 1
    fi

    # Create backup of original config
    backup_file="${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$config_file" "$backup_file"
    echo "Backup created: $backup_file"

    # Update the base port in the config file
    if grep -q "^export CRYOSPARC_BASE_PORT=" "$config_file"; then
        # Replace existing CRYOSPARC_BASE_PORT line
        sed -i "s/^export CRYOSPARC_BASE_PORT=.*/export CRYOSPARC_BASE_PORT=$base_port/" "$config_file"
        echo "Updated CRYOSPARC_BASE_PORT to $base_port in $config_file"
    else
        echo "Warning: CRYOSPARC_BASE_PORT not found in config file"
        echo "Adding CRYOSPARC_BASE_PORT=$base_port to config file"
        # Add the line after the Instance Configuration comment
        sed -i "/# Instance Configuration/a export CRYOSPARC_BASE_PORT=$base_port" "$config_file"
    fi

    # Verify the change
    echo ""
    echo "Verification - Current CRYOSPARC_BASE_PORT setting:"
    grep "^export CRYOSPARC_BASE_PORT=" "$config_file"

    echo ""
    echo "Configuration updated successfully!"
    echo "Config file: $config_file"
    echo "Backup file: $backup_file"
    return 0
}

# Function to prompt for input
prompt_input() {
    local prompt_msg=$1
    local var_name=$2
    
    while true; do
        read -p "$prompt_msg: " input
        if [ -n "$input" ]; then
            eval "$var_name='$input'"
            break
        else
            echo "Input cannot be empty. Please try again."
        fi
    done
}

# Main script execution
echo "CryoSPARC Manager Script to Update Base Port"
echo "========================"
echo ""

# Step 1: Stop CryoSPARC
stop_cryosparc

# Step 2: Find free port block
find_free_port_block

if [ $FOUND_FREE_PORT -eq -1 ]; then
    echo "Cannot proceed without a free port block. Exiting."
    exit 1
fi

free_port_start=$FOUND_FREE_PORT

# Step 3: Get user inputs
echo "=========================================="
echo "CONFIGURATION SETUP"
echo "=========================================="

prompt_input "Enter PI CNET ID" pi_cnetid
prompt_input "Enter User CNET ID" user_cnetid

# Ask if user wants to use the found free port or specify their own
echo ""
echo "Found free port block starting at: $free_port_start"
read -p "Use this port ($free_port_start) or specify your own? (u/s): " port_choice

if [ "$port_choice" = "s" ] || [ "$port_choice" = "S" ]; then
    prompt_input "Enter Base Port Number" base_port
    
    # Validate port number
    if ! [[ "$base_port" =~ ^[0-9]+$ ]] || [ "$base_port" -lt 1024 ] || [ "$base_port" -gt 65535 ]; then
        echo "Error: Base port must be a number between 1024 and 65535"
        exit 1
    fi
else
    base_port=$free_port_start
fi

# Step 4: Update configuration
update_config "$pi_cnetid" "$user_cnetid" "$base_port"

if [ $? -ne 0 ]; then
    echo ""
    echo "=========================================="
    echo "SCRIPT COMPLETED WITH ERRORS"
    echo "=========================================="
    echo "Please check the error messages above."
    exit 1
fi

# Step 5: Apply port changes to CryoSPARC
apply_port_changes() {
    echo "=========================================="
    echo "APPLYING PORT CHANGES TO CRYOSPARC"
    echo "=========================================="
    
    echo "Step 1: Starting CryoSPARC database..."
    cryosparcm start database &
    
    echo "Waiting 30 seconds for database to start..."
    sleep 30
    
    echo "Step 2: Fixing database port..."
    cryosparcm fixdbport &
    
    echo "Step 3: Restarting CryoSPARC..."
    cryosparcm restart &
    
    echo "Waiting 30 seconds for restart to complete..."
    sleep 30
    
    echo "Step 4: Final stop and start cycle..."
    echo "  Stopping CryoSPARC..."
    cryosparcm stop
    
    echo "  Starting CryoSPARC..."
    cryosparcm start
    
    echo "Port changes applied successfully!"
    echo ""
}

apply_port_changes

echo ""
echo "=========================================="
echo "SCRIPT COMPLETED SUCCESSFULLY"
echo "=========================================="
echo "CryoSPARC has been stopped, reconfigured, and restarted."
echo "Base port set to: $base_port"
echo "CryoSPARC should now be running on the new port configuration."