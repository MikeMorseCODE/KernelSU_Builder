# KernelSU Builder

KernelSU Builder is a tool that allows you to build kernels with or without KernelSU support. It uses GitHub Actions for automated kernel builds and supports multiple versions and configurations. The kernel is fully compiled using Clang.

[![Build Kernel](https://github.com/HowWof/KernelSU_Builder/actions/workflows/build_kernel.yml/badge.svg)](https://github.com/HowWof/KernelSU_Builder/actions/workflows/build_kernel.yml)
[![Watch KernelSU](https://github.com/HowWof/KernelSU_Builder/actions/workflows/watch_ksu.yml/badge.svg)](https://github.com/HowWof/KernelSU_Builder/actions/workflows/watch_ksu.yml)

## Table of Contents
- [Building Kernel](#building-kernel)
- [Flashing the Kernel](#flashing-the-kernel)

## Building Kernel

Follow these steps to use this Builder:

1. Fork this repository.
2. Update the `sources.yaml` file with your build sources and provide AnyKernel3.
3. Set up the necessary secrets in your repository settings. The required secret is `GH_PAT`: A personal access token with the `repo` scope.
4. Trigger the GitHub Actions workflow manually or wait for it to be triggered automatically on each push.
5. The builder will compile the kernel using Clang and create a release on the GitHub repository.

### Rapid Bring-Up Workflow (until the kernel compiles)

If you are trying to finish quickly, use this loop:

1. **Start with a clean state**: run `clean.sh`, then run `clone.sh` with `VERSION` set.
2. **Validate tooling early**: ensure `python`, `jq`, `git`, `clang`, and required host build tools are available before compiling.
3. **Run one build attempt**: execute `build.sh` and capture the full error output.
4. **Classify failures**:
   - missing headers / symbols -> source or defconfig issue
   - linker/vendor symbols -> likely proprietary blob or dump dependency
   - dtb/dtbo packing errors -> AnyKernel/device tree packaging mismatch
5. **Patch and retry immediately**: apply minimal fixes, then repeat from step 1.
6. **Request proprietary inputs when needed**: if the build fails on vendor/proprietary symbols, provide blobs, proprietary files, or dumps so they can be integrated and the loop can continue.

This repeated diagnose -> patch -> rebuild loop is the fastest path to a successful kernel build.

## Flashing the Kernel

To flash the kernel onto your device:

1. Go to the GitHub repository's releases page and download the latest build.
2. Boot your device into recovery mode.
3. Select 'Install' and navigate to the downloaded kernel zip file.
4. Swipe to confirm the flash.
5. Reboot your device.

Please note that this workflow is provided as-is without any warranties. Use it at your own risk. Ensure compatibility and follow device-specific guidelines before flashing custom kernels. Read and understand the installation instructions and warnings before proceeding with kernel installation.
