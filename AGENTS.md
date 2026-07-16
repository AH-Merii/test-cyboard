# AGENTS.md

## Repo Shape
- This is a ZMK user config for a Cyboard Imprint keyboard, not a standalone app; firmware overrides live in `config/`.
- Derive the checkout with `git rev-parse --show-toplevel` and inspect its remote with `git remote get-url origin`; neither the local path nor repository name is stable.
- CI delegates from `.github/workflows/build.yml` to `zmkfirmware/zmk/.github/workflows/build-user-config.yml@main`; `build.yaml` is the matrix.
- `config/west.yml` tracks ZMK's moving `main` branch and the moving `zmk-keyboards` `zephyr-4.1` branch. The branch pairing is required because `zmk-keyboards/main` targets ZMK v0.3.0 and the obsolete Zephyr hardware model. There is no lockfile, so upstream changes can alter or break unchanged builds.
- `boards/shields/` contains no local hardware definitions. The `assimilator-bt` board and `imprint_*` shields come from `zmk-keyboards`.
- Because `zephyr/module.yml` exists, the delegated workflow copies `config/` to an isolated workspace and passes this checkout as `ZMK_EXTRA_MODULES`; mirror that behavior locally.

## Build And Verify
- CI currently builds board `assimilator-bt` with shields `imprint_left`, `imprint_right`, and `imprint_left settings_reset`.
- There is no repo-local lint or test harness; compiling the relevant firmware targets is the verification step.
- Do not initialize a west workspace in this repo root. `./build-local.sh` is the supported local build entry point and uses a Docker volume outside the checkout for west sources and build intermediates.
- `build-local.sh` tracks dependency revisions per target and automatically requests a pristine target build when they change; manual Docker volume removal is reserved for a damaged west source workspace.
- Read `BUILD.md` when building firmware or when changing, verifying, or troubleshooting the local build workflow. Do not load `BUILD.md` for unrelated keymap work.
- If Docker is unavailable, report that firmware compilation could not be performed rather than initializing west in the repository root.

## Keymap And Layout Notes
- Firmware overrides are `config/imprint.keymap`, `config/imprint.conf`, and the half-specific overlays. `config/info.json` is layout-editor metadata, not a firmware build input.
- `config/default keymaps/` contains reference keymaps, not active CI inputs unless copied into the active config names.
- The keymap chooses the upstream 48-position `&imprint_letters_only_no_bottom_row` transform and pads unused outer/bottom positions with `&none`. The overlays include local `imprint_36key.dtsi`, but `&imprint_36key` is dormant until selected in `chosen`.
- Switching to the 36-key transform also requires changing every layer's binding count and auditing position-based hold triggers and combos; changing only `chosen` is not sufficient.
- `config/imprint_right.overlay` adds `row-offset = <7>` to `&imprint_36key`; preserve left/right overlay differences when changing matrix transforms.
- Trackball behavior is at the bottom of `config/imprint.keymap`: the central listener scrolls; the peripheral listener moves the cursor, uses `SCROLL` (layer 7) for scroll mode, and temporarily activates `MOUSE` (layer 6).

## Maintaining AGENTS.md
- Changes to repository structure, build or verification workflows, firmware input locations, board or shield architecture, layout architecture, or important operational constraints may warrant an `AGENTS.md` update.
- Routine keymap changes that do not alter repository-level guidance do not warrant an update.
- At the end of a qualifying task, if `AGENTS.md` was not already updated as part of explicitly approved work, ask: These changes may warrant an AGENTS.md update. Would you like me to propose one?
- If the user says yes, propose concise changes for review. Do not apply the proposal until the user explicitly approves it.
