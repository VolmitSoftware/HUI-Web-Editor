/// The eight non-menu Gloss formats as JSON-path models, and the registry the
/// code editor looks a kind up in.
///
/// None of these kinds has a shipped JSON schema — `schema/gloss.schema.json`
/// in the plugin covers the menu format alone — so every entry here is read out
/// of three places in this repo, in this order:
///   1. `model/gloss_*.dart`: the `toJson` body names the keys and their types,
///      and the `_*Known` sets name the keys the decoder consumes.
///   2. `logic/*_validation.dart`: the accepted values and numeric ranges,
///      which is where the summaries' "Gloss clamps to a..b" lines come from.
///   3. `config/field_docs.dart`: the prose, reached through
///      [GlossJsonField.docKey] rather than copied, so one wording serves the
///      inspector and the editor both.
///
/// Kinds are keyed by the workspace kind enum's `name` string rather than by
/// the enum values, because `doctype_guard_test.dart` reserves those names for
/// the doctype layer. The string is the same one the workspace stores.
library;

import '../logic/json_schema.dart';
import '../model/gloss_animation.dart';
import '../model/gloss_bubble_style.dart';
import '../model/gloss_damage_indicators.dart';
import '../model/gloss_motd.dart';
import '../model/gloss_real_drop_animation.dart';
import '../model/gloss_real_drops.dart';
import '../model/gloss_scoreboard.dart';
import '../model/gloss_tablist.dart';
import 'gloss_menu_json_schema.dart';

/// `schemaVersion` — the generation check every Gloss document opens with.
/// A mismatch is rejected before anything else is read.
GlossJsonField _schemaVersionField(int version) => GlossJsonField(
  key: 'schemaVersion',
  type: GlossJsonType.integer,
  title: 'Schema version',
  summary: 'Format generation. Gloss rejects the file when it is not $version.',
  values: <GlossJsonValue>[GlossJsonValue('$version')],
  defaultLiteral: '$version',
);

/// `revision` — server-owned and monotonic; the editor round-trips it.
const GlossJsonField _revisionField = GlossJsonField(
  key: 'revision',
  type: GlossJsonType.integer,
  title: 'Revision',
  summary: 'Server-owned counter, 1 through 9007199254740991. Leave it alone.',
  docKey: 'document.revision',
  defaultLiteral: '1',
);

List<GlossJsonValue> _values(List<String> tokens) => <GlossJsonValue>[
  for (final String token in tokens) GlossJsonValue('"$token"'),
];

const GlossJsonArray _textLinesNode = GlossJsonArray(
  itemType: GlossJsonType.string,
  itemTitle: 'Line',
  itemSummary: 'One line of text, through the Gloss text pipeline.',
);

const GlossJsonArray _plainStringsNode = GlossJsonArray(
  itemType: GlossJsonType.string,
  itemTitle: 'Entry',
  itemSummary: 'One name.',
);

// --- hologram ---------------------------------------------------------------

const GlossJsonObject _hologramAnchorNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'world',
      type: GlossJsonType.string,
      title: 'World',
      summary: 'World name the hologram is anchored in.',
      docKey: 'hologram.anchor.world',
      defaultLiteral: '""',
    ),
    GlossJsonField(
      key: 'position',
      type: GlossJsonType.array,
      title: 'Position',
      summary: 'Anchor position as [x, y, z]. Exactly three numbers.',
      docKey: 'hologram.anchor.position',
      node: glossVector3Node,
    ),
  ],
);

final GlossJsonObject glossHologramJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _schemaVersionField(1),
    _revisionField,
    const GlossJsonField(
      key: 'anchor',
      type: GlossJsonType.object,
      title: 'Anchor',
      summary: 'Where the hologram stands. Missing anchor rejects the file.',
      node: _hologramAnchorNode,
    ),
    const GlossJsonField(
      key: 'lines',
      type: GlossJsonType.array,
      title: 'Lines',
      summary: 'Hologram text, joined with newlines into one text display.',
      docKey: 'hologram.lines',
      node: _textLinesNode,
    ),
    const GlossJsonField(
      key: 'seeThrough',
      type: GlossJsonType.boolean,
      title: 'See through',
      summary: 'Renders through blocks instead of being occluded by them.',
      docKey: 'hologram.seeThrough',
      defaultLiteral: 'true',
    ),
  ],
);

// --- animation --------------------------------------------------------------

final GlossJsonObject glossAnimationJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _schemaVersionField(1),
    _revisionField,
    GlossJsonField(
      key: 'mode',
      type: GlossJsonType.string,
      title: 'Mode',
      summary: 'Frame order. An unknown mode rejects the whole file.',
      docKey: 'animation.mode',
      values: _values(glossAnimationModes),
      defaultLiteral: '"ascend"',
    ),
    const GlossJsonField(
      key: 'frameIntervalMs',
      type: GlossJsonType.integer,
      title: 'Frame interval',
      summary:
          'Milliseconds per frame. Silently clamped to '
          '$glossMinFrameIntervalMs..$glossMaxFrameIntervalMs.',
      docKey: 'animation.frameIntervalMs',
      defaultLiteral: '500',
    ),
    const GlossJsonField(
      key: 'frames',
      type: GlossJsonType.array,
      title: 'Frames',
      summary: 'The frame texts, in order. Must not be empty.',
      docKey: 'animation.frames',
      node: _textLinesNode,
    ),
  ],
);

// --- scoreboard -------------------------------------------------------------

const GlossJsonObject _conditionSelectNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'priority',
      type: GlossJsonType.integer,
      title: 'Priority',
      summary: 'Highest matching priority wins; ids break ties.',
      defaultLiteral: '0',
    ),
    GlossJsonField(
      key: 'when',
      type: GlossJsonType.string,
      title: 'Condition',
      summary: 'Typed boolean expression evaluated against the viewer context.',
      docKey: 'condition.when',
      defaultLiteral: '"true"',
    ),
  ],
);

const GlossJsonObject _scoreboardPresentationNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'title',
      type: GlossJsonType.string,
      title: 'Title',
      summary:
          'Sidebar header. Empty falls back to the board id; '
          '$glossBoardMaxTitleLength rendered characters is the cap.',
      docKey: 'scoreboard.presentation.title',
      defaultLiteral: '""',
    ),
    GlossJsonField(
      key: 'lines',
      type: GlossJsonType.array,
      title: 'Lines',
      summary:
          'Sidebar rows, top first. Past $glossBoardMaxLines never reaches '
          'the client.',
      docKey: 'scoreboard.presentation.lines',
      node: _textLinesNode,
    ),
    GlossJsonField(
      key: 'hideNumbers',
      type: GlossJsonType.boolean,
      title: 'Hide numbers',
      summary: 'Uses the blank score format on 1.20.3 and newer clients.',
      docKey: 'scoreboard.presentation.hideNumbers',
      defaultLiteral: 'false',
    ),
  ],
);

