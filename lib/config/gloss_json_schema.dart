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
import '../model/gloss_motd.dart';
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

final GlossJsonObject glossScoreboardJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _schemaVersionField(1),
    _revisionField,
    const GlossJsonField(
      key: 'title',
      type: GlossJsonType.string,
      title: 'Title',
      summary:
          'Sidebar header. Empty falls back to the board id; '
          '$glossBoardMaxTitleLength rendered characters is the cap.',
      docKey: 'scoreboard.title',
      defaultLiteral: '""',
    ),
    const GlossJsonField(
      key: 'lines',
      type: GlossJsonType.array,
      title: 'Lines',
      summary:
          'Sidebar rows, top first. Past $glossBoardMaxLines never reaches '
          'the client.',
      docKey: 'scoreboard.lines',
      node: _textLinesNode,
    ),
    const GlossJsonField(
      key: 'primary',
      type: GlossJsonType.boolean,
      title: 'Primary',
      summary: 'Volunteers as the default board for unsteered players.',
      docKey: 'scoreboard.primary',
      defaultLiteral: 'false',
    ),
    const GlossJsonField(
      key: 'hideNumbers',
      type: GlossJsonType.boolean,
      title: 'Hide numbers',
      summary: 'Uses the blank score format on 1.20.3 and newer clients.',
      docKey: 'scoreboard.hideNumbers',
      defaultLiteral: 'false',
    ),
    const GlossJsonField(
      key: 'permission',
      type: GlossJsonType.string,
      title: 'Permission',
      summary:
          'Trimmed and lowercased; "$glossBoardUnrestrictedPermission" or '
          'empty is unrestricted, anything else gates on '
          '$glossBoardPermissionNodePrefix<value>.',
      docKey: 'scoreboard.permission',
      defaultLiteral: '"$glossBoardUnrestrictedPermission"',
    ),
    const GlossJsonField(
      key: 'groups',
      type: GlossJsonType.array,
      title: 'Groups',
      summary: 'Vault groups this board serves; trimmed, lowercased, deduped.',
      docKey: 'scoreboard.groups',
      node: _plainStringsNode,
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
    GlossJsonField(
      key: 'edgeColor',
      type: GlossJsonType.any,
      title: 'Edge colour (retired)',
      summary: 'The two-tone band is gone; the key is read and dropped.',
      legacy: true,
    ),
  ],
);

const GlossJsonObject _bubbleSelectNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'worlds',
      type: GlossJsonType.array,
      title: 'Worlds',
      summary: 'World-name globs with * and ?. Trimmed, case kept.',
      docKey: 'bubble.select.worlds',
      node: _plainStringsNode,
    ),
    GlossJsonField(
      key: 'groups',
      type: GlossJsonType.array,
      title: 'Groups',
      summary: 'Vault groups. Trimmed, blanks dropped, lowercased.',
      docKey: 'bubble.select.groups',
      node: _plainStringsNode,
    ),
    GlossJsonField(
      key: 'priority',
      type: GlossJsonType.integer,
      title: 'Priority',
      summary: 'Highest match wins; ties break to the smaller style id.',
      docKey: 'bubble.select.priority',
      defaultLiteral: '0',
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

const GlossJsonObject _tablistNameFormatsNode = GlossJsonObject(
  openKeyType: GlossJsonType.string,
  openKeyTitle: 'Group format',
  openKeySummary: 'Vault group name; keys are trimmed and lowercased on load.',
  fields: <GlossJsonField>[
    GlossJsonField(
      key: glossTablistDefaultGroupKey,
      type: GlossJsonType.string,
      title: 'Default format',
      summary: 'The fallback list-name format for everyone else.',
      defaultLiteral: '"$glossTablistFallbackFormat"',
    ),
    GlossJsonField(
      key: glossTablistOpGroupKey,
      type: GlossJsonType.string,
      title: 'Operator format',
      summary: 'The format operators get first, before any group match.',
      defaultLiteral: '"$glossTablistFallbackFormat"',
    ),
  ],
);

final GlossJsonObject glossTablistJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _schemaVersionField(1),
    _revisionField,
    const GlossJsonField(
      key: 'useHeaderFooter',
      type: GlossJsonType.boolean,
      title: 'Use header and footer',
      summary: 'Off clears anything Gloss applied and leaves the tab alone.',
      docKey: 'tablist.useHeaderFooter',
      defaultLiteral: 'false',
    ),
    const GlossJsonField(
      key: 'header',
      type: GlossJsonType.string,
      title: 'Header',
      summary: 'Rendered per viewer, per update tick.',
      docKey: 'tablist.header',
      defaultLiteral: '""',
    ),
    const GlossJsonField(
      key: 'footer',
      type: GlossJsonType.string,
      title: 'Footer',
      summary: 'Rendered per viewer, per update tick.',
      docKey: 'tablist.footer',
      defaultLiteral: '""',
    ),
    const GlossJsonField(
      key: 'groupListNames',
      type: GlossJsonType.boolean,
      title: 'Group list names',
      summary: 'Off resets list names to vanilla and ignores nameFormats.',
      docKey: 'tablist.groupListNames',
      defaultLiteral: 'false',
    ),
    const GlossJsonField(
      key: 'nameFormats',
      type: GlossJsonType.object,
      title: 'Name formats',
      summary: 'Group key to list-name format. $glossTablistFallbackFormat is '
          'the player name.',
      docKey: 'tablist.nameFormats',
      node: _tablistNameFormatsNode,
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
  ],
);

const GlossJsonObject _realDropLandingNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'mode',
      type: GlossJsonType.string,
      title: 'Landing mode',
      summary: 'The pose a settled stack takes. Unknown values fall to NATURAL.',
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

final GlossJsonObject glossRealDropsJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _schemaVersionField(1),
    _revisionField,
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
};

/// The model for [kindName], or null when this build has none for that kind.
GlossJsonObject? glossJsonSchemaFor(String kindName) =>
    glossJsonSchemas[kindName];
