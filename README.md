# HoloUI Editor

Visual web editor for [HoloUI](https://github.com/VolmitSoftware/HoloUi) menu configurations. Build holographic menus on a calibrated canvas, edit every field the plugin actually parses, and export `menus/<id>.json` files (plus an `images.zip`) that drop straight into `plugins/holoui/`.

Version 3.0.0 — a from-scratch rewrite in [arcane_jaspr](https://github.com/ArcaneArts/arcane_jaspr) (Dart, compiled to a fully static site). Replaces the retired Next.js editor.

## Features

- **Visual canvas** in block space: zoom/pan, grid + snapping, drag components, selection, keyboard nudge. Renders text (legacy `&` codes and MiniMessage, in the Minecraft font), item sprites, pixel-art image icons and animated icons at the exact in-game metrics (0.21875 blocks per text line, `uiScale` semantics, hitbox overlays matching the plugin's `debugHitbox`).
- **Linked button hitboxes**: text and image click planes follow the visible render, while an optional custom width and height can replace automatic icon-derived sizing without creating an independent position that can drift away.
- **Full format coverage** as the plugin's Gson actually reads it — all three component types (button / decoration / toggle), all four authorable icon types (text / textImage / animatedTextImage / item), both actions (command / sound with all 10 sound categories), toggle conditions, `maxDistance`, `closeOnDeath`, `closeOnTeleport`, `customModelValue` (the real key — not the `customModelData` the old schema documented).
- **Code view** with two-way sync, plus split view.
- **Validation** engine encoding the plugin's real parsing rules (lowercase registry keys, required action sources, silent-zero pitfalls like `volume: 0`, the `&n`/`&k` legacy-code trap, hitbox overlap warnings).
- **Image library**: upload pixel art, preview exactly as the plugin rasterizes it, export `images.zip` laid out for `plugins/holoui/images/`.
- **Workspace**: multiple menus, autosave to browser storage, undo/redo, templates, searchable item/sound catalogs.

Everything runs client-side. No server, no accounts, no network calls beyond loading the static assets.

## Development

Requires Dart ≥ 3.10 and a checkout of `arcane_jaspr` at `.deps/arcane_jaspr` (a symlink to a local clone works):

```bash
git clone https://github.com/ArcaneArts/arcane_jaspr .deps/arcane_jaspr   # or: ln -s /path/to/arcane_jaspr .deps/arcane_jaspr
dart pub get
dart run jaspr_cli:jaspr serve      # dev server on :8080
dart test                           # core-logic test suite
dart run jaspr_cli:jaspr build      # static output in build/jaspr/
```

## Releasing

The hosted editor is deployed to [holoui.volmitsoftware.com](https://holoui.volmitsoftware.com/) on Firebase Hosting by `.github/workflows/firebase-hosting.yml` after every push to `master`. The workflow analyzes and tests the project before building, deploying, and verifying the custom-domain bundle. It requires the `FIREBASE_SERVICE_ACCOUNT_HOLOUI_EDITOR` repository secret.

The editor is deployed to https://holoui.volmitsoftware.com on every push to `master` (`.github/workflows/firebase-hosting.yml`). There are no releases: the plugin's `/holoui builder` command simply links players to the hosted editor.


## Architecture

```
lib/model/        HoloUI JSON data model + codec (parser-truth, round-trip lossless)
lib/logic/        validation rules, Minecraft text parser, viewport math, hitbox geometry
lib/services/     localStorage, image library, catalogs, file transfer, clipboard
lib/state/        EditorStore (undo/redo, autosave), multi-doc workspace
lib/components/   shell (top bar, shortcuts, palette), canvas, inspector, panels, dialogs
web/assets/       fonts (Geist, lucide, Minecraft), item/sound catalogs, backdrop, brand
tool/             asset extraction scripts
```

The format contract was derived from the plugin's Java parsing code (`art.arcane.holoui.config.*` via VolmLib's Gson setup), not from the shipped JSON schema, which has drifted. Where the two disagree, this editor follows the code.