const GlossJsonObject _scoreboardVariantNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'id',
      type: GlossJsonType.string,
      title: 'Variant id',
      summary: 'Stable unique id; the smaller id wins a priority tie.',
    ),
    GlossJsonField(
      key: 'priority',
      type: GlossJsonType.integer,
      title: 'Priority',
      summary: 'Highest matching variant priority wins.',
      defaultLiteral: '0',
    ),
    GlossJsonField(
      key: 'when',
      type: GlossJsonType.string,
      title: 'Condition',
      summary: 'Typed boolean expression evaluated for this viewer.',
      docKey: 'condition.when',
      defaultLiteral: '"false"',
    ),
    GlossJsonField(
      key: 'presentation',
      type: GlossJsonType.object,
      title: 'Presentation',
      summary: 'Complete sidebar layout used when this variant wins.',
      node: _scoreboardPresentationNode,
    ),
  ],
);

final GlossJsonObject glossScoreboardJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _schemaVersionField(glossScoreboardCurrentSchemaVersion),
    _revisionField,
    const GlossJsonField(
      key: 'select',
      type: GlossJsonType.object,
      title: 'Selection',
      summary: 'Board-level priority and eligibility condition.',
      node: _conditionSelectNode,
    ),
    const GlossJsonField(
      key: 'presentation',
      type: GlossJsonType.object,
      title: 'Default presentation',
      summary: 'Complete fallback sidebar layout.',
      node: _scoreboardPresentationNode,
    ),
    const GlossJsonField(
      key: 'variants',
      type: GlossJsonType.array,
      title: 'Conditional variants',
      summary:
          'Complete alternative layouts selected by condition and priority.',
      node: GlossJsonArray(
        item: _scoreboardVariantNode,
        itemTitle: 'Variant',
        itemSummary: 'One condition and complete sidebar presentation.',
      ),
    ),
  ],
);

// --- MOTD -------------------------------------------------------------------

const GlossJsonObject _motdEntryNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'lines',
      type: GlossJsonType.array,
      title: 'Lines',
      summary:
          '1 to $glossMotdMaxLinesPerEntry lines shown together in the '
          'server list.',
      docKey: 'motd.lines',
      node: _textLinesNode,
    ),
  ],
);

final GlossJsonObject glossMotdJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _schemaVersionField(1),
    _revisionField,
    const GlossJsonField(
      key: 'entries',
      type: GlossJsonType.array,
      title: 'Entries',
      summary: 'The random-pick pool. One entry per ping. Must not be empty.',
      docKey: 'motd.entries',
      node: GlossJsonArray(
        item: _motdEntryNode,
        itemType: GlossJsonType.object,
        itemTitle: 'Entry',
        itemSummary: 'One MOTD candidate.',
      ),
    ),
  ],
);

// --- emoji ------------------------------------------------------------------

final GlossJsonObject glossEmojiJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _schemaVersionField(1),
    _revisionField,
    const GlossJsonField(
      key: 'trigger',
      type: GlossJsonType.string,
      title: 'Trigger',
      summary: 'Optional second spelling replaced in chat, e.g. <3.',
      docKey: 'emoji.trigger',
      defaultLiteral: '""',
    ),
    const GlossJsonField(
      key: 'emoji',
      type: GlossJsonType.string,
      title: 'Emoji',
      summary: 'A literal glyph or U+XXXX; escapes. Blank rejects the file.',
      docKey: 'emoji.emoji',
      defaultLiteral: '""',
    ),
    const GlossJsonField(
      key: 'enabled',
      type: GlossJsonType.boolean,
      title: 'Enabled',
      summary: 'A disabled emoji stays listed but is never substituted.',
      docKey: 'emoji.enabled',
      defaultLiteral: 'true',
    ),
  ],
);

// --- bubble style -----------------------------------------------------------

const GlossJsonObject _bubbleMotionVectorNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'x',
      type: GlossJsonType.string,
      title: 'X expression',
      summary: 'Expression over t, ageMs and lifetimeMs. Strings only.',
      defaultLiteral: '"0"',
    ),
    GlossJsonField(
      key: 'y',
      type: GlossJsonType.string,
      title: 'Y expression',
      summary: 'Expression over t, ageMs and lifetimeMs. Strings only.',
      defaultLiteral: '"0"',
    ),
    GlossJsonField(
      key: 'z',
      type: GlossJsonType.string,
      title: 'Z expression',
      summary: 'Expression over t, ageMs and lifetimeMs. Strings only.',
      defaultLiteral: '"0"',
    ),
  ],
);

const GlossJsonObject _bubbleMotionNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'translation',
      type: GlossJsonType.object,
      title: 'Translation',
      summary: 'Per-axis offset expressions, in blocks.',
      node: _bubbleMotionVectorNode,
    ),
    GlossJsonField(
      key: 'scale',
      type: GlossJsonType.object,
      title: 'Scale',
      summary: 'Per-axis scale expressions.',
      node: _bubbleMotionVectorNode,
    ),
    GlossJsonField(
      key: 'rotation',
      type: GlossJsonType.object,
      title: 'Rotation',
      summary: 'Per-axis rotation expressions, in degrees.',
      node: _bubbleMotionVectorNode,
    ),
    GlossJsonField(
      key: 'opacity',
      type: GlossJsonType.string,
      title: 'Opacity',
      summary: 'Expression for the bubble alpha, 0 through 1.',
      defaultLiteral: '"1"',
    ),
  ],
);

const GlossJsonObject _bubbleShimmerNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'spawn',
      type: GlossJsonType.boolean,
      title: 'Spawn sweep',
      summary: 'One bounded sweep after spawnDelayMs.',
      defaultLiteral: 'true',
    ),
    GlossJsonField(
      key: 'flyAway',
      type: GlossJsonType.boolean,
      title: 'Fly-away sweep',
      summary: 'A second sweep, flyAwayLeadMs before the bubble expires.',
      docKey: 'bubble.shimmer.flyAway',
      defaultLiteral: 'true',
    ),
    GlossJsonField(
      key: 'color',
      type: GlossJsonType.string,
      title: 'Colour',
      summary: 'Colour of every lit glyph in the band, as #RRGGBB.',
      docKey: 'bubble.shimmer.color',
      defaultLiteral: '"$glossBubbleShimmerDefaultColor"',
    ),
    GlossJsonField(
      key: 'width',
      type: GlossJsonType.integer,
      title: 'Width',
      summary:
          'Lit glyphs in the band. Clamped to '
          '$glossBubbleMinShimmerWidth..$glossBubbleMaxShimmerWidth.',
      defaultLiteral: '3',
    ),
    GlossJsonField(
      key: 'durationMs',
      type: GlossJsonType.integer,
      title: 'Duration',
      summary:
          'Milliseconds one pass takes. Clamped to '
          '$glossBubbleMinShimmerDurationMs..$glossBubbleMaxShimmerDurationMs.',
      docKey: 'bubble.shimmer.durationMs',
      defaultLiteral: '$glossBubbleShimmerDefaultDurationMs',
    ),
    GlossJsonField(
      key: 'spawnDelayMs',
      type: GlossJsonType.integer,
      title: 'Spawn delay',
      summary:
          'Milliseconds before the spawn sweep. Clamped to '
          '0..$glossBubbleMaxShimmerOffsetMs.',
      defaultLiteral: '$glossBubbleShimmerDefaultSpawnDelayMs',
    ),
    GlossJsonField(
      key: 'flyAwayLeadMs',
      type: GlossJsonType.integer,
      title: 'Fly-away lead',
      summary:
          'Milliseconds before expiry the second sweep starts. Clamped to '
          '0..$glossBubbleMaxShimmerOffsetMs.',
      defaultLiteral: '$glossBubbleShimmerDefaultFlyAwayLeadMs',
    ),
  ],
);

