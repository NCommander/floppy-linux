ROOT_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
INITRAMFS_BASE=$(ROOT_DIR)/out/initramfs

UBUNTU_SYSLINUX_ORIG=http://archive.ubuntu.com/ubuntu/pool/main/s/syslinux/syslinux_6.04~git20190206.bf6db5b4+dfsg1.orig.tar.xz
UBUNTU_SYSLINUX_PKG=http://archive.ubuntu.com/ubuntu/pool/main/s/syslinux/syslinux_6.04~git20190206.bf6db5b4+dfsg1-3ubuntu1.debian.tar.xz

LINUX_DIR=linux-6.4
LINUX_TARBALL=$(LINUX_DIR).tar.xz
LINUX_KERNEL_URL=https://cdn.kernel.org/pub/linux/kernel/v6.x/$(LINUX_TARBALL)

BUSYBOX_DIR=busybox-1.36.1
BUSYBOX_TARBALL=$(BUSYBOX_DIR).tar.bz2
BUSYBOX_URL=https://busybox.net/downloads/$(BUSYBOX_TARBALL)

.PHONY: all clean

all: stamp/fetch-kernel \
	 stamp/fetch-busybox

	-mkdir -p stamp
	echo "Starting build ..."

stamp/fetch-kernel:
	-mkdir -p dist src stamp
	cd dist && wget $(LINUX_KERNEL_URL)
	cd src && tar -xvf ../dist/$(LINUX_TARBALL)
	touch stamp/fetch-kernel		

stamp/fetch-busybox:
	-mkdir -p dist src stamp
	cd dist && wget $(BUSYBOX_URL)
	cd src && tar -xvf ../dist/$(BUSYBOX_TARBALL)
	touch stamp/fetch-busybox		

stamp/fetch-syslinux:
	-mkdir -p dist src stamp
	cd dist && wget $(UBUNTU_SYSLINUX_ORIG) -O syslinux_orig.tar.xz
	cd dist && wget $(UBUNTU_SYSLINUX_PKG) -O syslinux_pkg.tar.xz
	cd src && tar -xvf ../dist/syslinux_orig.tar.xz
	cd src && mv syslinux-6.04~git20190206.bf6db5b4 syslinux
	cd src/syslinux && tar -xvf ../../dist/syslinux_pkg.tar.xz
	cd src/syslinux && QUILT_PATCHES=debian/patches quilt push -a
	cd src/syslinux && patch -p1 < ../../patches/0030-fix-e88.patch
	touch stamp/fetch-syslinux		

kernelmenuconfig: stamp/fetch-kernel
	cp config/kernel.config src/$(LINUX_DIR)/.config
	cd src/$(LINUX_DIR) && make ARCH=x86 CROSS_COMPILE=i486-linux-musl- menuconfig
	cp src/$(LINUX_DIR)/.config config/kernel.config

busyboxmenuconfig: stamp/fetch-busybox
	cp config/busybox.config src/$(BUSYBOX_DIR)/.config
	cd src/$(BUSYBOX_DIR) && make ARCH=x86 CROSS_COMPILE=i486-linux-musl- menuconfig
	cp src/$(BUSYBOX_DIR)/.config config/busybox.config

build-syslinux: stamp/fetch-syslinux
	cd src/syslinux && make bios PYTHON=python3 
	cd src/syslinux && make bios install INSTALLROOT=`pwd`/../../out/syslinux PYTHON=python3

build-kernel: stamp/fetch-kernel build-busybox build-initramfs
	-mkdir out
	cp config/kernel.config src/$(LINUX_DIR)/.config
	cd src/$(LINUX_DIR) && $(MAKE) -j4 ARCH=x86 CROSS_COMPILE=i486-linux-musl-
	cp src/$(LINUX_DIR)/arch/x86/boot/bzImage out/bzImage

build-busybox: stamp/fetch-busybox
	-mkdir -p out/initramfs
	cp config/busybox.config src/$(BUSYBOX_DIR)/.config
	cd src/$(BUSYBOX_DIR) && $(MAKE) -j4 ARCH=x86 CROSS_COMPILE=i486-linux-musl-
	cd src/$(BUSYBOX_DIR) && $(MAKE) -j4 ARCH=x86 CROSS_COMPILE=i486-linux-musl- install
	cp -rv src/$(BUSYBOX_DIR)/_install/* out/initramfs

build-initramfs:
	-rm -rf out/initramfs/dev
	-mkdir -p out/initramfs/dev

	-rm -rf out/initramfs/sys
	-mkdir -p out/initramfs/sys

	-rm -rf out/initramfs/proc
	-mkdir -p out/initramfs/proc

	mkdir -p out/initramfs/etc/init.d/
	cp etc/rc out/initramfs/etc/init.d/rc
	chmod +x out/initramfs/etc/init.d/rc

	cp etc/inittab out/initramfs/etc/inittab
	chmod +x out/initramfs/etc/inittab

	cd out/initramfs && \
	find . | cpio -o -H newc | bzip2 -9 > $(ROOT_DIR)/out/initramfs.cpio.bz2

build-floppy: build-kernel build-initramfs build-syslinux
	dd if=/dev/zero of=./floppy_linux.img bs=1k count=1440
	mkdosfs floppy_linux.img
	out/syslinux/usr/bin/syslinux --install floppy_linux.img
	mcopy -i floppy_linux.img config/syslinux.cfg ::
	mcopy -i floppy_linux.img out/bzImage  ::
	mcopy -i floppy_linux.img out/initramfs.cpio.bz2  ::rootfs.ram

clean:
	echo "Making a fresh build ..."
	-rm -rf src dist stamp out
