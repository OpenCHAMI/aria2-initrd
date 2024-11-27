#!/bin/bash

# Ensure output directory exists
mkdir -p /workspace/output

# Create initrd directory structure
mkdir -p initrd/{bin,sbin,etc,proc,sys,dev,tmp,var,usr/{bin,sbin}}

# Copy busybox and aria2 static binaries
cp /workspace/files/bin/busybox initrd/bin/
cp /workspace/files/bin/aria2c initrd/usr/bin/

# Create symlinks for busybox utilities
cd initrd/bin
for cmd in sh ls mkdir mount umount cat echo; do
    ln -s busybox $cmd
done
cd -

# Add init script and configuration
cp /workspace/files/init initrd/
cp /workspace/files/etc/resolv.conf initrd/etc/

# Add certificate bundle
mkdir -p initrd/etc/ssl
cp files/etc/ssl/ca-bundle.crt initrd/etc/ssl/ca-bundle.crt


# Add minimal device nodes
mknod -m 666 initrd/dev/null c 1 3
mknod -m 666 initrd/dev/console c 5 1

# Package initrd
cd initrd
find . | cpio -o -H newc | gzip > /workspace/output/custom-initrd.img
cd ..

echo "custom-initrd.img created successfully in /workspace/output/"

