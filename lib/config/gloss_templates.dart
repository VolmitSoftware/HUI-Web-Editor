/// Starter documents for the Gloss kinds.
///
/// The "on the server" entries are byte-identical copies of what the plugin
/// ships — `test/gloss_templates_test.dart` holds them against the Gloss
/// resources the same way `preview_templates_test.dart` pins the thirteen
/// preview cards. Starters are teaching documents the jar does not ship.
library;

import '../model/model.dart';

const String kGlossDamageIndicatorsDefaultJson = r'''
{
  "show": true,
  "schemaVersion": 4,
  "revision": 1,
  "limits": {
    "maxPerSecond": 40,
    "lifetimeMs": 3000,
    "minimumDelta": 0.009,
    "decimals": 0
  },
  "damage": {
    "when": "true",
    "presentation": {
      "format": "&c&l{amount}",
      "offset": [
        0.0,
        0.7,
        0.0
      ],
      "motion": {
        "horizontalSpeed": 0.8,
        "verticalSpeed": 1.3,
        "verticalAcceleration": -0.93,
        "spinDegreesPerSecond": 0.0
      },
      "transform": {
        "startScale": 1.0,
        "endScale": 0.82,
        "fadeStartFraction": 0.68
      },
      "particleLayers": [],
      "style": {
        "billboard": "center",
        "seeThrough": true,
        "scaleX": 1.0,
        "scaleY": 1.0,
        "scaleZ": 1.0
      },
      "box": {
        "enabled": false,
        "padding": 4,
        "borderWidth": 1,
        "backgroundArgb": "#B31B1B22",
        "borderArgb": "#FFAAAAAA"
      }
    },
    "variants": []
  },
  "healing": {
    "when": "true",
    "presentation": {
      "format": "&a&l{amount}",
      "offset": [
        0.0,
        -0.1,
        0.0
      ],
      "motion": {
        "horizontalSpeed": 0.45,
        "verticalSpeed": 0.65,
        "verticalAcceleration": 0.05,
        "spinDegreesPerSecond": 0.0
      },
      "transform": {
        "startScale": 1.0,
        "endScale": 1.1,
        "fadeStartFraction": 0.62
      },
      "particleLayers": [],
      "style": {
        "billboard": "center",
        "seeThrough": true,
        "scaleX": 1.0,
        "scaleY": 1.0,
        "scaleZ": 1.0
      },
      "box": {
        "enabled": false,
        "padding": 4,
        "borderWidth": 1,
        "backgroundArgb": "#B31B1B22",
        "borderArgb": "#FFAAAAAA"
      }
    },
    "variants": []
  },
  "audience": {
    "when": "hasPermission('viewer', 'gloss.indicators.show')"
  }
}
''';

GlossDamageIndicatorsDoc buildDefaultGlossDamageIndicators() =>
    decodeGlossDamageIndicatorsDoc(kGlossDamageIndicatorsDefaultJson);

/// `Gloss/src/main/resources/baselines/hologram.json`, byte for byte — what
/// `/gloss hologram create` starts a file from, and therefore what a blank
/// hologram document is here.
const String kGlossHologramBaselineJson = r'''
{
  "schemaVersion": 3,
  "revision": 1,
  "anchor": {
    "world": "world",
    "position": [
      0.0,
      0.0,
      0.0
    ]
  },
  "lines": [
    "&dNew hologram"
  ],
  "particleLayers": [],
  "style": {
    "billboard": "center",
    "seeThrough": true,
    "scaleX": 1.0,
    "scaleY": 1.0,
    "scaleZ": 1.0
  },
  "box": {
    "enabled": false,
    "padding": 4,
    "borderWidth": 1,
    "backgroundArgb": "#B31B1B22",
    "borderArgb": "#FFAAAAAA"
  }
}
''';

/// A richer starter showing the text pipeline: bracket hex, legacy codes,
/// native player/server values, an optional PAPI expansion and an animation
/// reference.
const String kGlossHologramShowcaseJson = r'''
{
  "schemaVersion": 3,
  "revision": 1,
  "anchor": {
    "world": "world",
    "position": [
      0.5,
      64.0,
      0.5
    ]
  },
  "lines": [
    "{{ hex(mix(#FF55FF, #55FFFF, (sin(time.seconds * 2) + 1) / 2)) }}&lWelcome",
    "&7Hello, &f{{ player.name }}&7!",
    "&7Health &a{{ bar(player.health, 20, 10, '■', '□') }}",
    "&7Rank {{ papi('vault_prefix', '&7Member') }}",
    "|animation.rainbow|&lLive colour prefix",
    "&7TPS &a{{ fixed(server.tps, 1) }}"
  ],
  "particleLayers": [],
  "style": {
    "billboard": "center",
    "seeThrough": true,
    "shadow": false,
    "backgroundArgb": "#00000000",
    "textOpacity": 255,
    "lineWidth": 16384,
    "textAlignment": "center",
    "scaleX": 1.0,
    "scaleY": 1.0,
    "scaleZ": 1.0,
    "viewRange": 1.0,
    "shadowRadius": 0.0,
    "shadowStrength": 0.0,
    "cullingWidth": 0.0,
    "cullingHeight": 0.0
  },
  "box": {
    "enabled": false,
    "padding": 4,
    "borderWidth": 1,
    "backgroundArgb": "#B31B1B22",
    "borderArgb": "#FFAAAAAA"
  }
}
''';

