# tiny-kernel

Small Linux boot experiment built around a tiny kernel config, a minimal BusyBox-based initramfs, and a local QEMU boot script.

## What this repo does

This repository keeps the pieces needed to boot a very small Linux userspace:

- a kernel `.config`
- a minimal `initramfs/` tree
- a `start.sh` helper that triggers a GitHub Actions build, downloads the released `bzImage` and `initrd.img`, and boots them with QEMU

The default `init` mounts `/proc`, `/sys`, and `/dev`, installs BusyBox applets, and then drops into `/bin/sh`.

## Inspiration

This project is directly inspired by blinry's article, [Building a tiny Linux from scratch](https://blinry.org/tiny-linux/), which walks through assembling a minimal Linux system from a tiny kernel, BusyBox, and an initramfs.

## Usage

Prerequisites:

- `gh`
- `qemu-system-x86_64`
- `tar`
- GitHub CLI authenticated with access to trigger Actions in the target repo

Run:

```bash
./start.sh
```

What happens:

1. `start.sh` triggers the `build-linux-tinyconfig.yml` workflow.
2. GitHub Actions builds `bzImage` from the repository `.config`.
3. GitHub Actions packs `initramfs/` into `initrd.img`.
4. The script downloads the release artifact and boots it with QEMU in serial mode.

If needed, override the branch used for the workflow dispatch:

```bash
RUN_REF=my-branch ./start.sh
```

## Repo layout

- `.config`: Linux kernel configuration used by CI
- `initramfs/init`: PID 1 inside the initramfs
- `initramfs/bin/busybox`: static BusyBox binary used by the initramfs
- `start.sh`: fetch-and-boot helper for local testing
- `.github/workflows/build-linux-tinyconfig.yml`: CI build and release pipeline

## Notes

- The local boot path expects prebuilt artifacts from GitHub Actions rather than compiling the kernel on your machine.
- QEMU is started with `-nographic`, so interaction happens through the terminal.