const GlossJsonObject _bubbleSelectNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'priority',
      type: GlossJsonType.integer,
      title: 'Priority',
      summary: 'Highest match wins; ties break to the smaller style id.',
      docKey: 'bubble.select.priority',
      defaultLiteral: '0',
    ),
    GlossJsonField(
      key: 'when',
      type: GlossJsonType.string,
      title: 'Condition',
      summary: 'Typed per-player condition. Errors fail closed.',
      docKey: 'condition.when',
      defaultLiteral: '"false"',
    ),
  ],
);

final GlossJsonObject glossBubbleStyleJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _schemaVersionField(glossBubbleCurrentSchemaVersion),
    _revisionField,
    const GlossJsonField(
      key: 'prefix',
      type: GlossJsonType.string,
      title: 'Prefix',
      summary:
          'Prepended to every bubble line. Only a MISSING key falls back to '
          '$glossBubbleDefaultPrefix; an explicit "" stays empty.',
      docKey: 'bubble.prefix',
      defaultLiteral: '"$glossBubbleDefaultPrefix"',
    ),
    const GlossJsonField(
      key: 'offset',
      type: GlossJsonType.array,
      title: 'Offset',
      summary: 'Bubble position above the player, as [x, y, z].',
      docKey: 'bubble.offset',
      node: glossVector3Node,
    ),
    const GlossJsonField(
      key: 'wordWrapChars',
      type: GlossJsonType.integer,
      title: 'Word wrap',
      summary:
          'Characters per line. Clamped to '
          '$glossBubbleMinWordWrapChars..$glossBubbleMaxWordWrapChars.',
      docKey: 'bubble.wordWrapChars',
      defaultLiteral: '32',
    ),
    const GlossJsonField(
      key: 'maxAliveMs',
      type: GlossJsonType.integer,
      title: 'Lifetime',
      summary:
          'Milliseconds a bubble lives. Clamped to '
          '$glossBubbleMinMaxAliveMs..$glossBubbleMaxMaxAliveMs.',
      docKey: 'bubble.maxAliveMs',
      defaultLiteral: '5000',
    ),
    const GlossJsonField(
      key: 'motion',
      type: GlossJsonType.object,
      title: 'Motion',
      summary: 'Expression-driven translation, scale, rotation and opacity.',
      node: _bubbleMotionNode,
    ),
    const GlossJsonField(
      key: 'shimmer',
      type: GlossJsonType.object,
      title: 'Shimmer',
      summary: 'The shine band that sweeps across the bubble.',
      node: _bubbleShimmerNode,
    ),
    const GlossJsonField(
      key: 'followPlayer',
      type: GlossJsonType.boolean,
      title: 'Follow player',
      summary: 'Keeps the bubble over the speaker as they move.',
      docKey: 'bubble.followPlayer',
      defaultLiteral: 'false',
    ),
    const GlossJsonField(
      key: 'hideOwn',
      type: GlossJsonType.boolean,
      title: 'Hide own',
      summary: 'Hides a player their own bubble.',
      docKey: 'bubble.hideOwn',
      defaultLiteral: 'false',
    ),
    const GlossJsonField(
      key: 'select',
      type: GlossJsonType.object,
      title: 'Select',
      summary: 'Auto-match rule. Without it the style never auto-matches.',
      node: _bubbleSelectNode,
    ),
  ],
);

// --- tablist ----------------------------------------------------------------

const GlossJsonObject _tablistHeaderFooterPresentationNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'header',
      type: GlossJsonType.string,
      title: 'Header',
      summary: 'Rendered above the player grid per viewer.',
      docKey: 'tablist.headerFooter.presentation.header',
      defaultLiteral: '""',
    ),
    GlossJsonField(
      key: 'footer',
      type: GlossJsonType.string,
      title: 'Footer',
      summary: 'Rendered below the player grid per viewer.',
      docKey: 'tablist.headerFooter.presentation.footer',
      defaultLiteral: '""',
    ),
  ],
);

const GlossJsonObject _tablistListNamePresentationNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'format',
      type: GlossJsonType.string,
      title: 'Format',
      summary: r'List name with $player and $group tokens.',
      docKey: 'tablist.listNames.presentation.format',
      defaultLiteral: '"$glossTablistFallbackFormat"',
    ),
  ],
);

const GlossJsonObject _tablistHeaderFooterVariantNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'id',
      type: GlossJsonType.string,
      title: 'Variant id',
      summary: 'Stable unique id; smaller ids win priority ties.',
    ),
    GlossJsonField(
      key: 'priority',
      type: GlossJsonType.integer,
      title: 'Priority',
      summary: 'Highest matching priority wins.',
      defaultLiteral: '0',
    ),
    GlossJsonField(
      key: 'when',
      type: GlossJsonType.string,
      title: 'Condition',
      summary: 'Typed boolean viewer condition.',
      docKey: 'condition.when',
      defaultLiteral: '"false"',
    ),
    GlossJsonField(
      key: 'presentation',
      type: GlossJsonType.object,
      title: 'Presentation',
      summary: 'Complete header/footer pair.',
      node: _tablistHeaderFooterPresentationNode,
    ),
  ],
);

const GlossJsonObject _tablistListNameVariantNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'id',
      type: GlossJsonType.string,
      title: 'Variant id',
      summary: 'Stable unique id; smaller ids win priority ties.',
    ),
    GlossJsonField(
      key: 'priority',
      type: GlossJsonType.integer,
      title: 'Priority',
      summary: 'Highest matching priority wins.',
      defaultLiteral: '0',
    ),
    GlossJsonField(
      key: 'when',
      type: GlossJsonType.string,
      title: 'Condition',
      summary: 'Typed viewer/subject condition.',
      docKey: 'condition.when',
      defaultLiteral: '"false"',
    ),
    GlossJsonField(
      key: 'presentation',
      type: GlossJsonType.object,
      title: 'Presentation',
      summary: 'Complete list-name format.',
      node: _tablistListNamePresentationNode,
    ),
  ],
);

const GlossJsonObject _tablistHeaderFooterNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'enabled',
      type: GlossJsonType.boolean,
      title: 'Enabled',
      summary: 'Off leaves the vanilla top and bottom untouched.',
      docKey: 'tablist.headerFooter.enabled',
      defaultLiteral: 'false',
    ),
    GlossJsonField(
      key: 'presentation',
      type: GlossJsonType.object,
      title: 'Default presentation',
      summary: 'Fallback header and footer.',
      node: _tablistHeaderFooterPresentationNode,
    ),
    GlossJsonField(
      key: 'variants',
      type: GlossJsonType.array,
      title: 'Variants',
      summary: 'Conditional complete header/footer alternatives.',
      node: GlossJsonArray(item: _tablistHeaderFooterVariantNode),
    ),
  ],
);