GlossHologramDoc buildBlankGlossHologram() =>
    decodeGlossHologramDoc(kGlossHologramBaselineJson);

GlossHologramDoc buildShowcaseGlossHologram() =>
    decodeGlossHologramDoc(kGlossHologramShowcaseJson);

const String kGlossRealDropsDefaultJson = r'''
{
  "show": true,
  "schemaVersion": 4,
  "revision": 1,
  "presentation": {
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
      "changeOnBounce": true,
      "velocityInfluence": 0.35,
      "submergedSpinMultiplier": 0.35,
      "groundRollMultiplier": 1.0
    },
    "landing": {
      "mode": "NATURAL",
      "tiltDegrees": 10.0,
      "randomYaw": true,
      "transitionTicks": 4,
      "faceAttraction": 0.55,
      "movingFaceAttraction": 0.15,
      "alignmentDegrees": 0.5,
      "settleDelayTicks": 4
    },
    "labels": {
      "enabled": true,
      "yOffset": 0.55,
      "style": {
        "billboard": "center",
        "shadow": true,
        "seeThrough": true,
        "textAlignment": "center",
        "backgroundArgb": "#50000000",
        "textOpacity": 255,
        "lineWidth": 16384,
        "blockLight": null,
        "skyLight": null,
        "viewRange": 0.5,
        "shadowRadius": 0,
        "shadowStrength": 0,
        "cullingWidth": 0,
        "cullingHeight": 0,
        "glowColor": null,
        "scaleX": 0.85,
        "scaleY": 0.85,
        "scaleZ": 0.85
      },
      "box": {
        "enabled": false,
        "padding": 4,
        "borderWidth": 1,
        "backgroundArgb": "#B31B1B22",
        "borderArgb": "#FFAAAAAA"
      }
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
    },
    "particleLayers": []
  },
  "variants": [],
  "audience": {
    "when": "true"
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
const String kGlossRealDropsPalmerHouseJson = r"""
{
  "schemaVersion": 3,
  "revision": 1,
  "presentation": {
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
  },
  "variants": [],
  "audience": {
    "when": "true"
  }
}
""";

/// Fast, wide and messy: a mined stack thrown across the floor.
const String kGlossRealDropsSawmillJson = r"""
{
  "schemaVersion": 3,
  "revision": 1,
  "presentation": {
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
  },
  "variants": [],
  "audience": {
    "when": "true"
  }
}
""";

/// Small, silent ground clutter: no labels, nothing spinning, cheap to run.
const String kGlossRealDropsQuietJson = r"""
{
  "schemaVersion": 3,
  "revision": 1,
  "presentation": {
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
  },
  "variants": [],
  "audience": {
    "when": "true"
  }
}
""";

GlossRealDropSettingsDoc buildPalmerHouseGlossRealDrops() =>
    decodeGlossRealDropSettingsDoc(kGlossRealDropsPalmerHouseJson);

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
  "show": true,
  "mode": "ascend",
  "frameIntervalMs": 53,
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

GlossAnimationDoc buildMarqueeGlossAnimation() => GlossAnimationDoc(
  extras: <String, Object?>{'show': true},
  frameIntervalMs: 1000,
  frames: <String>[
    "&b{{ marquee('GLOSS REALMS', 12, floor(time.seconds * 4)) }}",
  ],
);

GlossAnimationDoc buildTimelineGlossAnimation() => GlossAnimationDoc(
  extras: <String, Object?>{'show': true},
  frameIntervalMs: 1000,
  frames: <String>[
    "{{ timeline([['&b' + marquee('WELCOME', 10, floor(time.seconds * 4)), 4], [flash('&a&lBOOSTED', '&7BOOSTED', floor(time.seconds * 4)), 4], ['&bEVENT LIVE', 4]], time.seconds) }}",
  ],
);

GlossAnimationDoc buildTypewriterGlossAnimation() => GlossAnimationDoc(
  extras: <String, Object?>{'show': true},
  frameIntervalMs: 1000,
  frames: <String>[
    "&f{{ typewriter('WELCOME', floor(time.seconds * 4) + 7, 1) }}",
  ],
);

GlossAnimationDoc buildFlashGlossAnimation() => GlossAnimationDoc(
  extras: <String, Object?>{'show': true},
  frameIntervalMs: 1000,
  frames: <String>[
    "{{ flash('&a&lBOOSTED', '&7BOOSTED', floor(time.seconds * 4)) }}",
  ],
);

GlossAnimationDoc buildWipeGlossAnimation() => GlossAnimationDoc(
  extras: <String, Object?>{'show': true},
  frameIntervalMs: 1000,
  frames: <String>["&d{{ wipe('WELCOME', floor(time.seconds * 4) + 7) }}"],
);

GlossAnimationDoc buildScannerGlossAnimation() => GlossAnimationDoc(
  extras: <String, Object?>{'show': true},
  frameIntervalMs: 1000,
  frames: <String>[
    "{{ scanner('BOOSTED', '&7', '&a', floor(time.seconds * 4)) }}",
  ],
);

GlossAnimationDoc buildDecodeGlossAnimation() => GlossAnimationDoc(
  extras: <String, Object?>{'show': true},
  frameIntervalMs: 1000,
  frames: <String>["&d{{ scramble('GHOSTWOOD', floor(time.seconds * 4)) }}"],
);

GlossAnimationDoc buildOdometerGlossAnimation() => GlossAnimationDoc(
  extras: <String, Object?>{'show': true},
  frameIntervalMs: 1000,
  frames: <String>[
    r'&6${{ odometer(0, 9999, mod(time.seconds, 20) / 20, 4) }}',
  ],
);

GlossAnimationDoc buildWaveGlossAnimation() => GlossAnimationDoc(
  extras: <String, Object?>{'show': true},
  frameIntervalMs: 1000,
  frames: <String>[
    "{{ wave('GLOSS', ['&a', '&7'], floor(time.seconds * 4)) }}",
  ],
);

final Map<String, GlossAnimationDoc Function()> shippedGlossAnimationBuilders =
    Map<String, GlossAnimationDoc Function()>.unmodifiable(
      <String, GlossAnimationDoc Function()>{
        'rainbow': buildRainbowGlossAnimation,
        'marquee': buildMarqueeGlossAnimation,
        'timeline': buildTimelineGlossAnimation,
        'typewriter': buildTypewriterGlossAnimation,
        'flash': buildFlashGlossAnimation,
        'wipe': buildWipeGlossAnimation,
        'scanner': buildScannerGlossAnimation,
        'decode': buildDecodeGlossAnimation,
        'odometer': buildOdometerGlossAnimation,
        'wave': buildWaveGlossAnimation,
      },
    );

/// `Gloss/src/main/resources/defaults/boards/default.json`, byte for byte —
/// the sidebar the plugin extracts into `plugins/Gloss/boards/` on first run
/// (deliberately `primary: false`, so nothing forces a sidebar on players).
const String kGlossScoreboardDefaultJson = r'''
{
  "schemaVersion": 2,
  "revision": 1,
  "show": true,
  "select": {
    "priority": 0,
    "when": "false"
  },
  "presentation": {
    "title": "&d&lGloss",
    "lines": [
      "&fWelcome!",
      "&7Edit boards/default.json",
      "&7or create your own board."
    ],
    "hideNumbers": false
  },
  "variants": []
}
''';

/// A richer sample: gated, grouped, primary, with an animated line and a
/// placeholder chip.
const String kGlossScoreboardShowcaseJson = r'''
{
  "schemaVersion": 2,
  "revision": 1,
  "select": {
    "priority": 20,
    "when": "hasPermission('viewer', 'gloss.board.vip') || inGroup('viewer', 'vip')"
  },
  "presentation": {
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
      "&d{{ select(['·', '•', '●', '•'], floor(time.seconds)) }} &f&lLIVE EVENT",
      "&d:heart: &fWelcome!",
      "&bplay.example.net"
    ],
    "hideNumbers": true
  },
  "variants": [
    {
      "id": "critical-health",
      "priority": 100,
      "when": "viewer.healthPercent <= 25",
      "presentation": {
        "title": "&c&lLOW HEALTH",
        "lines": ["&cYou are in danger", "&7Find somewhere safe"],
        "hideNumbers": true
      }
    }
  ]
}
''';

const String kGlossScoreboardAnimationShowcaseJson = r'''
{
  "schemaVersion": 2,
  "revision": 1,
  "show": true,
  "select": {
    "priority": 0,
    "when": "false"
  },
  "presentation": {
    "title": "&d&lANIMATION LAB",
    "lines": [
      "{{ select(['&c', '&6', '&e', '&a', '&b', '&d'], floor(time.seconds * 4)) }}&lRAINBOW",
      "&b{{ marquee('MARQUEE', 7, floor(time.seconds * 4)) }}",
      "{{ timeline([['&aTIMELINE', 2], ['&eNEXT SCENE', 2]], time.seconds) }}",
      "&f{{ typewriter('TYPEWRITER', floor(time.seconds * 4) + 9, 1) }}",
      "{{ flash('&d&lFLASH', '&7FLASH', floor(time.seconds * 4)) }}",
      "&d{{ wipe('WIPE', floor(time.seconds * 4) + 4) }}",
      "{{ scanner('SCANNER', '&7', '&a', floor(time.seconds * 4)) }}",
      "&5{{ scramble('DECODE', floor(time.seconds * 4)) }}",
      "&6ODO {{ odometer(0, 999, mod(time.seconds, 10) / 10, 3) }}",
      "{{ wave('WAVE', ['&a', '&7'], floor(time.seconds * 4)) }}",
      "&d&kMAGIC&r",
      "&a{{ align('GLOSS', 20, 'left') }}",
      "&e{{ align('GLOSS', 20, 'center') }}",
      "&c{{ align('GLOSS', 20, 'right') }}"
    ],
    "hideNumbers": true
  },
  "variants": []
}
''';

GlossScoreboardDoc buildDefaultGlossScoreboard() =>
    decodeGlossScoreboardDoc(kGlossScoreboardDefaultJson);

GlossScoreboardDoc buildShowcaseGlossScoreboard() =>
    decodeGlossScoreboardDoc(kGlossScoreboardShowcaseJson);

GlossScoreboardDoc buildAnimationShowcaseGlossScoreboard() =>
    decodeGlossScoreboardDoc(kGlossScoreboardAnimationShowcaseJson);

/// `Gloss/src/main/resources/defaults/connections/connections.json`, byte for
/// byte — the join and leave lines the plugin extracts to
/// `plugins/Gloss/connections.json` on first run.
const String kGlossConnectionsDefaultJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "show": true,
  "join": {
    "enabled": true,
    "show": true,
    "audience": "network",
    "presentation": { "text": "&a+ &f{{ subject.name }} &7joined" },
    "variants": []
  },
  "leave": {
    "enabled": true,
    "show": true,
    "audience": "network",
    "presentation": { "text": "&c- &f{{ subject.name }} &7left" },
    "variants": []
  }
}
''';

