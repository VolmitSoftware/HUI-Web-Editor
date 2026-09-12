# Editor sync protocol v3

The API base includes `/v3`. JSON endpoints require
`Content-Type: application/json` where a body is present and every response
uses `protocol: 3`.

## Security model

Session creation requires a configured create capability unless anonymous
creation is explicitly enabled. A successful create returns independent
server and editor bearer capabilities. The editor capability can read the
session and publish one pending replacement; the server capability can poll,
acknowledge, revoke, and read the current snapshot.

Relay URLs are capabilities. Do not log them, put them in analytics, or share
them beyond the intended editor tab. Production editor origins and relay
CORS policy must be allowlisted explicitly.

## HTTP surface

- `POST /v3/sessions` creates a session from a current project snapshot.
- `GET /v3/sessions/{id}` reads the current editor view.
- `PUT /v3/sessions/{id}/publication` submits an explicit editor
  publication.
- `GET /v3/sessions/{id}/publication?after=N` long-polls from the server.
- `POST /v3/sessions/{id}/publication/{revision}/ack` applies, conflicts,
  or rejects a publication, carrying the per-document `conflicts` list.
- `GET /v3/sessions/{id}/history?kind=&documentId=&version=` asks the server
  for one stored version and long-polls up to 30 seconds for it. The query
  form keeps tree document ids (`shop/main`) out of the path.
- `POST /v3/sessions/{id}/history?kind=&documentId=&version=` is how the
  server answers that ask.
- `DELETE /v3/sessions/{id}` revokes a session.
- `GET /v3/health` reports relay health.

The editor never publishes on autosave. Only the visible **Publish to Server**
action creates a pending publication.

## Project

A project has the required top-level keys
`format`, `version`, `kind`, `subjectId`, `baseRevision`,
`documents`, `images`, `constraints`, and `warnings`, and the optional
server-owned keys `history`, `schemas`, and `defaults`.

- `format` is `gloss-sync-project`.
- `version` is `3`.
- `documents` is sorted by `kind` then `id` and may be empty for a
  workspace project.
- `images` is sorted by path and may be empty.
- `baseRevision` is
  `sha256:<lowercase hex SHA-256>` over canonical project JSON with only
  `baseRevision` omitted.

Document kinds are open slugs: the relay validates the grammar and never
interprets a kind. The table below is generated from
`EditorSyncDocumentKind.ORDERED_WIRE_NAMES` in the paired Gloss checkout and is
pinned by `test/protocol_kinds_pin_test.dart` in the editor repository, so a
kind a newer server adds shows up here rather than being quietly dropped.

| Wire kind | Storage | Layout | Versioned | Singleton id |
|---|---|---|---|---|
| `animation` | `animations` | FOLDER | yes | - |
| `behavior` | `behaviors` | FOLDER | yes | - |
| `bubble-style` | `bubbles` | FOLDER | yes | - |
| `channel` | `channels` | FOLDER | yes | - |
| `container-preview` | `previews` | FOLDER | no | - |
| `damage-indicators` | `damage-indicators` | FOLDER | yes | `default` |
| `dialog` | `dialogs` | FOLDER | yes | - |
| `emoji` | `emoji` | FOLDER | yes | - |
| `entity-overlays` | `entity-overlays` | FOLDER | yes | `default` |
| `glyph` | `glyphs` | FOLDER | yes | - |
| `hologram` | `holograms` | FOLDER | yes | - |
| `inventory` | `inventories` | FOLDER | yes | - |
| `leaderboard` | `leaderboards` | FOLDER | yes | - |
| `marker` | `markers` | FOLDER | yes | - |
| `menu` | `menus` | TREE | no | - |
| `motd` | `motd.json` | SINGLE | yes | `motd` |
| `motion` | `motion` | FOLDER | yes | - |
| `nameplate` | `nameplates` | FOLDER | yes | - |
| `nametag` | `nametags` | FOLDER | yes | - |
| `panel` | `panels` | TREE | yes | - |
| `real-drops` | `real-drops` | REAL_DROPS | yes | `default` |
| `rig` | `rigs` | FOLDER | yes | - |
| `rig-instance` | `rig-instances` | FOLDER | yes | - |
| `scoreboard` | `boards` | FOLDER | yes | - |
| `strings` | `strings` | FOLDER | yes | - |
| `surface` | `surfaces` | FOLDER | yes | - |
| `tablist` | `tablist.json` | SINGLE | yes | `tablist` |
| `waypoint` | `waypoints` | FOLDER | yes | - |
| `zone` | `zones` | FOLDER | yes | - |

