# Editor sync protocol v1

The API base includes `/v1`. JSON endpoints require `Content-Type:
application/json`. Editor and server bearer tokens are separate 256-bit
capabilities; only SHA-256 token hashes are stored.

Session creation has a separate deployment admission credential. The official
relay configures `HOLOUI_RELAY_CREATE_TOKENS` with one distinct URL-safe
22–128-character capability per operator. The plugin sends its assigned value
as `Authorization: Bearer <token>` on `POST /sessions`; missing, malformed, or
incorrect credentials receive the same `401 unauthorized` response before
request-body parsing or create-rate admission. The credential is never
included in the editor URL or used on later session requests. A custom relay
may explicitly opt into anonymous creation with
`HOLOUI_RELAY_ALLOW_ANONYMOUS_CREATE=true`; missing tokens otherwise fail
startup closed.

The relay data volume contains plaintext project snapshots. HTTPS protects the
wire; deployment-level volume encryption and access control protect data at
rest. An expired session remains as a tombstone for at most one configured
maximum-TTL window; revocation keeps the session through its normal expiry and
that same cleanup window so clients receive an unambiguous gone response.

1. The plugin sends `POST /sessions` with
   `{"protocol":1,"expiresInSeconds":3600,"snapshot":PROJECT}`.
2. The response contains `sessionId`, `editorToken`, `serverToken`, `expiresAt`
   and `baseRevision`. The plugin places only the editor capability in the URL
   fragment.
3. The editor reads `GET /sessions/{id}` with its bearer token. Explicit
   publish sends `PUT /sessions/{id}/publication` with the old optimistic
   `baseRevision` and the edited snapshot. The edited snapshot carries its own
   new content revision and normally differs from the optimistic base.
4. The plugin polls `GET /sessions/{id}/publication?after=N` with the server
   token. It validates and transactionally applies the project, then posts
   `applied`, `conflict`, or `rejected` to
   `/sessions/{id}/publication/{revision}/ack`.
5. Applied and conflict acknowledgements include the actual current server
   snapshot and `serverRevision`; these become the relay's new current base.
   Rejected publications do not rebase. Only one pending publication exists,
   and publication revisions increase monotonically.
6. `DELETE /sessions/{id}` with the server bearer token revokes the capability.

`PROJECT` is `holoui-sync-project` version 1. It contains `kind`, `subjectId`,
`menus`, optional `board`, `images`, immutable server-owned `constraints`,
`warnings`, and root `baseRevision`. The revision is SHA-256 over UTF-8 canonical
JSON after removing only the root `baseRevision`: object keys are sorted,
arrays keep order, strings use JSON escaping, and finite IEEE-754 numbers use
one value spelling across Java and Dart. Negative zero becomes `0`; trailing
`.0` is removed; magnitudes from `1e-6` through values below `1e21` use plain
decimal, while other values use a lowercase exponent without leading zeros.
Integer contract fields never exceed JavaScript's safe integer maximum.

`constraints` is copied unchanged for the lifetime of a session. Its captured
ids and prefixes bound what the editor may touch. Because `allowDeletes` is
false in protocol v1, every publication retains all menu and image entries in
the current server base, including prior in-session additions; removing a
navigation edge or image reference retains the now-orphaned file.

The relay treats project contents as bounded opaque JSON. The plugin remains
the authority for menu, board, image, scope, revision, permission and path
validation. Protocol v1 allows at most 256 menu documents, 512 image assets,
and 512 KiB of decoded data per image; the configured snapshot limit bounds
the complete envelope.

## HTTP contract

The API base itself includes `/v1`; the official base is
`https://sync.holoui.volmitsoftware.com/v1`. Every JSON response includes
`protocol: 1`; failures use
`{"protocol":1,"error":{"code":"snake_case","message":"safe text"}}`.
Bodies and capabilities are never logged, all responses are `no-store`, and a
revoked or expired session returns `410` only after the supplied capability is
authenticated. Unknown sessions return `404`; an invalid capability returns
`401`.

| Request | Capability | Success |
| --- | --- | --- |
| `POST /sessions` | configured create admission token | `201` with `sessionId`, editor/server tokens, expiry, and base revision |
| `GET /sessions/{id}` | editor | `200` current snapshot and last publication/ack state |
| `PUT /sessions/{id}/publication` | editor | `202` new pending publication summary |
| `GET /sessions/{id}/publication?after=N` | server | `200` pending project or `204` |
| `POST /sessions/{id}/publication/{N}/ack` | server | `200` acknowledged publication summary |
| `DELETE /sessions/{id}` | server | `204` and a retained revoked tombstone |
| `GET /health` | none | `200` |

`GET /health` remains unauthenticated and returns only
`{"status":"ok","protocol":1}`; it does not reveal whether create admission
is enabled. Per-address and stable hashed-principal create throttling, bounded
rate-limit state, active and retained session limits, and durably recorded
worst-case storage reservations are enforced in addition to admission
authorization. The official edge must independently enforce connection and
request-rate DDoS controls.

`PUT` carries the old optimistic session `baseRevision`; its edited snapshot
carries the new content hash. A second `PUT` while one publication is pending,
or a `PUT` against a stale base, returns `409`. `applied` and `conflict`
acknowledgements require the server's actual current snapshot plus its matching
revision. An `applied` response promotes that snapshot; a `conflict` also
promotes it so the editor can explicitly refresh. `rejected` omits a snapshot
and retains the old base. Terminal publications do not block a later `PUT`, and
the next publication revision always increases. Exact acknowledgement retries
are idempotent; attempts to rewrite the result return `409`.
Acknowledgement response envelopes always contain `serverRevision`: it is the
promoted revision for `applied` and `conflict`, and JSON `null` for `rejected`.

The official relay admits 8 MiB projects by default and can be configured up
to the 32 MiB protocol ceiling. The maximum request is the configured project
size plus 256 KiB. An editor session response may contain both current and
pending snapshots, so its maximum is twice the configured project size plus
256 KiB (16.25 MiB by default, 64.25 MiB at the protocol ceiling).
Each retained session durably preserves the snapshot ceiling in effect when it
was created, so later increases apply only to new sessions and cannot invalidate
existing global or per-operator storage reservations.

The authoritative JSON Schemas and golden exchanges are under `schema/` and
`fixtures/`. The relay intentionally validates only the bounded JSON transport
and root revision syntax; the plugin validates the complete project schema,
canonical hash, immutable constraints, board/menu identities, paths, images,
permissions, and transactional publication.
