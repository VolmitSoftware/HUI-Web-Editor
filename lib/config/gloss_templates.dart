/// Starter documents for the Gloss kinds.
///
/// The "on the server" entries are byte-identical copies of what the plugin
/// ships — `test/gloss_templates_test.dart` holds them against the Gloss
/// resources the same way `preview_templates_test.dart` pins the thirteen
/// preview cards. Starters are teaching documents the jar does not ship.
library;

import '../model/model.dart';

/// `Gloss/src/main/resources/baselines/hologram.json`, byte for byte — what
/// `/gloss hologram create` starts a file from, and therefore what a blank
/// hologram document is here.
const String kGlossHologramBaselineJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "anchor": {
    "world": "world",
    "position": [0.0, 0.0, 0.0]
  },
  "lines": [
    "&dNew hologram"
  ]
}
''';

/// A richer starter showing the text pipeline: bracket hex, legacy codes,
/// a PAPI placeholder and an animation reference.
const String kGlossHologramShowcaseJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "anchor": {
    "world": "world",
    "position": [0.5, 64.0, 0.5]
  },
  "lines": [
    "[FFAA00]&lWelcome to the server",
    "&7Hello, %player_name%!",
    "|animation.rainbow|",
    "&8Powered by Gloss"
  ]
}
''';

GlossHologramDoc buildBlankGlossHologram() =>
    decodeGlossHologramDoc(kGlossHologramBaselineJson);

GlossHologramDoc buildShowcaseGlossHologram() =>
    decodeGlossHologramDoc(kGlossHologramShowcaseJson);

/// `Gloss/src/main/resources/defaults/animations/rainbow.json`, byte for
/// byte — the animation the plugin extracts into
/// `plugins/Gloss/animations/` on first run.
const String kGlossAnimationRainbowJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "mode": "ascend",
  "frameIntervalMs": 500,
  "frames": [
    "&cGloss",
    "&6Gloss",
    "&aGloss",
    "&bGloss"
  ]
}
''';

/// The smallest animation Gloss accepts: one frame (`AnimationDoc.copyFrames`
/// rejects an empty list), the default mode and interval.
const String kGlossAnimationBlankJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "mode": "ascend",
  "frameIntervalMs": 500,
  "frames": [
    "&fNew animation"
  ]
}
''';

GlossAnimationDoc buildRainbowGlossAnimation() =>
    decodeGlossAnimationDoc(kGlossAnimationRainbowJson);

GlossAnimationDoc buildBlankGlossAnimation() =>
    decodeGlossAnimationDoc(kGlossAnimationBlankJson);

/// `Gloss/src/main/resources/defaults/boards/default.json`, byte for byte —
/// the sidebar the plugin extracts into `plugins/Gloss/boards/` on first run
/// (deliberately `primary: false`, so nothing forces a sidebar on players).
const String kGlossScoreboardDefaultJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "title": "&d&lGloss",
  "lines": [
    "&fWelcome!",
    "&7Edit boards/default.json",
    "&7or create your own board."
  ],
  "primary": false,
  "permission": "default",
  "groups": []
}
''';

/// A richer sample: gated, grouped, primary, with an animated line and a
/// placeholder chip.
const String kGlossScoreboardShowcaseJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "title": "[FF55FF]&lMy Server",
  "lines": [
    "&7Welcome, &f%player_name%",
    "",
    "&fRank: &6VIP",
    "|animation.rainbow|",
    "&8volmitsoftware.com"
  ],
  "primary": true,
  "permission": "vip",
  "groups": ["vip", "mvp"]
}
''';

GlossScoreboardDoc buildDefaultGlossScoreboard() =>
    decodeGlossScoreboardDoc(kGlossScoreboardDefaultJson);

GlossScoreboardDoc buildShowcaseGlossScoreboard() =>
    decodeGlossScoreboardDoc(kGlossScoreboardShowcaseJson);

/// `Gloss/src/main/resources/defaults/motd/motd.json`, byte for byte — the
/// MOTD the plugin extracts to `plugins/Gloss/motd.json` on first run.
const String kGlossMotdDefaultJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "entries": [
    {
      "lines": [
        "&dA glossy server"
      ]
    }
  ]
}
''';

/// A richer sample: three entries the ping randomizes over, two-line entries,
/// bracket hex, and an animated line — everything `renderStatic` supports.
const String kGlossMotdShowcaseJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "entries": [
    {
      "lines": [
        "[FF55FF]&lMy Server &8- &7Season 4",
        "&7Now with &dGloss"
      ]
    },
    {
      "lines": [
        "&6&lDouble XP weekend!",
        "|animation.rainbow|"
      ]
    },
    {
      "lines": [
        "&bCome say hi."
      ]
    }
  ]
}
''';

