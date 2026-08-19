# Gloss Editor

Visual web editor for [Gloss](https://github.com/VolmitSoftware/Gloss) menu and display configurations. Build holographic menus on a calibrated canvas, edit every field the plugin actually parses, and export documents and images that drop straight into `plugins/Gloss/`.

Version 4.0.0 — a from-scratch rewrite in [arcane_jaspr](https://github.com/ArcaneArts/arcane_jaspr) (Dart, compiled to a fully static site). Replaces the retired Next.js editor.

## Features

- **Visual canvas** in block space: zoom/pan, grid + snapping, drag components, selection, keyboard nudge. Uses the runtime's documented text-line scale, `uiScale` semantics and hitbox geometry while clearly separating approximations that depend on the Minecraft client.
- **Linked button hitboxes**: text and image click planes follow the visible render, while an optional custom width and height can replace automatic icon-derived sizing without creating an independent position that can drift away.
- **Runtime 3D preview**: simulates the open pose, `followPlayer` position and yaw, fixed / vertical / horizontal / center icon billboards, click planes, hover push and nearest-click behavior. Client text wrapping, culling, brightness, entity models, effects, obstruction and competition between personal menus and boards still require in-game validation. PlaceholderAPI tokens remain literal because the browser has no server context; the preview reports their `refreshTicks` cadence instead.
- **Full format coverage** as the plugin's Gson actually reads it — all three component types (button / decoration / toggle), all seven authorable icon types (text / textImage / animatedTextImage / item / block / customItem / entity), all six actions (command / sound / message / teleport / connect / navigate), toggle conditions, `maxDistance`, `closeOnDeath`, `closeOnTeleport`, `customModelValue` (the real key — the `customModelData` older files carry is migrated on import).
- **Code view** with two-way sync, plus split view. Validated menu handoffs retain their exact source formatting and extension keys through storage and export until the first visual edit or explicit Format action.
- **Validation** engine aligned with the plugin's authoring contract (lowercase registry keys, action source spellings, silent-zero pitfalls like `volume: 0`, legacy and MiniMessage formatting, hitbox overlap warnings).
- **Image library**: upload validated PNG pixel art, preview with the plugin's rasterization rules, export `images.zip` laid out for `plugins/Gloss/images/`. Server sync preserves captured PNG, JPEG, GIF, WebP and BMP bytes losslessly.
- **Workspace**: folders, multiple menus and menu flow maps, atomic IndexedDB autosave with previous-transaction recovery and cross-tab conflict protection, undo/redo, templates, and searchable catalogs. Renaming a runtime id updates navigation, linked world-panel roots and sync scope as one checked save; dropped JSON opens as a uniquely named document instead of replacing the active one. Existing `holoui.workspace.v1` / `v2` localStorage data migrates once without deleting the rollback copy.
- **Optional server sync**: capability links opened from `/gloss menu edit` import an exact menu or persistent panel graph through the configured relay. Linked panels expose typed root-menu, transform, follow, audience, permission and range controls, with strict JSON under Advanced. Panel publication retains the bound no-delete baseline and adds only menus reachable from the panel root, leaving unrelated folder documents local. A labelled **Publish to Server** action appears in the connection bar during a live capability session; it durably saves a panel project and hot-reloads the running panel, while revision conflicts never overwrite local work. Links use the configured HTTPS relay (the plugin defaults to `https://sync.gloss.volmitsoftware.com/v2`) or a localhost HTTP development relay; an unreachable provider is reported without implying that a deployment is available.

The editor itself remains a static client with no accounts. Normal authoring and autosave are local-only; opening a server-issued capability link enables bounded HTTPS requests to that link's relay until the tab disconnects. Capability tokens stay in the URL fragment and tab `sessionStorage`, never in workspace documents or exported bundles. If tab storage is blocked, the capability stays in the fragment and the sync bar tells you to copy the link before reloading.

Sync v2 does not delete captured server resources. A panel can add menus only under the displayed `newMenuPrefix`; menus and panels can add images only under `newImagePrefix`. The editor validates exact runtime ids, the whole bound graph, typed panel JSON, image bytes, immutable constraints and content revisions before publishing. Synced raster assets are limited to 64×64 pixels each and 262,144 stored pixels per project; every repeated text-image component and animated frame is counted again against a 262,144-pixel / 4,096-row runtime-render budget. The protocol safety ceiling is 32 MiB per project; a relay deployment may enforce a lower configured limit and return `413`.

Workspace bundles and server projects span IndexedDB documents and localStorage images. Import and refresh use checked compensation when either write fails, but browsers provide no atomic transaction across those two storage systems; force-closing the browser between their writes can leave a partial import.

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

The hosted editor is deployed to [gloss.volmitsoftware.com](https://gloss.volmitsoftware.com/) through the existing Firebase `holoui-editor` project and Hosting site by `.github/workflows/firebase-hosting.yml` after every push to `master`. The workflow checks the paired Gloss runtime contract, analyzes and tests the project, then builds, deploys, and verifies the custom-domain bundle. It requires the `FIREBASE_SERVICE_ACCOUNT_HOLOUI_EDITOR` repository secret. There are no editor releases: `/gloss menu builder` links players to the hosted editor.


## Architecture

```
lib/model/        Gloss menu JSON data model + codec (runtime semantics, unknown-key preserving)
lib/doctype/      per-kind DocumentTypeAdapter registry (codec, views, capabilities, templates, inspector)
lib/logic/        validation rules, Minecraft text parser, viewport math, hitbox geometry
lib/services/     browser storage, image library, catalogs, file transfer, clipboard
lib/state/        EditorStore, IndexedDB persistence, multi-doc workspace and menu flow maps
lib/components/   shell (top bar, shortcuts, palette), canvas, inspector, panels, dialogs
web/assets/       fonts (Geist, lucide, Minecraft), item/sound catalogs, backdrop, brand
tool/             asset extraction scripts
```

## Editor Tandem

This editor is developed in tandem with the merged **Gloss** plugin (`VolmitSoftware/Gloss`, checked out beside this repo at `../Gloss`), and **Gloss is the truth repo**: every format contract is derived from its Java parsing code (`art.arcane.gloss.*` via VolmLib's Gson setup), never from schemas or documentation — where prose and code disagree, this editor follows the code. The concrete anchors of that contract — shipped defaults, baselines, preview cards, golden snapshots, generated catalogs, and the cross-repo vector tables — are inventoried in [`FIXTURES.md`](FIXTURES.md); the test suite compares the editor's copies against the live Gloss checkout, so a change to any shared contract must land editor-side and plugin-side in the same workstream, with both suites green against the paired checkouts. Editor copies are never edited in place: the Gloss resource changes first, then the copy (and its embedded Dart constant) is refreshed or regenerated here.
