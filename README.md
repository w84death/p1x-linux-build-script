# ![P1X LiNUX BUiLD SCRiPT](media/banner.png)

## About

This scripts generates working Linux ISO image (7.8MiB). It is very, very small and basic.

## Media

![Dialog script](media/screen_script.png)

![Live Linux](media/screen_live.png)

## History

Based on [Minimal Linux Script](https://github.com/ivandavidov/minimal-linux-script) and [Minimal Linux Live](http://github.com/ivandavidov/minimal).

The script below uses **Linux kernel 4.7.6**, **BusyBox 1.24.2** and **Syslinux 6.03**.

For Debian/Ubuntu you'll need

    sudo apt-get install wget bc build-essential gawk xorriso dialog

Then just run the script

    ./build-linux.sh
