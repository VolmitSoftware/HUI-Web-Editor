/// Byte-identical copies of `Gloss/src/main/resources/previews/*.json`.
///
/// Do not hand-edit. Re-copy from the plugin and keep
/// `test/fixtures/previews/` in lockstep. `preview_templates_test.dart`
/// fails if any of the three copies diverge.
library;

const Map<String, String> kShippedPreviewJson = <String, String>{
  'beehive': r'''
{
  "match": {
    "blocks": ["BEEHIVE", "BEE_NEST"],
    "priority": 10,
    "vars": {
      "cells": 3,
      "beeColor": "#FF8A6618",
      "wellColor": "#FF15151B",
      "titleKey": "gloss.preview.theme.title.beehive",
      "accent": "#F2D451"
    }
  },
  "variants": [
    {
      "blocks": ["BEE_NEST"],
      "vars": { "titleKey": "gloss.preview.theme.title.bee_nest" }
    }
  ],
  "card": {
    "title": "'&f&l' + plain(lang(vars.titleKey))",
    "accent": "vars.accent"
  },
  "elements": [
    {
      "type": "cell",
      "repeat": { "count": "vars.cells", "var": "i" },
      "x": "round((i - (vars.cells - 1) / 2) * 20)",
      "y": 0,
      "size": 18,
      "color": "i < bees ? vars.beeColor : vars.wellColor"
    },
    {
      "type": "label",
      "x": 0,
      "y": 21,
      "text": "'&6' + lang('gloss.preview.stat.bees_and_honey', bees, maxBees, honey, maxHoney)"
    }
  ]
}
''',
  'brewing_stand': r'''
{
  "match": {
    "blocks": ["BREWING_STAND"],
    "priority": 10,
    "vars": {
      "segments": 6,
      "fuelCells": 3,
      "bottleSlots": 3,
      "wellColor": "#FF15151B",
      "fill": "#FFB152DA",
      "pulseBright": "#FFE8A6F2",
      "pulseDim": "#FF5E2E78",
      "bubble": "#FFD98AE8",
      "fuelColor": "#FFF2A535",
      "stateColor": "<#B152DA>",
      "surgeColor": "<#E8A6F2>",
      "titleKey": "gloss.preview.theme.title.brewing_stand",
      "accent": "#EC88EC"
    }
  },
  "card": {
    "title": "'&f&l' + (customName != '' ? customName : plain(lang(vars.titleKey)))",
    "accent": "vars.accent"
  },
  "elements": [
    { "type": "slot", "x": 0, "y": 16, "size": 18, "index": 3 },
    { "type": "slot", "x": -44, "y": 16, "size": 18, "index": 4 },
    {
      "type": "slot",
      "repeat": { "count": "vars.bottleSlots", "var": "bottle" },
      "x": "(bottle - 1) * 24",
      "y": -12,
      "size": 18,
      "index": "bottle"
    },
    {
      "type": "cell",
      "repeat": { "count": "vars.segments", "var": "i" },
      "x": 44,
      "y": "18 - i * 7",
      "size": 5,
      "color": "brewTime > 0 ? (i < floor(clamp(1 - brewTime / brewTotal, 0, 1) * vars.segments) ? (surge.active ? (mod(floor(brewTime / 2) + i, 2) == 0 ? vars.pulseBright : vars.fill) : vars.fill) : (i == floor(clamp(1 - brewTime / brewTotal, 0, 1) * vars.segments) ? (mod(floor(brewTime / 4), 2) == 0 ? vars.pulseBright : vars.pulseDim) : (mod(floor(brewTime / 4) + i * 2, 7) == 0 ? vars.bubble : vars.wellColor))) : vars.wellColor"
    },
    {
      "type": "cell",
      "repeat": { "count": "vars.fuelCells", "var": "i" },
      "x": -44,
      "y": "-12 + i * 7",
      "size": 5,
      "color": "i < ceil(clamp(fuelLevel, 0, maxFuel) / maxFuel * vars.fuelCells) ? vars.fuelColor : vars.wellColor"
    },
    {
      "type": "label",
      "x": 0,
      "y": -32,
      "text": "(brewTime > 0 ? vars.stateColor + lang('gloss.preview.state.brewing', round(clamp(1 - brewTime / brewTotal, 0, 1) * 100)) : (occupied(3) && (occupied(0) || occupied(1) || occupied(2)) && fuelLevel <= 0 ? '&c' + lang('gloss.preview.state.needs_blaze_powder') : (occupied(3) && (occupied(0) || occupied(1) || occupied(2)) ? '&7' + lang('gloss.preview.state.waiting') : (occupied(0) || occupied(1) || occupied(2) ? '&7' + lang('gloss.preview.state.no_ingredient') : '&8' + lang('gloss.preview.state.empty'))))) + (surge.active ? vars.surgeColor + lang('gloss.preview.state.surge_suffix', surge.gain == floor(surge.gain) ? str(surge.gain) : fixed(surge.gain, 1)) : '')"
    },
    {
      "type": "label",
      "x": 0,
      "y": -46,
      "text": "(fuelLevel > 0 ? '&e' + lang('gloss.preview.stat.fuel_level', fuelLevel, maxFuel) : '&8' + lang('gloss.preview.stat.no_fuel')) + '<dark_gray>  •  </dark_gray>' + ((occupied(0) ? 1 : 0) + (occupied(1) ? 1 : 0) + (occupied(2) ? 1 : 0) > 0 ? '<light_purple>' + lang('gloss.preview.stat.bottles', (occupied(0) ? 1 : 0) + (occupied(1) ? 1 : 0) + (occupied(2) ? 1 : 0), vars.bottleSlots) + '</light_purple>' : '<dark_gray>' + lang('gloss.preview.stat.bottles', (occupied(0) ? 1 : 0) + (occupied(1) ? 1 : 0) + (occupied(2) ? 1 : 0), vars.bottleSlots) + '</dark_gray>')"
    }
  ]
}
''',
  'cauldron': r'''
{
  "match": {
    "blocks": ["CAULDRON", "WATER_CAULDRON", "LAVA_CAULDRON", "POWDER_SNOW_CAULDRON"],
    "priority": 10,
    "vars": {
      "cells": 3,
      "fluidColor": "#FF2E5E8C",
      "wellColor": "#FF15151B",
      "titleKey": "gloss.preview.theme.title.cauldron",
      "accent": "#A6ACB6"
    }
  },
  "variants": [
    {
      "blocks": ["WATER_CAULDRON"],
      "vars": {
        "fluidColor": "#FF2E5E8C",
        "titleKey": "gloss.preview.theme.title.water_cauldron",
        "accent": "#5E82FF"
      }
    },
    {
      "blocks": ["LAVA_CAULDRON"],
      "vars": {
        "fluidColor": "#FFA14C16",
        "titleKey": "gloss.preview.theme.title.lava_cauldron",
        "accent": "#F2A535"
      }
    },
    {
      "blocks": ["POWDER_SNOW_CAULDRON"],
      "vars": {
        "fluidColor": "#FFD8E5EF",
        "titleKey": "gloss.preview.theme.title.powder_snow_cauldron",
        "accent": "#CBD0D9"
      }
    }
  ],
  "card": {
    "title": "'&f&l' + plain(lang(vars.titleKey))",
    "accent": "vars.accent"
  },
  "elements": [
    {
      "type": "cell",
      "repeat": { "count": "vars.cells", "var": "i" },
      "x": "round((i - (vars.cells - 1) / 2) * 20)",
      "y": 0,
      "size": 18,
      "color": "i < ceil(level / maxLevel * vars.cells) ? vars.fluidColor : vars.wellColor"
    },
    {
      "type": "label",
      "x": 0,
      "y": 21,
      "text": "level <= 0 ? '&7' + lang('gloss.preview.stat.cauldron_empty', level, maxLevel) : '&b' + lang('gloss.preview.stat.cauldron_level', level, maxLevel)"
    }
  ]
}
''',
  'chest': r'''
{
  "match": {
    "blocks": ["CHEST", "TRAPPED_CHEST", "BARREL"],
    "priority": 10,
    "vars": {
      "cols": 9,
      "maxRows": 6,
      "titleKey": "gloss.preview.theme.title.chest",
      "titleArg": "",
      "accent": "#F2A535"
    }
  },
  "variants": [
    {
      "blocks": ["TRAPPED_CHEST"],
      "vars": { "titleKey": "gloss.preview.theme.title.trapped_chest", "accent": "#EC6464" }
    },
    {
      "blocks": ["BARREL"],
      "vars": { "titleKey": "gloss.preview.theme.title.barrel", "accent": "#F2D451" }
    },
    {
      "blocks": ["*COPPER_CHEST"],
      "vars": { "titleKey": "gloss.preview.theme.title.copper_chest", "accent": "#F2A535" }
    },
    {
      "blocks": ["WHITE_SHULKER_BOX"],
      "vars": { "titleKey": "gloss.preview.theme.title.shulker", "titleArg": "White", "accent": "#CBD0D9" }
    },
    {
      "blocks": ["ORANGE_SHULKER_BOX"],
      "vars": { "titleKey": "gloss.preview.theme.title.shulker", "titleArg": "Orange", "accent": "#F2A535" }
    },
    {
      "blocks": ["MAGENTA_SHULKER_BOX"],
      "vars": { "titleKey": "gloss.preview.theme.title.shulker", "titleArg": "Magenta", "accent": "#EC88EC" }
    },
    {
      "blocks": ["LIGHT_BLUE_SHULKER_BOX"],
      "vars": { "titleKey": "gloss.preview.theme.title.shulker", "titleArg": "Light Blue", "accent": "#6FEAEA" }
    },
    {
      "blocks": ["YELLOW_SHULKER_BOX"],
      "vars": { "titleKey": "gloss.preview.theme.title.shulker", "titleArg": "Yellow", "accent": "#F2D451" }
    },
    {
      "blocks": ["LIME_SHULKER_BOX"],
      "vars": { "titleKey": "gloss.preview.theme.title.shulker", "titleArg": "Lime", "accent": "#6FE06F" }
    },
    {
      "blocks": ["PINK_SHULKER_BOX"],
      "vars": { "titleKey": "gloss.preview.theme.title.shulker", "titleArg": "Pink", "accent": "#EC88EC" }
    },
    {
      "blocks": ["GRAY_SHULKER_BOX"],
      "vars": { "titleKey": "gloss.preview.theme.title.shulker", "titleArg": "Gray", "accent": "#6E747E" }
    },
    {
      "blocks": ["LIGHT_GRAY_SHULKER_BOX"],
      "vars": { "titleKey": "gloss.preview.theme.title.shulker", "titleArg": "Light Gray", "accent": "#A6ACB6" }
    },
    {
      "blocks": ["CYAN_SHULKER_BOX"],
      "vars": { "titleKey": "gloss.preview.theme.title.shulker", "titleArg": "Cyan", "accent": "#3AC4C4" }
    },
    {
      "blocks": ["PURPLE_SHULKER_BOX"],
      "vars": { "titleKey": "gloss.preview.theme.title.shulker", "titleArg": "Purple", "accent": "#B152DA" }
    },
    {
      "blocks": ["BLUE_SHULKER_BOX"],
      "vars": { "titleKey": "gloss.preview.theme.title.shulker", "titleArg": "Blue", "accent": "#5E82FF" }
    },
    {
      "blocks": ["BROWN_SHULKER_BOX"],
      "vars": { "titleKey": "gloss.preview.theme.title.shulker", "titleArg": "Brown", "accent": "#F2A535" }
    },
    {
      "blocks": ["GREEN_SHULKER_BOX"],
      "vars": { "titleKey": "gloss.preview.theme.title.shulker", "titleArg": "Green", "accent": "#3FB84F" }
    },
    {
      "blocks": ["RED_SHULKER_BOX"],
      "vars": { "titleKey": "gloss.preview.theme.title.shulker", "titleArg": "Red", "accent": "#EC6464" }
    },
    {
      "blocks": ["BLACK_SHULKER_BOX"],
      "vars": { "titleKey": "gloss.preview.theme.title.shulker", "titleArg": "Black", "accent": "#202028" }
    },
    {
      "blocks": ["SHULKER_BOX"],
      "vars": { "titleKey": "gloss.preview.theme.title.shulker", "titleArg": "Purple", "accent": "#B152DA" }
    }
  ],
  "card": {
    "title": "'&f&l' + (customName != '' ? customName : (plain(lang(vars.titleKey, vars.titleArg == '' ? readable(blockType) : vars.titleArg)) != '' ? plain(lang(vars.titleKey, vars.titleArg == '' ? readable(blockType) : vars.titleArg)) : readable(blockType)))",
    "accent": "vars.accent"
  },
  "elements": [
    {
      "type": "slot",
      "repeat": {
        "count": "min(vars.cols * clamp(ceil(inventory.size / vars.cols), 1, vars.maxRows), inventory.size)",
        "var": "i"
      },
      "x": "round((mod(i, vars.cols) - (vars.cols - 1) / 2) * 20)",
      "y": "round(((clamp(ceil(inventory.size / vars.cols), 1, vars.maxRows) - 1) / 2 - floor(i / vars.cols)) * 20)",
      "size": 18,
      "index": "i"
    }
  ]
}
''',
  'chiseled_bookshelf': r'''
{
  "match": {
    "blocks": ["CHISELED_BOOKSHELF"],
    "priority": 10,
    "vars": {
      "cols": 3,
      "rows": 2,
      "titleKey": "gloss.preview.theme.title.chiseled_bookshelf",
      "accent": "#F2A535"
    }
  },
  "card": {
    "title": "'&f&l' + plain(lang(vars.titleKey))",
    "accent": "vars.accent"
  },
  "elements": [
    {
      "type": "slot",
      "repeat": { "count": "min(vars.cols * vars.rows, inventory.size)", "var": "i" },
      "x": "round((mod(i, vars.cols) - (vars.cols - 1) / 2) * 20)",
      "y": "round(((vars.rows - 1) / 2 - floor(i / vars.cols)) * 20)",
      "size": 18,
      "index": "i"
    }
  ]
}
''',
  'dispenser': r'''
{
  "match": {
    "blocks": ["DISPENSER", "DROPPER"],
    "priority": 10,
    "vars": {
      "cols": 3,
      "rows": 3,
      "titleKey": "gloss.preview.theme.title.dispenser",
      "accent": "#A6ACB6"
    }
  },
  "variants": [
    {
      "blocks": ["DROPPER"],
      "vars": {
        "titleKey": "gloss.preview.theme.title.dropper",
        "accent": "#6E747E"
      }
    }
  ],
  "card": {
    "title": "'&f&l' + (customName != '' ? customName : plain(lang(vars.titleKey)))",
    "accent": "vars.accent"
  },
  "elements": [
    {
      "type": "slot",
      "repeat": { "count": "min(vars.cols * vars.rows, inventory.size)", "var": "i" },
      "x": "round((mod(i, vars.cols) - (vars.cols - 1) / 2) * 20)",
      "y": "round(((vars.rows - 1) / 2 - floor(i / vars.cols)) * 20)",
      "size": 18,
      "index": "i"
    }
  ]
}
''',
  'ender_chest': r'''
{
  "match": {
    "blocks": ["ENDER_CHEST"],
    "special": "enderChest",
    "priority": 10,
    "vars": {
      "cols": 9,
      "maxRows": 6,
      "titleKey": "gloss.preview.theme.title.ender_chest",
      "accent": "#B152DA"
    }
  },
  "card": {
    "title": "'&f&l' + plain(lang(vars.titleKey))",
    "accent": "vars.accent"
  },
  "elements": [
    {
      "type": "slot",
      "repeat": {
        "count": "min(vars.cols * clamp(ceil(inventory.size / vars.cols), 1, vars.maxRows), inventory.size)",
        "var": "i"
      },
      "x": "round((mod(i, vars.cols) - (vars.cols - 1) / 2) * 20)",
      "y": "round(((clamp(ceil(inventory.size / vars.cols), 1, vars.maxRows) - 1) / 2 - floor(i / vars.cols)) * 20)",
      "size": 18,
      "index": "i"
    }
  ]
}
''',
  'furnace': r'''
{
  "match": {
    "blocks": ["FURNACE", "BLAST_FURNACE", "SMOKER"],
    "priority": 10,
    "vars": {
      "style": "furnace",
      "segments": 8,
      "wellColor": "#FF15151B",
      "fill": "#FFF2A535",
      "pulseBright": "#FFFFD978",
      "pulseDim": "#FF8A5E1E",
      "chase": "#FF9A5E22",
      "idle": "#FF2A2A33",
      "flame0": "#FFE2641E",
      "flame1": "#FFF2A535",
      "flame2": "#FFF7D14C",
      "smoke0": "#FF5E5E66",
      "smoke1": "#FF8A8A92",
      "smoke2": "#FFB8B8C0",
      "activeItemKey": "gloss.preview.state.smelting_item",
      "activeKey": "gloss.preview.state.smelting",
      "stateColor": "<#F2A535>",
      "surgeColor": "<#FFD978>",
      "titleKey": "gloss.preview.theme.title.furnace",
      "accent": "#F2A535"
    }
  },
  "variants": [
    {
      "blocks": ["BLAST_FURNACE"],
      "vars": {
        "style": "blast",
        "fill": "#FF6FB8E8",
        "pulseBright": "#FFE8F7FF",
        "pulseDim": "#FF2E5E80",
        "chase": "#FF4FA8D8",
        "idle": "#FF23262E",
        "flame0": "#FF4FA8E8",
        "flame1": "#FF8ED4FF",
        "flame2": "#FFE8F7FF",
        "activeItemKey": "gloss.preview.state.blasting_item",
        "activeKey": "gloss.preview.state.blasting",
        "stateColor": "<#6FB8E8>",
        "surgeColor": "<#E8F7FF>",
        "titleKey": "gloss.preview.theme.title.blast_furnace",
        "accent": "#6FEAEA"
      }
    },
    {
      "blocks": ["SMOKER"],
      "vars": {
        "style": "smoker",
        "fill": "#FFC8893A",
        "pulseBright": "#FFF2C878",
        "pulseDim": "#FF6E4A1E",
        "chase": "#FF8A6234",
        "idle": "#FF2A2A33",
        "flame0": "#FFE25822",
        "flame1": "#FFF2A535",
        "flame2": "#FFC23B22",
        "activeItemKey": "gloss.preview.state.smoking_item",
        "activeKey": "gloss.preview.state.smoking",
        "stateColor": "<#C8893A>",
        "surgeColor": "<#F2C878>",
        "titleKey": "gloss.preview.theme.title.smoker",
        "accent": "#F2D451"
      }
    }
  ],
  "card": {
    "title": "'&f&l' + (customName != '' ? customName : plain(lang(vars.titleKey)))",
    "accent": "vars.accent"
  },
  "elements": [
    { "type": "slot", "x": -40, "y": 10, "size": 18, "index": 0 },
    { "type": "slot", "x": -40, "y": -10, "size": 18, "index": 1 },
    { "type": "slot", "x": 40, "y": 10, "size": 18, "index": 2 },
    {
      "type": "cell",
      "repeat": { "count": "vars.segments", "var": "i" },
      "x": "-24 + i * 7",
      "y": 10,
      "size": 5,
      "color": "cookTime > 0 && cookTimeTotal > 0 ? (i < floor(cookTime / cookTimeTotal * vars.segments) ? (surge.active ? (mod(floor(cookTime / 2) + i, 2) == 0 ? vars.pulseBright : vars.fill) : vars.fill) : (i == floor(cookTime / cookTimeTotal * vars.segments) ? (mod(floor(cookTime / 4), 2) == 0 ? vars.pulseBright : vars.pulseDim) : vars.wellColor)) : (burnTime > 0 && i == mod(floor(burnTime / 4), vars.segments) ? vars.chase : vars.wellColor)"
    },
    {
      "type": "cell",
      "visible": "vars.style != 'blast'",
      "x": -20,
      "y": -10,
      "size": 12,
      "color": "burnTime > 0 ? palette([vars.flame0, vars.flame1, vars.flame2], floor(burnTime / (surge.active ? 2 : 4))) : vars.idle"
    },
    {
      "type": "cell",
      "visible": "vars.style == 'blast'",
      "repeat": { "count": 3, "var": "vent" },
      "x": "-20 + vent * 8",
      "y": -10,
      "size": 6,
      "color": "burnTime > 0 ? palette([vars.flame0, vars.flame1, vars.flame2], floor(burnTime / (surge.active ? 2 : 4)) + vent) : vars.idle"
    },
    {
      "type": "cell",
      "visible": "vars.style == 'smoker'",
      "repeat": { "count": 2, "var": "wisp" },
      "x": "wisp == 0 ? -8 : 2",
      "y": -10,
      "size": "wisp == 0 ? 8 : 6",
      "color": "burnTime > 0 ? palette([vars.smoke0, vars.smoke1, vars.smoke2], floor(burnTime / (surge.active ? 2 : 4)) + wisp + 1) : vars.idle"
    },
    {
      "type": "label",
      "x": 0,
      "y": -32,
      "text": "(cookTime > 0 && cookTimeTotal > 0 ? vars.stateColor + lang(occupied(0) ? vars.activeItemKey : vars.activeKey, occupied(0) ? readable(item(0)) : round(cookTime * 100 / cookTimeTotal), round(cookTime * 100 / cookTimeTotal)) : (burnTime > 0 && occupied(0) ? '&e' + lang('gloss.preview.state.heating') : (occupied(0) && !occupied(1) ? '&c' + lang('gloss.preview.state.needs_fuel') : (!occupied(0) ? '&7' + lang('gloss.preview.state.no_input') : '&7' + lang('gloss.preview.state.waiting'))))) + (surge.active ? vars.surgeColor + lang('gloss.preview.state.surge_suffix', surge.gain == floor(surge.gain) ? str(surge.gain) : fixed(surge.gain, 1)) : '')"
    },
    {
      "type": "label",
      "x": 0,
      "y": -46,
      "text": "(burnTime > 0 ? '&e' + lang('gloss.preview.stat.fuel_seconds', fuelSeconds) : (occupied(1) ? '&7' + lang('gloss.preview.stat.fuel_ready') : '&8' + lang('gloss.preview.stat.no_fuel'))) + (bankedXp >= 0 ? '<dark_gray>  •  </dark_gray>' + (bankedXp > 0 ? '<green>' + lang('gloss.preview.stat.xp_gain', bankedXp == floor(bankedXp) ? str(bankedXp) : fixed(bankedXp, 1)) + '</green>' : '<dark_gray>' + lang('gloss.preview.stat.xp_zero') + '</dark_gray>') : '')"
    }
  ]
}
''',
  'furnace_minecart': r'''
{
  "match": {
    "entities": ["FURNACE_MINECART"],
    "priority": 10,
    "vars": {
      "cells": 7,
      "wellColor": "#FF15151B",
      "flame0": "#FFE2641E",
      "flame1": "#FFF2A535",
      "flame2": "#FFF7D14C",
      "titleKey": "gloss.preview.theme.title.mobile",
      "accent": "#F2A535"
    }
  },
  "card": {
    "title": "'&f&l' + (customName != '' ? customName : plain(lang(vars.titleKey, readable(blockType))))",
    "accent": "vars.accent"
  },
  "elements": [
    {
      "type": "cell",
      "repeat": { "count": "vars.cells", "var": "i" },
      "x": "round((i - (vars.cells - 1) / 2) * 10)",
      "y": 0,
      "size": 8,
      "color": "powered ? (i == mod(floor(time / 2), vars.cells) ? palette([vars.flame0, vars.flame1, vars.flame2], floor(time / 2)) : vars.flame0) : vars.wellColor"
    },
    {
      "type": "label",
      "x": 0,
      "y": -19,
      "text": "powered ? '&e' + lang('gloss.preview.stat.fuel_seconds', fuelSeconds) : '&8' + lang('gloss.preview.stat.no_fuel')"
    }
  ]
}
''',
  'hopper': r'''
{
  "match": {
    "blocks": ["HOPPER"],
    "priority": 10,
    "vars": {
      "slots": 5,
      "titleKey": "gloss.preview.theme.title.hopper",
      "accent": "#6E747E"
    }
  },
  "card": {
    "title": "'&f&l' + (customName != '' ? customName : plain(lang(vars.titleKey)))",
    "accent": "vars.accent"
  },
  "elements": [
    {
      "type": "slot",
      "repeat": { "count": "min(vars.slots, inventory.size)", "var": "i" },
      "x": "round((i - (vars.slots - 1) / 2) * 20)",
      "y": 0,
      "size": 18,
      "index": "i"
    }
  ]
}
''',
  'jukebox': r'''
{
  "match": {
    "blocks": ["JUKEBOX"],
    "priority": 10,
    "vars": {
      "titleKey": "gloss.preview.theme.title.jukebox",
      "accent": "#EC88EC"
    }
  },
  "card": {
    "title": "'&f&l' + plain(lang(vars.titleKey))",
    "accent": "vars.accent"
  },
  "elements": [
    { "type": "slot", "x": 0, "y": 0, "size": 18, "index": 0 },
    {
      "type": "label",
      "x": 0,
      "y": -21,
      "text": "record != '' ? (playing ? '&a' + lang('gloss.preview.state.disc_playing', record) : '&7' + lang('gloss.preview.state.disc_loaded', record)) : '&8' + lang('gloss.preview.state.no_disc')"
    }
  ]
}
''',
  'locked': r'''
{
  "match": {
    "special": "locked",
    "priority": 10
  },
  "card": {
    "framed": false
  },
  "elements": [
    { "type": "cell", "x": 0, "y": 10, "z": 4, "size": 16, "color": "#FFFFB000" },
    { "type": "cell", "x": 0, "y": 10, "z": 6, "size": 8, "color": "#FF21170A" },
    { "type": "cell", "x": 0, "y": -4, "z": 7, "size": 24, "color": "#FFFFB000" },
    { "type": "cell", "x": 0, "y": -4, "z": 8, "size": 5, "color": "#FF21170A" }
  ]
}
''',
  'minecart': r'''
{
  "match": {
    "entities": ["CHEST_MINECART", "HOPPER_MINECART", "*_CHEST_BOAT", "*_CHEST_RAFT"],
    "special": "anyInventoryHolder",
    "priority": 10,
    "vars": {
      "cols": 9,
      "maxRows": 6,
      "slots": 5,
      "row": false,
      "titleKey": "gloss.preview.theme.title.mobile",
      "accent": "#A6ACB6"
    }
  },
  "variants": [
    {
      "entities": ["HOPPER_MINECART"],
      "vars": {
        "row": true,
        "titleKey": "gloss.preview.theme.title.hopper_minecart",
        "accent": "#6E747E"
      }
    },
    {
      "entities": ["CHEST_MINECART"],
      "vars": {
        "titleKey": "gloss.preview.theme.title.chest_minecart",
        "accent": "#F2A535"
      }
    }
  ],
  "card": {
    "title": "'&f&l' + (customName != '' ? customName : plain(lang(vars.titleKey, readable(blockType))))",
    "accent": "vars.accent"
  },
  "elements": [
    {
      "type": "slot",
      "visible": "vars.row",
      "repeat": { "count": "min(vars.slots, inventory.size)", "var": "i" },
      "x": "round((i - (min(vars.slots, inventory.size) - 1) / 2) * 20)",
      "y": 0,
      "size": 18,
      "index": "i"
    },
    {
      "type": "slot",
      "visible": "!vars.row",
      "repeat": {
        "count": "min(vars.cols * clamp(ceil(inventory.size / vars.cols), 1, vars.maxRows), inventory.size)",
        "var": "i"
      },
      "x": "round((mod(i, vars.cols) - (vars.cols - 1) / 2) * 20)",
      "y": "round(((clamp(ceil(inventory.size / vars.cols), 1, vars.maxRows) - 1) / 2 - floor(i / vars.cols)) * 20)",
      "size": 18,
      "index": "i"
    }
  ]
}
''',
  'shelf': r'''
{
  "match": {
    "blocks": ["*_SHELF"],
    "priority": 10,
    "vars": {
      "titleKey": "gloss.preview.theme.title.shelf",
      "accent": "#F2A535"
    }
  },
  "card": {
    "title": "'&f&l' + plain(lang(vars.titleKey, readable(blockType)))",
    "accent": "vars.accent"
  },
  "elements": [
    {
      "type": "slot",
      "repeat": { "count": "inventory.size", "var": "i" },
      "x": "round((i - (inventory.size - 1) / 2) * 20)",
      "y": 0,
      "size": 18,
      "index": "i"
    }
  ]
}
''',
};
