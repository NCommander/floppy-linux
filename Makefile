LINUX_DIR=linux-6.4
LINUX_TARBALL=${LINUX_DIR}.tar.xz
LINUX_KERNEL_URL=https://cdn.kernel.org/pub/linux/kernel/v6.x/${LINUX_TARBALL}

.PHONY: all clean

all: stamp/fetch-kernel
	-mkdir -p stamp
	echo "Starting build ..."

stamp/fetch-kernel:
	-mkdir -p dist src stamp
	cd dist && wget ${LINUX_KERNEL_URL}
	cd src && tar -xvf ../dist/${LINUX_TARBALL}
	touch stamp/fetch-kernel

kernelmenuconfig: stamp/fetch-kernel
	cp config/kernel.config src/${LINUX_DIR}/.config
	cd src/${LINUX_DIR} && make ARCH=x86 CROSS_COMPILE=i486-linux-musl- menuconfig
	cp src/${LINUX_DIR}/.config config/kernel.config

clean:
	echo "Making a fresh build ..."
	-rm -rf src dist stamp
