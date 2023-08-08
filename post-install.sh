#!/bin/bash

##### Install necessary virtualization packages #####
echo "Installing virtualization packages"
sleep 1

dnf update
dnf install @virtualization -y
systemctl enable libvirtd --now
usermod -aG libvirt $USER


##### Configuring GRUB #####
echo "Adding necessary GRUB parameters"
sleep 1

cp /etc/default/grub new_grub

# Detecting CPU
CPU=$(lscpu | grep GenuineIntel | rev | cut -d ' ' -f 1 | rev )

INTEL="0"

if [ "$CPU" = "GenuineIntel" ]
	then
	INTEL="1"
fi

# Building string intel_iommu=on or amd_iommu=on
if [ $INTEL = 1 ]
	then
	IOMMU="intel_iommu=on iommu=pt"
	echo "Set intel_iommu=on"
	else
	IOMMU="amd_iommu=on iommu=pt"
	echo "Set amd_iommu=on"
fi

# Putting together new grub string
OLD_OPTIONS=`cat new_grub | grep GRUB_CMDLINE_LINUX | cut -d '"' -f 1,2`

NEW_OPTIONS="$OLD_OPTIONS $IOMMU\""
echo $NEW_OPTIONS

# Rebuilding grub
sed -i -e "s|^GRUB_CMDLINE_LINUX.*|${NEW_OPTIONS}|" new_grub

mv new_grub /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg


##### Installing Libvirt automation #####
echo "Installing Libvirt automation (VFIO-Tools Hook Helper) into system"
sleep 1

# Adding "hooks" folder inside /etc/libvirt
mkdir -p /etc/libvirt/hooks

# Pulling hook helper from GitHub
wget 'https://raw.githubusercontent.com/PassthroughPOST/VFIO-Tools/master/libvirt_hooks/qemu' -O /etc/libvirt/hooks/qemu

# Making hook helper executable
chmod +x /etc/libvirt/hooks/qemu

# Restarting Libvirt service
systemctl restart libvirtd


##### Adding start and stop script for Libvirt automation #####
echo "Configuring Libvirt automation"

# Creating start file
mkdir -p /etc/libvirt/hooks/qemu.d/windows11-main/prepare/begin/

touch /etc/libvirt/hooks/qemu.d/windows11-main/prepare/begin/start.sh

cat << EOF > /etc/libvirt/hooks/qemu.d/windows11-main/prepare/begin/start.sh
#!/bin/bash
set -x

# Stop display manager
systemctl stop display-manager
killall gdm-x-session

# Unbind VTconsoles: might not be needed
echo 0 > /sys/class/vtconsole/vtcon0/bind
echo 0 > /sys/class/vtconsole/vtcon1/bind

# Unbind EFI Framebuffer
echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

# Stop script for 1 seconds
sleep 1

# Unload NVIDIA kernel modules
modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia

# Unload AMD kernel module
#modprobe -r amdgpu

# Detach GPU devices from host
# Use your GPU and HDMI Audio PCI host device
virsh nodedev-detach pci_0000_01_00_0
virsh nodedev-detach pci_0000_01_00_1

# Load vfio module
modprobe vfio-pci
EOF

chmod +x /etc/libvirt/hooks/qemu.d/windows11-main/prepare/begin/start.sh

# Creating stop file
mkdir -p /etc/libvirt/hooks/qemu.d/windows11-main/release/end/

touch /etc/libvirt/hooks/qemu.d/windows11-main/release/end/stop.sh

cat << EOF > /etc/libvirt/hooks/qemu.d/windows11-main/release/end/stop.sh
#!/bin/bash
set -x

# Attach GPU devices to host
# Use your GPU and HDMI Audio PCI host device
virsh nodedev-reattach pci_0000_01_00_0
virsh nodedev-reattach pci_0000_01_00_1

# Unload vfio module
modprobe -r vfio-pci

# Load AMD kernel module
#modprobe amdgpu

# Rebind framebuffer to host
echo "efi-framebuffer.0" > /sys/bus/platform/drivers/efi-framebuffer/bind

# Load NVIDIA kernel modules
modprobe nvidia_drm
modprobe nvidia_modeset
modprobe nvidia_uvm
modprobe nvidia

# Bind VTconsoles: might not be needed
echo 1 > /sys/class/vtconsole/vtcon0/bind
echo 1 > /sys/class/vtconsole/vtcon1/bind

# Restart Display Manager
systemctl start display-manager
EOF

chmod +x /etc/libvirt/hooks/qemu.d/windows11-main/release/end/stop.sh


##### Defining VM with virsh #####
echo "Adding VM config to system"
sleep 1

cp windows11-main.xml /etc/libvirt/qemu/ -v
virsh define /etc/libvirt/qemu/windows11-main


##### Adding GPU ROM File #####
mkdir /usr/share/vgabios
cp GP107.rom /usr/share/vgabios -v


##### Notify user to reboot the computer #####
echo "Please reboot this machine"