Each document entry has `kind`, `id`, JSON source text and an optional
`baseRevision`. Unversioned kinds omit `revision`; versioned kinds require an
integer `revision` equal to the revision inside their JSON.

`baseRevision` on a document entry is `sha256:<hex>` over the canonical JSON of
that document when the server served it. The editor returns it unchanged. The
server compares it per document, so a publication whose other documents moved
under it still applies the ones that did not, and reports the rest as conflicts
instead of failing as a whole.

A kind this build of the editor does not know still round-trips: it is echoed
back byte for byte, and the server refuses any change to it by name rather than
dropping it.

Menu and panel ids are canonical tree ids; every other kind has flat ids.
The singleton ids are `motd`, `tablist`, and `default` for damage-indicators,
entity-overlays, and real-drops.

A panel entry contains only the canonical runtime panel definition. Browser
flow-map layout and unlinked flow maps are editor-only and never enter a
project.

## Constraints

Constraints have exact fields `subjectId`, sorted unique `documentKinds`,
sorted unique `createDocumentKinds`, `allowDeletes`, and optional
`newMenuPrefix` and `newImagePrefix`.

- Workspace: subject `workspace`; both kind lists contain all eleven kinds;
  deletes are allowed; prefixes are absent.
- Menu: only `menu`; no document creates or deletes; image prefix required.
- Panel: `menu` and `panel`; menu creates allowed; menu and image prefixes
  required; deletes disabled.
- Other document subjects: only their subject kind; no creates, deletes, or
  prefixes.

The base snapshot defines the resources captured by an individual session.
Workspace publications are authoritative full mirrors: missing documents and
images delete, new identities create, and matching identities update.
Individual scopes may only make changes permitted by their immutable
constraints.

## Images and budgets

Projects carry every workspace image asset, including unreferenced assets.
The transport permits 512 assets, 512 documents, 512 KiB per asset, 4096
pixels per dimension, 16,777,216 decoded pixels per asset, and 67,108,864
decoded pixels in aggregate, within the configured project byte limit.

Only image paths referenced by menu `textImage` and `animatedTextImage`
content are subject to the text-display 16×16 limit and aggregate render
pixel/row budgets. Individual menu and panel projects include only their
captured or referenced assets.

## Warnings, history, schemas and defaults

`warnings` carries diagnostics as `code|kind|id|pointer|message` strings. The
editor's Problems panel parses that shape; anything without a pipe is a plain
sentence.

`history` lists the stored versions of the documents the project carries, at
most twenty per document, as `{kind, id, version, source, bytes}`. `version` is
the epoch-millisecond stamp the history request names. `source` says what took
the copy: `watchdog`, `editor:<session>`, `pack:<id>`, `import:<source>`,
`restore` or `command`.

`schemas` maps a wire kind to its JSON Schema and `defaults` maps a wire kind to
its shipped default documents, so an editor with no dedicated stage for a kind
can still offer an inspector and a template for it.

All four sections are server-owned. The server rebuilds them on every snapshot
and ignores whatever the editor sends back, which is why the concurrency checks
compare documents and images only.

## Concurrency

A publication names the session `baseRevision`. The relay permits one
pending publication. The server acknowledges it as `applied`, `conflict`,
or `rejected`. Applied and conflict acknowledgements promote the supplied
server snapshot and revision; rejected acknowledgements do not.

Every acknowledgement carries a `conflicts` array of `{kind, id}`. An `applied`
acknowledgement with a non-empty list means the publication landed except for
those documents, which kept the server's copy. `conflict` is reserved for the
case where every change the editor made conflicted.

If a tab has pending local content when the server revision changes, the
editor preserves that local work and opens the conflict flow. The user can
export a complete workspace backup before explicitly refreshing from the
server.

The machine-readable contracts are
[`schema/project-v3.schema.json`](schema/project-v3.schema.json) and
[`schema/http-v3.schema.json`](schema/http-v3.schema.json). Golden envelopes
live under `fixtures/`.
