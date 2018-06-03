#!/bin/sh
# ******************************************************************************
# P1X LiNUX BUiLD SCRiPT - 2018.06
# ******************************************************************************

set -ex

# ******************************************************************************
# GLOBALS
# ******************************************************************************

SCRIPT_NAME="P1X LiNUX BUiLD SCRiPT"
SCRIPT_VERSION="2018.6"
DISTRIBUTION_VERSION="1.0 RC3"
KERNEL_VERSION=4.12.3
BUSYBOX_VERSION=1.27.1
SYSLINUX_VERSION=6.03
ROOT_DIR=`realpath --no-symlinks $PWD`
PAGES="6"

# ******************************************************************************
# FUNCTIONS
# ******************************************************************************

show_dialog() {
	dialog --backtitle "$SCRIPT_NAME - $SCRIPT_VERSION / v$DISTRIBUTION_VERSION" \
		--title "$1" \
		--msgbox "$2" 12 48
}

ask_dialog() {
        dialog --stdout \
                --backtitle "$SCRIPT_NAME - $SCRIPT_VERSION / v$DISTRIBUTION_VERSION" \
                --title "$1" \
                --yesno "$2" 12 48
}

get_sources() {
        wget -O kernel.tar.xz http://kernel.org/pub/linux/kernel/v4.x/linux-$KERNEL_VERSION.tar.xz
        wget -O busybox.tar.bz2 http://busybox.net/downloads/busybox-$BUSYBOX_VERSION.tar.bz2
        wget -O syslinux.tar.xz http://kernel.org/pub/linux/utils/boot/syslinux/syslinux-$SYSLINUX_VERSION.tar.xz
        tar -xvf kernel.tar.xz
        tar -xvf busybox.tar.bz2
        tar -xvf syslinux.tar.xz
}

prepare_dirs() {
        if [ ! -d "isoimage" ]; then
                mkdir isoimage
        fi
}

build_busybox() {
        cd $ROOT_DIR/busybox-$BUSYBOX_VERSION
        make distclean defconfig
        sed -i "s/.*CONFIG_STATIC.*/CONFIG_STATIC=y/" .config
        make busybox install

        INSTALL_ROOT="$ROOT_DIR/busybox-$BUSYBOX_VERSION/_install"
        cd "$INSTALL_ROOT"
        rm -f linuxrc

        mkdir "$INSTALL_ROOT/etc"
        mkdir "$INSTALL_ROOT/tmp"
        mkdir "$INSTALL_ROOT/proc"
        mkdir "$INSTALL_ROOT/sys"
        mkdir "$INSTALL_ROOT/dev"
        mkdir "$INSTALL_ROOT/home"
        mkdir "$INSTALL_ROOT/mnt"
        mkdir "$INSTALL_ROOT/var"
        mkdir "$INSTALL_ROOT/root"
        chmod a+rwxt "$INSTALL_ROOT/tmp"
        ln -s usr/bin "$INSTALL_ROOT/bin"
        ln -s usr/sbin "$INSTALL_ROOT/sbin"
        ln -s usr/lib "$INSTALL_ROOT/lib"

        cat > "$INSTALL_ROOT"/init << 'EOF' &&
#!/bin/sh
dmesg -n 1
export HOME=/home
export PATH=/bin:/sbin
mountpoint -q proc || mount -t proc proc proc
mountpoint -q sys || mount -t sysfs sys sys
/bin/sh
umount /sys /proc
EOF
        chmod +x "$INSTALL_ROOT"/init

        cat > "$INSTALL_ROOT"/etc/passwd << 'EOF' &&
root::0:0:root:/home/root:/bin/sh
guest:x:500:500:guest:/home/guest:/bin/sh
nobody:x:65534:65534:nobody:/proc/self:/dev/null
EOF

        cat > "$INSTALL_ROOT"/etc/group << 'EOF' &&
root:x:0:
guest:x:500:
EOF

        find . | cpio -R root:root -H newc -o | gzip > $ROOT_DIR/isoimage/rootfs.gz
}

