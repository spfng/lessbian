#!/bin/bash

echo Install required tools
apt-get update
apt-get -y install debootstrap squashfs-tools xorriso isolinux syslinux-efi grub-pc-bin grub-efi-amd64-bin mtools dosfstools zstd

echo Create directory where we will make the image
TEMP=`mktemp -d -p $PWD build.XXX`
install -d $TEMP/live_boot

echo Install Debian
debootstrap --arch=amd64 --variant=minbase bookworm $TEMP/live_boot/chroot http://192.168.1.144/debian/

echo Copy supporting documents into the chroot
cp -v $PWD/setup-chroot.sh $TEMP/live_boot/chroot/setup-chroot.sh
cp -v $PWD/sources.list $TEMP/live_boot/chroot/etc/apt/sources.list

echo Mounting dev / proc / sys
mount -t proc none $TEMP/live_boot/chroot/proc
mount -o bind /dev $TEMP/live_boot/chroot/dev
mount -o bind /sys $TEMP/live_boot/chroot/sys

echo Run install script inside chroot
chroot $TEMP/live_boot/chroot /setup-chroot.sh

echo Copy in systemd-networkd config
cp -v $PWD/99-dhcp-en.network $TEMP/live_boot/chroot/etc/systemd/network/99-dhcp-en.network

echo Enable autologin
mkdir -p -v $TEMP/live_boot/chroot/etc/systemd/system/getty@tty1.service.d/
cp -v $PWD/override.conf $TEMP/live_boot/chroot/etc/systemd/system/getty@tty1.service.d/override.conf

echo Unmounting dev / proc / sys
umount $TEMP/live_boot/chroot/proc
umount $TEMP/live_boot/chroot/dev
umount $TEMP/live_boot/chroot/sys

echo Create directories that will contain files for our live environment files and scratch files.
mkdir -p $TEMP/live_boot/{staging/{EFI/boot,boot/grub/x86_64-efi,isolinux,live},tmp}

echo Copy kernel and initrd
cp -v $TEMP/live_boot/chroot/vmlinuz $TEMP/live_boot/staging/live/vmlinuz
cp -v $TEMP/live_boot/chroot/initrd.img $TEMP/live_boot/staging/live/initrd.img

echo Clean chroot
rm $TEMP/live_boot/chroot/setup-chroot.sh
rm $TEMP/live_boot/chroot/boot/*
rm $TEMP/live_boot/chroot/vmlinuz{,.old}
rm $TEMP/live_boot/chroot/initrd.img{,.old}

echo Compress the chroot environment into a Squash filesystem.
mksquashfs $TEMP/live_boot/chroot $TEMP/live_boot/staging/live/filesystem.squashfs -comp zstd

echo Copy boot config files
cp -v $PWD/isolinux.cfg $TEMP/live_boot/staging/isolinux/isolinux.cfg
cp -v $PWD/grub.cfg $TEMP/live_boot/staging/boot/grub/grub.cfg
cp -v $PWD/grub-earlyboot.cfg $TEMP/live_boot/tmp/grub-earlyboot.cfg
touch $TEMP/live_boot/staging/DEBIAN_GNULINUX

echo Copy boot images
cp -v /usr/lib/ISOLINUX/isolinux.bin "$TEMP/live_boot/staging/isolinux/"
cp -v /usr/lib/syslinux/modules/bios/* "$TEMP/live_boot/staging/isolinux/"
cp -v -r /usr/lib/grub/x86_64-efi/* "$TEMP/live_boot/staging/boot/grub/x86_64-efi/"

echo Make UEFI grub files
grub-mkstandalone --format=x86_64-efi --output=$TEMP/live_boot/tmp/bootx64.efi --locales=""  --fonts="" "boot/grub/grub.cfg=$TEMP/live_boot/tmp/grub-earlyboot.cfg"

cd $TEMP/live_boot/staging/EFI/boot
SIZE=`expr $(stat --format=%s $TEMP/live_boot/tmp/bootx64.efi) + 65536`
dd if=/dev/zero of=efiboot.img bs=$SIZE count=1
/sbin/mkfs.vfat efiboot.img
mmd -i efiboot.img efi efi/boot
mcopy -vi efiboot.img $TEMP/live_boot/tmp/bootx64.efi ::efi/boot/

echo Build ISO
xorriso \
    -as mkisofs \
    -iso-level 3 \
    -o "$TEMP/live_boot/output.iso" \
    -full-iso9660-filenames \
    -volid "DEBIAN_GNULINUX" \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -eltorito-boot \
        isolinux/isolinux.bin \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --eltorito-catalog isolinux/isolinux.cat \
    -eltorito-alt-boot \
        -e /EFI/boot/efiboot.img \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
    -append_partition 2 0xef $TEMP/live_boot/staging/EFI/boot/efiboot.img \
    "$TEMP/live_boot/staging"

echo Output
echo $TEMP/live_boot/output.iso