/// A richer sample: both sections conditional, a staff-only variant on each,
/// and the scoped names a connection message actually reads.
const String kGlossConnectionsShowcaseJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "show": true,
  "join": {
    "enabled": true,
    "show": true,
    "audience": "network",
    "presentation": { "text": "&a+ &f{{ subject.name }} &7joined &8(&7{{ server.online }}&8/&7{{ server.max }}&8)" },
    "variants": [
      {
        "priority": 10,
        "when": "inGroup('subject', 'staff')",
        "presentation": { "text": "&6\u00bb &e&l{{ subject.name }} &6joined &7\u2014 staff on duty" }
      }
    ]
  },
  "leave": {
    "enabled": true,
    "show": true,
    "audience": "network",
    "presentation": { "text": "&c- &f{{ subject.name }} &7left" },
    "variants": [
      {
        "priority": 10,
        "when": "inGroup('subject', 'staff')",
        "presentation": { "text": "&6\u00ab &e{{ subject.name }} &6signed off" }
      }
    ]
  }
}
''';

GlossConnectionsDoc buildDefaultGlossConnections() =>
    decodeGlossConnectionsDoc(kGlossConnectionsDefaultJson);

GlossConnectionsDoc buildShowcaseGlossConnections() =>
    decodeGlossConnectionsDoc(kGlossConnectionsShowcaseJson);

/// `Gloss/src/main/resources/defaults/surfaces/welcome.json`, byte for byte —
/// the action-bar greeting the plugin extracts to
/// `plugins/Gloss/surfaces/welcome.json` on first run. It ships with
/// `select.when` at `false`, so nothing shows it until an author writes the
/// condition.
const String kGlossSurfaceWelcomeJson = r"""
{
  "schemaVersion": 1,
  "revision": 1,
  "surface": "actionbar",
  "show": "true",
  "select": { "priority": 0, "when": "false" },
  "presentation": { "text": "&7Welcome, &f{{ player.name }}", "slots": ["center"], "priority": "ambient", "ttlTicks": 40 },
  "variants": []
}
""";

/// An action bar that reports where the viewer is standing, with a
/// higher-priority variant for the moment their health drops.
const String kGlossSurfaceActionbarShowcaseJson = r"""
{
  "schemaVersion": 1,
  "revision": 1,
  "surface": "actionbar",
  "show": true,
  "select": { "priority": 10, "when": "viewer.world == 'world'" },
  "presentation": {
    "text": "&8┃ &7world &f{{ viewer.world }} &8┃ &7tps &a{{ fixed(server.tps, 1) }} &8┃ &7online &f{{ server.online }}&8/&7{{ server.max }}",
    "slots": ["center"],
    "priority": "status",
    "ttlTicks": 60
  },
  "variants": [
    {
      "id": "critical-health",
      "priority": 40,
      "when": "viewer.healthPercent <= 25",
      "presentation": {
        "text": "&c&l! &fLOW HEALTH &8┃ &c{{ fixed(viewer.health, 1) }}&8/&7{{ fixed(viewer.maxHealth, 1) }}",
        "slots": ["center"],
        "priority": "modal",
        "ttlTicks": 40
      }
    }
  ]
}
""";

/// A boss bar whose fill is an expression and whose notch style changes with
/// the viewer's group — the two knobs only this surface has.
const String kGlossSurfaceBossbarShowcaseJson = r"""
{
  "schemaVersion": 1,
  "revision": 1,
  "surface": "bossbar",
  "show": true,
  "select": { "priority": 20, "when": "viewer.level >= 0" },
  "presentation": {
    "title": "&d&lHARVEST FESTIVAL &8┃ &f{{ viewer.name }}",
    "progress": "{{ clamp(viewer.level / 30, 0, 1) }}",
    "color": "purple",
    "style": "segmented_10",
    "slots": ["center"],
    "priority": "progress",
    "ttlTicks": 200
  },
  "variants": [
    {
      "id": "vip-lane",
      "priority": 30,
      "when": "inGroup('viewer', 'vip')",
      "presentation": {
        "title": "&6&lHARVEST FESTIVAL &8┃ &eVIP &f{{ viewer.name }}",
        "progress": "{{ clamp(viewer.level / 20, 0, 1) }}",
        "color": "yellow",
        "style": "segmented_20",
        "slots": ["center"],
        "priority": "progress",
        "ttlTicks": 200
      }
    }
  ]
}
""";

/// A title card with a subtitle and the full fade, stay and repeat set.
const String kGlossSurfaceTitleShowcaseJson = r"""
{
  "schemaVersion": 1,
  "revision": 1,
  "surface": "title",
  "show": true,
  "select": { "priority": 30, "when": "viewer.world == 'world'" },
  "presentation": {
    "title": "&d&lWELCOME BACK",
    "subtitle": "&7{{ viewer.name }} &8· &7level &f{{ viewer.level }}",
    "slots": ["center"],
    "priority": "notice",
    "fadeInTicks": 12,
    "stayTicks": 70,
    "fadeOutTicks": 16,
    "trigger": "once",
    "ttlTicks": 120
  },
  "variants": [
    {
      "id": "nether-arrival",
      "priority": 20,
      "when": "viewer.world == 'world_nether'",
      "presentation": {
        "title": "&c&lTHE NETHER",
        "subtitle": "&7mind the ledges",
        "slots": ["center"],
        "priority": "notice",
        "fadeInTicks": 8,
        "stayTicks": 60,
        "fadeOutTicks": 12,
        "trigger": "repeat",
        "repeatTicks": 400,
        "ttlTicks": 120
      }
    }
  ]
}
""";

GlossSurfaceDoc buildDefaultGlossSurface() =>
    decodeGlossSurfaceDoc(kGlossSurfaceWelcomeJson);

GlossSurfaceDoc buildActionbarShowcaseGlossSurface() =>
    decodeGlossSurfaceDoc(kGlossSurfaceActionbarShowcaseJson);

GlossSurfaceDoc buildBossbarShowcaseGlossSurface() =>
    decodeGlossSurfaceDoc(kGlossSurfaceBossbarShowcaseJson);

GlossSurfaceDoc buildTitleShowcaseGlossSurface() =>
    decodeGlossSurfaceDoc(kGlossSurfaceTitleShowcaseJson);

/// `Gloss/src/main/resources/defaults/motd/motd.json`, byte for byte — the
/// MOTD the plugin extracts to `plugins/Gloss/motd.json` on first run.
const String kGlossMotdDefaultJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "show": true,
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
/// bracket hex, an animated line, the hover sample and counts an entry can
/// author, a version label, and the pause-menu links the document publishes
/// once per revision — everything `renderStatic` and `applyExtras` support.
const String kGlossMotdShowcaseJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "entries": [
    {
      "lines": [
        "{{ select(['&d', '&b', '&6'], floor(time.seconds * 4)) }}&lMy Server",
        "&7Online &a{{ server.online }}&8/&a{{ server.maxPlayers }}"
      ],
      "sample": [
        "&7Skyblock &8• &7Survival &8• &7Creative",
        "&8Type &f/menu &8in game"
      ],
      "version": "&dGloss"
    },
    {
      "lines": [
        "|animation.rainbow|&lDouble XP weekend!",
        "&7The colour changes every ping"
      ],
      "online": "{{ server.online }}",
      "max": "{{ server.maxPlayers }}"
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
  ],
  "links": [
    {
      "type": "website",
      "url": "https://example.net"
    },
    {
      "type": "report_bug",
      "url": "https://example.net/bugs"
    },
    {
      "label": "&bStore",
      "url": "https://store.example.net"
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
  "show": true,
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
  "show": true,
  "schemaVersion": 5,
  "revision": 1,
  "prefix": "&7",
  "offset": [
    0.0,
    0.3,
    0.0
  ],
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
  },
  "particleLayers": [],
  "style": {
    "billboard": "center",
    "seeThrough": true,
    "scaleX": 1.0,
    "scaleY": 1.0,
    "scaleZ": 1.0
  },
  "box": {
    "enabled": false,
    "padding": 4,
    "borderWidth": 1,
    "backgroundArgb": "#B31B1B22",
    "borderArgb": "#FFAAAAAA"
  }
}
''';

