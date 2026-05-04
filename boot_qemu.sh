SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
boot_qemu() {
  exec qemu-system-x86_64 \
    -m 1G \
    -enable-kvm \
    -kernel "${SCRIPT_DIR}/bzImage" \
    -initrd "${SCRIPT_DIR}/initrd.img" \
    -nographic \
    -append "console=ttyS0 nokaslr"
}
boot_qemu() {
  exec qemu-system-x86_64 \
    -m 1G \
    -enable-kvm \
    -kernel "${SCRIPT_DIR}/bzImage" \
    -initrd "/boot/initramfs-linux.img" \
    -nographic \
    -append "console=ttyS0 nokaslr"
}
boot_qemu

