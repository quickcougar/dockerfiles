#!/usr/bin/bash

set -e
umask 022

if [[ "$UID" != '0' ]]; then
    echo 'Needs to be run as root.'
    exit 1
fi
if ! hash pacstrap &>/dev/null; then
    echo 'Could not find pacstrap. Run pacman -S arch-install-scripts'
    exit 1
fi

SCRIPTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

ROOTFS=$(mktemp --directory ${TMPDIR:-/var/tmp}/rootfs-archlinux-XXXXXXXXXX)
chmod 755 "$ROOTFS"

function cleanup {
    echo "Removing $ROOTFS"
    rm --recursive "$ROOTFS"
}
trap cleanup EXIT

PKGS='bash filesystem glibc pacman shadow'

pacstrap -c -d -G -M "$ROOTFS" $PKGS haveged procps-ng sed
install --mode=644 "$SCRIPTDIR/etc/pacman.d/mirrorlist" "$ROOTFS/etc/pacman.d/"
install --mode=644 "$SCRIPTDIR/etc/locale.conf" "$ROOTFS/etc/"
install --mode=644 "$SCRIPTDIR/etc/locale.gen" "$ROOTFS/etc/"

arch-chroot "$ROOTFS" /usr/bin/bash << 'EOF'
haveged --write=1024
pacman-key --init
pkill --exact haveged
pacman-key --populate archlinux
pkill --exact gpg-agent

sed --in-place 's/^CheckSpace/#CheckSpace/g' /etc/pacman.conf

ln --symbolic /usr/share/zoneinfo/UTC /etc/localtime
locale-gen

pacman --remove --recursive --nosave --noconfirm haveged procps-ng sed
EOF

DEV="$ROOTFS/dev"
rm --recursive --force "$DEV"
mkdir --parents "$DEV"
mknod --mode=666 "$DEV/null" c 1 3
mknod --mode=666 "$DEV/zero" c 1 5
mknod --mode=666 "$DEV/random" c 1 8
mknod --mode=666 "$DEV/urandom" c 1 9
mkdir --mode=755 "$DEV/pts"
mkdir --mode=1777 "$DEV/shm"
mknod --mode=666 "$DEV/tty" c 5 0
mknod --mode=600 "$DEV/console" c 5 1
mknod --mode=666 "$DEV/tty0" c 4 0
mknod --mode=666 "$DEV/full" c 1 7
mknod --mode=600 "$DEV/initctl" p
mknod --mode=666 "$DEV/ptmx" c 5 2
ln --symbolic --force /proc/self/fd "$DEV/fd"

tar --numeric-owner --xattrs --acls --xz --create --directory="$ROOTFS" --file="$SCRIPTDIR/arch-mini.tar.xz" .
