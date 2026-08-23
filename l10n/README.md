# Translating the Gloss editor

The JSON files in this directory are the canonical editor translations. Each
locale uses the same flat structure so a translator can edit values without
working in Dart:

- `messages` maps the exact English source text to its translation. Do not edit
  the English keys.
- `contexts` maps stable meaning-specific IDs to translations. The English
  meaning is in `en_US.json`; IDs distinguish words that need different
  translations in different UI contexts. Keep IDs stable: for example,
  `action.open` is an imperative while `state.open` is a state, and
  `field.pitch.sound` is audio pitch while `field.pitch.orientation` is an
  angle. Sound-category IDs use the official Minecraft client terminology;
  billboard/alignment and animation-blend IDs likewise preserve their specific
  UI meanings.
- `plurals` maps stable IDs to the plural forms required by that locale. Keep
  every form already present in the locale file.
- `previewMessages` maps Gloss plugin message IDs to translations used by the
  in-editor preview. The 55 IDs and their values mirror the sibling Gloss
  runtime language catalogs byte-for-byte when that repository is available.

Required plural forms are:

- `one`, `other`: `en_US`, `de_DE`, `fi_FI`, `nl_NL`, `tr_TR`, `vi_VI`
- `one`, `many`, `other`: `es_ES`, `fr_FR`, `it_IT`, `pt_PT`
- `one`, `two`, `other`: `he_IL`
- `one`, `few`, `other`: `lt_LT`
- `one`, `few`, `many`, `other`: `pl_PL`, `ru_RU`
- `other`: `ja-JP`, `ko_KR`, `zh_CN`, `zh_TW`

Preserve placeholders such as `{count}` and `{file}` exactly. Also preserve
commands, paths, filenames, permission nodes, JSON/YAML keys, MiniMessage tags,
Minecraft IDs, colour codes, product and platform names such as `Gloss`,
`Paper`, and `VolmLib`, and leading or trailing whitespace byte-for-byte.
Translate only the surrounding natural language.

The catalog validator also locks a small high-risk glossary for ambiguous
Minecraft and editor terms such as player, item, tick, hover, scoreboard,
tablist, pitch, and Open. These expectations prevent common false-friend
translations and keep the editor consistent with the Gloss runtime and the
Minecraft client. If a translator intentionally chooses different wording for
one of these entries, update the corresponding locale-and-key expectation in
`tool/localization_catalog.dart` with the catalog change. Do not bypass the
protocol, placeholder, residue, or semantic checks, and do not add prose to an
allowlist simply to make validation pass.

After adding or changing source text, run:

```sh
dart run tool/update_localizations.dart
```

The command adds missing keys while retaining existing translations, imports
the authoritative preview strings from a sibling Gloss checkout, and writes
deterministic deployment mirrors to `web/languages/` plus locale-specific PWA
manifests in `web/manifests/`. Translate any new English fallbacks in all
non-English files, then validate everything with:

```sh
dart run tool/update_localizations.dart --check
dart test test/localization_catalog_test.dart
```

Files under `web/languages/` and `web/manifests/` are generated deployment
assets and must not be edited by hand.
