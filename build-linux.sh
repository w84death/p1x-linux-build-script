#!/bin/bash
# ******************************************************************************
# P1X LiNUX BUiLD SCRiPT - 2018.06
# ******************************************************************************

set -ex

# ******************************************************************************
# GLOBALS
# ******************************************************************************

SCRIPT_NAME="P1X LiNUX BUiLD SCRiPT"
SCRIPT_VERSION="2018.6"
DISTRIBUTION_VERSION="1.0 RC8"
KERNEL_VERSION="4.14.39"
BUSYBOX_VERSION="1.28.3"
SYSLINUX_VERSION="6.03"
NCURSES_VERSION="6.0"
NANO_VERSION="2.8.7"

BASEDIR=`realpath --no-symlinks $PWD`
SOURCEDIR=${BASEDIR}/sources
DESTDIR=${BASEDIR}/rootfs
ISODIR=${BASEDIR}/iso


DIALOG_OUT=/tmp/dialog_$$
CFLAGS="-Os -s -fno-stack-protector -fomit-frame-pointer -U_FORTIFY_SOURCE"
CPU_CORES=4

# ******************************************************************************
# FUNCTIONS
# ******************************************************************************

show_menu() {
        dialog --backtitle "$SCRIPT_NAME - $SCRIPT_VERSION / v$DISTRIBUTION_VERSION" \
                --title "$SCRIPT_NAME MENU" \
                --menu "Run each step in order. Choose wisely:" 20 64 10 \
                1 "PREPARE DIRECTORIES" \
                2 "GET SOURCES" \
                3 "BUILD BUSYBOX" \
                4 "BUILD EXTRAS" \
                5 "MAKE ROOTFS" \
                6 "BUILD KERNEL" \
                7 "MAKE ISO IMAGE" \
                8 "RUN QEMU" \
                9 "CLEAN FILES" \
                10 "QUIT" 2> $DIALOG_OUT
}

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
        cd ${SOURCEDIR}
        wget -O kernel.tar.xz http://kernel.org/pub/linux/kernel/v4.x/linux-$KERNEL_VERSION.tar.xz
        wget -O busybox.tar.bz2 http://busybox.net/downloads/busybox-$BUSYBOX_VERSION.tar.bz2
        wget -O syslinux.tar.xz http://kernel.org/pub/linux/utils/boot/syslinux/syslinux-$SYSLINUX_VERSION.tar.xz
        wget -O ncurses.tar.gz https://ftp.gnu.org/pub/gnu/ncurses/ncurses-$NCURSES_VERSION.tar.gz
        wget -O nano.tar.xz https://nano-editor.org/dist/v2.8/nano-$NANO_VERSION.tar.xz
        tar -xvf kernel.tar.xz
        tar -xvf busybox.tar.bz2
        tar -xvf syslinux.tar.xz
        tar -xvf ncurses.tar.gz
        tar -xvf nano.tar.xz
}

prepare_dirs() {
        if [ ! -d ${SOURCEDIR} ]; then
                mkdir ${SOURCEDIR}
        fi
        if [ ! -d ${DESTDIR} ]; then
                mkdir ${DESTDIR}
                mkdir -p ${DESTDIR}/{bin,boot,dev,etc,home,lib,media,mnt,proc,root,sys,tmp,var}
                mkdir -p ${DESTDIR}/dev/{pts,input,net,usb}
                mkdir -p ${DESTDIR}/usr/{bin,include,local,lib,share}
                mkdir -p ${DESTDIR}/var/{cache,lib,local,log,run,spool}
                chmod 1777 ${DESTDIR}/tmp
        fi
        if [ ! -d ${ISODIR} ]; then
                mkdir ${ISODIR}
        fi
}

build_busybox() {
        cd ${SOURCEDIR}/busybox-$BUSYBOX_VERSION
        make distclean defconfig
        sed -i "s/.*CONFIG_STATIC.*/CONFIG_STATIC=y/" .config
        make CONFIG_PREFIX=${DESTDIR} install
        cp examples/bootfloppy/mkdevs.sh ${DESTDIR}/bin
        cd ${DESTDIR}
        chmod 4755 bin/busybox
        rm -f linuxrc
        ln -sf bin/busybox init
        bin/mkdevs.sh ${DESTDIR}/dev

        create_etc_files
}