build_kernel() {
        cd $ROOT_DIR/linux-$KERNEL_VERSION
        make mrproper -j 4
        make defconfig -j 4
        sed -i "s/.*CONFIG_DEFAULT_HOSTNAME.*/CONFIG_DEFAULT_HOSTNAME=\"P1X\"/" .config
        sed -i "s/.*CONFIG_OVERLAY_FS.*/CONFIG_OVERLAY_FS=y/" .config
        sed -i "s/.*\\(CONFIG_KERNEL_.*\\)=y/\\#\\ \\1 is not set/" .config
        sed -i "s/.*CONFIG_KERNEL_XZ.*/CONFIG_KERNEL_XZ=y/" .config
        sed -i "s/.*CONFIG_FB_VESA.*/CONFIG_FB_VESA=y/" .config
        sed -i "s/.*CONFIG_LOGO.*/CONFIG_LOGO=y/" .config
        cp $ROOT_DIR/logo.ppm drivers/video/logo/logo_linux_clut224.ppm
        sed -i "s/.*CONFIG_LOGO_LINUX_CLUT224.*/CONFIG_LOGO_LINUX_CLUT224=y/" .config
        sed -i "s/.*LOGO_LINUX_CLUT224.*/LOGO_LINUX_CLUT224=y/" .config
        sed -i "s/^CONFIG_DEBUG_KERNEL.*/\\# CONFIG_DEBUG_KERNEL is not set/" .config

        make bzImage -j 4
        cp arch/x86/boot/bzImage $ROOT_DIR/isoimage/kernel.gz
}

make_isoimage() {
        cd $ROOT_DIR/isoimage
        cp ../syslinux-$SYSLINUX_VERSION/bios/core/isolinux.bin .
        cp ../syslinux-$SYSLINUX_VERSION/bios/com32/elflink/ldlinux/ldlinux.c32 .
        cat > ./isolinux.cfg << 'EOF' &&
 DEFAULT linux
  SAY Now booting the kernel from SYSLINUX...
 LABEL linux
  KERNEL kernel.gz
  APPEND initrd=rootfs.gz vga=791
EOF

        xorriso \
          -as mkisofs \
          -o ../p1x_linux_live.iso \
          -b isolinux.bin \
          -c boot.cat \
          -no-emul-boot \
          -boot-load-size 4 \
          -boot-info-table \
          ./
        cd ..
}

clean () {
        rm -rf busybox* isoimage kernel* linux* syslinux*
        echo "YOU WERE USING \\e[1mP1X \\e[32mLiNUX BUiLD SCRiPT \\e[31m2018.6\\e[0m, Visit http://linux.p1x.in"
}

# ******************************************************************************
# THE SCRIPT
# ******************************************************************************


if ! ask_dialog "[0/$PAGES] WELCOME" \
 "Welcome. Create your own Linux distribution from one script file!\n\nScript is divided into parts: GETTING SOURCES, PREPARING DIRECTORIES, BUILD BUSYBOX, BUILD KERNEL, MAKE ISO IMAGE\n\nStart now?"; then
        return 0
else
        if ask_dialog "[1/$PAGES] GETTING SOURCES" "Download Linux, Busybox, Syslinux?"; then
                get_sources
        fi

        show_dialog "[2/$PAGES] PREPARING DIRECTORIES" "Create nessesary directories."
        prepare_dirs

        if ask_dialog "[3/$PAGES] BUILD BUSYBOX" "Start building Busybox?"; then
                build_busybox
        fi

        if ask_dialog "[4/$PAGES] BUILD KERNEL" "Start building Linux Kernel?"; then
                build_kernel
        fi

        if ask_dialog "[5/$PAGES] MAKE ISO IMAGE" "Make final image?"; then
                make_isoimage
        fi

        show_dialog "[6/$PAGES] FINISHED" "P1X LiNUX is created :)\nBurn p1x_linux_live.iso and enjoy the distribution!"

        #clean
fi

set +ex

# ******************************************************************************
# EOF
# ******************************************************************************
