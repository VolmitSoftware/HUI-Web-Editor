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
  ],
  "seeThrough": true
}
''';

/// A richer starter showing the text pipeline: bracket hex, legacy codes,
/// native player/server values, an optional PAPI expansion and an animation
/// reference.
const String kGlossHologramShowcaseJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "anchor": {
    "world": "world",
    "position": [0.5, 64.0, 0.5]
  },
  "lines": [
    "{{ hex(mix(#FF55FF, #55FFFF, (sin(time.seconds * 2) + 1) / 2)) }}&lWelcome",
    "&7Hello, &f{{ player.name }}&7!",
    "&7Health &a{{ bar(player.health, 20, 10, '■', '□') }}",
    "&7Rank {{ papi('vault_prefix', '&7Member') }}",
    "|animation.rainbow|&lLive colour prefix",
    "&7TPS &a{{ fixed(server.tps, 1) }}"
  ],
  "seeThrough": true
}
''';

GlossHologramDoc buildBlankGlossHologram() =>
    decodeGlossHologramDoc(kGlossHologramBaselineJson);

GlossHologramDoc buildShowcaseGlossHologram() =>
    decodeGlossHologramDoc(kGlossHologramShowcaseJson);

const String kGlossRealDropsDefaultJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "limits": {
    "updateIntervalTicks": 2,
    "settledPollIntervalTicks": 20,
    "maxVisualsPerStack": 3,
    "maxVisualsPerChunk": 128,
    "viewRange": 32.0,
    "spread": 0.18
  },
  "scale": {
    "defaultScale": 0.4,
    "flatItems": 0.65,
    "thinBlocks": 0.45
  },
  "motion": {
    "tumble": true,
    "speedMultiplier": 1.35,
    "degreesPerSecondX": 160.0,
    "degreesPerSecondY": 120.0,
    "degreesPerSecondZ": 100.0,
    "variance": 0.2,
    "changeOnBounce": true
  },
  "landing": {
    "mode": "NATURAL",
    "tiltDegrees": 10.0,
    "randomYaw": true,
    "transitionTicks": 4
  },
  "labels": {
    "enabled": true,
    "yOffset": 0.55,
    "scale": 0.85,
    "viewRange": 32.0,
    "billboard": "CENTER",
    "seeThrough": true,
    "shadow": true,
    "background": true,
    "backgroundRed": 0,
    "backgroundGreen": 0,
    "backgroundBlue": 0,
    "backgroundAlpha": 80
  },
  "filters": {
    "disabledWorlds": [],
    "materialBlacklist": [
      "BEDROCK",
      "BARRIER"
    ],
    "onlyPlayerDrops": false
  },
  "physics": {
    "enabled": false,
    "gravityMultiplier": 1.0,
    "bounce": 0.0,
    "waterBuoyancy": 0.0,
    "waterDrag": 0.0
  },
  "script": {
    "enabled": false,
    "vars": {},
    "offset": {
      "x": "0",
      "y": "0",
      "z": "0"
    },
    "rotation": {
      "x": "0",
      "y": "0",
      "z": "0"
    },
    "scale": {
      "x": "1",
      "y": "1",
      "z": "1"
    },
    "glow": "",
    "visible": "true"
  }
}
''';

GlossRealDropSettingsDoc buildDefaultGlossRealDrops() =>
    decodeGlossRealDropSettingsDoc(kGlossRealDropsDefaultJson);

/// Three authored looks for the same feature, so the templates tab teaches
/// what the fields do rather than only what the defaults are. None of these
/// ship with the plugin.
///
/// Slow, upright and legible: loot you are meant to read from across the room.
const String kGlossRealDropsRedRoomJson = r"""
{
  "schemaVersion": 1,
  "revision": 1,
  "limits": {
    "updateIntervalTicks": 1,
    "settledPollIntervalTicks": 20,
    "maxVisualsPerStack": 4,
    "maxVisualsPerChunk": 128,
    "viewRange": 48.0,
    "spread": 0.3
  },
  "scale": {
    "defaultScale": 0.55,
    "flatItems": 0.85,
    "thinBlocks": 0.6
  },
  "motion": {
    "tumble": true,
    "speedMultiplier": 0.5,
    "degreesPerSecondX": 40.0,
    "degreesPerSecondY": 70.0,
    "degreesPerSecondZ": 30.0,
    "variance": 0.1,
    "changeOnBounce": false
  },
  "landing": {
    "mode": "UPRIGHT",
    "tiltDegrees": 4.0,
    "randomYaw": true,
    "transitionTicks": 12
  },
  "labels": {
    "enabled": true,
    "yOffset": 0.85,
    "scale": 1.35,
    "viewRange": 48.0,
    "billboard": "CENTER",
    "seeThrough": true,
    "shadow": true,
    "background": true,
    "backgroundRed": 60,
    "backgroundGreen": 6,
    "backgroundBlue": 18,
    "backgroundAlpha": 170
  },
  "filters": {
    "disabledWorlds": [],
    "materialBlacklist": [
      "BEDROCK",
      "BARRIER"
    ],
    "onlyPlayerDrops": false
  }
}
""";

/// Fast, wide and messy: a mined stack thrown across the floor.
const String kGlossRealDropsSawmillJson = r"""
{
  "schemaVersion": 1,
  "revision": 1,
  "limits": {
    "updateIntervalTicks": 1,
    "settledPollIntervalTicks": 20,
    "maxVisualsPerStack": 5,
    "maxVisualsPerChunk": 192,
    "viewRange": 32.0,
    "spread": 0.75
  },
  "scale": {
    "defaultScale": 0.35,
    "flatItems": 0.6,
    "thinBlocks": 0.4
  },
  "motion": {
    "tumble": true,
    "speedMultiplier": 2.6,
    "degreesPerSecondX": 340.0,
    "degreesPerSecondY": 260.0,
    "degreesPerSecondZ": 300.0,
    "variance": 0.6,
    "changeOnBounce": true
  },
  "landing": {
    "mode": "NATURAL",
    "tiltDegrees": 28.0,
    "randomYaw": true,
    "transitionTicks": 3
  },
  "labels": {
    "enabled": true,
    "yOffset": 0.4,
    "scale": 0.7,
    "viewRange": 24.0,
    "billboard": "CENTER",
    "seeThrough": false,
    "shadow": true,
    "background": true,
    "backgroundRed": 0,
    "backgroundGreen": 0,
    "backgroundBlue": 0,
    "backgroundAlpha": 60
  },
  "filters": {
    "disabledWorlds": [],
    "materialBlacklist": [
      "BEDROCK",
      "BARRIER"
    ],
    "onlyPlayerDrops": true
  }
}
""";

/// Small, silent ground clutter: no labels, nothing spinning, cheap to run.
const String kGlossRealDropsQuietJson = r"""
{
  "schemaVersion": 1,
  "revision": 1,
  "limits": {
    "updateIntervalTicks": 4,
    "settledPollIntervalTicks": 60,
    "maxVisualsPerStack": 2,
    "maxVisualsPerChunk": 64,
    "viewRange": 16.0,
    "spread": 0.12
  },
  "scale": {
    "defaultScale": 0.25,
    "flatItems": 0.4,
    "thinBlocks": 0.28
  },
  "motion": {
    "tumble": false,
    "speedMultiplier": 1.0,
    "degreesPerSecondX": 0.0,
    "degreesPerSecondY": 0.0,
    "degreesPerSecondZ": 0.0,
    "variance": 0.0,
    "changeOnBounce": false
  },
  "landing": {
    "mode": "FLAT",
    "tiltDegrees": 0.0,
    "randomYaw": true,
    "transitionTicks": 6
  },
  "labels": {
    "enabled": false,
    "yOffset": 0.55,
    "scale": 0.85,
    "viewRange": 16.0,
    "billboard": "CENTER",
    "seeThrough": false,
    "shadow": true,
    "background": true,
    "backgroundRed": 0,
    "backgroundGreen": 0,
    "backgroundBlue": 0,
    "backgroundAlpha": 80
  },
  "filters": {
    "disabledWorlds": [],
    "materialBlacklist": [
      "BEDROCK",
      "BARRIER"
    ],
    "onlyPlayerDrops": false
  }
}
""";

GlossRealDropSettingsDoc buildRedRoomGlossRealDrops() =>
    decodeGlossRealDropSettingsDoc(kGlossRealDropsRedRoomJson);

GlossRealDropSettingsDoc buildSawmillGlossRealDrops() =>
    decodeGlossRealDropSettingsDoc(kGlossRealDropsSawmillJson);

GlossRealDropSettingsDoc buildQuietGlossRealDrops() =>
    decodeGlossRealDropSettingsDoc(kGlossRealDropsQuietJson);

/// `Gloss/src/main/resources/defaults/animations/rainbow.json`, byte for
/// byte — the animation the plugin extracts into
/// `plugins/Gloss/animations/` on first run.
const String kGlossAnimationRainbowJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "mode": "ascend",
  "frameIntervalMs": 50,
  "frames": [
    "[FF0000]",
    "[FF1A00]",
    "[FF3300]",
    "[FF4D00]",
    "[FF6600]",
    "[FF8000]",
    "[FF9900]",
    "[FFB300]",
    "[FFCC00]",
    "[FFE600]",
    "[FFFF00]",
    "[E5FF00]",
    "[CCFF00]",
    "[B2FF00]",
    "[99FF00]",
    "[7FFF00]",
    "[66FF00]",
    "[4CFF00]",
    "[33FF00]",
    "[19FF00]",
    "[00FF00]",
    "[00FF1A]",
    "[00FF33]",
    "[00FF4D]",
    "[00FF66]",
    "[00FF80]",
    "[00FF99]",
    "[00FFB3]",
    "[00FFCC]",
    "[00FFE6]",
    "[00FFFF]",
    "[00E5FF]",
    "[00CCFF]",
    "[00B2FF]",
    "[0099FF]",
    "[007FFF]",
    "[0066FF]",
    "[004CFF]",
    "[0033FF]",
    "[0019FF]",
    "[0000FF]",
    "[1A00FF]",
    "[3300FF]",
    "[4D00FF]",
    "[6600FF]",
    "[8000FF]",
    "[9900FF]",
    "[B300FF]",
    "[CC00FF]",
    "[E600FF]",
    "[FF00FF]",
    "[FF00E5]",
    "[FF00CC]",
    "[FF00B2]",
    "[FF0099]",
    "[FF007F]",
    "[FF0066]",
    "[FF004C]",
    "[FF0033]",
    "[FF0019]"
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
  "title": "[FF55FF]&lMY SERVER",
  "lines": [
    "&7Player &f{{ player.name }}",
    "&7Rank {{ papi('vault_prefix', '&6VIP') }}",
    "",
    "&7Ping {{ player.ping < 100 ? '&a' : '&e' }}{{ player.ping }}ms",
    "&7Health &a{{ bar(player.health, 20, 8, '■', '□') }}",
    "&7Online &a{{ server.online }}&8/&a{{ server.maxPlayers }}",
    "&7TPS &a{{ fixed(server.tps, 1) }}",
    "&7Tick &f{{ fixed(metric('react.tick-ms', 1000 / server.tps), 1) }}ms",
    "&7Balance &6${{ fixed(papiNumber('vault_eco_balance', 0), 2) }}",
    "",
    "&d{{ select(['·', '•', '●', '•'], floor(time.seconds * 8)) }} &f&lLIVE EVENT",
    "&d:heart: &fWelcome!",
    "&bplay.example.net"
  ],
  "primary": true,
  "hideNumbers": true,
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

/// A richer sample: four entries the ping randomizes over, two-line entries,
/// bracket hex, and an animated line — everything `renderStatic` supports.
const String kGlossMotdShowcaseJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "entries": [
    {
      "lines": [
        "{{ select(['&d', '&b', '&6'], floor(time.seconds / 2)) }}&lMy Server",
        "&7Online &a{{ server.online }}&8/&a{{ server.maxPlayers }}"
      ]
    },
    {
      "lines": [
        "|animation.rainbow|&lDouble XP weekend!",
        "&7The colour changes every ping"
      ]
    },
    {
      "lines": [
        "{{ hex(mix(#FF55FF, #55FFFF, (sin(time.seconds) + 1) / 2)) }}&lLive RGB pulse"
      ]
    },
    {
      "lines": [
        "&bNew worlds. New menus.",
        "&7play.example.net"
      ]
    }
  ]
}
''';