create_etc_files () {
        cat > ${DESTDIR}/etc/passwd << 'EOF' &&
root:x:0:0:root:/root:/bin/sh
EOF

        cat > ${DESTDIR}/etc/group << 'EOF' &&
root:x:0:root
EOF

        cat > ${DESTDIR}/etc/motd << 'EOF' &&
*******************************
* Welcome to P1X LiNUX 2018.6 *
*******************************
EOF

        cat > ${DESTDIR}/etc/rc.boot << 'EOF' &&
#!/bin/sh
dmesg -n 1
mount -t proc -o nosuid,noexec,nodev /proc /proc
mount -t sysfs -o nosuid,noexec,nodev  /sys /sys
mount -t devtmpfs /dev /dev
mount -t devpts devpts /dev/pts
mount -t tmpfs -o nosuid /tmp /tmp
echo /sbin/mdev > /proc/sys/kernel/hotplug
mdev -s
export HOSTNAME=P1X
mount -o remount,ro /
fsck -A -T -C -p
mount -o remount,rw /
dmesg >/var/log/dmesg.log
EOF

        chmod +x ${DESTDIR}/etc/rc.boot

        cat > ${DESTDIR}/etc/rc.shutdown << 'EOF' &&
killall5 -s TERM
sleep
killall5 -s KILL
umount -a
sync
EOF
        chmod +x ${DESTDIR}/etc/rc.shutdown

        cat > ${DESTDIR}/etc/profile  << 'EOF' &&
# /etc/profile

umask 022

PATH="/usr/sbin:/usr/bin:/sbin:/bin"
LD_LIBRARY_PATH="/usr/lib:/lib"

export PATH
export LD_LIBRARY_PATH
EOF

        cat > ${DESTDIR}/etc/issue  << 'EOF' &&
P1X LiNUX 2018.6
EOF

        cat > ${DESTDIR}/etc/inittab  << 'EOF' &&
# /etc/inittab

::sysinit:/etc/rc.boot

tty1::respawn:/sbin/getty 38400 tty1
tty2::respawn:/sbin/getty 38400 tty2
tty3::respawn:/sbin/getty 38400 tty3
tty4::respawn:/sbin/getty 38400 tty4
tty5::respawn:/sbin/getty 38400 tty5
tty6::respawn:/sbin/getty 38400 tty6

::shutdown:/etc/rc.shutdown
::ctrlaltdel:/sbin/reboot
EOF


        cat > ${DESTDIR}/etc/fstab  << 'EOF' &&
#proc            /proc        proc    defaults          0       0
#sysfs           /sys         sysfs   defaults          0       0
#devpts          /dev/pts     devpts  defaults          0       0
#tmpfs           /dev/shm     tmpfs   defaults          0       0
EOF


        cat > ${DESTDIR}/etc/securetty  << 'EOF' &&
console
ttyS0
tty1
tty2
tty3
tty4
tty5
tty6
EOF
        echo "done"
}

build_extras () {
        build_ncurses
        build_nano
}

build_ncurses () {
        cd $SOURCEDIR/ncourses-$NCURSES_VERSION
        if [ -f Makefile ] ; then
                make -j $CPU_CORES clean
        fi
        sed -i '/LIBTOOL_INSTALL/d' c++/Makefile.in
        CFLAGS="$CFLAGS" ./configure \
                --prefix=/usr \
                --with-termlib \
                --with-terminfo-dirs=/lib/terminfo \
                --with-default-terminfo-dirs=/lib/terminfo \
                --without-normal \
                --without-debug \
                --without-cxx-binding \
                --with-abi-version=5 \
                --enable-widec \
                --enable-pc-files \
                --with-shared \
                CPPFLAGS=-I$PWD/ncurses/widechar \
                LDFLAGS=-L$PWD/lib \
                CPPFLAGS="-P"

        make -j $CPU_CORES
        make -j $CPU_CORES install DESTDIR=$DESTDIR

        cd $DESTDIR/usr/lib
        ln -s libncursesw.so.5 libncurses.so.5
        ln -s libncurses.so.5 libncurses.so
        ln -s libtinfow.so.5 libtinfo.so.5
        ln -s libtinfo.so.5 libtinfo.so
        #strip -g $DESTDIR/usr/bin/*
}

build_nano () {
        cd $SOURCEDIR/nano-$NANO_VERSION
        if [ -f Makefile ] ; then
                make -j $CPU_CORES clean
        fi
        sed -i '/LIBTOOL_INSTALL/d' c++/Makefile.in
        CFLAGS="$CFLAGS" ./configure \
                --prefix=/usr \
                LDFLAGS=-L$DESTDIR/usr/include

        make -j $CPU_CORES
        make -j $CPU_CORES install DESTDIR=$DESTDIR

        #strip -g $DESTDIR/usr/bin/*
}

make_rootfs () {
        cd ${DESTDIR}
        find . -print | cpio -o -H newc | gzip -9 > ${ISODIR}/rootfs.gz
        #-R root:root
}

build_kernel() {
        cd $SOURCEDIR/linux-$KERNEL_VERSION
        make mrproper -j $CPU_CORES
        make defconfig -j $CPU_CORES
        sed -i "s/.*CONFIG_DEFAULT_HOSTNAME.*/CONFIG_DEFAULT_HOSTNAME=\"P1X\"/" .config
        sed -i "s/.*CONFIG_OVERLAY_FS.*/CONFIG_OVERLAY_FS=y/" .config
        sed -i "s/.*\\(CONFIG_KERNEL_.*\\)=y/\\#\\ \\1 is not set/" .config
        sed -i "s/.*CONFIG_KERNEL_XZ.*/CONFIG_KERNEL_XZ=y/" .config
        sed -i "s/.*CONFIG_FB_VESA.*/CONFIG_FB_VESA=y/" .config
        cp $BASEDIR/logo.ppm drivers/video/logo/logo_linux_clut224.ppm
        sed -i "s/.*CONFIG_LOGO_LINUX_CLUT224.*/CONFIG_LOGO_LINUX_CLUT224=y/" .config
        sed -i "s/.*LOGO_LINUX_CLUT224.*/LOGO_LINUX_CLUT224=y/" .config
        #sed -i "s/^CONFIG_DEBUG_KERNEL.*/\\# CONFIG_DEBUG_KERNEL is not set/" .config

        make bzImage -j $CPU_CORES
        make INSTALL_MOD_PATH=${DESTDIR} modules_install
        cp arch/x86/boot/bzImage ${ISODIR}/bzImage
}

