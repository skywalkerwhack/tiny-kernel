# tiny-kernel

This repository contains a GitHub Actions workflow that builds a Linux kernel
`bzImage` from the latest upstream Linux source using `tinyconfig`, then
publishes the result as a rolling GitHub release.

## What it does

The workflow:

1. Clones the latest Linux kernel source from
   `https://github.com/torvalds/linux.git` on branch `master`
2. Runs `make tinyconfig`
3. Builds `arch/x86/boot/bzImage`
4. Deletes existing releases and tags in this repository
5. Creates a fresh release named `latest` and uploads the new `bzImage`

The result is a single release model: each manual run replaces the previous
release so there is only one release at a time.

## Workflow

Workflow file:

- `.github/workflows/build-linux-tinyconfig.yml`

Trigger:

- Manual only, via GitHub Actions `workflow_dispatch`

Required repository permission:

- `contents: write`

## How to use

1. Push this repository to GitHub
2. Open the repository's `Actions` tab
3. Select `Build Linux tinyconfig`
4. Click `Run workflow`
5. Wait for the job to finish
6. Open the repository's `Releases` page and download `bzImage`

## Output

Published asset:

- `bzImage`

Kernel config:

- `tinyconfig`

Kernel source:

- Latest upstream Linux `master`

## Important behavior

- Every run deletes all existing releases in this repository before publishing a
  new one
- Every run also deletes all existing tags before recreating the `latest` tag
- Do not store any other releases or tags in this repository unless you want
  them removed by the workflow
- The workflow builds an x86 kernel image because it publishes
  `arch/x86/boot/bzImage`

## Notes

- The build runs on `ubuntu-latest`
- The workflow installs the required kernel build dependencies during the run
- This repository does not store Linux source code; it fetches it during the
  workflow run
