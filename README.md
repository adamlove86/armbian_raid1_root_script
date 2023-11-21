# armbian_raid1_root_script
# Armbian RAID Setup for Raspberry Pi 4

Set up a RAID1 root for armbian on your two external drives.
-partitions 1: RPICFG boot identically copied to 1st partitions (256MB) on the SSDs. They're non raid as raspi doesn't recognise raid boot.
-partitions 2: armbian_root as 32gb RAID1, md0, btrfs.
-partitions 3: Remainder of the disk as a btrfs md1 RAID1 storage. I did it this way so I can wipe and reinstall md0 without having to restore all my other data.

You need armbian running from an sd card, working as a 'live cd' of sorts. You run the script from there.

## Prerequisites
- Raspberry Pi 4 Model B
- Armbian installed and running from sd card. Access to it via terminal or SSH.
- Two external SSDs plugged in. They'll be formatted completely.
- Web link to the Armbian image file you want to use

## Usage
Run the provided script as root. The script will guide you through the necessary steps, including partitioning drives, creating RAID arrays, and setting up the filesystem.

## Support
For issues or support, take it up with ChatGPT or similar, sorry. This repo is just for my reference, but because it's so complex and I couldn't find anything for it online, hopefully someone finds this a useful start for anything they want to do. You can also try contacting the Armbian community support forums.

## Disclaimer
This script comes with no warranty. Data loss can occur, everything's at your own risk. Always back up important data before proceeding.

For more details, refer to the full script provided in the repository.