make_isoimage() {
        cd ${ISODIR}
        SYSLINUX_DIR=${SOURCEDIR}/syslinux-${SYSLINUX_VERSION}
        cp $SYSLINUX_DIR/bios/core/isolinux.bin .
        cp $SYSLINUX_DIR/bios/com32/elflink/ldlinux/ldlinux.c32 .
        cp $SYSLINUX_DIR/bios/com32/libutil/libutil.c32 .
        cp $SYSLINUX_DIR/bios/com32/menu/menu.c32 .

        cat > ./isolinux.cfg << 'EOF' &&
UI menu.c32
PROMPT 0

MENU TITLE P1X LiNUX 2018.6:
    TIMEOUT 60
    DEFAULT p1x

LABEL p1x
        MENU LABEL P1X LiNUX 4.14.39
        KERNEL bzImage
        APPEND initrd=rootfs.gz vga=791 quiet

LABEL p1x_debug
        MENU LABEL P1X LiNUX 4.14.39 (debug)
        KERNEL bzImage
        APPEND initrd=rootfs.gz vga=ask nomodeset
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
        cd ${BASEDIR}
}

clean () {
        rm -rf $SOURCEDIR $DESTDIR $ISODIR
}

# ******************************************************************************
# SCRIPT MENU
# ******************************************************************************

menu_prepare_dirs () {
        show_dialog "REPARE DIRECTORIES" "Create nessesary directories."
        prepare_dirs && menu_get_sources
}

menu_get_sources () {
        if ask_dialog "GET SOURCES" "Download sources for Linux, Busybox, Syslinux, ncourses, nano?";
        then
                get_sources && menu_build_busybox
        else
                loop_menu
        fi
}

menu_build_busybox () {
        if [ ! -d $SOURCEDIR/busybox-$BUSYBOX_VERSION ];
        then
                show_dialog "MISSING FILES" "Busybox files are missing" && loop_menu
        fi

        if ask_dialog "BUILD BUSYBOX" "Start building Busybox?";
        then
                build_busybox && menu_build_extras
        else
                loop_menu
        fi
}

menu_build_extras () {
        if [ ! -d $SOURCEDIR/nano-$NANO_VERSION ];
        then
                show_dialog "MISSING FILES" "Nano files are missing" && loop_menu
        fi

        if [ ! -d $SOURCEDIR/ncurses-$NCURSES_VERSION ];
        then
                show_dialog "MISSING FILES" "nCurses files are missing" && loop_menu
        fi

        if ask_dialog "BUILD EXTRAS" "Start building ncurses, nano?";
        then
                build_extras && menu_make_rootfs
        else
                loop_menu
        fi
}

menu_make_rootfs () {
        if [ ! -f $DESTDIR/init ];
        then
                show_dialog "MISSING FILES" "Rootfs init file is missing" && loop_menu
        fi
        if ask_dialog "MAKE ROOTFS" "Start making rootfs?";
        then
                make_rootfs && menu_build_kernel
        else
                loop_menu
        fi
}

menu_build_kernel () {
        if ask_dialog "BUILD KERNEL" "Start building Linux Kernel?";
        then
                build_kernel && menu_make_iso
        else
                loop_menu
        fi
}

menu_make_iso () {
        if ask_dialog "MAKE ISO IMAGE" "Make final image?";
        then
                make_isoimage && show_dialog "FINISHED" "P1X LiNUX is created :)\nBurn p1x_linux_live.iso or run qemu from menu and enjoy the distribution!" && loop_menu
        else
                loop_menu
        fi
}

menu_qemu () {
        qemu-system-x86_64 -m 128M -cdrom p1x_linux_live.iso -boot d -vga std && loop_menu
}

menu_clean () {
        if ask_dialog "CLEAN FILES" "Remove all downloaded and compiled files?"; then
                clean && loop_menu
        else
                loop_menu
        fi
}

loop_menu () {
        show_menu
        choice=$(cat $DIALOG_OUT)

        case $choice in
                1) menu_prepare_dirs ;;

                2) menu_get_sources ;;

                3) menu_build_busybox ;;

                4) menu_build_extras ;;

                5) menu_make_rootfs ;;

                6) menu_build_kernel ;;

                7) menu_make_iso ;;

                8) menu_qemu ;;

                9) menu_clean ;;

                10) exit;;
        esac
}

# ******************************************************************************
# THE SCRIPT
# ******************************************************************************

loop_menu

set +ex

# ******************************************************************************
# EOF
# ******************************************************************************
