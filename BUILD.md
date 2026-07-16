# Local firmware builds

This repository provides a Docker-based local build for the Cyboard Imprint. The build uses the same `assimilator-bt` board and Imprint shields as CI while keeping the west workspace outside the repository.

## Prerequisites

Install the following tools:

- Bash
- Git
- Docker with a running daemon accessible to your user

Use Docker's [official installation instructions](https://docs.docker.com/engine/install/) for your platform. The script reports separate errors when the Docker CLI is missing and when the Docker daemon is unavailable.

## Building firmware

Run the build script from the repository root:

```sh
./build-local.sh
./build-local.sh left
./build-local.sh right
./build-local.sh reset
```

With no argument, the script defaults to `left`. Each invocation refreshes the Docker image and west dependencies, builds the selected target, and prints the absolute path to the resulting firmware. Firmware is built but is not flashed automatically.

## Build outputs

Builds write these ignored files under `firmware/`:

- `firmware/imprint-left.uf2`
- `firmware/imprint-right.uf2`
- `firmware/imprint-reset.uf2`

The script verifies that its expected output exists and is non-empty before reporting success. Output ownership is set to the user who invoked the script.

## Flashing normal firmware

Flash the UF2 for the intended keyboard half:

1. Connect the intended half over USB.
2. Double-tap the reset button next to the USB-C port.
3. Wait for the USB drive named `ASSIMILATOR` to appear.
4. Copy the correct UF2 to the root of the drive.
5. Wait for the drive to unmount and the controller to restart.

Keymap-only changes generally require flashing only the central left half. Changes that affect peripheral behavior may require flashing the right half too.

See [Cyboard's Imprint flashing instructions](https://docs.cyboard.digital/user-manual/quick-start/configure-layout) and [ZMK's UF2 flashing documentation](https://zmk.dev/docs/user-setup#flash-uf2-files) for additional context.

## Resetting persistent settings

Warning: Reset firmware erases Bluetooth profiles and other persistent settings. Bluetooth is disabled while reset firmware is installed, so normal firmware must be restored afterward.

1. Build `firmware/imprint-reset.uf2` with `./build-local.sh reset`.
2. Flash `imprint-reset.uf2` to both halves.
3. Flash `imprint-left.uf2` to the left half.
4. Flash `imprint-right.uf2` to the right half.
5. Reset both halves at roughly the same time if they do not reconnect.
6. Forget the old keyboard pairing on host devices and pair it again.

Generate fresh normal images with `./build-local.sh left` and `./build-local.sh right` if needed. See ZMK's [split-keyboard settings-reset procedure](https://zmk.dev/docs/troubleshooting/connection-issues#split-keyboard-parts-unable-to-pair) for more detail.

## Docker workspace cache

The first build downloads the large ZMK Docker image and west dependencies. Subsequent builds reuse the named Docker volume `zmk-imprint-west` for source checkouts and build intermediates.

The script records the manifest and resolved west project revisions for each target. When those revisions change, it automatically creates a pristine build for that target while retaining downloaded sources. Later builds remain incremental until the dependencies change again.

Remove that cache with:

```sh
docker volume rm zmk-imprint-west
```

Removing the volume deletes only cached sources and build intermediates. It does not delete files under `firmware/`.

## Dependency updates and reproducibility

The script uses `--pull=always`, so every build refreshes the mutable official `docker.io/zmkfirmware/zmk-build-arm:stable` image. It also runs `west update` every time.

`config/west.yml` tracks ZMK's moving `main` branch and the moving `zmk-keyboards` `zephyr-4.1` branch. This pairing provides the current Zephyr hardware model; `zmk-keyboards/main` instead targets ZMK v0.3.0. Builds performed at different times can therefore use different upstream commits even when this repository has not changed.

## Troubleshooting

- `Docker CLI is required but was not found in PATH`: install Docker using the official instructions and reopen the terminal if necessary.
- `Docker daemon is not running or is inaccessible`: start Docker and ensure the current user has permission to access its daemon.
- A west update or firmware build fails after previously succeeding: an upstream branch or the mutable Docker image may have changed. Review the build output and retry after upstream issues are resolved.
- Automatic pristine rebuilding cannot recover a damaged west source workspace: remove `zmk-imprint-west` with the cache-removal command above and rebuild.
- The `ASSIMILATOR` drive does not appear: confirm that the intended half is connected over USB and double-tap the reset button next to the USB-C port again. ZMK's [flashing troubleshooting documentation](https://zmk.dev/docs/troubleshooting/flashing-issues) covers additional UF2 issues.