const GlossJsonObject _tablistListNamesNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'enabled',
      type: GlossJsonType.boolean,
      title: 'Enabled',
      summary: 'Off resets all list names to vanilla.',
      docKey: 'tablist.listNames.enabled',
      defaultLiteral: 'false',
    ),
    GlossJsonField(
      key: 'presentation',
      type: GlossJsonType.object,
      title: 'Default presentation',
      summary: 'Fallback list-name format.',
      node: _tablistListNamePresentationNode,
    ),
    GlossJsonField(
      key: 'variants',
      type: GlossJsonType.array,
      title: 'Variants',
      summary: 'Conditional complete list-name alternatives.',
      node: GlossJsonArray(item: _tablistListNameVariantNode),
    ),
  ],
);

final GlossJsonObject glossTablistJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _schemaVersionField(glossTablistCurrentSchemaVersion),
    _revisionField,
    const GlossJsonField(
      key: 'headerFooter',
      type: GlossJsonType.object,
      title: 'Header and footer',
      summary: 'Conditional header/footer configuration.',
      node: _tablistHeaderFooterNode,
    ),
    const GlossJsonField(
      key: 'listNames',
      type: GlossJsonType.object,
      title: 'List names',
      summary: 'Conditional listed-player name configuration.',
      node: _tablistListNamesNode,
    ),
  ],
);

// --- real drops -------------------------------------------------------------

const GlossJsonObject _realDropLimitsNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'updateIntervalTicks',
      type: GlossJsonType.integer,
      title: 'Update interval',
      summary: 'Ticks between pose updates. Clamped to 1..20.',
      defaultLiteral: '2',
    ),
    GlossJsonField(
      key: 'settledPollIntervalTicks',
      type: GlossJsonType.integer,
      title: 'Settled poll interval',
      summary: 'Ticks between checks on a settled stack. Clamped to 2..200.',
      defaultLiteral: '20',
    ),
    GlossJsonField(
      key: 'maxVisualsPerStack',
      type: GlossJsonType.integer,
      title: 'Displays per stack',
      summary: 'Item displays one stack may spawn. Clamped to 1..5.',
      defaultLiteral: '3',
    ),
    GlossJsonField(
      key: 'maxVisualsPerChunk',
      type: GlossJsonType.integer,
      title: 'Displays per chunk',
      summary: 'Budget for one chunk. Clamped to 8..1024.',
      defaultLiteral: '128',
    ),
    GlossJsonField(
      key: 'viewRange',
      type: GlossJsonType.number,
      title: 'View range',
      summary: 'Blocks a drop stays visible for. Clamped to 4..128.',
      defaultLiteral: '32',
    ),
    GlossJsonField(
      key: 'spread',
      type: GlossJsonType.number,
      title: 'Spread',
      summary: 'How far the displays of one stack fan out. Clamped to 0..1.',
      defaultLiteral: '0.18',
    ),
  ],
);

const GlossJsonObject _realDropScaleNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'defaultScale',
      type: GlossJsonType.number,
      title: 'Default scale',
      summary: 'Scale for materials in no other family. Clamped to 0.05..2.',
      defaultLiteral: '0.4',
    ),
    GlossJsonField(
      key: 'flatItems',
      type: GlossJsonType.number,
      title: 'Flat items',
      summary: 'Scale for sprite-flat items. Clamped to 0.05..2.',
      defaultLiteral: '0.65',
    ),
    GlossJsonField(
      key: 'thinBlocks',
      type: GlossJsonType.number,
      title: 'Thin blocks',
      summary: 'Scale for slabs, carpets and panes. Clamped to 0.05..2.',
      defaultLiteral: '0.45',
    ),
  ],
);

const GlossJsonObject _realDropMotionNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'tumble',
      type: GlossJsonType.boolean,
      title: 'Tumble',
      summary: 'Off leaves drops in their landing pose without spinning.',
      defaultLiteral: 'true',
    ),
    GlossJsonField(
      key: 'speedMultiplier',
      type: GlossJsonType.number,
      title: 'Speed multiplier',
      summary: 'Scales every tumble rate. Clamped to 0.1..4.',
      defaultLiteral: '1.35',
    ),
    GlossJsonField(
      key: 'degreesPerSecondX',
      type: GlossJsonType.number,
      title: 'Tumble rate X',
      summary: 'Degrees per second on x. Clamped to -1440..1440.',
      defaultLiteral: '160',
    ),
    GlossJsonField(
      key: 'degreesPerSecondY',
      type: GlossJsonType.number,
      title: 'Tumble rate Y',
      summary: 'Degrees per second on y. Clamped to -1440..1440.',
      defaultLiteral: '120',
    ),
    GlossJsonField(
      key: 'degreesPerSecondZ',
      type: GlossJsonType.number,
      title: 'Tumble rate Z',
      summary: 'Degrees per second on z. Clamped to -1440..1440.',
      defaultLiteral: '100',
    ),
    GlossJsonField(
      key: 'variance',
      type: GlossJsonType.number,
      title: 'Variance',
      summary: 'Per-stack randomisation of the rates. Clamped to 0..1.',
      defaultLiteral: '0.2',
    ),
    GlossJsonField(
      key: 'changeOnBounce',
      type: GlossJsonType.boolean,
      title: 'Change on bounce',
      summary: 'Re-rolls the tumble rates every time a stack bounces.',
      defaultLiteral: 'true',
    ),
    GlossJsonField(
      key: 'velocityInfluence',
      type: GlossJsonType.number,
      title: 'Throw momentum',
      summary: 'How strongly real speed increases tumble. Clamped to 0..4.',
      defaultLiteral: '0.35',
    ),
    GlossJsonField(
      key: 'submergedSpinMultiplier',
      type: GlossJsonType.number,
      title: 'Submerged spin',
      summary: 'Angular-speed multiplier in fluid. Clamped to 0..1.',
      defaultLiteral: '0.35',
    ),
    GlossJsonField(
      key: 'groundRollMultiplier',
      type: GlossJsonType.number,
      title: 'Ground roll',
      summary: 'Rotation produced by supported travel. Clamped to 0..4.',
      defaultLiteral: '1',
    ),
  ],
);

