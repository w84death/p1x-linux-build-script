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
KERNEL_VERSION=4.12.3
BUSYBOX_VERSION=1.27.1
SYSLINUX_VERSION=6.03
ROOT_DIR=`realpath --no-symlinks $PWD`
PAGES="6"

# ******************************************************************************
# FUNCTIONS
# ******************************************************************************

show_dialog() {
	dialog --backtitle "$SCRIPT_NAME - $SCRIPT_VERSION" \
		--title "$1" \
		--msgbox "$2" 12 48
}

ask_dialog() {
        dialog --stdout \
                --backtitle "$SCRIPT_NAME - $SCRIPT_VERSION" \
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
        cd _install
        rm -f linuxrc
        mkdir dev proc sys
        echo '#!/bin/sh' > init
        echo 'dmesg -n 1' >> init
        echo 'mount -t devtmpfs none /dev' >> init
        echo 'mount -t proc none /proc' >> init
        echo 'mount -t sysfs none /sys' >> init
        echo 'setsid cttyhack /bin/sh' >> init
        echo 'echo -e "\\e[1mP1X \\e[32mLiNUX BUiLD SCRiPT \\e[31m2018.6\\e[0m\nVisit http://linux.p1x.in\n"' >> init
        chmod +x init
        find . | cpio -R root:root -H newc -o | gzip > ../../isoimage/rootfs.gz
}

build_kernel() {
        cd $ROOT_DIR/linux-$KERNEL_VERSION
        make mrproper -j 4
        make defconfig -j 4

        sed -i "s/.*CONFIG_DEFAULT_HOSTNAME.*/CONFIG_DEFAULT_HOSTNAME=\"p1x\"/" .config
        echo "CONFIG_OVERLAY_FS_REDIRECT_DIR=y" >> .config
        sed -i "s/.*\\(CONFIG_KERNEL_.*\\)=y/\\#\\ \\1 is not set/" .config
        sed -i "s/.*CONFIG_KERNEL_XZ.*/CONFIG_KERNEL_XZ=y/" .config
        sed -i "s/.*CONFIG_FB_VESA.*/CONFIG_FB_VESA=y/" .config
        cp $ROOT_DIR/logo.ppm drivers/video/logo/logo_linux_clut224.ppm
        sed -i "s/.*CONFIG_LOGO_LINUX_CLUT224.*/CONFIG_LOGO_LINUX_CLUT224=y/" .config

        make bzImage -j 4
        cp arch/x86/boot/bzImage $ROOT_DIR/isoimage/kernel.gz
}

make_isoimage() {
        cd $ROOT_DIR/isoimage
        cp ../syslinux-$SYSLINUX_VERSION/bios/core/isolinux.bin .
        cp ../syslinux-$SYSLINUX_VERSION/bios/com32/elflink/ldlinux/ldlinux.c32 .
        echo 'default kernel.gz initrd=rootfs.gz' > ./isolinux.cfg

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

if ! ask_dialog "[0/$PAGES] P1X LiNUX BUiLD SCRiPT 2018.6" "Create your own Linux distribution from one script file!\n\nStart now?"; then
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