GlossMotdDoc buildDefaultGlossMotd() => decodeGlossMotdDoc(kGlossMotdDefaultJson);

GlossMotdDoc buildShowcaseGlossMotd() =>
    decodeGlossMotdDoc(kGlossMotdShowcaseJson);

/// `Gloss/src/main/resources/defaults/emoji/heart.json`, byte for byte — one
/// of the 67 emoji the plugin extracts into `plugins/Gloss/emoji/` on first
/// run, and the one whose trigger (`<3`) teaches the trigger mechanic.
const String kGlossEmojiHeartJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "trigger": "<3",
  "emoji": "U+2764;",
  "enabled": true
}
''';

/// An editor-authored starter: a valid sparkles glyph, no trigger. Not a
/// shipped file — the blank has to open clean, and an empty emoji value is
/// exactly what the plugin rejects.
const String kGlossEmojiBlankJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "trigger": "",
  "emoji": "U+2728;",
  "enabled": true
}
''';

GlossEmojiDoc buildHeartGlossEmoji() =>
    decodeGlossEmojiDoc(kGlossEmojiHeartJson);

GlossEmojiDoc buildBlankGlossEmoji() =>
    decodeGlossEmojiDoc(kGlossEmojiBlankJson);

/// `Gloss/src/main/resources/defaults/bubbles/default.json`, byte for byte —
/// the style the plugin extracts into `plugins/Gloss/bubbles/` on first run,
/// and the fallback every unmatched player gets (its file name IS the
/// fallback id).
const String kGlossBubbleDefaultJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "prefix": "&7",
  "offset": [0.0, 1.0, 0.0],
  "wordWrapChars": 32,
  "lineStaggerTicks": 5,
  "maxAliveMs": 5000,
  "flyAway": true,
  "followPlayer": true,
  "hideOwn": true
}
''';

/// A richer sample: a gold-prefixed, tight-wrapped, anchored (does not
/// follow) style that auto-applies to VIPs in overworld-named worlds.
const String kGlossBubbleShowcaseJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "prefix": "&6",
  "offset": [0.0, 1.2, 0.0],
  "wordWrapChars": 24,
  "lineStaggerTicks": 8,
  "maxAliveMs": 7000,
  "flyAway": true,
  "followPlayer": false,
  "hideOwn": false,
  "select": {
    "worlds": ["world*"],
    "groups": ["vip"],
    "priority": 10
  }
}
''';

GlossBubbleStyleDoc buildDefaultGlossBubbleStyle() =>
    decodeGlossBubbleStyleDoc(kGlossBubbleDefaultJson);

GlossBubbleStyleDoc buildShowcaseGlossBubbleStyle() =>
    decodeGlossBubbleStyleDoc(kGlossBubbleShowcaseJson);

/// `Gloss/src/main/resources/defaults/tablist/tablist.json`, byte for byte —
/// the tab config the plugin extracts to `plugins/Gloss/tablist.json` on
/// first run.
const String kGlossTablistDefaultJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "useHeaderFooter": true,
  "header": "&d&lGloss",
  "footer": "&7VolmitSoftware.com",
  "groupListNames": true,
  "nameFormats": {
    "default": "$player",
    "_op": "&6$player"
  }
}
''';

/// A richer sample: hex header, an animated footer line, and per-group list
/// names using both tokens.
const String kGlossTablistShowcaseJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "useHeaderFooter": true,
  "header": "[FF55FF]&lMy Server\n&7Season 4",
  "footer": "|animation.rainbow|",
  "groupListNames": true,
  "nameFormats": {
    "default": "&7$player",
    "_op": "&c[OP] &f$player",
    "vip": "&6[$group] &f$player"
  }
}
''';

GlossTablistDoc buildDefaultGlossTablist() =>
    decodeGlossTablistDoc(kGlossTablistDefaultJson);

GlossTablistDoc buildShowcaseGlossTablist() =>
    decodeGlossTablistDoc(kGlossTablistShowcaseJson);
