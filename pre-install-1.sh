#!/bin/bash

# Allow 10 packages to be downloaded in parallel
cat << EOF >> /etc/dnf/dnf.conf
max_parallel_downloads=10
EOF

# Update the system to the latest version that is currently available
dnf update -y

# Enable RPM Pusion free and non-free repositories
dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y

# Update the repository
dnf update --refresh -y

# Notify user to reboot the computer
echo "Please reboot this machine"