/// A richer sample: a gold-prefixed, tight-wrapped, anchored (does not
/// follow) style that auto-applies to VIPs in overworld-named worlds.
const String kGlossBubbleShowcaseJson = r'''
{
  "schemaVersion": 5,
  "revision": 1,
  "prefix": "{{ hex(mix(#FF55FF, #55FFFF, (sin(time.seconds * 2) + 1) / 2)) }}&l",
  "offset": [
    0.0,
    1.2,
    0.0
  ],
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
    "priority": 10,
    "when": "matchesGlob(viewer.world, 'world*') && inGroup('viewer', 'vip')"
  },
  "style": {
    "billboard": "center",
    "seeThrough": true,
    "shadow": false,
    "backgroundArgb": "#00000000",
    "textOpacity": 255,
    "lineWidth": 16384,
    "textAlignment": "center",
    "scaleX": 1.0,
    "scaleY": 1.0,
    "scaleZ": 1.0,
    "viewRange": 1.0,
    "shadowRadius": 0.0,
    "shadowStrength": 0.0,
    "cullingWidth": 0.0,
    "cullingHeight": 0.0
  },
  "box": {
    "enabled": false,
    "padding": 4,
    "borderWidth": 1,
    "backgroundArgb": "#B31B1B22",
    "borderArgb": "#FFAAAAAA"
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
  "schemaVersion": 2,
  "revision": 1,
  "show": true,
  "headerFooter": {
    "enabled": true,
    "show": true,
    "presentation": {
      "header": "&d&lGloss",
      "footer": "&7VolmitSoftware.com"
    },
    "variants": []
  },
  "listNames": {
    "enabled": true,
    "show": true,
    "presentation": {
      "format": "$player"
    },
    "variants": [
      {
        "id": "operator",
        "priority": 100,
        "when": "subject.op",
        "presentation": {
          "format": "&6$player"
        }
      }
    ]
  }
}
''';

