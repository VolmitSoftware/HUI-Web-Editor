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
  or rejects a publication.
- `DELETE /v3/sessions/{id}` revokes a session.
- `GET /v3/health` reports relay health.

The editor never publishes on autosave. Only the visible **Publish to Server**
action creates a pending publication.

## Project

A project has the exact top-level keys
`format`, `version`, `kind`, `subjectId`, `baseRevision`,
`documents`, `images`, `constraints`, and `warnings`.

- `format` is `gloss-sync-project`.
- `version` is `3`.
- `documents` is sorted by `kind` then `id` and may be empty for a
  workspace project.
- `images` is sorted by path and may be empty.
- `baseRevision` is
  `sha256:<lowercase hex SHA-256>` over canonical project JSON with only
  `baseRevision` omitted.

The current document kinds are `animation`, `bubble-style`,
`container-preview`, `emoji`, `hologram`, `menu`, `motd`, `panel`,
`real-drops`, `scoreboard`, and `tablist`.

Each document entry has `kind`, `id`, and JSON source text. Menu and
container-preview entries omit `revision`. The other nine kinds require an
integer `revision` equal to the revision inside their JSON.

Menu and panel ids are canonical tree ids. Animation, bubble-style,
container-preview, emoji, hologram, and scoreboard ids are flat. Singleton ids
are `motd`, `tablist`, and `default` for real-drops.

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

## Concurrency

A publication names the session `baseRevision`. The relay permits one
pending publication. The server acknowledges it as `applied`, `conflict`,
or `rejected`. Applied and conflict acknowledgements promote the supplied
server snapshot and revision; rejected acknowledgements do not.

If a tab has pending local content when the server revision changes, the
editor preserves that local work and opens the conflict flow. The user can
export a complete workspace backup before explicitly refreshing from the
server.

The machine-readable contracts are
[`schema/project-v3.schema.json`](schema/project-v3.schema.json) and
[`schema/http-v3.schema.json`](schema/http-v3.schema.json). Golden envelopes
live under `fixtures/`.
