#!/bin/bash

# Ensure output directory exists
mkdir -p /workspace/output

# Create initrd directory structure
mkdir -p initrd/{bin,sbin,etc,proc,sys,dev,tmp,var,usr/{bin,sbin,share},lib,usr/lib}
mkdir -p initrd/usr/share/dbus-1

# Create device nodes for TPM in the initrd
mknod -m 666 initrd/dev/tpm0 c 10 224 || true
mknod -m 666 initrd/dev/tpmrm0 c 10 232 || true

# Create necessary directories for D-Bus and TPM2 Resource Manager

mkdir -p initrd/run
mkdir -p initrd/var/run
mkdir -p initrd/run/dbus
mkdir -p initrd/var/run/dbus

# Create directories for TPM keys
mkdir -p initrd/etc/tpm

# Copy busybox and aria2 static binaries
cp /workspace/files/bin/busybox initrd/bin/
cp /workspace/files/bin/aria2c initrd/usr/bin/

# Create symlinks for busybox utilities and tpm tools 
cd initrd/bin
for cmd in sh ls mkdir mount umount cat echo mknod ifconfig udhcpc wget \
           ln pwd sleep chmod chown route modprobe insmod rmmod depmod \
           lsmod sysctl free df; do
    ln -s busybox $cmd
done
cd -


# Copy kexec binary
cp /usr/sbin/kexec initrd/sbin/

# Copy curl binary
cp /usr/bin/curl initrd/usr/bin/

# Copy TPM2 tools binaries
cp /usr/bin/tpm2_* initrd/usr/bin/

# Copy D-Bus daemon (required for tpm2-abrmd)
cp /usr/bin/dbus-daemon initrd/usr/bin/

# Copy tpm2-abrmd daemon
cp /usr/sbin/tpm2-abrmd initrd/usr/sbin/

# Copy D-Bus system configuration
cp /usr/share/dbus-1/system.conf initrd/usr/share/dbus-1/



# Create and modify D-Bus system configuration to run as root
cp /usr/share/dbus-1/system.conf initrd/usr/share/dbus-1/system.conf
sed -i 's/<user>dbus<\/user>/<user>root<\/user>/' initrd/usr/share/dbus-1/system.conf

# Create minimal /etc/passwd and /etc/group
echo "root:x:0:0:root:/root:/bin/sh" > initrd/etc/passwd
echo "root:x:0:" > initrd/etc/group

# Add minimal nsswitch.conf for user lookup
echo "passwd: files" > initrd/etc/nsswitch.conf
echo "group: files" >> initrd/etc/nsswitch.conf

# Copy necessary shared libraries for all binaries (copied earlier)

function copy_libs {
    for bin in "$@"; do
        ldd "$bin" | grep "=>" | awk '{print $3}' | xargs -I '{}' cp -v --parents '{}' initrd/
	for lib_dir in $host_lib_dir; do
            find "$lib_dir" -name "libnss*" -print0 | while IFS= read -r -d $'\0' lib; do
                if [ -f "$lib" ]; then
                    cp -v --parents "$lib" initrd/
                    ldd "$lib" 2>/dev/null | grep "=>" | awk '{print $3}' | while read -r dep; do
                        if [ -f "$dep" ]; then
                           cp -v --parents "$dep" initrd/
                        fi
                    done
                fi
            done
        done
    done
}


copy_libs /workspace/files/bin/busybox \
          /workspace/files/bin/aria2c \
          /usr/sbin/kexec \
          /usr/bin/curl \
          /usr/bin/tpm2_pcrread \
          /usr/bin/dbus-daemon \
          /usr/sbin/tpm2-abrmd

echo "Checking if 'ldd' is functional..."
ldd --version || { echo "ldd not found or not functional."; exit 1; }

echo "Verifying dbus-daemon dependencies..."
ldd /usr/bin/dbus-daemon

echo "Copying dbus-daemon dependencies into initrd..."
ldd /usr/bin/dbus-daemon | grep "=>" | awk '{print $3}' | xargs -I '{}' cp -v --parents '{}' initrd/

# Ensure that the dynamic linker is copied:
# This is often something like /lib64/ld-linux-x86-64.so.2
if ! find initrd -name "ld-linux-*.so.*" | grep -q ld-linux; then
    echo "Dynamic linker not found in initrd, copying it..."
    LNK=$(ldd /usr/bin/dbus-daemon | grep 'ld-linux' | awk '{print $1}')
    [ -n "$LNK" ] && cp -v --parents "$LNK" initrd/
fi

# Copy all libraries from /lib64 on the host to initrd/lib64
cp -av /lib64/libnss* initrd/lib64/

# Add init script and configuration
cp /workspace/files/init initrd/
cp /workspace/files/etc/resolv.conf initrd/etc/

# Copy TPM2 tools and scripts into the initrd filesystem
cp /workspace/tpm_init.sh initrd/bin

# Add certificate bundle
mkdir -p initrd/etc/ssl
cp files/etc/ssl/ca-bundle.crt initrd/etc/ssl/ca-bundle.crt


# Add minimal device nodes
mknod -m 666 initrd/dev/null c 1 3
mknod -m 666 initrd/dev/console c 5 1

# Create essential device nodes for initrd

# Create a TTY device node for terminal input/output (needed for logging/debugging during early boot)
mknod -m 666 initrd/dev/tty c 5 0

# Create a random number generator device node (used for cryptographic operations like key generation)
mknod -m 666 initrd/dev/random c 1 8

# Create a non-blocking random number generator device node (commonly used for generating random data efficiently)
mknod -m 666 initrd/dev/urandom c 1 9

# Create a zero-filled device node (provides a stream of zero bytes, useful for memory initialization)
mknod -m 666 initrd/dev/zero c 1 10

# Create a pseudo-terminal multiplexer device node (enables multiple terminal sessions, useful for advanced debugging)
mknod -m 666 initrd/dev/ptmx c 5 2




# Ensure all binaries are executable
chmod +x initrd/init
chmod +x files/bin/*
chmod +x initrd/usr/bin/*
chmod +x initrd/usr/sbin/*
chmod +x initrd/sbin/*
chmod +x initrd/bin/tpm_init.sh
chmod +x initrd/usr/share/dbus-1/*
chmod +x initrd/etc/passwd
chmod +x initrd/etc/group


# Verify directory structure
echo "Verifying directory structure:"
ls -l initrd/etc/
ls -l initrd/run/dbus
ls -l initrd/var/run/dbus


# Package initrd
cd initrd
find . | cpio -o -H newc | gzip > /workspace/output/custom-initrd.img
cd ..

echo "custom-initrd.img created successfully in /workspace/output/"