#!/bin/sh

# if script is located on /opt/cross/arm-v7a then it build and packs toolchain
# otherwise it build generic linux toolchain using docker (and old ubuntu to support many glibc versions)
if [ ! -f /opt/cross/arm-v7a/build.sh ]; then
	exec docker run --rm -it -v `pwd`:/opt/cross/arm-v7a ubuntu:14.04 /opt/cross/arm-v7a/build.sh
fi

# path is only useful for macOS build where we want to add symlinks to gnu tools
# awk -> /usr/local/bin/gawk
# install -> /usr/local/bin/ginstall
# readlink -> /usr/local/bin/greadlink
export PATH=/opt/cross/bin:$PATH

# "tar" doesn't like to be configured as root
export FORCE_UNSAFE_CONFIGURE=1

echo 'Checking for GNU readlink'
readlink --version | grep GNU || exit 1
echo OK

cd /opt/cross/arm-v7a || exit 1

OK=n
test -d bin || \
test -d build_dir || \
test -f scripts/config/conf || \
test -f scripts/config/mconf* || \
test -d staging_dir || \
test -d tmp || \
OK=y

if [ "x$OK" = "xn" ]; then
	while true; do
		read -p "Do you want to remove files from previous build? " yn
		case $yn in
			[Yy]* ) rm -rf bin build_dir scripts/config/conf \
				scripts/config/lxdialog \
				scripts/config/*o staging_dir tmp && echo OK; break;;
			[Nn]* ) break;;
			* ) echo "Please answer yes or no.";;
		esac
	done
fi

apt-get update
apt-get -y install build-essential ncurses-dev libz-dev gawk unzip wget python git

if [ ! -e .git ]; then
	git clone https://git.lede-project.org/source.git /tmp/lede
	mv /tmp/lede/.git .
	rm -rf /tmp/lede
	git fetch --tags
	git checkout v17.01.4
fi

git checkout .

cat <<CONFIG > .config
CONFIG_TARGET_bcm53xx=y
CONFIG_TARGET_bcm53xx_Generic=y
CONFIG_TARGET_BOARD="bcm53xx"
CONFIG_MAKE_TOOLCHAIN=y
CONFIG_DEVEL=y
CONFIG_TOOLCHAINOPTS=y
CONFIG_BINUTILS_USE_VERSION_2_27=y
CONFIG_BINUTILS_VERSION="2.27"
CONFIG_BINUTILS_VERSION_2_27=y
CONFIG_GCC_USE_VERSION_6=y
CONFIG_GCC_VERSION="6.3.0"
CONFIG

make defconfig
make tools/download
make toolchain/download
make -j 4 toolchain/install V=s || exit 1

tar cvJf /opt/cross/arm-v7a/arm-v7a.tar.xz \
	/opt/cross/arm-v7a/staging_dir/host/bin \
	/opt/cross/arm-v7a/staging_dir/toolchain*
