#!/bin/bash
set -x

# Install NVIDIA driver
dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda -y

# Notify user to reboot the computer
echo "Please reboot this machine"
