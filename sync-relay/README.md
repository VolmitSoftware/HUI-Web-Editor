# Gloss editor sync relay

This service transfers bounded Gloss project snapshots between a Minecraft
server and the static web editor. It never connects to Minecraft: the plugin
creates and polls sessions through outbound HTTP. Browser autosave remains
local and publishing is always an explicit action.

The official relay base is `https://sync.gloss.volmitsoftware.com/v3`.
Any operator can run this same protocol at another HTTPS URL and set
`editorSyncEndpoint` accordingly. HTTP is intended only for localhost tests.

## Run

```sh
docker build -t gloss-sync-relay .
docker run --rm -p 127.0.0.1:8080:8080 \
  --env-file /secure/path/gloss-sync-relay.env \
  -v gloss-sync-data:/data/gloss-sync gloss-sync-relay
```

Place a TLS reverse proxy in front of the container. Keep the service on one
node with a persistent volume: the bundled file store serializes atomic session
updates but is not a horizontally distributed database. The default listener
is loopback outside Docker. If `GLOSS_RELAY_TRUST_PROXY=true`, firewall the
listener so only the trusted proxy can reach it; otherwise forged forwarding
headers can defeat per-address create limits.

Every public deployment must set `GLOSS_RELAY_CREATE_TOKENS` to a
comma-separated set of distinct, cryptographically random URL-safe operator
capabilities of 22–128 characters. The official relay requires one capability
per operator; each operator obtains theirs from the relay administrator and
sets it as the plugin's `editorSyncCreateToken`. The plugin sends it only in
the `Authorization: Bearer` header of `POST /sessions`. It is distinct from
the editor and server session capabilities and must not appear in an editor
URL. Store the list in a mode-`0600` environment file or secret manager, not in
a container command. The relay hashes the list at startup, persists only a
derived principal hash with each session, and never logs or persists the
plaintext credentials.

A private custom relay may set `GLOSS_RELAY_ALLOW_ANONYMOUS_CREATE=true`
instead. Anonymous creation is fail-closed unless that explicit switch is set.
Use it only behind equivalent admission controls or on a network-restricted
service. Per-address, per-principal, active-session, retained-session, and
storage capacity bounds remain active in either mode. Public deployments also
need a trusted edge for connection/request-rate DDoS controls; the application
limits do not replace one. The unauthenticated health response stays limited
to `{"status":"ok","protocol":3}` and does not disclose admission
configuration.

Environment variables:

- `PORT=8080`, `GLOSS_RELAY_BIND=127.0.0.1`, and
  `GLOSS_RELAY_DATA=/data/gloss-sync` select the listener and durable volume.
- `GLOSS_RELAY_API_PREFIX=/v3` selects the internal API mount.
- `GLOSS_RELAY_CREATE_TOKENS` accepts up to 4096 comma-separated, deduplicated
  URL-safe 22–128 character operator capabilities. It is mandatory for the
  official and any other public deployment. `GLOSS_RELAY_CREATE_TOKEN` is a
  mutually exclusive single-operator convenience.
- `GLOSS_RELAY_ALLOW_ANONYMOUS_CREATE=false` must be explicitly set to `true`
  for a custom relay without create tokens. Tokens and anonymous mode are
  mutually exclusive.
- `GLOSS_RELAY_ALLOWED_ORIGINS=https://gloss.volmitsoftware.com` is a
  comma-separated list of exact browser origins. Wildcard origins and CORS
  credentials are never emitted.
- `GLOSS_RELAY_MAX_SNAPSHOT_BYTES=8388608` sets the project limit. The
  official default is 8 MiB, matching the plugin; operators may raise it to the
  protocol ceiling of 32 MiB. Request and editor-session response limits derive
  as `snapshot + 256 KiB` and `2 * snapshot + 256 KiB`.
- `GLOSS_RELAY_MAX_STORED_BYTES=1073741824` limits worst-case reserved storage.
- `GLOSS_RELAY_MAX_ACTIVE_SESSIONS=10000`,
  `GLOSS_RELAY_CREATE_RATE=30`, and
  `GLOSS_RELAY_MAX_RATE_ADDRESSES=10000` bound live sessions, per-address
  creates per minute, and the rate-limit address table.
- `GLOSS_RELAY_MAX_RETAINED_SESSIONS_PER_PRINCIPAL=8`,
  `GLOSS_RELAY_MAX_ACTIVE_SESSIONS_PER_PRINCIPAL=8`,
  `GLOSS_RELAY_MAX_STORED_BYTES_PER_PRINCIPAL=136314880`, and
  `GLOSS_RELAY_CREATE_RATE_PER_PRINCIPAL=10` bound each operator's retained
  tombstones, live sessions, worst-case reserved bytes, and creates per minute.
- `GLOSS_RELAY_MIN_TTL_SECONDS=300` and
  `GLOSS_RELAY_MAX_TTL_SECONDS=86400` bound requested session lifetimes.
- `GLOSS_RELAY_TRUST_PROXY=false` controls whether the first strictly parsed
  `X-Forwarded-For` address becomes the rate-limit key.

Storage admission durably records room for two maximum-size snapshots per
retained session. Revoked and recently expired tombstones count against both
global and operator reserves until cleanup, so repeated create/revoke calls
cannot fill the volume outside the configured bounds. Each atomic rename or
delete includes a parent-directory durability sync before success is returned.
A session retains its creation-time snapshot ceiling across restarts; raising
the global limit affects new sessions only.

The relay logs operational failures but never logs bearer tokens or snapshot
bodies. Project snapshots are stored as plaintext JSON on the configured data
volume until their expiry tombstones are cleaned up, so protect that volume
and terminate TLS before exposing the service. The container starts with an
owner-only `077` umask; non-container launches should do the same. Capability
URLs should be treated as secrets. See
[`protocol.md`](protocol.md) for the wire contract.
The machine-readable project envelope is
[`schema/project-v3.schema.json`](schema/project-v3.schema.json), HTTP
envelopes are in [`schema/http-v3.schema.json`](schema/http-v3.schema.json),
and [`fixtures/`](fixtures) contains golden payloads for other clients.
