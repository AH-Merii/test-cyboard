# Shared 36-Key ZMK Keymap Plan

## Status

This document records the agreed implementation plan. No firmware changes described here had been implemented when this file was created.

The initial implementation scope is the Cyboard repository only. Toucan remains a separate firmware build and repository; its future integration is documented here but is not part of the initial implementation.

## Objective

Maintain one hardware-neutral 36-key ZMK keymap for:

- Cyboard Imprint using ZMK `main` and the `zmk-keyboards` `zephyr-4.1` branch.
- Beekeeb Toucan1 using its known-working vendor-derived ZMK `v0.3` build.

Both keyboards use a canonical `3x5+3` logical layout. Matrix transforms normalize hardware wiring and physical ordering. Pointing devices, displays, build manifests, and other hardware behavior remain board-specific.

## Decisions

1. Keep Cyboard and Toucan in separate west workspaces because their currently proven dependency graphs differ.
2. Use this repository as the data-only Zephyr module that exposes the shared keymap.
3. Implement and verify only the Cyboard consumer initially.
4. Do not add Toucan to this repository's build matrix.
5. Do not port Toucan hardware to ZMK `main`.
6. Do not introduce a generalized framework for arbitrary keyboard sizes.
7. Do not add board-specific thumb abstractions until a concrete semantic difference requires them.

## Current State

### Cyboard

- The active keymap is `config/imprint.keymap`.
- The physical keyboard uses 36 keys in a `3x5+3` arrangement.
- The keymap currently selects the upstream 48-position `&imprint_letters_only_no_bottom_row` transform.
- Every layer currently pads unused outer alpha positions and a second thumb row.
- `config/imprint_36key.dtsi` already contains the correct canonical 36-position transform.
- `config/imprint_left.overlay` includes that transform without an offset.
- `config/imprint_right.overlay` includes that transform and applies `row-offset = <7>`.
- The 36-key transform is dormant until the keymap selects `&imprint_36key`.

The existing uncommitted changes in `config/imprint.keymap` must be preserved, including:

- Named layer constants.
- The `RGUI` binding on the scroll layer.
- The updated trackball layer references and comments.

### Toucan1

- The vendor repository is `https://github.com/beekeeb/zmk-keyboard-toucan`.
- The vendor build uses the `seeeduino_xiao_ble` board and `toucan_left`/`toucan_right` shields.
- The left side includes the display and the right side includes the Cirque trackpad.
- The vendor transform exposes 42 logical positions: three rows of 12 alpha keys and six thumbs.
- The 36-key view keeps alpha columns 1 through 10 and all six thumbs.
- The vendor right overlay already applies `col-offset = <6>` to `&default_transform`.
- The vendor repository uses a different ZMK dependency graph, so it must not import this repository's `config/west.yml`.

There was no local Toucan checkout and no public `AH-Merii/zmk-keyboard-toucan` fork when this plan was written.

## Canonical Position Contract

The shared keymap uses this logical order:

```text
 0  1  2  3  4       5  6  7  8  9
10 11 12 13 14      15 16 17 18 19
20 21 22 23 24      25 26 27 28 29
         30 31 32   33 34 35
```

The contract is:

- Positions `0..29`: 30 shared alpha positions.
- Positions `30..32`: left thumb cluster.
- Positions `33..35`: right thumb cluster.

### Cyboard 48-to-36 Conversion

```text
Old  1..10  -> New  0..9
Old 13..22  -> New 10..19
Old 25..34  -> New 20..29
Old 36..41  -> New 30..35
```

Drop old positions:

```text
0, 11, 12, 23, 24, 35, 42, 43, 44, 45, 46, 47
```

Every layer must contain exactly 36 bindings after conversion.

## Position-Sensitive Behavior

The transform change must be atomic with these updates.

### Caps Combo

The Caps Lock combo moves from old positions `13 22` to:

```dts
key-positions = <10 19>;
```

### Home-Row Mod Triggers

The left-side home-row mod behavior is allowed to hold when a right-side key is pressed:

```dts
hold-trigger-key-positions = <
    5 6 7 8 9
    15 16 17 18 19
    25 26 27 28 29
    33 34 35
>;
```