const GlossJsonObject _realDropLandingNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'mode',
      type: GlossJsonType.string,
      title: 'Landing mode',
      summary:
          'The pose a settled stack takes. Unknown values fall to NATURAL.',
      values: <GlossJsonValue>[
        GlossJsonValue('"NATURAL"', summary: 'Tilted, as an item would fall.'),
        GlossJsonValue('"FLAT"', summary: 'Lying flat on the ground.'),
        GlossJsonValue('"UPRIGHT"', summary: 'Standing on end.'),
      ],
      defaultLiteral: '"NATURAL"',
    ),
    GlossJsonField(
      key: 'tiltDegrees',
      type: GlossJsonType.number,
      title: 'Tilt',
      summary: 'Degrees off flat in NATURAL. Clamped to 0..45.',
      defaultLiteral: '10',
    ),
    GlossJsonField(
      key: 'randomYaw',
      type: GlossJsonType.boolean,
      title: 'Random yaw',
      summary: 'Gives every settled stack its own facing.',
      defaultLiteral: 'true',
    ),
    GlossJsonField(
      key: 'transitionTicks',
      type: GlossJsonType.integer,
      title: 'Transition ticks',
      summary: 'Client interpolation window into the settled pose. 0..20.',
      defaultLiteral: '4',
    ),
    GlossJsonField(
      key: 'faceAttraction',
      type: GlossJsonType.number,
      title: 'Resting face pull',
      summary: 'Near-rest face attraction per sample. Clamped to 0..1.',
      defaultLiteral: '0.55',
    ),
    GlossJsonField(
      key: 'movingFaceAttraction',
      type: GlossJsonType.number,
      title: 'Moving face pull',
      summary: 'Face attraction retained while moving. Clamped to 0..1.',
      defaultLiteral: '0.15',
    ),
    GlossJsonField(
      key: 'alignmentDegrees',
      type: GlossJsonType.number,
      title: 'Alignment tolerance',
      summary: 'Subvisual final face snap. Clamped to 0.05..10 degrees.',
      defaultLiteral: '0.5',
    ),
    GlossJsonField(
      key: 'settleDelayTicks',
      type: GlossJsonType.integer,
      title: 'Stable delay',
      summary: 'Stable ticks before sparse polling. Clamped to 0..100.',
      defaultLiteral: '4',
    ),
  ],
);

const GlossJsonObject _realDropLabelsNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'enabled',
      type: GlossJsonType.boolean,
      title: 'Enabled',
      summary: 'Draws the &7{count}x {type} label over each stack.',
      defaultLiteral: 'true',
    ),
    GlossJsonField(
      key: 'yOffset',
      type: GlossJsonType.number,
      title: 'Y offset',
      summary: 'Blocks above the stack the label floats. Clamped to 0..4.',
      defaultLiteral: '0.55',
    ),
    GlossJsonField(
      key: 'scale',
      type: GlossJsonType.number,
      title: 'Scale',
      summary: 'Label text scale. Clamped to 0.1..4.',
      defaultLiteral: '0.85',
    ),
    GlossJsonField(
      key: 'viewRange',
      type: GlossJsonType.number,
      title: 'View range',
      summary: 'Blocks the label stays visible for. Clamped to 4..128.',
      defaultLiteral: '32',
    ),
    GlossJsonField(
      key: 'billboard',
      type: GlossJsonType.string,
      title: 'Billboard',
      summary: 'Which axes the label rotates on. Unknown falls to CENTER.',
      values: <GlossJsonValue>[
        GlossJsonValue('"CENTER"'),
        GlossJsonValue('"FIXED"'),
        GlossJsonValue('"HORIZONTAL"'),
        GlossJsonValue('"VERTICAL"'),
      ],
      defaultLiteral: '"CENTER"',
    ),
    GlossJsonField(
      key: 'seeThrough',
      type: GlossJsonType.boolean,
      title: 'See through',
      summary: 'Draws the label through blocks.',
      defaultLiteral: 'true',
    ),
    GlossJsonField(
      key: 'shadow',
      type: GlossJsonType.boolean,
      title: 'Shadow',
      summary: 'Vanilla text drop shadow on the label.',
      defaultLiteral: 'true',
    ),
    GlossJsonField(
      key: 'background',
      type: GlossJsonType.boolean,
      title: 'Background',
      summary: 'Draws the panel behind the label text.',
      defaultLiteral: 'true',
    ),
    GlossJsonField(
      key: 'backgroundRed',
      type: GlossJsonType.integer,
      title: 'Background red',
      summary: 'Red channel, 0 through 255.',
      defaultLiteral: '0',
    ),
    GlossJsonField(
      key: 'backgroundGreen',
      type: GlossJsonType.integer,
      title: 'Background green',
      summary: 'Green channel, 0 through 255.',
      defaultLiteral: '0',
    ),
    GlossJsonField(
      key: 'backgroundBlue',
      type: GlossJsonType.integer,
      title: 'Background blue',
      summary: 'Blue channel, 0 through 255.',
      defaultLiteral: '0',
    ),
    GlossJsonField(
      key: 'backgroundAlpha',
      type: GlossJsonType.integer,
      title: 'Background alpha',
      summary: 'Panel opacity, 0 through 255.',
      defaultLiteral: '80',
    ),
  ],
);

const GlossJsonObject _realDropFiltersNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'disabledWorlds',
      type: GlossJsonType.array,
      title: 'Disabled worlds',
      summary: 'Worlds that keep the vanilla dropped-item entity.',
      node: _plainStringsNode,
    ),
    GlossJsonField(
      key: 'materialBlacklist',
      type: GlossJsonType.array,
      title: 'Material blacklist',
      summary: 'Materials that never get a real drop, in Bukkit spelling.',
      node: _plainStringsNode,
    ),
    GlossJsonField(
      key: 'onlyPlayerDrops',
      type: GlossJsonType.boolean,
      title: 'Only player drops',
      summary: 'Restricts real drops to stacks a player dropped.',
      defaultLiteral: 'false',
    ),
  ],
);

const GlossJsonObject _realDropPhysicsNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'enabled',
      type: GlossJsonType.boolean,
      title: 'Enabled',
      summary: 'Allows Gloss to modify the authoritative item entity.',
      defaultLiteral: 'false',
    ),
    GlossJsonField(
      key: 'gravityMultiplier',
      type: GlossJsonType.number,
      title: 'Gravity multiplier',
      summary: 'Real gravity scale. Zero holds vertical motion. 0..4.',
      defaultLiteral: '1',
    ),
    GlossJsonField(
      key: 'bounce',
      type: GlossJsonType.number,
      title: 'Bounce',
      summary: 'Landing restitution. Clamped to 0..0.9.',
      defaultLiteral: '0',
    ),
    GlossJsonField(
      key: 'waterBuoyancy',
      type: GlossJsonType.number,
      title: 'Water buoyancy',
      summary: 'Additional upward velocity in water. Clamped to 0..1.',
      defaultLiteral: '0',
    ),
    GlossJsonField(
      key: 'waterDrag',
      type: GlossJsonType.number,
      title: 'Water drag',
      summary: 'Velocity removed per tick in water. Clamped to 0..1.',
      defaultLiteral: '0',
    ),
  ],
);

const GlossJsonObject _realDropScriptAxisNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'x',
      type: GlossJsonType.string,
      title: 'X expression',
      summary: 'Expression for the x axis.',
    ),
    GlossJsonField(
      key: 'y',
      type: GlossJsonType.string,
      title: 'Y expression',
      summary: 'Expression for the y axis.',
    ),
    GlossJsonField(
      key: 'z',
      type: GlossJsonType.string,
      title: 'Z expression',
      summary: 'Expression for the z axis.',
    ),
  ],
);