/// A richer sample: hex header, an animated footer line, and per-group list
/// names using both tokens.
const String kGlossTablistShowcaseJson = r'''
{
  "schemaVersion": 2,
  "revision": 1,
  "headerFooter": {
    "enabled": true,
    "presentation": {
      "header": "{{ hex(mix(#FF55FF, #55FFFF, (sin(time.seconds * 2) + 1) / 2)) }}&lMy Server\n&7Welcome &f{{ player.name }} &8• {{ papi('vault_prefix', '&7Member') }} &8• &a{{ player.ping }}ms",
      "footer": "|animation.rainbow|&lONLINE &8• &7TPS &a{{ fixed(server.tps, 1) }}"
    },
    "variants": []
  },
  "listNames": {
    "enabled": true,
    "presentation": {
      "format": "&7$player"
    },
    "variants": [
      {
        "id": "operator",
        "priority": 100,
        "when": "subject.op",
        "presentation": {
          "format": "{{ hex(mix(#FF3355, #FF55FF, (sin(time.seconds * 4) + 1) / 2)) }}&l[OP] &f$player"
        }
      },
      {
        "id": "vip",
        "priority": 50,
        "when": "inGroup('subject', 'vip')",
        "presentation": {
          "format": "&6[$group] &f$player"
        }
      }
    ]
  }
}
''';

