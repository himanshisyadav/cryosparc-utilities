#!/bin/bash

#Copy script to PI's /beagle3/pi_cnetid folder, so the user's account has permissions to run it 
#Run this script after logging into the user's account on the beagle3 login node where the installation will be. 

set -e

# Install a specific CryoSPARC version

pi_cnetid="$1"
user_cnetid="$2"
license_id="$3"
base_port="$4"
install_dir="/beagle3/$pi_cnetid/cryosparc_$user_cnetid"
password="$5"
firstname="$6"
lastname="$7"

install_cmd="$install_dir/master/install.sh"
cryosparc_bin_dir="$install_dir/master/bin"

if [[ -f "$install_cmd" ]]; then
  bash "$install_cmd" --yes --insecure \
    --license "$license_id" \
    --dbpath "$install_dir/db" \
    --port "$base_port"

  if [[ $? -eq 0 ]]; then
    echo "CryoSPARC installed successfully in $install_dir"

    # 1. Add the path to ~/.bashrc

    # Check if the line is already in .bashrc to avoid duplicates.
    if ! grep -q "export PATH=\"\$PATH:$cryosparc_bin_dir\"" ~/.bashrc; then  # -q for quiet (no output)
      echo "Adding CryoSPARC bin directory i.e. $cryosparc_bin_dir to PATH in ~/.bashrc"
      echo "export PATH=\"\$PATH:$cryosparc_bin_dir\"" >> ~/.bashrc 
    else
        echo "Cryosparc path already in .bashrc"
    fi

    # 2. Source ~/.bashrc to apply the changes immediately

    echo "Sourcing ~/.bashrc to apply changes..."
    source ~/.bashrc

    echo "CryoSPARC bin directory added to PATH and sourced."

    # Optional: Verify the PATH
    echo "Current PATH: $PATH" # Check if the directory is there

    # Start CryoSPARC master
    cryosparcm start

    # Create user (replace with actual details)
    cryosparcm createuser --email "$user_cnetid@uchicago.edu" \
      --password "$password"\
      --username "$user_cnetid" \
      --firstname "$firstname" \
      --lastname "$lastname"

      # Copy cluster files
    cp /software/src/cryosparc_install/cluster_info.json "$install_dir/master/"
    cp /software/src/cryosparc_install/cluster_script.sh "$install_dir/master/"

    # Change account name in cluster_script.sh 
    sed -i "s/^#SBATCH --account=[^ ]*/#SBATCH --account=pi-$pi_cnetid/" "$install_dir/master/cluster_script.sh" 
    echo "Account name in cluster_script.sh changed to pi-$pi_cnetid"

    # Check if the install directory exists
    if [ ! -d "$install_dir/master" ]; then
      echo "Error: CryoSPARC master directory not found at $install_dir/master"
      exit 1
    fi

    cd "$install_dir/master" || {  # The || handles the cd failure case
      echo "Error: Failed to cd to $install_dir/master"
      exit 1
    }

    # Connect to cluster
    cryosparcm cluster connect
  else
    echo "Error: CryoSPARC installation failed."
  fi
else
  echo "Error: Installer script not found at $install_cmd"
fi