GlossMotdDoc buildDefaultGlossMotd() =>
    decodeGlossMotdDoc(kGlossMotdDefaultJson);

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
  "schemaVersion": 2,
  "revision": 1,
  "prefix": "&7",
  "offset": [0.0, 0.3, 0.0],
  "wordWrapChars": 32,
  "maxAliveMs": 5000,
  "followPlayer": true,
  "hideOwn": true,
  "motion": {
    "translation": {
      "x": "0",
      "y": "10 * pow(clamp((ageMs - lifetimeMs + 2000) / 2000, 0, 1), 16)",
      "z": "0"
    },
    "scale": {
      "x": "1",
      "y": "1",
      "z": "1"
    },
    "rotation": {
      "x": "0",
      "y": "0",
      "z": "0"
    },
    "opacity": "1"
  },
  "shimmer": {
    "spawn": true,
    "flyAway": true,
    "color": "#ffffff",
    "width": 3,
    "durationMs": 700,
    "spawnDelayMs": 400,
    "flyAwayLeadMs": 700
  }
}
''';

/// A richer sample: a gold-prefixed, tight-wrapped, anchored (does not
/// follow) style that auto-applies to VIPs in overworld-named worlds.
const String kGlossBubbleShowcaseJson = r'''
{
  "schemaVersion": 2,
  "revision": 1,
  "prefix": "{{ hex(mix(#FF55FF, #55FFFF, (sin(time.seconds * 2) + 1) / 2)) }}&l",
  "offset": [0.0, 1.2, 0.0],
  "wordWrapChars": 34,
  "maxAliveMs": 7000,
  "motion": {
    "translation": {
      "x": "4 * t",
      "y": "5 * sin(pi * t) - 6 * t",
      "z": "2 * sin(pi * 2 * t + seed * pi)"
    },
    "scale": {
      "x": "1 - 0.35 * smoothstep(0.45, 1, t)",
      "y": "1 - 0.35 * smoothstep(0.45, 1, t)",
      "z": "1 - 0.35 * smoothstep(0.45, 1, t)"
    },
    "rotation": {
      "x": "45 * t",
      "y": "90 * t",
      "z": "180 * t"
    },
    "opacity": "1 - smoothstep(0.75, 1, t)"
  },
  "shimmer": {
    "spawn": true,
    "flyAway": true,
    "color": "#ff88ff",
    "width": 5,
    "spawnDelayMs": 100,
    "flyAwayLeadMs": 1000
  },
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
  "header": "{{ hex(mix(#FF55FF, #55FFFF, (sin(time.seconds * 2) + 1) / 2)) }}&lMy Server\n&7Welcome &f{{ player.name }} &8• {{ papi('vault_prefix', '&7Member') }} &8• &a{{ player.ping }}ms",
  "footer": "|animation.rainbow|&lONLINE &8• &7TPS &a{{ fixed(server.tps, 1) }}",
  "groupListNames": true,
  "nameFormats": {
    "default": "&7$player",
    "_op": "{{ hex(mix(#FF3355, #FF55FF, (sin(time.seconds * 4) + 1) / 2)) }}&l[OP] &f$player",
    "vip": "&6[$group] &f$player"
  }
}
''';

GlossTablistDoc buildDefaultGlossTablist() =>
    decodeGlossTablistDoc(kGlossTablistDefaultJson);

GlossTablistDoc buildShowcaseGlossTablist() =>
    decodeGlossTablistDoc(kGlossTablistShowcaseJson);
