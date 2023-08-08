#!/bin/bash
set -x

# Install NVIDIA driver
dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda -y