const GlossJsonObject _realDropScriptVarsNode = GlossJsonObject(
  fields: <GlossJsonField>[],
);

const GlossJsonObject _realDropScriptNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'enabled',
      type: GlossJsonType.boolean,
      title: 'Enabled',
      summary: 'Runs advanced display modifiers.',
      defaultLiteral: 'false',
    ),
    GlossJsonField(
      key: 'vars',
      type: GlossJsonType.object,
      title: 'Variables',
      summary: 'Ordered named numeric expressions.',
      node: _realDropScriptVarsNode,
    ),
    GlossJsonField(
      key: 'offset',
      type: GlossJsonType.object,
      title: 'Offset',
      summary: 'Additive per-axis display displacement.',
      node: _realDropScriptAxisNode,
    ),
    GlossJsonField(
      key: 'rotation',
      type: GlossJsonType.object,
      title: 'Rotation',
      summary: 'Additive per-axis display rotation.',
      node: _realDropScriptAxisNode,
    ),
    GlossJsonField(
      key: 'scale',
      type: GlossJsonType.object,
      title: 'Scale',
      summary: 'Multiplicative per-axis display scale.',
      node: _realDropScriptAxisNode,
    ),
    GlossJsonField(
      key: 'glow',
      type: GlossJsonType.string,
      title: 'Glow expression',
      summary: 'Expression producing an optional outline colour.',
      defaultLiteral: '""',
    ),
    GlossJsonField(
      key: 'visible',
      type: GlossJsonType.string,
      title: 'Visibility expression',
      summary: 'Boolean expression controlling display visibility.',
      defaultLiteral: '"true"',
    ),
  ],
);

final GlossJsonObject _realDropAnimationKeyframeNode = GlossJsonObject(
  fields: <GlossJsonField>[
    const GlossJsonField(
      key: 'tick',
      type: GlossJsonType.number,
      title: 'Tick',
      summary: 'Position in the clip, from zero through durationTicks.',
      docKey: 'realDrops.animation.keyframe.tick',
      defaultLiteral: '0',
    ),
    const GlossJsonField(
      key: 'value',
      type: GlossJsonType.number,
      title: 'Value',
      summary: 'Scalar value applied to the track target.',
      docKey: 'realDrops.animation.keyframe.value',
      defaultLiteral: '0',
    ),
    const GlossJsonField(
      key: 'materialMap',
      type: GlossJsonType.string,
      title: 'Material map',
      summary: 'Optional property map for GLOW or LIGHT_LEVEL values.',
      docKey: 'realDrops.animation.keyframe.materialMap',
      defaultLiteral: '""',
    ),
    GlossJsonField(
      key: 'easing',
      type: GlossJsonType.string,
      title: 'Easing',
      summary: 'Curve used while approaching this keyframe.',
      docKey: 'realDrops.animation.keyframe.easing',
      values: _values(<String>[
        for (final GlossRealDropAnimationEasing easing
            in GlossRealDropAnimationEasing.values)
          easing.wire,
      ]),
      defaultLiteral: '"LINEAR"',
    ),
  ],
);

final GlossJsonObject _realDropAnimationTrackNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'target',
      type: GlossJsonType.string,
      title: 'Target',
      summary: 'Display, physics, or light property driven by this track.',
      docKey: 'realDrops.animation.track.target',
      values: _values(<String>[
        for (final GlossRealDropAnimationTarget target
            in GlossRealDropAnimationTarget.values)
          target.wire,
      ]),
      defaultLiteral: '"OFFSET_X"',
    ),
    GlossJsonField(
      key: 'blend',
      type: GlossJsonType.string,
      title: 'Blend',
      summary: 'How this track combines with the current target value.',
      docKey: 'realDrops.animation.track.blend',
      values: _values(<String>[
        for (final GlossRealDropAnimationBlend blend
            in GlossRealDropAnimationBlend.values)
          blend.wire,
      ]),
      defaultLiteral: '"ADD"',
    ),
    GlossJsonField(
      key: 'keyframes',
      type: GlossJsonType.array,
      title: 'Keyframes',
      summary: 'Scalar samples; ticks must be unique inside the clip.',
      docKey: 'realDrops.animation.track.keyframes',
      node: GlossJsonArray(
        item: _realDropAnimationKeyframeNode,
        itemType: GlossJsonType.object,
        itemTitle: 'Keyframe',
        itemSummary: 'One scalar sample and its incoming easing curve.',
      ),
    ),
  ],
);

final GlossJsonObject _realDropAnimationClipNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'trigger',
      type: GlossJsonType.string,
      title: 'Trigger',
      summary: 'Lifecycle state or event that activates the clip.',
      docKey: 'realDrops.animation.clip.trigger',
      values: _values(<String>[
        for (final GlossRealDropAnimationTrigger trigger
            in GlossRealDropAnimationTrigger.values)
          trigger.wire,
      ]),
      defaultLiteral: '"SPAWN"',
    ),
    const GlossJsonField(
      key: 'durationTicks',
      type: GlossJsonType.number,
      title: 'Duration',
      summary: 'Clip duration in ticks, from 0 through 1000000.',
      docKey: 'realDrops.animation.clip.durationTicks',
      defaultLiteral: '0',
    ),
    const GlossJsonField(
      key: 'loop',
      type: GlossJsonType.boolean,
      title: 'Loop',
      summary: 'Wraps elapsed time at durationTicks while active.',
      docKey: 'realDrops.animation.clip.loop',
      defaultLiteral: 'false',
    ),
    GlossJsonField(
      key: 'tracks',
      type: GlossJsonType.array,
      title: 'Tracks',
      summary: 'Ordered scalar tracks evaluated for this trigger.',
      docKey: 'realDrops.animation.clip.tracks',
      node: GlossJsonArray(
        item: _realDropAnimationTrackNode,
        itemType: GlossJsonType.object,
        itemTitle: 'Track',
        itemSummary: 'One typed target and its keyframes.',
      ),
    ),
  ],
);

final GlossJsonObject _realDropAnimationProfileNode = GlossJsonObject(
  fields: <GlossJsonField>[
    const GlossJsonField(
      key: 'id',
      type: GlossJsonType.string,
      title: 'Profile id',
      summary: 'Unique author-facing profile name.',
      docKey: 'realDrops.animation.profile.id',
      defaultLiteral: '"default"',
    ),
    const GlossJsonField(
      key: 'priority',
      type: GlossJsonType.integer,
      title: 'Priority',
      summary: 'Higher matching profiles win. Clamped to -10000..10000.',
      docKey: 'realDrops.animation.profile.priority',
      defaultLiteral: '0',
    ),
    const GlossJsonField(
      key: 'materials',
      type: GlossJsonType.array,
      title: 'Materials',
      summary:
          'Material globs matched case-insensitively after namespace removal.',
      docKey: 'realDrops.animation.profile.materials',
      node: GlossJsonArray(
        itemType: GlossJsonType.string,
        itemTitle: 'Material glob',
        itemSummary: '* and ? wildcards are supported.',
      ),
    ),
    GlossJsonField(
      key: 'clips',
      type: GlossJsonType.array,
      title: 'Clips',
      summary: 'Trigger clips declared in evaluation order.',
      docKey: 'realDrops.animation.profile.clips',
      node: GlossJsonArray(
        item: _realDropAnimationClipNode,
        itemType: GlossJsonType.object,
        itemTitle: 'Clip',
        itemSummary: 'One trigger, duration, and track collection.',
      ),
    ),
  ],
);

