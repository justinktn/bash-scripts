#!/bin/bash
set -x

##### Configuring GRUB #####
echo "Adding necessary GRUB parameters"
sleep 1

# GRUB parameters to add
grub_params="intel_iommu=on iommu=pt"

# Get the current GRUB configuration
current_config=$(grep "^GRUB_CMDLINE_LINUX=" /etc/default/grub)

# Check if the parameters are already present
if [[ $current_config == *"$grub_params"* ]]; then
    echo "Parameters already present in GRUB config. No changes needed."
else
    # Add the new parameters to the existing GRUB configuration
    grub_config="${current_config%\"} ${grub_params}\""
    sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"$new_config|" /etc/default/grub

    # Update GRUB
    grub2-mkconfig -o /boot/grub2/grub.cfg
    echo "Parameters added to GRUB config. GRUB updated."
fi


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

# Stop script for 2 seconds
sleep 2

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


##### Asking user to reboot #####
echo "Please reboot this machine"
