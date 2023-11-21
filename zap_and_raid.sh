#!/bin/bash

echo "Starting the RAID setup for Armbian on Raspberry Pi 4..."
read -p "Please enter the direct download link for the Armbian image: " ARMBIAN_URL
read -p "Please enter a label for the large storage partition (md1): " STORAGE_LABEL

# Install required tools if not present
if ! command -v sgdisk &> /dev/null || ! command -v mdadm &> /dev/null; then
    echo "sgdisk and mdadm are required but not installed. Installing them now..."
    sudo apt-get update
    sudo apt-get install -y gdisk mdadm wget
fi

# Download the Armbian image
echo "Downloading the Armbian image..."
wget "$ARMBIAN_URL" -O armbian.img.xz

# Extract the Armbian image
echo "Extracting the Armbian image..."
unxz armbian.img.xz

# Confirm with the user before proceeding to wipe drives
echo "This script will wipe the specified drives and configure them for RAID 1."
read -p "Are you sure you want to continue? (y/N): " confirm
if [[ "$confirm" != [Yy]* ]]; then
    echo "Aborting as per user request."
    exit 1
fi

# Get device names
read -rp "Enter the first device name (e.g., /dev/sda): " DEV1
read -rp "Enter the second device name (e.g., /dev/sdb): " DEV2

# Wipe both drives
echo "Wiping both drives..."
sudo sgdisk --zap-all "$DEV1"
sudo sgdisk --zap-all "$DEV2"

# Create GPT partitions
echo "Creating GPT partitions and RAID arrays..."
create_partitions_and_raid() {
    local dev=$1
    sudo sgdisk -n 1:0:+256M -t 1:0700 -c 1:"RPICFG" "$dev"
    sudo sgdisk -n 2:0:+32G -t 2:FD00 -c 2:"armbian_root" "$dev"
    sudo sgdisk -n 3:0:0 -t 3:FD00 -c 3:"$STORAGE_LABEL" "$dev"

    sudo mkfs.vfat -F 32 "${dev}1" -n RPICFG
}

create_partitions_and_raid "$DEV1"
create_partitions_and_raid "$DEV2"

# Create the RAID arrays
echo "Creating the RAID arrays..."
sudo mdadm --create --verbose /dev/md0 --level=1 --raid-devices=2 "${DEV1}2" "${DEV2}2"
sudo mdadm --create --verbose /dev/md1 --level=1 --raid-devices=2 "${DEV1}3" "${DEV2}3"

# Format the RAID arrays with Btrfs
echo "Formatting the RAID arrays with Btrfs..."
sudo mkfs.btrfs -f -L armbian_root /dev/md0
sudo mkfs.btrfs -f -L "$STORAGE_LABEL" /dev/md1

# Update mdadm.conf
echo "Updating mdadm.conf..."
echo "MAILADDR root" | sudo tee -a /etc/mdadm/mdadm.conf
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf

# Ensure mdadm runs at boot to assemble RAID arrays
echo "Updating initramfs to ensure mdadm runs at boot..."
sudo update-initramfs -u

echo "RAID arrays are syncing. You can monitor the progress with 'watch cat /proc/mdstat'."
echo "Press any key to continue to the next step..."
read -n 1 -s -r

# Mount the RAID array to access its filesystem
echo "Mounting the RAID array..."
sudo mkdir -p /mnt/md0
sudo mount /dev/md0 /mnt/md0

# Copy the boot partition from the Armbian image to the RAID array's boot directory
echo "Copying the boot files to the RAID array's boot directory..."
sudo mkdir -p /mnt/md0/boot
sudo mount -o loop,offset=$((8192*512)) armbian.img /mnt/armbian_img
sudo cp -a /mnt/armbian_img/* /mnt/md0/boot

# Unmount the Armbian image
echo "Unmounting the Armbian image..."
sudo umount /mnt/armbian_img
rm -rf /mnt/armbian_img

# Configure /etc/fstab
echo "You will now need to configure /etc/fstab with the correct entries for your RAID and boot setup."
echo

echo "Configuring /etc/fstab..."
echo "The current contents of /etc/fstab are:"
cat /mnt/md0/etc/fstab
echo
echo "Press any key to edit /etc/fstab..."
read -n 1 -s -r
sudo nano /mnt/md0/etc/fstab

echo "Configuring the bootloader's cmdline.txt..."
echo "The current contents of cmdline.txt are:"
cat /mnt/md0/boot/cmdline.txt
echo
echo "Press any key to edit cmdline.txt..."
read -n 1 -s -r
sudo nano /mnt/md0/boot/cmdline.txt

# Assuming the user has finished editing the fstab and cmdline.txt files
echo "All configurations are complete. Please review the changes to ensure everything is correct."

echo "Configuration complete. The system will now power off."
echo "Please remove the SD card once the system is off, and then power up again."
echo "Press any key to power off the system."
read -n 1 -s -r
sudo poweroff
