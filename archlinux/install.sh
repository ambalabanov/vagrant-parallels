#!/usr/bin/env bash

# stop on errors
set -eu

# variables
DISK='/dev/sda'
FQDN='arch.local'
TIMEZONE='Asia/Yekaterinburg'
TARGET_DIR='/mnt'
CONFIG_SCRIPT='/usr/local/bin/arch-config.sh'
USERN='vagrant'
USERC='vagrant user'
USERP='vagrant'

echo "Creating partitions on ${DISK}.."
parted ${DISK} mklabel gpt 
parted ${DISK} mkpart "EFI" fat32 1 501
parted ${DISK} mkpart "root" ext4 501 100%
parted ${DISK} set 1 esp on
mkfs.vfat ${DISK}1
mkfs.ext4 ${DISK}2

echo "Mount filesystems.."
mount /dev/sda2 /mnt/
mkdir -p /mnt/boot/efi
mount /dev/sda1 /mnt/boot/efi

echo "Bootstrapping the base installation.."
/usr/bin/pacstrap ${TARGET_DIR} base base-devel linux linux-firmware linux-headers dkms vim bash-completion man man-pages grub efibootmgr openssh sudo

echo "Generating fstab.."
/usr/bin/genfstab -pU ${TARGET_DIR} >> "${TARGET_DIR}/etc/fstab"

echo "Network configuring.."
cp -L /etc/resolv.conf ${TARGET_DIR}/etc
cp /etc/systemd/network/* ${TARGET_DIR}/etc/systemd/network

echo "Generating the chroot script.."
/usr/bin/install --mode=0755 /dev/null "${TARGET_DIR}${CONFIG_SCRIPT}"
cat <<-EOF > "${TARGET_DIR}${CONFIG_SCRIPT}"
hostnamectl set-hostname ${FQDN}
hwclock --systohc --utc
timedatectl set-timezone ${TIMEZONE}
timedatectl set-ntp true
sed -i "s/#\(en_US\.UTF-8\)/\1/" /etc/locale.gen
sed -i "s/#\(ru_RU\.UTF-8\)/\1/" /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
sed -i '/^#\[multilib\]/s/^#//g' /etc/pacman.conf
sed -i '/^\[multilib\]/{N;s/\n#/\n/}' /etc/pacman.conf
pacman-key --init
pacman-key --populate archlinux
pacman -Syy
systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service
systemctl enable sshd.service
useradd --create-home --user-group --groups wheel,audio,video,storage --shell /bin/bash --comment "${USERC}" ${USERN}
echo "${USERN}:${USERP}" | chpasswd
echo "${USERN} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/${USERN}
install --directory --mode=0700 --owner=${USERN} --group=${USERN} /home/${USERN}/.ssh
install --mode=0600 --owner=${USERN} --group=${USERN} /home/${USERN}/.ssh/authorized_keys
curl https://raw.githubusercontent.com/hashicorp/vagrant/master/keys/vagrant.pub -o /home/${USERN}/.ssh/authorized_keys
curl -O https://blackarch.org/strap.sh
chmod +x strap.sh
./strap.sh
EOF

echo "Chrooting.."
/usr/bin/arch-chroot ${TARGET_DIR} ${CONFIG_SCRIPT}
rm "${TARGET_DIR}${CONFIG_SCRIPT}"

echo "Installation complete!"