The right-side home-row mod behavior is allowed to hold when a left-side key is pressed:

```dts
hold-trigger-key-positions = <
    0 1 2 3 4
    10 11 12 13 14
    20 21 22 23 24
    30 31 32
>;
```

### Mouse Clicks

The existing Y/U/N mouse buttons become:

```text
Position 5:  left click
Position 6:  right click
Position 25: middle click
```

### Scroll-Layer RGUI

The existing `RGUI` binding on O moves from old position 9 to canonical position 8.

## Shared Module Layout

Add the common keymap under the module DTS root:

```text
dts/
└── ah_merii/
    └── keymaps/
        └── common_36.dtsi
```

The board wrapper will include it as:

```dts
#include <ah_merii/keymaps/common_36.dtsi>
```

Update `zephyr/module.yml` to expose the DTS root while preserving the existing board root:

```yaml
name: ah-merii-keymap
build:
  settings:
    board_root: .
    dts_root: .
```

`dts_root` is supported by both the older Zephyr generation used by the Toucan vendor build and the current Zephyr generation used by Cyboard.

## Shared File Responsibilities

`dts/ah_merii/keymaps/common_36.dtsi` will own:

- Generic ZMK key, Bluetooth, behavior, and pointing includes required by the bindings.
- Layer IDs for `DEFAULT`, `ARROW`, `NAV`, `NUM`, `SYM`, `FUNC`, `MOUSE`, and `SCROLL`.
- Home-row mod binding macros.
- Hyper macro behavior.
- Home-row hold-tap behaviors.
- Thumb hold-tap behaviors.
- Caps Lock combo.
- All eight layer nodes.
- Exactly 36 bindings per layer.

Exported C preprocessor names and devicetree labels should be namespaced where practical to avoid collisions when the file is consumed by another keyboard repository.

The shared file must not contain:

- A `chosen` matrix transform.
- Cyboard trackball listener labels.
- Toucan trackpad listener labels.
- Cirque or trackball scaling and orientation.
- Display configuration.
- Board, shield, matrix, GPIO, or split configuration.
- West dependencies or build targets.

## Cyboard Wrapper

Refactor `config/imprint.keymap` into a thin board-specific wrapper.

It will:

1. Include the input processor and input transform definitions required by the trackball configuration.
2. Include `<ah_merii/keymaps/common_36.dtsi>`.
3. Select the existing transform:

```dts
/ {
    chosen {
        zmk,matrix-transform = &imprint_36key;
    };
};
```

4. Retain the central trackball listener as an always-on scroll wheel.
5. Retain the peripheral trackball listener as cursor movement with temporary `MOUSE` activation.
6. Retain the peripheral trackball's `SCROLL`-layer mode.

The existing listener behavior remains:

- Central trackball: scroll wheel with existing scaling and Y inversion.
- Peripheral trackball: normal cursor movement.
- Peripheral movement: temporarily activates `MOUSE` for 500 ms.
- Holding I: activates `SCROLL`; peripheral movement becomes scrolling.

No changes are needed in:

- `config/imprint_36key.dtsi`
- `config/imprint_left.overlay`
- `config/imprint_right.overlay`
- `config/imprint.conf`
- `build.yaml`
- `.github/workflows/build.yml`
- `build-local.sh`
- `BUILD.md`

## Cyboard Verification

Run the supported Docker builds from the repository root:

```sh
./build-local.sh left
./build-local.sh right
./build-local.sh reset
```

Expected outputs:

```text
firmware/imprint-left.uf2
firmware/imprint-right.uf2
firmware/imprint-reset.uf2
```

Before reporting completion:

1. Confirm all three firmware builds succeed.
2. Confirm every layer has 36 bindings.
3. Confirm `&imprint_36key` is the selected transform.
4. Confirm the right build retains `row-offset = <7>`.
5. Confirm the Caps combo uses positions `10 19`.
6. Confirm the two home-row trigger lists use canonical positions.
7. Confirm Y/U/N clicks are at positions `5`, `6`, and `25`.
8. Confirm O/RGUI is retained on `SCROLL` at position 8.

Because both the logical transform and the peripheral build's position mapping change, flash both normal halves for hardware verification.