const GlossJsonObject _realDropAnimationMaterialMapsNode = GlossJsonObject(
  openKeyType: GlossJsonType.object,
  openKeyTitle: 'Property map',
  openKeySummary: 'Named material-pattern map supplying glow and light values.',
);

final GlossJsonObject _realDropAnimationNode = GlossJsonObject(
  fields: <GlossJsonField>[
    const GlossJsonField(
      key: 'enabled',
      type: GlossJsonType.boolean,
      title: 'Enabled',
      summary: 'Evaluates matching lifecycle animation profiles.',
      docKey: 'realDrops.animation.enabled',
      defaultLiteral: 'false',
    ),
    const GlossJsonField(
      key: 'materialProperties',
      type: GlossJsonType.object,
      title: 'Material properties',
      summary: 'Named material maps for GLOW and LIGHT_LEVEL keyframes.',
      docKey: 'realDrops.animation.materialProperties',
      node: _realDropAnimationMaterialMapsNode,
    ),
    GlossJsonField(
      key: 'profiles',
      type: GlossJsonType.array,
      title: 'Profiles',
      summary: 'Priority-ordered material profile candidates.',
      docKey: 'realDrops.animation.profiles',
      node: GlossJsonArray(
        item: _realDropAnimationProfileNode,
        itemType: GlossJsonType.object,
        itemTitle: 'Profile',
        itemSummary: 'One material selection and its trigger clips.',
      ),
    ),
  ],
);

final GlossJsonObject _realDropPresentationNode = GlossJsonObject(
  fields: <GlossJsonField>[
    const GlossJsonField(
      key: 'limits',
      type: GlossJsonType.object,
      title: 'Limits',
      summary: 'Update cadence, per-stack and per-chunk budgets, view range.',
      node: _realDropLimitsNode,
    ),
    const GlossJsonField(
      key: 'scale',
      type: GlossJsonType.object,
      title: 'Scale',
      summary: 'The scale family a material lands in.',
      node: _realDropScaleNode,
    ),
    const GlossJsonField(
      key: 'motion',
      type: GlossJsonType.object,
      title: 'Motion',
      summary: 'Tumble rates, their variance and the bounce re-roll.',
      node: _realDropMotionNode,
    ),
    const GlossJsonField(
      key: 'landing',
      type: GlossJsonType.object,
      title: 'Landing',
      summary: 'The pose a stack settles into once it stops moving.',
      node: _realDropLandingNode,
    ),
    const GlossJsonField(
      key: 'labels',
      type: GlossJsonType.object,
      title: 'Labels',
      summary: 'The count label drawn over each settled stack.',
      node: _realDropLabelsNode,
    ),
    const GlossJsonField(
      key: 'filters',
      type: GlossJsonType.object,
      title: 'Filters',
      summary: 'Where real drops are switched off.',
      node: _realDropFiltersNode,
    ),
    const GlossJsonField(
      key: 'physics',
      type: GlossJsonType.object,
      title: 'Physics',
      summary: 'Authoritative gravity, bounce, buoyancy, and drag.',
      node: _realDropPhysicsNode,
    ),
    const GlossJsonField(
      key: 'script',
      type: GlossJsonType.object,
      title: 'Advanced modifiers',
      summary: 'Optional expression-driven visual modifiers.',
      node: _realDropScriptNode,
    ),
    GlossJsonField(
      key: 'animation',
      type: GlossJsonType.object,
      title: 'Timeline animation',
      summary: 'Material profiles with event clips and typed scalar tracks.',
      docKey: 'realDrops.animation',
      node: _realDropAnimationNode,
    ),
  ],
);

final GlossJsonObject _realDropVariantNode = GlossJsonObject(
  fields: <GlossJsonField>[
    const GlossJsonField(
      key: 'id',
      type: GlossJsonType.string,
      title: 'Variant id',
      summary: 'Stable unique id; smaller ids win priority ties.',
    ),
    const GlossJsonField(
      key: 'priority',
      type: GlossJsonType.integer,
      title: 'Priority',
      summary: 'Highest matching priority wins. Clamped to -10000..10000.',
      defaultLiteral: '0',
    ),
    const GlossJsonField(
      key: 'when',
      type: GlossJsonType.string,
      title: 'Condition',
      summary: 'Typed condition evaluated against the immutable drop.',
      docKey: 'condition.when',
      defaultLiteral: '"false"',
    ),
    GlossJsonField(
      key: 'presentation',
      type: GlossJsonType.object,
      title: 'Presentation',
      summary: 'Complete independent real-drop presentation.',
      node: _realDropPresentationNode,
    ),
  ],
);

const GlossJsonObject _realDropAudienceNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'when',
      type: GlossJsonType.string,
      title: 'Viewer condition',
      summary: 'A matching viewer receives Gloss displays instead of vanilla.',
      docKey: 'condition.when',
      defaultLiteral: '"true"',
    ),
  ],
);

final GlossJsonObject glossRealDropsJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _schemaVersionField(glossRealDropsCurrentSchemaVersion),
    _revisionField,
    GlossJsonField(
      key: 'presentation',
      type: GlossJsonType.object,
      title: 'Presentation',
      summary: 'Fallback presentation when no conditional variant matches.',
      node: _realDropPresentationNode,
    ),
    GlossJsonField(
      key: 'variants',
      type: GlossJsonType.array,
      title: 'Conditional variants',
      summary: 'Complete alternatives selected by condition and priority.',
      node: GlossJsonArray(
        item: _realDropVariantNode,
        itemTitle: 'Variant',
        itemSummary: 'One conditional real-drop presentation.',
      ),
    ),
    const GlossJsonField(
      key: 'audience',
      type: GlossJsonType.object,
      title: 'Audience',
      summary: 'Per-viewer visibility for the selected presentation.',
      node: _realDropAudienceNode,
    ),
  ],
);

// --- damage indicators -----------------------------------------------------