GlossTablistDoc buildDefaultGlossTablist() =>
    decodeGlossTablistDoc(kGlossTablistDefaultJson);

GlossTablistDoc buildShowcaseGlossTablist() =>
    decodeGlossTablistDoc(kGlossTablistShowcaseJson);

const String kGlossDialogBlankJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "show": "false",
  "type": "notice",
  "title": "&6Notice",
  "canCloseWithEscape": true,
  "pause": false,
  "afterAction": "close",
  "body": [
    {
      "type": "text",
      "text": "&7A short notice for {{ viewer.name }}.",
      "width": 220
    }
  ],
  "buttons": [
    { "label": "&aOK", "actions": [] }
  ],
  "columns": 1,
  "variants": []
}
''';

const String kGlossInventoryBlankJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "show": "false",
  "title": "&8Chest",
  "resolution": "9x3",
  "mask": [
    "#########",
    "#.......#",
    "#########"
  ],
  "keys": {
    "#": {
      "type": "decoration",
      "icon": { "type": "item", "item": "minecraft:gray_stained_glass_pane", "name": " " }
    }
  },
  "slots": {},
  "closeOnTeleport": true,
  "variants": []
}
''';

const String kGlossMarkerDefaultJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "show": "true",
  "anchor": { "world": "world", "x": 0, "y": 64, "z": 0 },
  "label": "&6Waypoint",
  "color": "#FFAA00",
  "hideWithin": 4,
  "maxDistance": 256,
  "beam": { "enabled": true, "height": 48, "width": 0.25, "material": "minecraft:yellow_stained_glass" },
  "edge": { "enabled": false, "margin": 0.8, "arrow": "&6>" },
  "trail": { "enabled": false, "particle": "minecraft:end_rod", "spacing": 2, "maxPoints": 48 },
  "lifetimeTicks": 0,
  "waypoint": false
}
''';

const String kGlossZoneDefaultJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "show": "true",
  "shape": { "type": "cuboid", "world": "world", "min": [0, 64, 0], "max": [16, 80, 16] },
  "render": {
    "mode": "particles",
    "particle": "minecraft:dust",
    "color": "#55FFFF",
    "spacing": 0.75,
    "wallMaterial": "minecraft:light_blue_stained_glass",
    "facingOnly": true,
    "edgesOnly": false
  },
  "ambience": { "enabled": false, "particle": "minecraft:ash", "perViewerPerTick": 4, "radius": 12, "when": "true" },
  "toggle": "gloss.zones.toggle"
}
''';