Hardware checks:

1. Test all 36 physical positions on the base layer.
2. Test all six thumbs and every layer transition.
3. Test both home-row mod directions and quick taps.
4. Hold both Shift home-row keys and confirm Caps Lock.
5. Confirm the central trackball scrolls.
6. Confirm the peripheral trackball moves the cursor.
7. Confirm peripheral movement activates the temporary mouse layer.
8. Confirm Y/U/N produce left/right/middle click while `MOUSE` is active.
9. Hold I and confirm peripheral movement scrolls.
10. Confirm O produces `RGUI` while `SCROLL` is active.

The reset image should be compiled as part of matrix verification. It does not need to be flashed unless persistent split or Bluetooth settings require a reset.

## Future Toucan Consumer

This section is documentation only for the initial implementation.

### Repository Setup

Create a separate fork or user config based on Beekeeb's Toucan repository. Add this repository as a west project and pin a known commit. Do not use `import` on the project, because the Toucan build must keep its own ZMK `v0.3` dependency graph rather than importing `config/west.yml` from this repository.

Conceptually:

```yaml
manifest:
  remotes:
    - name: ah-merii
      url-base: https://github.com/AH-Merii
  projects:
    - name: test-cyboard
      remote: ah-merii
      revision: <pinned-commit>
      path: modules/keymaps/ah-merii
```

The exact repository name should be taken from its actual remote when implemented rather than assumed from a local checkout name.

### Toucan 36-Key Projection

Prefer overriding the vendor's existing `&default_transform`. Its right overlay already applies the required `col-offset = <6>`.

The 36-key map is:

```dts
&default_transform {
    map = <
        RC(0,1) RC(0,2) RC(0,3) RC(0,4) RC(0,5)
        RC(0,6) RC(0,7) RC(0,8) RC(0,9) RC(0,10)

        RC(1,1) RC(1,2) RC(1,3) RC(1,4) RC(1,5)
        RC(1,6) RC(1,7) RC(1,8) RC(1,9) RC(1,10)

        RC(2,1) RC(2,2) RC(2,3) RC(2,4) RC(2,5)
        RC(2,6) RC(2,7) RC(2,8) RC(2,9) RC(2,10)

        RC(3,3) RC(3,4) RC(3,5)
        RC(3,6) RC(3,7) RC(3,8)
    >;
};
```

Also replace `&default_layout.keys` with the matching 36 physical-key records in this order:

```text
Existing records 1..10
Existing records 13..22
Existing records 25..34
Existing records 36..41
```

Do not merely add `chosen { zmk,matrix-transform = ...; };` while retaining the active 42-key physical layout. Toucan's Studio-enabled build should continue using one consistent 36-position physical layout and transform.

### Toucan Pointing Behavior

The Toucan wrapper will keep the vendor Cirque scaling and orientation while adopting the Cyboard interaction model:

- One-finger motion moves the cursor.
- Trackpad activity temporarily activates the shared `MOUSE` layer for 500 ms.
- Y/U/N provide left/right/middle click through the shared keymap.
- Holding I activates the shared `SCROLL` layer.
- Motion on `SCROLL` uses the vendor's scroll mapper, scaler, and X inversion.
- Native trackpad tap clicks remain enabled if emitted by the vendor driver.

Conceptually:

```dts
&glidepoint_listener {
    input-processors =
        <&zip_xy_scaler 250 100>,
        <&zip_temp_layer MERII_MOUSE 500>;

    scroller {
        layers = <MERII_SCROLL>;
        input-processors = <
            &zip_xy_to_scroll_mapper
            &zip_scroll_scaler 1 5
            &zip_scroll_transform INPUT_TRANSFORM_X_INVERT
        >;
    };
};
```

Preserve the vendor's increased `CONFIG_INPUT_THREAD_STACK_SIZE=2048`, power settings, trackpad driver, display shield, RGB adapter, and build targets.

### Toucan Verification

When a Toucan consumer is eventually created, build:

- Toucan left with its display and Studio shields.
- Toucan right with its trackpad and RGB adapter.
- Toucan settings reset.

Then verify:

- The active transform and physical layout each expose 36 positions.
- The right half retains `col-offset = <6>`.
- All six outer alpha positions omitted from the transform are inert.
- All 36 retained physical positions match Cyboard semantics.
- The display still renders normally.
- Cursor, temporary mouse layer, native taps, and hold-I scrolling all work.
- A settings reset is performed if stored Studio mappings mask source-keymap changes.

## Board-Specific Thumb Clusters

### What Transforms Can Normalize

The exact same 36-binding keymap can be reused when both boards have six logical thumbs and only these properties differ:

- Physical angle, rotation, spacing, or stagger.
- Matrix rows and columns.
- Mirrored or reversed wiring order.
- A fixed permutation of the six physical thumb switches.

Each board's matrix transform should list its physical coordinates in canonical semantic order. Physical layout metadata should describe geometry in the same logical order.

### When Bindings Must Differ

A transform cannot express:

- Different thumb behavior on only some layers.
- Different semantic assignments rather than a fixed physical permutation.
- Missing thumb keys.
- Layer-dependent physical remapping.

If a future six-thumb board needs different thumb semantics, add one optional C preprocessor token-list macro per affected layer. The common file would continue owning the 30 alpha bindings and append the selected six-binding thumb tail.

Conceptually:

```dts
/* Board wrapper, before the common include. */
#define MERII_THUMBS_DEFAULT \
    &kp LGUI  &mo NAV  &kp SPACE  &kp ENTER  &mo SYM  &kp RALT

#include <ah_merii/keymaps/common_36.dtsi>
```

The shared layer would conceptually contain:

```dts
default_layer {
    bindings = <
        /* 30 common alpha bindings */
        MERII_THUMBS_DEFAULT
    >;
};
```

Do not implement this override mechanism for Cyboard and Toucan initially. Both have six thumbs and can use the same canonical thumb bindings.

### Bounded 34-Key Case

A `3x5+2` board cannot use the exact 36-position contract because a transform cannot create two missing physical keys. It would need:

- A 34-position transform.
- The same 30 alpha bindings.
- Four board-specific thumb bindings per layer.
- Updated left/right thumb positions in home-row hold triggers.

The Caps combo would remain at positions `10 19` because the 30 alpha positions would not move. Do not pad a 34-key board with phantom matrix coordinates solely to preserve a 36-binding keymap.

## Approaches Rejected

- One west workspace for both boards: their currently proven ZMK versions and hardware modules differ.
- Downgrading Cyboard to ZMK `v0.3`: this conflicts with its current Zephyr 4.1 hardware model.
- Porting Toucan to ZMK `main` now: this adds unnecessary Cirque, display, shield, and power-management work.
- DTS overlays that replace only thumb bindings: a DTS overlay replaces the complete `bindings` property and would duplicate all 36 bindings per layer.
- Wrapper-owned complete layer nodes: this duplicates layer structure and risks drift.
- Phantom or unreachable logical positions: these complicate Studio, transforms, combos, and hold-trigger positions.
- A broad layout-macro framework: it is not justified for two compatible `3x5+3` keyboards.

## Research Basis

The include/module approach follows standard ZMK and Zephyr mechanisms and is consistent with established community configurations:

- ZMK keymaps: `https://zmk.dev/docs/keymaps`
- Zephyr modules: `https://docs.zephyrproject.org/3.2.0/develop/modules.html`
- urob's ZMK config: `https://github.com/urob/zmk-config`
- urob shared keymap discussion: `https://github.com/urob/zmk-config/discussions/72`
- Miryoku ZMK: `https://github.com/manna-harbour/miryoku_zmk`
- ZMK node-free configuration: `https://zmk.dev/blog/2023/12/17/nodefree-config`
- Beekeeb Toucan firmware: `https://github.com/beekeeb/zmk-keyboard-toucan`

## Repository Guidance Follow-Up

Implementing this plan changes the repository's firmware input locations and layout architecture. After implementation and verification, review whether `AGENTS.md` should document:

- The new shared DTS root.
- The common 36-position contract.
- The thin Imprint wrapper responsibilities.
- The repository's role as a consumable keymap module.

Per the repository policy, propose any `AGENTS.md` changes for approval rather than applying them automatically.
