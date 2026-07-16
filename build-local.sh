#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'Usage: ./build-local.sh [left|right|reset]\n' >&2
}

if (( $# > 1 )); then
    usage
    exit 2
fi

TARGET="${1:-left}"
case "$TARGET" in
    left)
        SHIELD="imprint_left"
        ;;
    right)
        SHIELD="imprint_right"
        ;;
    reset)
        SHIELD="imprint_left settings_reset"
        ;;
    *)
        usage
        exit 2
        ;;
esac

if ! command -v git >/dev/null 2>&1; then
    printf 'Error: Git is required but was not found in PATH.\n' >&2
    exit 1
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if ! REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
    printf 'Error: Could not resolve the Git repository containing %s.\n' "$SCRIPT_DIR" >&2
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    printf 'Error: Docker CLI is required but was not found in PATH.\n' >&2
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    printf 'Error: Docker daemon is not running or is inaccessible. Ensure Docker is running and your user can access it.\n' >&2
    exit 1
fi

IMAGE="docker.io/zmkfirmware/zmk-build-arm:stable"
WORKSPACE_VOLUME="zmk-imprint-west"
OUTPUT_DIR="$REPO_ROOT/firmware"
OUTPUT_FILE="$OUTPUT_DIR/imprint-$TARGET.uf2"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

mkdir -p "$OUTPUT_DIR"
docker volume create "$WORKSPACE_VOLUME" >/dev/null

docker run \
    --rm \
    --pull=always \
    --security-opt label=disable \
    --workdir /work \
    --env "HOST_UID=$HOST_UID" \
    --env "HOST_GID=$HOST_GID" \
    --env "TARGET=$TARGET" \
    --env "SHIELD=$SHIELD" \
    --volume "$WORKSPACE_VOLUME:/work:rw" \
    --volume "$REPO_ROOT/config:/work/config:ro" \
    --volume "$REPO_ROOT:/repo:ro" \
    --volume "$OUTPUT_DIR:/out:rw" \
    "$IMAGE" \
    bash -euo pipefail -c '
        if [[ ! -d /work/.west ]]; then
            west init -l /work/config
        fi
        west update --fetch-opt=--filter=tree:0
        west zephyr-export

        DEPENDENCY_STATE="$(
            printf "manifest:%s\n" "$(git hash-object -- /work/config/west.yml)"
            while IFS=: read -r PROJECT_NAME PROJECT_PATH; do
                if [[ "$PROJECT_NAME" == "manifest" ]]; then
                    continue
                fi
                printf "%s:%s\n" "$PROJECT_NAME" "$(git -C "$PROJECT_PATH" rev-parse HEAD)"
            done < <(west list -f "{name}:{abspath}")
        )"
        STATE_DIR="/work/.build-state"
        STATE_FILE="$STATE_DIR/$TARGET-dependencies"
        PRISTINE="auto"

        if [[ -d "/work/build/$TARGET" ]]; then
            PREVIOUS_DEPENDENCY_STATE=""
            if [[ -f "$STATE_FILE" ]]; then
                PREVIOUS_DEPENDENCY_STATE="$(< "$STATE_FILE")"
            fi
            if [[ "$PREVIOUS_DEPENDENCY_STATE" != "$DEPENDENCY_STATE" ]]; then
                printf "Dependency revisions changed; creating a pristine %s build.\n" "$TARGET"
                PRISTINE="always"
            fi
        fi

        west build \
            -p "$PRISTINE" \
            -s zmk/app \
            -d "/work/build/$TARGET" \
            -b assimilator-bt \
            -- \
            -DZMK_CONFIG=/work/config \
            -DZMK_EXTRA_MODULES=/repo \
            "-DSHIELD=$SHIELD"
        mkdir -p "$STATE_DIR"
        printf "%s\n" "$DEPENDENCY_STATE" > "$STATE_FILE"
        cp "/work/build/$TARGET/zephyr/zmk.uf2" "/out/imprint-$TARGET.uf2"
        chown "$HOST_UID:$HOST_GID" "/out/imprint-$TARGET.uf2"
    '

if [[ ! -s "$OUTPUT_FILE" ]]; then
    printf 'Error: Expected firmware output is missing or empty: %s\n' "$OUTPUT_FILE" >&2
    exit 1
fi

if [[ "$TARGET" == "reset" ]]; then
    printf '\nWARNING: FLASHING THIS FIRMWARE WILL ERASE PERSISTENT SETTINGS.\n\n'
    printf 'Build successful.\n\n'
    printf 'Firmware written to:\n  %s\n\n' "$OUTPUT_FILE"
    printf 'The firmware has not been flashed yet.\n\n'
    printf 'The reset firmware erases Bluetooth profiles and other persistent settings.\n'
    printf 'Bluetooth is disabled by the reset firmware. Restore normal firmware afterward.\n\n'
    printf 'Next steps:\n'
    printf '  1. Connect the left half over USB.\n'
    printf '  2. Double-tap the reset button next to the USB-C port.\n'
    printf '  3. Wait for the ASSIMILATOR USB drive to appear.\n'
    printf '  4. Copy the reset firmware shown above to the root of that drive.\n'
    printf '  5. Wait for the drive to unmount and the keyboard to restart.\n'
    printf '  6. Repeat steps 1-5 to flash the same reset firmware to the right half.\n'
    printf '  7. Generate normal firmware if needed:\n'
    printf '       ./build-local.sh left\n'
    printf '       ./build-local.sh right\n'
    printf '  8. Flash imprint-left.uf2 to the left half using the procedure above.\n'
    printf '  9. Flash imprint-right.uf2 to the right half using the procedure above.\n'
    printf ' 10. If the halves do not reconnect, reset both halves at roughly the same time.\n'
    printf ' 11. Forget the keyboard on previously paired host devices and pair it again.\n'
else
    printf '\nBuild successful.\n\n'
    printf 'Firmware written to:\n  %s\n\n' "$OUTPUT_FILE"
    printf 'The firmware has not been flashed yet.\n\n'
    printf 'Next steps:\n'
    printf '  1. Connect the %s half over USB.\n' "$TARGET"
    printf '  2. Double-tap the reset button next to the USB-C port.\n'
    printf '  3. Wait for the ASSIMILATOR USB drive to appear.\n'
    printf '  4. Copy the firmware shown above to the root of that drive.\n'
    printf '  5. Wait for the drive to unmount and the keyboard to restart.\n'
fi
