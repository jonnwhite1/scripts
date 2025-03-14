#!/bin/bash

# Print hostname
hostname=$(hostname)
echo "============================="
echo "Maintenance started on: $(date)"
echo "Host: $hostname"
echo "============================="

# Host maintenance
echo "Running apt update..."
output=$(sudo DEBIAN_FRONTEND=noninteractive apt update -y 2>&1)

# Check for errors during the update process
if echo "$output" | grep -q "Err:"; then
    echo "❌ An error occurred while running 'apt update'."
    exit 1
fi

# Check if there are any packages available for upgrade
if echo "$output" | grep -q "can be upgraded"; then
    echo "Packages can be upgraded. Proceeding with upgrade..."

    # Run apt upgrade safely
    upgrade_output=$(NEEDRESTART_MODE=a sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y 2>&1)
    
    # Extract upgraded packages
    upgraded_packages=$(echo "$upgrade_output" | grep -E "^Inst|^Conf|^Unpacking|^Setting up")

    if [ -n "$upgraded_packages" ]; then
        echo "✅ Upgraded packages:"
        echo "$upgraded_packages" | awk '{print $2}' | sort | uniq
    else
        echo "✅ No packages were upgraded."
    fi
else
    echo "✅ System is already up-to-date."
fi


# Docker maintenance - Only run this if it's Sunday
# Get the day of the week (0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thur, 5=Fri, 6=Sat)
day_of_week=$(date +%w)

if [ ! "$day_of_week" -eq 0 ]; then
    echo "❌ Today is not Sunday, no need to perform Docker maintenance."
fi

if [ "$day_of_week" -eq 0 ]; then
    echo "🔄 Today is Sunday. Performing Docker maintenance."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "⚠️ Docker is not installed on $hostname. Skipping Docker maintenance."
        exit 0
    fi

    echo "✅ Docker is installed. Performing maintenance..."
    
    # Get current Docker version
    docker_version=$(docker --version)
    echo "🛠️ Current Docker version: $docker_version"

    # Update Docker if necessary
    echo "🔄 Checking for Docker updates..."
    docker_update_output=$(sudo apt-get install --only-upgrade docker-ce docker-ce-cli containerd.io -y 2>&1)
    
    # Extract upgraded Docker components
    docker_upgraded_packages=$(echo "$docker_update_output" | grep -E "^(Setting up|Preparing to unpack|Unpacking) ")
    
    if [ -n "$docker_upgraded_packages" ]; then
        echo "✅ Docker components upgraded:"
        echo "$docker_upgraded_packages" | awk '{print $NF}' | sort | uniq
    else
        echo "✅ No Docker components were upgraded."
    fi

    # Restart running Docker containers
    echo "🔄 Restarting all running Docker containers..."
    container_count=$(docker ps -q | wc -l)

    if [ "$container_count" -gt 0 ]; then
        echo "✅ Found $container_count running container(s). Restarting now..."
        docker ps -q | xargs --no-run-if-empty docker restart
        echo "✅ Restart completed."
    else
        echo "⚠️ No running containers to restart."
    fi
fi

echo "🎉 Maintenance script completed on: $(date)"
echo "====================================="