#!/bin/bash

#Before running this script, add yourself to pi_cnetid group on my.rcc

# Define variables
CRYOSPARC_VERSIONS=("3" "4.1.2" "4.4.0" "4.5.1" "4.6") 
CRYOSPARC_BASE_DIR="/software/src"

set -e

version="$1"
pi_cnetid="$2"
username="$3"
install_dir="/beagle3/$pi_cnetid/cryosparc_$username"
source_file="" # Initialize source file variable

# Create directories
mkdir "$install_dir"
mkdir "$install_dir/db"
mkdir "$install_dir/projects"

case "$version" in
  "3")
    source_file="$CRYOSPARC_BASE_DIR/cryosparc_install/cryosparc_master.tar.gz"
    ;;
  "4.1.2")
    source_file="$CRYOSPARC_BASE_DIR/cryosparc_4.1.2/cryosparc_master.tar.gz"
    ;;
  "4.4.0")
      source_file="$CRYOSPARC_BASE_DIR/cryosparc_4.4/cryosparc_master.tar.gz"
    ;;
  "4.5.1")
    source_file="$CRYOSPARC_BASE_DIR/cryosparc_4.5.1/cryosparc_master.tar.gz"
    ;;
  "4.6")
    source_file="$CRYOSPARC_BASE_DIR/cryosparc_4.6/cryosparc_master.tar.gz"
    ;;
  *)
    echo "Error: Invalid CryoSPARC version: $version"
    ;;
esac

if [[ ! -f "$source_file" ]]; then
      echo "Error: CryoSPARC $version source file not found at $source_file"
fi

echo "Tar-ing CryoSPARC $version from $source_file into $install_dir/cryosparc_master"
tar -xzf "$source_file" -C "$install_dir"

# Rename cryosparc_master directory to master (if it exists)
if [[ -d "$install_dir/cryosparc_master" ]]; then
  mv "$install_dir/cryosparc_master" "$install_dir/master"
    echo "Renamed cryosparc_master to master"
fi

# Check the return code of the function:
if [[ $? -eq 0 ]]; then
  echo "CryoSPARC $version_to_install initial setup successful!"
else
  echo "CryoSPARC $version_to_install initial setup failed. Check the error messages above."
fi

## After this request sudo access to the user's account and change user's CryoSPARC directory ownership to the user, instead of your account with systems team's help 