const GlossJsonObject _damageIndicatorLimitsNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'maxPerSecond',
      type: GlossJsonType.integer,
      title: 'Maximum per second',
      summary: 'Global indicator spawn cap. Gloss accepts 1..1000.',
      defaultLiteral: '40',
    ),
    GlossJsonField(
      key: 'lifetimeMs',
      type: GlossJsonType.integer,
      title: 'Lifetime',
      summary: 'Visible lifetime in milliseconds. Gloss accepts 250..30000.',
      defaultLiteral: '3000',
    ),
    GlossJsonField(
      key: 'minimumDelta',
      type: GlossJsonType.number,
      title: 'Minimum delta',
      summary: 'Smallest health change that spawns a number. Range 0..1000.',
      defaultLiteral: '0.009',
    ),
    GlossJsonField(
      key: 'decimals',
      type: GlossJsonType.integer,
      title: 'Decimals',
      summary: 'Digits after the decimal point. Gloss accepts 0..4.',
      defaultLiteral: '0',
    ),
  ],
);

const GlossJsonObject _damageIndicatorMotionNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'horizontalSpeed',
      type: GlossJsonType.number,
      title: 'Horizontal speed',
      summary: 'Outward speed in blocks per second. Range 0..16.',
    ),
    GlossJsonField(
      key: 'verticalSpeed',
      type: GlossJsonType.number,
      title: 'Vertical speed',
      summary: 'Initial vertical speed in blocks per second. Range -16..16.',
    ),
    GlossJsonField(
      key: 'verticalAcceleration',
      type: GlossJsonType.number,
      title: 'Vertical acceleration',
      summary:
          'Vertical acceleration in blocks per second squared. Range -32..32.',
    ),
    GlossJsonField(
      key: 'spinDegreesPerSecond',
      type: GlossJsonType.number,
      title: 'Spin',
      summary: 'Screen-plane roll in degrees per second. Range -1440..1440.',
      defaultLiteral: '0.0',
    ),
  ],
);

const GlossJsonObject _damageIndicatorTransformNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'startScale',
      type: GlossJsonType.number,
      title: 'Start scale',
      summary: 'Text-display scale at spawn. Range 0..16.',
    ),
    GlossJsonField(
      key: 'endScale',
      type: GlossJsonType.number,
      title: 'End scale',
      summary: 'Text-display scale at expiry. Range 0..16.',
    ),
    GlossJsonField(
      key: 'fadeStartFraction',
      type: GlossJsonType.number,
      title: 'Fade start',
      summary: 'Lifetime fraction where fading begins. Range 0..1.',
    ),
  ],
);

const GlossJsonObject _damageIndicatorStyleNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'when',
      type: GlossJsonType.string,
      title: 'Condition',
      summary: 'The event must satisfy this typed condition.',
      docKey: 'condition.when',
      defaultLiteral: '"true"',
    ),
    GlossJsonField(
      key: 'presentation',
      type: GlossJsonType.object,
      title: 'Default presentation',
      summary: 'Fallback complete indicator presentation.',
      node: _damageIndicatorCompletePresentationNode,
    ),
    GlossJsonField(
      key: 'variants',
      type: GlossJsonType.array,
      title: 'Variants',
      summary: 'Conditional complete presentation alternatives.',
      node: GlossJsonArray(item: _damageIndicatorVariantNode),
    ),
  ],
);

const GlossJsonObject
_damageIndicatorCompletePresentationNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'format',
      type: GlossJsonType.string,
      title: 'Format',
      summary:
          'Minecraft text. Must contain {amount} or Gloss rejects the file.',
    ),
    GlossJsonField(
      key: 'offset',
      type: GlossJsonType.array,
      title: 'Offset',
      summary: 'Spawn offset from the entity as [x, y, z] blocks.',
      node: glossVector3Node,
    ),
    GlossJsonField(
      key: 'motion',
      type: GlossJsonType.object,
      title: 'Motion',
      summary: 'Closed-form trajectory and roll.',
      node: _damageIndicatorMotionNode,
    ),
    GlossJsonField(
      key: 'transform',
      type: GlossJsonType.object,
      title: 'Transform',
      summary: 'Scale interpolation and fade timing.',
      node: _damageIndicatorTransformNode,
    ),
  ],
);

const GlossJsonObject _damageIndicatorVariantNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'id',
      type: GlossJsonType.string,
      title: 'Variant id',
      summary: 'Stable unique id; smaller ids win priority ties.',
    ),
    GlossJsonField(
      key: 'priority',
      type: GlossJsonType.integer,
      title: 'Priority',
      summary: 'Highest matching priority wins.',
      defaultLiteral: '0',
    ),
    GlossJsonField(
      key: 'when',
      type: GlossJsonType.string,
      title: 'Condition',
      summary: 'Typed condition for this complete alternative.',
      docKey: 'condition.when',
      defaultLiteral: '"false"',
    ),
    GlossJsonField(
      key: 'presentation',
      type: GlossJsonType.object,
      title: 'Presentation',
      summary: 'Complete format, offset, motion and transform.',
      node: _damageIndicatorCompletePresentationNode,
    ),
  ],
);

const GlossJsonObject _damageIndicatorAudienceNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'when',
      type: GlossJsonType.string,
      title: 'Viewer condition',
      summary: 'Each viewer must satisfy this condition to see indicators.',
      docKey: 'condition.when',
    ),
  ],
);

final GlossJsonObject glossDamageIndicatorsJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _schemaVersionField(glossDamageIndicatorsCurrentSchemaVersion),
    _revisionField,
    const GlossJsonField(
      key: 'limits',
      type: GlossJsonType.object,
      title: 'Limits',
      summary: 'Spawn admission, lifetime and number formatting.',
      node: _damageIndicatorLimitsNode,
    ),
    const GlossJsonField(
      key: 'damage',
      type: GlossJsonType.object,
      title: 'Damage',
      summary: 'Conditional presentations for health loss.',
      node: _damageIndicatorStyleNode,
    ),
    const GlossJsonField(
      key: 'healing',
      type: GlossJsonType.object,
      title: 'Healing',
      summary: 'Conditional presentations for health gain.',
      node: _damageIndicatorStyleNode,
    ),
    const GlossJsonField(
      key: 'audience',
      type: GlossJsonType.object,
      title: 'Audience',
      summary: 'Per-viewer visibility condition.',
      node: _damageIndicatorAudienceNode,
    ),
  ],
);

// --- registry ---------------------------------------------------------------

/// Every kind this model covers, keyed by the workspace kind enum's `name`.
///
/// The two kinds deliberately absent are `panel`, which is an editor-only flow
/// map with no code view at all, and `containerPreview`, whose format is the
/// preview schema rather than a Gloss runtime document.
final Map<String, GlossJsonObject> glossJsonSchemas = <String, GlossJsonObject>{
  'menu': glossMenuJsonSchema,
  'hologram': glossHologramJsonSchema,
  'animation': glossAnimationJsonSchema,
  'scoreboard': glossScoreboardJsonSchema,
  'motd': glossMotdJsonSchema,
  'emoji': glossEmojiJsonSchema,
  'bubbleStyle': glossBubbleStyleJsonSchema,
  'tablist': glossTablistJsonSchema,
  'realDrops': glossRealDropsJsonSchema,
  'damageIndicators': glossDamageIndicatorsJsonSchema,
};

/// The model for [kindName], or null when this build has none for that kind.
GlossJsonObject? glossJsonSchemaFor(String kindName) =>
    glossJsonSchemas[kindName];