GlossDialogDoc buildBlankGlossDialog() =>
    decodeGlossDialogDoc(kGlossDialogBlankJson);

GlossDialogDoc buildShowcaseGlossDialog() =>
    decodeGlossDialogDoc(kGlossDialogExampleJson);

GlossInventoryDoc buildBlankGlossInventory() =>
    decodeGlossInventoryDoc(kGlossInventoryBlankJson);

GlossInventoryDoc buildShowcaseGlossInventory() =>
    decodeGlossInventoryDoc(kGlossInventoryExampleJson);

GlossNameplateDoc buildDefaultGlossNameplate() =>
    decodeGlossNameplateDoc(kGlossNameplateDefaultJson);

GlossNametagDoc buildDefaultGlossNametag() =>
    decodeGlossNametagDoc(kGlossNametagDefaultJson);

GlossMotionDoc buildDefaultGlossMotion() =>
    decodeGlossMotionDoc(kGlossMotionBreatheJson);

GlossMotionDoc buildShowcaseGlossMotion() =>
    decodeGlossMotionDoc(kGlossMotionSpinJson);

GlossRigDoc buildDefaultGlossRig() => decodeGlossRigDoc(kGlossRigPedestalJson);

GlossMarkerDoc buildDefaultGlossMarker() =>
    decodeGlossMarkerDoc(kGlossMarkerDefaultJson);

GlossZoneDoc buildDefaultGlossZone() =>
    decodeGlossZoneDoc(kGlossZoneDefaultJson);

const String kGlossDialogExampleJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "show": "false",
  "type": "multi_action",
  "title": "&6Trader",
  "externalTitle": "Trader",
  "canCloseWithEscape": true,
  "pause": false,
  "afterAction": "close",
  "body": [
    {
      "type": "text",
      "text": "Pick a trade, {{ viewer.name }}.",
      "width": 220
    },
    {
      "type": "item",
      "item": { "type": "item", "item": "minecraft:emerald" },
      "description": "&aEmeralds accepted",
      "showTooltip": true,
      "showDecorations": true,
      "width": 220,
      "height": 20
    }
  ],
  "inputs": [
    { "type": "number", "key": "qty", "label": "Quantity", "start": 1, "end": 64, "step": 1, "initial": 1, "width": 200 },
    { "type": "option", "key": "color", "label": "Color", "options": [
      { "id": "red", "label": "Red" },
      { "id": "blue", "label": "Blue", "initial": true }
    ] },
    { "type": "bool", "key": "gift", "label": "Gift wrap", "initial": false },
    { "type": "text", "key": "note", "label": "Note", "initial": "", "maxLength": 32, "multiline": { "maxLines": 2, "height": 40 } }
  ],
  "buttons": [
    {
      "label": "&aBuy",
      "tooltip": "Buys {{ input.qty }} {{ input.color }}",
      "width": 150,
      "actions": [
        { "type": "economy", "op": "withdraw", "amount": "{{ input.qty }} * 10", "denyMessage": "&cNot enough coins." },
        { "type": "message", "message": "&aBought {{ input.qty }} {{ input.color }}." }
      ]
    },
    { "label": "&7Later", "actions": [] }
  ],
  "exit": { "label": "Close" },
  "columns": 2,
  "fallback": { "inventory": "example" },
  "variants": []
}
''';

const String kGlossInventoryExampleJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "show": "false",
  "title": "&8Shop &7- {{ viewer.name }}",
  "resolution": "9x6",
  "mask": [
    "#########",
    "#.......#",
    "#.......#",
    "#.......#",
    "#.......#",
    "#<##X##>#"
  ],
  "keys": {
    "#": { "type": "decoration", "icon": { "type": "item", "item": "minecraft:gray_stained_glass_pane", "name": " " } },
    "<": { "type": "button", "icon": { "type": "item", "item": "minecraft:arrow", "name": "&7Previous" },
           "actions": [ { "type": "navigate", "mode": "page", "target": "prev" } ] },
    ">": { "type": "button", "icon": { "type": "item", "item": "minecraft:arrow", "name": "&7Next" },
           "actions": [ { "type": "navigate", "mode": "page", "target": "next" } ] },
    "X": { "type": "button", "icon": { "type": "item", "item": "minecraft:barrier", "name": "&cClose" },
           "actions": [ { "type": "close" } ] }
  },
  "slots": {
    "10": {
      "type": "button",
      "icon": { "type": "item", "item": "minecraft:diamond_sword", "name": "&bSword", "lore": ["&7100 coins"] },
      "show": "viewer.level >= 5",
      "actions": [
        { "type": "message", "message": "&aThe shop is an example; edit inventories/example.json." }
      ]
    }
  },
  "list": {
    "area": ".",
    "var": "entry",
    "source": "['stone','dirt','oak_log']",
    "pageSize": 28,
    "template": {
      "type": "button",
      "icon": { "type": "item", "item": "minecraft:stone", "name": "&f{{ entry }}" },
      "actions": [ { "type": "message", "message": "&7You picked &f{{ entry }}&7." } ]
    }
  },
  "closeOnTeleport": true,
  "variants": []
}
''';

const String kGlossNameplateDefaultJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "show": "true",
  "select": {
    "priority": 0,
    "when": "true"
  },
  "presentation": {
    "lines": [
      {
        "text": "&7[{{ subject.group }}] &f{{ subject.name }}",
        "show": "true"
      },
      {
        "text": "{{ bar(subject.health, subject.maxHealth, 10, '&c|', '&8|') }}",
        "show": "subject.health < subject.maxHealth"
      }
    ],
    "offset": 0.3,
    "hideSneaking": true,
    "relations": [
      {
        "when": "hasPermission('subject', 'server.staff')",
        "color": "&c"
      }
    ]
  },
  "variants": []
}
''';

const String kGlossNametagDefaultJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "show": "true",
  "select": { "priority": 0, "when": "false" },
  "presentation": { "prefix": "&7[{{ subject.group }}] ", "suffix": "", "color": "white", "nameTagVisibility": "always", "collision": "always" },
  "variants": [
    { "id": "staff", "priority": 10, "when": "hasPermission('subject', 'server.staff')",
      "presentation": { "prefix": "&c[Staff] ", "suffix": " &c*", "color": "red", "nameTagVisibility": "always", "collision": "never" } }
  ]
}
''';

const String kGlossMotionBreatheJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "durationTicks": 40,
  "loop": "pingpong",
  "fps": 30,
  "tracks": [
    {
      "bone": "root",
      "channel": "translation.y",
      "blend": "add",
      "keyframes": [
        { "tick": 0, "value": 0, "easing": "ease_in_out" },
        { "tick": 40, "value": 0.15, "easing": "ease_in_out" }
      ]
    },
    {
      "bone": "root",
      "channel": "scale.y",
      "blend": "multiply",
      "keyframes": [
        { "tick": 0, "value": 1 },
        { "tick": 40, "value": 1.04, "easing": "ease_in_out" }
      ]
    }
  ]
}
''';

const String kGlossMotionSpinJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "durationTicks": 80,
  "loop": "loop",
  "fps": 30,
  "tracks": [
    {
      "bone": "root",
      "channel": "rotation.y",
      "blend": "add",
      "keyframes": [
        { "tick": 0, "value": 0 },
        { "tick": 80, "value": 360 }
      ]
    }
  ]
}
''';

const String kGlossRigPedestalJson = r'''
{
  "schemaVersion": 1,
  "revision": 1,
  "show": "true",
  "bones": [
    { "id": "root", "parent": null, "rest": { "translation": [0, 0, 0], "rotation": [0, 0, 0], "scale": [1, 1, 1] } },
    { "id": "lid", "parent": "root", "rest": { "translation": [0, 0.9, -0.45], "rotation": [0, 0, 0], "scale": [1, 1, 1] } }
  ],
  "parts": [
    { "id": "base", "bone": "root", "type": "block", "block": "minecraft:chiseled_stone_bricks", "transform": { "translation": [-0.5, 0, -0.5], "scale": [1, 0.9, 1] }, "brightness": 15 },
    { "id": "lidPart", "bone": "lid", "type": "item", "item": { "type": "item", "item": "minecraft:oak_trapdoor" }, "transform": { "translation": [0, 0, 0.45], "scale": [1, 0.1, 1] } },
    { "id": "label", "bone": "root", "type": "text", "text": "&6{{ rig.state }}", "transform": { "translation": [0, 1.4, 0] }, "billboard": "vertical" }
  ],
  "clips": { "idle": "breathe", "open": { "motion": "spin", "loop": "once" } },
  "graph": {
    "initial": "idle",
    "states": { "idle": { "clip": "idle" }, "open": { "clip": "open", "then": "idle" } },
    "transitions": [
      { "from": "idle", "to": "open", "when": "rig.var.opened == true" },
      { "from": "open", "to": "idle", "when": "rig.var.opened == false" }
    ]
  },
  "hitboxes": [
    { "part": "base", "size": [1, 1, 1], "actions": [
      { "type": "setRig", "var": "opened", "value": "rig.var.opened != true", "trigger": "right_click" }
    ] }
  ],
  "lod": { "reducedAt": 32, "minimalAt": 64, "cullAt": 96, "minimalPart": "base" },
  "audience": { "when": "true" }
}
''';
