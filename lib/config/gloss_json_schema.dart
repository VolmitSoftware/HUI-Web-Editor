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
import '../model/gloss_entity_overlays.dart';
import '../model/gloss_hologram.dart';
import '../model/gloss_motd.dart';
import '../model/gloss_names.dart';
import 'catalog_document_schema.dart';
import 'glyph_json_schema.dart';
import 'display_refresh_schema.dart';
import 'behavior_json_schema.dart';
import 'presets_json_schema.dart';
import 'inventory_json_schema.dart';
import '../model/gloss_real_drop_animation.dart';
import '../model/gloss_real_drops.dart';
import '../model/gloss_scoreboard.dart';
import '../model/gloss_surface.dart';
import '../model/gloss_tablist.dart';
import 'gloss_menu_json_schema.dart';

const GlossJsonField glossShowField = GlossJsonField(
  key: 'show',
  type: GlossJsonType.any,
  title: 'Show condition',
  summary: 'Boolean or visibility expression.',
  defaultLiteral: 'true',
);
final GlossJsonField glossDisplayStyleField = GlossJsonField(
  key: 'style',
  type: GlossJsonType.object,
  title: 'Display style',
  summary: 'Native Gloss display style.',
  node: glossIconStyleNode,
);
const GlossJsonField glossHologramBoxField = GlossJsonField(
  key: 'box',
  type: GlossJsonType.object,
  title: 'Box decoration',
  summary: 'A uniform box that follows the visible text size.',
  node: glossHologramBoxNode,
);

/// `schemaVersion` — the generation check every Gloss document opens with.
/// A mismatch is rejected before anything else is read.
GlossJsonField _schemaVersionField(int version) => GlossJsonField(
  key: 'schemaVersion',
  type: GlossJsonType.integer,
  title: 'Schema version',
  summary: 'Schema version',
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

GlossJsonField _displayVariantsField({bool overlay = false}) => GlossJsonField(
  key: 'variants',
  type: GlossJsonType.array,
  title: 'Conditional variants',
  summary: 'Conditional variants',
  node: GlossJsonArray(
    itemType: GlossJsonType.object,
    itemTitle: 'Variant',
    itemSummary: 'Variant',
    item: GlossJsonObject(
      fields: <GlossJsonField>[
        const GlossJsonField(
          key: 'id',
          type: GlossJsonType.string,
          title: 'Id',
          summary: 'Id',
        ),
        const GlossJsonField(
          key: 'priority',
          type: GlossJsonType.integer,
          title: 'Priority',
          summary: 'Priority',
          defaultLiteral: '0',
        ),
        const GlossJsonField(
          key: 'when',
          type: GlossJsonType.any,
          title: 'Condition',
          summary: 'Condition',
          defaultLiteral: '"true"',
        ),
        GlossJsonField(
          key: 'presentation',
          type: GlossJsonType.object,
          title: 'Presentation',
          summary: 'Presentation',
          node: GlossJsonObject(
            fields: <GlossJsonField>[
              const GlossJsonField(
                key: 'lines',
                type: GlossJsonType.array,
                title: 'Lines',
                summary: 'Lines',
              ),
              glossDisplayStyleField,
              glossHologramBoxField,
              glossParticleLayersField,
              if (overlay) ...<GlossJsonField>[
                const GlossJsonField(
                  key: 'verticalOffset',
                  type: GlossJsonType.number,
                  title: 'Vertical offset',
                  summary: 'Vertical offset',
                ),
                const GlossJsonField(
                  key: 'healthSegments',
                  type: GlossJsonType.integer,
                  title: 'Health segments',
                  summary: 'Health segments',
                ),
                const GlossJsonField(
                  key: 'healthBar',
                  type: GlossJsonType.object,
                  title: 'Health and placement',
                  summary: 'Health and placement',
                  node: glossHealthBarNode,
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  ),
);

final GlossJsonObject glossHologramJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    glossDisplayRefreshField,
    _displayVariantsField(),
    const GlossJsonField(
      key: 'pages',
      type: GlossJsonType.array,
      title: 'Pages',
      summary: 'Pages',
      node: GlossJsonArray(
        itemType: GlossJsonType.object,
        itemTitle: 'Page',
        itemSummary: 'Page',
        item: GlossJsonObject(
          fields: <GlossJsonField>[
            GlossJsonField(
              key: 'id',
              type: GlossJsonType.string,
              title: 'Id',
              summary: 'Id',
            ),
            GlossJsonField(
              key: 'lines',
              type: GlossJsonType.array,
              title: 'Lines',
              summary: 'Lines',
            ),
            glossShowField,
          ],
        ),
      ),
    ),
    GlossJsonField(
      key: 'actions',
      type: GlossJsonType.array,
      title: 'Actions',
      summary: 'Actions',
      node: GlossJsonArray(
        item: glossActionNode,
        itemType: GlossJsonType.object,
        itemTitle: 'Action',
        itemSummary: 'Action',
      ),
    ),
    const GlossJsonField(
      key: 'hitbox',
      type: GlossJsonType.object,
      title: 'Hitbox',
      summary: 'Hitbox',
      node: GlossJsonObject(
        fields: <GlossJsonField>[
          GlossJsonField(
            key: 'width',
            type: GlossJsonType.number,
            title: 'Width',
            summary: 'Width',
          ),
          GlossJsonField(
            key: 'height',
            type: GlossJsonType.number,
            title: 'Height',
            summary: 'Height',
          ),
          GlossJsonField(
            key: 'perLine',
            type: GlossJsonType.boolean,
            title: 'Lines',
            summary: 'Lines',
          ),
        ],
      ),
    ),

    const GlossJsonField(
      key: 'viewDistance',
      type: GlossJsonType.number,
      title: 'View range',
      summary: 'View range',
      defaultLiteral: '48',
    ),
    const GlossJsonField(
      key: 'refreshTicks',
      type: GlossJsonType.integer,
      title: 'Refresh ticks',
      summary: 'Refresh ticks',
      defaultLiteral: '10',
    ),

    _schemaVersionField(glossHologramCurrentSchemaVersion),
    _revisionField,
    glossShowField,
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
      node: GlossJsonArray(
        itemType: GlossJsonType.any,
        itemTitle: 'Line',
        itemSummary: 'Line',
      ),
    ),
    glossDisplayStyleField,
    glossHologramBoxField,
    const GlossJsonField(
      key: 'yaw',
      type: GlossJsonType.number,
      title: 'Yaw',
      summary: 'Yaw',
      defaultLiteral: '0',
    ),
    const GlossJsonField(
      key: 'pitch',
      type: GlossJsonType.number,
      title: 'Pitch',
      summary: 'Pitch',
      defaultLiteral: '0',
    ),
    glossParticleLayersField,
  ],
);

// --- animation --------------------------------------------------------------

final GlossJsonObject glossAnimationJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _schemaVersionField(1),
    _revisionField,
    glossShowField,
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

const GlossJsonObject _scoreboardRowNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'text',
      type: GlossJsonType.string,
      title: 'Label',
      summary: 'Left column text.',
      defaultLiteral: '""',
    ),
    GlossJsonField(
      key: 'value',
      type: GlossJsonType.string,
      title: 'Value',
      summary: 'Text for fixed or styled score formats.',
    ),
    GlossJsonField(
      key: 'format',
      type: GlossJsonType.string,
      title: 'Score format',
      summary: 'blank, fixed, styled or number. A value defaults to fixed.',
      values: <GlossJsonValue>[
        GlossJsonValue('"blank"'),
        GlossJsonValue('"fixed"'),
        GlossJsonValue('"styled"'),
        GlossJsonValue('"number"'),
      ],
    ),
    GlossJsonField(
      key: 'id',
      type: GlossJsonType.string,
      title: 'Row ID',
      summary:
          'Stable unique identity within the expanded page; 1–64 letters, digits, dots, underscores or hyphens.',
    ),
    glossShowField,
    GlossJsonField(
      key: 'section',
      type: GlossJsonType.string,
      title: 'Section reference',
      summary:
          'Insert a named layout section. Only show may accompany a section reference.',
    ),
  ],
);

const GlossJsonArray _scoreboardRowsNode = GlossJsonArray(
  itemType: GlossJsonType.any,
  item: _scoreboardRowNode,
  itemTitle: 'Row',
  itemSummary: 'Text string, configured row, or section reference.',
);

const GlossJsonObject _scoreboardLayoutNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'sections',
      type: GlossJsonType.object,
      title: 'Sections',
      summary: 'Up to 64 named reusable row lists; references may not recurse.',
      node: GlossJsonObject(
        openKeyType: GlossJsonType.array,
        openKeyTitle: 'Section',
        openKeySummary: 'A list of text strings or row objects.',
      ),
    ),
    GlossJsonField(
      key: 'pages',
      type: GlossJsonType.array,
      title: 'Pages',
      summary: 'Rotate through up to 64 eligible pages in order.',
      node: GlossJsonArray(
        itemType: GlossJsonType.object,
        item: GlossJsonObject(
          fields: <GlossJsonField>[
            GlossJsonField(
              key: 'id',
              type: GlossJsonType.string,
              title: 'Page ID',
              summary: 'Unique page identity.',
            ),
            GlossJsonField(
              key: 'title',
              type: GlossJsonType.string,
              title: 'Page title',
              summary: 'Omitted uses the presentation title.',
            ),
            GlossJsonField(
              key: 'lines',
              type: GlossJsonType.array,
              title: 'Rows',
              summary: 'Rows for this page.',
              node: _scoreboardRowsNode,
            ),
            glossShowField,
            GlossJsonField(
              key: 'durationTicks',
              type: GlossJsonType.integer,
              title: 'Duration',
              summary: '1–72000 ticks.',
              defaultLiteral: '100',
            ),
          ],
        ),
      ),
    ),
    GlossJsonField(
      key: 'overflow',
      type: GlossJsonType.string,
      title: 'Overflow',
      summary:
          'truncate shows the first 15 visible rows; error rejects more than 15 expanded rows.',
      defaultLiteral: '"truncate"',
      values: <GlossJsonValue>[
        GlossJsonValue('"truncate"'),
        GlossJsonValue('"error"'),
      ],
    ),
    GlossJsonField(
      key: 'refresh',
      type: GlossJsonType.object,
      title: 'Refresh',
      summary:
          'Optional independent intervals; omitted values use automatic animation detection.',
      node: GlossJsonObject(
        fields: <GlossJsonField>[
          GlossJsonField(
            key: 'titleTicks',
            type: GlossJsonType.integer,
            title: 'Title interval',
            summary: '1–72000 ticks.',
          ),
          GlossJsonField(
            key: 'textTicks',
            type: GlossJsonType.integer,
            title: 'Label interval',
            summary: '1–72000 ticks.',
          ),
          GlossJsonField(
            key: 'valueTicks',
            type: GlossJsonType.integer,
            title: 'Value interval',
            summary: '1–72000 ticks.',
          ),
        ],
      ),
    ),
  ],
);

const GlossJsonObject _scoreboardObjectiveNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'title',
      type: GlossJsonType.string,
      title: 'Title',
      summary: 'Native objective title rendered for the viewer.',
    ),
    GlossJsonField(
      key: 'value',
      type: GlossJsonType.string,
      title: 'Numeric value',
      summary: 'Subject expression, rounded to a signed 32-bit integer.',
      defaultLiteral: '"subject.health"',
    ),
    GlossJsonField(
      key: 'renderType',
      values: <GlossJsonValue>[
        GlossJsonValue('"integer"'),
        GlossJsonValue('"hearts"'),
      ],
      type: GlossJsonType.string,
      title: 'Render type',
      summary: 'Native integer or hearts rendering.',
      defaultLiteral: '"integer"',
    ),
    GlossJsonField(
      key: 'format',
      values: <GlossJsonValue>[
        GlossJsonValue('"number"'),
        GlossJsonValue('"blank"'),
        GlossJsonValue('"fixed"'),
        GlossJsonValue('"styled"'),
      ],
      type: GlossJsonType.string,
      title: 'Score format',
      summary: 'number, blank, fixed or styled.',
      defaultLiteral: '"number"',
    ),
    GlossJsonField(
      key: 'valueText',
      type: GlossJsonType.string,
      title: 'Formatted value',
      summary: 'Fixed text or styled formatting, rendered for the subject.',
    ),
    glossShowField,
    GlossJsonField(
      key: 'subjects',
      type: GlossJsonType.any,
      title: 'Subject condition',
      summary: 'Only matching online players publish a score.',
      defaultLiteral: 'true',
    ),
    GlossJsonField(
      key: 'refreshTicks',
      type: GlossJsonType.integer,
      title: 'Refresh interval',
      summary: '1–72000 ticks.',
      defaultLiteral: '20',
    ),
    GlossJsonField(
      key: 'conflict',
      values: <GlossJsonValue>[
        GlossJsonValue('"yield"'),
        GlossJsonValue('"override"'),
      ],
      type: GlossJsonType.string,
      title: 'Slot conflict',
      summary:
          'yield preserves foreign objectives; override explicitly takes the slot.',
      defaultLiteral: '"yield"',
    ),
  ],
);

const GlossJsonObject _scoreboardPresentationNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'title',
      type: GlossJsonType.string,
      title: 'Title',
      summary: 'Full-width sidebar header. Empty stays blank.',
      docKey: 'scoreboard.presentation.title',
      defaultLiteral: '""',
    ),
    GlossJsonField(
      key: 'lines',
      type: GlossJsonType.array,
      title: 'Lines',
      summary:
          'Sidebar rows, top first. Up to $glossBoardMaxLines visible rows render.',
      docKey: 'scoreboard.presentation.lines',
      node: _scoreboardRowsNode,
    ),
    GlossJsonField(
      key: 'hideNumbers',
      type: GlossJsonType.boolean,
      title: 'Hide numbers',
      summary: 'Uses the blank score format on 1.20.3 and newer clients.',
      docKey: 'scoreboard.presentation.hideNumbers',
      defaultLiteral: 'false',
    ),
    GlossJsonField(
      key: 'layout',
      type: GlossJsonType.object,
      title: 'Layout',
      summary: 'Sections, pages, overflow and independent refresh intervals.',
      node: _scoreboardLayoutNode,
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
    glossShowField,
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
    const GlossJsonField(
      key: 'objectives',
      type: GlossJsonType.object,
      title: 'Native objectives',
      summary: 'Optional native player-list and below-name scores.',
      node: GlossJsonObject(
        fields: <GlossJsonField>[
          GlossJsonField(
            key: 'playerList',
            type: GlossJsonType.object,
            title: 'Player-list objective',
            summary: 'Native tab overlay score slot.',
            node: _scoreboardObjectiveNode,
          ),
          GlossJsonField(
            key: 'belowName',
            type: GlossJsonType.object,
            title: 'Below-name objective',
            summary: 'Native score attached to player names.',
            node: _scoreboardObjectiveNode,
          ),
        ],
      ),
    ),
  ],
);

// --- surface ----------------------------------------------------------------

const GlossJsonObject _surfaceSelectNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'priority',
      type: GlossJsonType.integer,
      title: 'Priority',
      summary: 'Highest matching priority wins its lane.',
      docKey: 'surface.select.priority',
      defaultLiteral: '0',
    ),
    GlossJsonField(
      key: 'when',
      type: GlossJsonType.string,
      title: 'Condition',
      summary:
          'Typed boolean expression. Omitted, this is false, so the document '
          'never shows.',
      docKey: 'condition.when',
      defaultLiteral: '"false"',
    ),
  ],
);

const GlossJsonObject _surfaceDeliveryNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'mode',
      type: GlossJsonType.string,
      title: 'Busy-slot behavior',
      summary: 'Queue, replace when allowed, or drop while busy.',
      values: <GlossJsonValue>[
        GlossJsonValue('"queue"'),
        GlossJsonValue('"replace"'),
        GlossJsonValue('"drop"'),
      ],
      defaultLiteral: '"replace"',
    ),
    GlossJsonField(
      key: 'preempt',
      type: GlossJsonType.string,
      title: 'Preemption',
      summary: 'Which new deliveries interrupt active content.',
      values: <GlossJsonValue>[
        GlossJsonValue('"higher"'),
        GlossJsonValue('"always"'),
        GlossJsonValue('"never"'),
      ],
      defaultLiteral: '"always"',
    ),
    GlossJsonField(
      key: 'maxPending',
      type: GlossJsonType.integer,
      title: 'Queue capacity',
      summary: 'Pending requests per viewer and lane, from 1 to 256.',
      defaultLiteral: '32',
    ),
    GlossJsonField(
      key: 'overflow',
      type: GlossJsonType.string,
      title: 'Full queue',
      summary:
          'Reject the incoming request or discard the oldest pending request.',
      values: <GlossJsonValue>[
        GlossJsonValue('"reject"'),
        GlossJsonValue('"drop-oldest"'),
      ],
      defaultLiteral: '"reject"',
    ),
    GlossJsonField(
      key: 'cooldownTicks',
      type: GlossJsonType.integer,
      title: 'Cooldown',
      summary:
          'Minimum ticks between accepted requests for this document, 0–72000.',
      defaultLiteral: '0',
    ),
    GlossJsonField(
      key: 'deduplicate',
      type: GlossJsonType.string,
      title: 'Deduplication',
      summary:
          'Match pending and active requests by document purpose or rendered content.',
      values: <GlossJsonValue>[
        GlossJsonValue('"none"'),
        GlossJsonValue('"purpose"'),
        GlossJsonValue('"content"'),
      ],
      defaultLiteral: '"none"',
    ),
    GlossJsonField(
      key: 'expireTicks',
      type: GlossJsonType.integer,
      title: 'Queue expiration',
      summary: 'Drop requests that wait this many ticks, 1–72000.',
      defaultLiteral: '1200',
    ),
  ],
);

const GlossJsonObject _surfaceEventNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'trigger',
      type: GlossJsonType.string,
      title: 'Event',
      summary: 'Join, interval, backend world change or proxy server change.',
      values: <GlossJsonValue>[
        GlossJsonValue('"join"'),
        GlossJsonValue('"interval"'),
        GlossJsonValue('"world_change"'),
        GlossJsonValue('"server_change"'),
      ],
    ),
    GlossJsonField(
      key: 'everyTicks',
      type: GlossJsonType.integer,
      title: 'Interval',
      summary: 'Required for interval events, 1–1728000 ticks.',
    ),
    GlossJsonField(
      key: 'delayTicks',
      type: GlossJsonType.integer,
      title: 'Delay',
      summary: 'Wait 0–72000 ticks after the event before submitting.',
      defaultLiteral: '0',
    ),
    GlossJsonField(
      key: 'when',
      type: GlossJsonType.string,
      title: 'Condition',
      summary: 'Viewer condition evaluated when this event fires.',
      defaultLiteral: '"true"',
    ),
  ],
);

final GlossJsonObject _surfacePresentationNode = GlossJsonObject(
  fields: <GlossJsonField>[
    const GlossJsonField(
      key: 'flags',
      type: GlossJsonType.array,
      title: 'Bossbar flags',
      summary: 'Client sky, boss music and fog effects; bossbars only.',
      node: GlossJsonArray(
        itemType: GlossJsonType.string,
        itemTitle: 'Flag',
        itemSummary: 'One supported client bossbar effect.',
        itemValues: <GlossJsonValue>[
          GlossJsonValue('"darken_sky"'),
          GlossJsonValue('"play_boss_music"'),
          GlossJsonValue('"create_fog"'),
        ],
      ),
    ),

    const GlossJsonField(
      key: 'text',
      type: GlossJsonType.string,
      title: 'Action-bar text',
      summary: 'The action-bar line. Required there, dropped everywhere else.',
      docKey: 'surface.presentation.text',
      defaultLiteral: '""',
    ),
    const GlossJsonField(
      key: 'title',
      type: GlossJsonType.string,
      title: 'Title',
      summary:
          'The boss-bar or title line. Required on both, dropped on an '
          'action bar.',
      docKey: 'surface.presentation.title',
      defaultLiteral: '""',
    ),
    const GlossJsonField(
      key: 'subtitle',
      type: GlossJsonType.string,
      title: 'Subtitle',
      summary: 'Second line of a title card. Dropped on the other two.',
      docKey: 'surface.presentation.subtitle',
      defaultLiteral: '""',
    ),
    const GlossJsonField(
      key: 'progress',
      type: GlossJsonType.string,
      title: 'Progress',
      summary:
          'Boss-bar fill as an expression yielding 0 through 1. Omitted, '
          'this is "1".',
      docKey: 'surface.presentation.progress',
      defaultLiteral: '"1"',
    ),
    GlossJsonField(
      key: 'color',
      type: GlossJsonType.string,
      title: 'Boss-bar colour',
      summary: 'One of the seven Bukkit boss-bar colours.',
      docKey: 'surface.presentation.color',
      values: _values(glossSurfaceColors),
      defaultLiteral: '"$glossSurfaceDefaultColor"',
    ),
    GlossJsonField(
      key: 'style',
      type: GlossJsonType.string,
      title: 'Notch style',
      summary: 'How many notches the boss bar is cut into.',
      docKey: 'surface.presentation.style',
      values: _values(glossSurfaceStyles),
      defaultLiteral: '"$glossSurfaceDefaultStyle"',
    ),
    GlossJsonField(
      key: 'slots',
      type: GlossJsonType.array,
      title: 'Slots',
      summary: 'Which HUD lanes the line claims. Omitted, this is ["center"].',
      docKey: 'surface.presentation.slots',
      node: GlossJsonArray(
        itemType: GlossJsonType.string,
        itemTitle: 'Slot',
        itemSummary: 'One of left, center, right.',
        itemValues: _values(glossSurfaceSlots),
      ),
    ),
    GlossJsonField(
      key: 'priority',
      type: GlossJsonType.string,
      title: 'Compositor lane',
      summary: 'Which HUD band the line competes in.',
      docKey: 'surface.presentation.priority',
      values: _values(glossSurfacePriorities),
      defaultLiteral: '"$glossSurfaceDefaultPriority"',
    ),
    const GlossJsonField(
      key: 'ttlTicks',
      type: GlossJsonType.integer,
      title: 'Lifetime',
      summary:
          'How long one delivery lives. Silently clamped to '
          '$glossSurfaceMinTtlTicks..$glossSurfaceMaxTtlTicks.',
      docKey: 'surface.presentation.ttlTicks',
    ),
    const GlossJsonField(
      key: 'fadeInTicks',
      type: GlossJsonType.integer,
      title: 'Fade in',
      summary:
          'Title fade-in. Silently clamped to '
          '$glossSurfaceMinFadeTicks..$glossSurfaceMaxFadeTicks.',
      docKey: 'surface.presentation.fadeInTicks',
      defaultLiteral: '$glossSurfaceDefaultFadeInTicks',
    ),
    const GlossJsonField(
      key: 'stayTicks',
      type: GlossJsonType.integer,
      title: 'Stay',
      summary:
          'How long a title holds. Silently clamped to '
          '$glossSurfaceMinFadeTicks..$glossSurfaceMaxFadeTicks.',
      docKey: 'surface.presentation.stayTicks',
      defaultLiteral: '$glossSurfaceDefaultStayTicks',
    ),
    const GlossJsonField(
      key: 'fadeOutTicks',
      type: GlossJsonType.integer,
      title: 'Fade out',
      summary:
          'Title fade-out. Silently clamped to '
          '$glossSurfaceMinFadeTicks..$glossSurfaceMaxFadeTicks.',
      docKey: 'surface.presentation.fadeOutTicks',
      defaultLiteral: '$glossSurfaceDefaultFadeOutTicks',
    ),
    GlossJsonField(
      key: 'trigger',
      type: GlossJsonType.string,
      title: 'Trigger',
      summary: 'When a title card replays.',
      docKey: 'surface.presentation.trigger',
      values: _values(glossSurfaceTriggers),
      defaultLiteral: '"$glossSurfaceDefaultTrigger"',
    ),
    const GlossJsonField(
      key: 'repeatTicks',
      type: GlossJsonType.integer,
      title: 'Repeat interval',
      summary:
          'Ticks between replays of a repeating title. Silently clamped to '
          '$glossSurfaceMinRepeatTicks..$glossSurfaceMaxRepeatTicks and never '
          'shorter than the stay.',
      docKey: 'surface.presentation.repeatTicks',
    ),
  ],
);

final GlossJsonObject _surfaceVariantNode = GlossJsonObject(
  fields: <GlossJsonField>[
    const GlossJsonField(
      key: 'id',
      type: GlossJsonType.string,
      title: 'Variant id',
      summary: 'Stable unique id; the smaller id wins a priority tie.',
    ),
    const GlossJsonField(
      key: 'priority',
      type: GlossJsonType.integer,
      title: 'Priority',
      summary: 'Highest matching variant priority wins.',
      defaultLiteral: '0',
    ),
    const GlossJsonField(
      key: 'when',
      type: GlossJsonType.string,
      title: 'Condition',
      summary: 'Typed boolean expression. Blank rejects the whole file.',
      docKey: 'condition.when',
      defaultLiteral: '"false"',
    ),
    GlossJsonField(
      key: 'presentation',
      type: GlossJsonType.object,
      title: 'Presentation',
      summary: 'Complete replacement presentation used when this variant wins.',
      node: _surfacePresentationNode,
    ),
  ],
);

final GlossJsonObject glossSurfaceJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _schemaVersionField(1),
    _revisionField,
    glossShowField,
    const GlossJsonField(
      key: 'group',
      type: GlossJsonType.string,
      title: 'Bossbar group',
      summary: 'Independent bossbar selection group, default main.',
      defaultLiteral: '"main"',
    ),
    const GlossJsonField(
      key: 'automatic',
      type: GlossJsonType.boolean,
      title: 'Automatic selection',
      summary: 'False restricts this document to events and surface actions.',
      defaultLiteral: 'true',
    ),
    const GlossJsonField(
      key: 'delivery',
      type: GlossJsonType.object,
      title: 'Delivery policy',
      summary: 'Finite request queue and preemption policy.',
      node: _surfaceDeliveryNode,
    ),
    const GlossJsonField(
      key: 'on',
      type: GlossJsonType.array,
      title: 'Events and intervals',
      summary:
          'Up to 64 event subscriptions; unsupported platform events fail to load.',
      node: GlossJsonArray(
        item: _surfaceEventNode,
        itemTitle: 'Subscription',
        itemSummary: 'Submit the surface when an event and condition match.',
      ),
    ),

    GlossJsonField(
      key: 'surface',
      type: GlossJsonType.string,
      title: 'Surface',
      summary:
          'Which client surface this document draws on. Decides which '
          'presentation fields survive.',
      docKey: 'surface.surface',
      values: _values(glossSurfaceKinds),
      defaultLiteral: '"$glossSurfaceKindActionbar"',
    ),
    const GlossJsonField(
      key: 'select',
      type: GlossJsonType.object,
      title: 'Selection',
      summary: 'Document-level lane and eligibility condition.',
      node: _surfaceSelectNode,
    ),
    GlossJsonField(
      key: 'presentation',
      type: GlossJsonType.object,
      title: 'Default presentation',
      summary: 'The fallback line for the chosen surface.',
      node: _surfacePresentationNode,
    ),
    GlossJsonField(
      key: 'variants',
      type: GlossJsonType.array,
      title: 'Conditional variants',
      summary: 'Complete alternative lines selected by condition and priority.',
      node: GlossJsonArray(
        item: _surfaceVariantNode,
        itemTitle: 'Variant',
        itemSummary: 'One condition and the complete line it draws.',
      ),
    ),
  ],
);

// --- MOTD -------------------------------------------------------------------

const GlossJsonArray _motdIconsNode = GlossJsonArray(
  itemType: GlossJsonType.string,
  itemTitle: 'Icon path',
  itemSummary: 'A 64×64 PNG under images/.',
);
const GlossJsonObject _motdRotationNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'mode',
      type: GlossJsonType.string,
      title: 'Rotation mode',
      summary:
          'Weighted random selection, per-request sequence, epoch-time rotation, or first eligible response.',
      values: <GlossJsonValue>[
        GlossJsonValue('"weighted"'),
        GlossJsonValue('"sequence"'),
        GlossJsonValue('"time"'),
        GlossJsonValue('"first"'),
      ],
      defaultLiteral: '"weighted"',
    ),
    GlossJsonField(
      key: 'intervalSeconds',
      type: GlossJsonType.integer,
      title: 'Rotation interval seconds',
      summary: 'Time rotation interval, 1 through 86400 seconds. Default 60.',
      defaultLiteral: '60',
    ),
  ],
);
const GlossJsonObject _motdSelectorNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'hostnames',
      type: GlossJsonType.array,
      title: 'Hostnames',
      summary:
          'Exact requested hostnames or *.example.org suffixes. Empty matches any hostname.',
      node: _textLinesNode,
    ),
    GlossJsonField(
      key: 'minProtocol',
      type: GlossJsonType.integer,
      title: 'Minimum protocol',
      summary:
          'Inclusive nonnegative client protocol bound. Unavailable metadata does not match.',
    ),
    GlossJsonField(
      key: 'maxProtocol',
      type: GlossJsonType.integer,
      title: 'Maximum protocol',
      summary:
          'Inclusive protocol bound, at least the minimum. Paper and Velocity only.',
    ),
    GlossJsonField(
      key: 'zone',
      type: GlossJsonType.string,
      title: 'Time zone',
      summary: 'IANA zone or UTC offset used by calendar conditions.',
      defaultLiteral: '"UTC"',
    ),
    GlossJsonField(
      key: 'startTime',
      type: GlossJsonType.string,
      title: 'Start time',
      summary: 'Inclusive local time in HH:mm format; requires an end time.',
    ),
    GlossJsonField(
      key: 'endTime',
      type: GlossJsonType.string,
      title: 'End time',
      summary:
          'Exclusive local time; overnight ranges are allowed. Equal times cover the full day.',
    ),
    GlossJsonField(
      key: 'days',
      type: GlossJsonType.array,
      title: 'Weekdays',
      summary:
          'ISO weekdays 1 through 7, Monday through Sunday. Empty means every day.',
      node: GlossJsonArray(
        itemType: GlossJsonType.integer,
        itemTitle: 'Weekday',
        itemSummary: 'An ISO weekday from 1 through 7.',
      ),
    ),
    GlossJsonField(
      key: 'states',
      type: GlossJsonType.array,
      title: 'Matching states',
      summary: 'Exact values of the document state. Empty means any state.',
      node: _textLinesNode,
    ),
    GlossJsonField(
      key: 'minOnline',
      type: GlossJsonType.integer,
      title: 'Minimum real online',
      summary:
          'Inclusive nonnegative real online-count bound, before display overrides.',
    ),
    GlossJsonField(
      key: 'maxOnline',
      type: GlossJsonType.integer,
      title: 'Maximum real online',
      summary: 'Inclusive real online-count bound, at least the minimum.',
    ),
  ],
);
const List<GlossJsonValue> _motdCountModes = <GlossJsonValue>[
  GlossJsonValue('"inherit"'),
  GlossJsonValue('"fixed"'),
  GlossJsonValue('"offset"'),
];
const GlossJsonObject _motdCountsNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'onlineMode',
      type: GlossJsonType.string,
      title: 'Online count mode',
      summary:
          'Inherit the response, set a fixed count, or offset the real count. Paper and Velocity only.',
      values: _motdCountModes,
      defaultLiteral: '"inherit"',
    ),
    GlossJsonField(
      key: 'onlineValue',
      type: GlossJsonType.integer,
      title: 'Online count value',
      summary:
          'Signed 32-bit integer. Fixed counts must be nonnegative; offset results clamp to the valid count range.',
      defaultLiteral: '0',
    ),
    GlossJsonField(
      key: 'maximumMode',
      type: GlossJsonType.string,
      title: 'Maximum count mode',
      summary:
          'Presentation policy only; this does not change admission limits.',
      values: _motdCountModes,
      defaultLiteral: '"inherit"',
    ),
    GlossJsonField(
      key: 'maximumValue',
      type: GlossJsonType.integer,
      title: 'Maximum count value',
      summary: 'Signed 32-bit integer; fixed values must not be negative.',
      defaultLiteral: '0',
    ),
    GlossJsonField(
      key: 'hide',
      type: GlossJsonType.boolean,
      title: 'Hide player counts',
      summary: 'Hide counts and the hover sample on Paper and Velocity.',
      defaultLiteral: 'false',
    ),
  ],
);
const GlossJsonObject _motdServerLinksNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'enabled',
      type: GlossJsonType.boolean,
      title: 'Publish server links',
      summary: 'Independent of the MOTD feature switch and entry selection.',
      defaultLiteral: 'true',
    ),
    GlossJsonField(
      key: 'links',
      type: GlossJsonType.array,
      title: 'Server links',
      summary: 'Up to 16 pause-menu links, updated for connected players.',
      node: GlossJsonArray(
        item: _motdLinkNode,
        itemType: GlossJsonType.object,
        itemTitle: 'Server link',
        itemSummary:
            'A client label or custom label and an HTTP or HTTPS address.',
      ),
    ),
  ],
);

const GlossJsonObject _motdEntryNode = GlossJsonObject(
  fields: <GlossJsonField>[
    glossShowField,
    GlossJsonField(
      key: 'select',
      type: GlossJsonType.object,
      title: 'Request selection',
      summary: 'Host, protocol, calendar, state and real-count conditions.',
      node: _motdSelectorNode,
    ),
    GlossJsonField(
      key: 'icons',
      type: GlossJsonType.array,
      title: 'Entry icon set',
      summary:
          'Up to 64 icons, preferred over this entry’s single icon and document icons.',
      node: _motdIconsNode,
    ),
    GlossJsonField(
      key: 'counts',
      type: GlossJsonType.object,
      title: 'Count policy',
      summary: 'Explicit modes take precedence over count expressions.',
      node: _motdCountsNode,
    ),
    GlossJsonField(
      key: 'sampleMode',
      type: GlossJsonType.string,
      title: 'Sample mode',
      summary: 'Omitted: replace when sample lines exist, otherwise inherit.',
      values: <GlossJsonValue>[
        GlossJsonValue('"inherit"'),
        GlossJsonValue('"replace"'),
        GlossJsonValue('"hide"'),
      ],
    ),
    GlossJsonField(
      key: 'weight',
      type: GlossJsonType.integer,
      title: 'Weight',
      summary: 'Relative chance among visible entries, from 1 to 1000000.',
      defaultLiteral: '1',
    ),
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
    GlossJsonField(
      key: 'favicon',
      type: GlossJsonType.string,
      title: 'Icon override',
      summary: 'Replaces the document icon for this entry only.',
      docKey: 'motd.entries.favicon',
    ),
    GlossJsonField(
      key: 'sample',
      type: GlossJsonType.array,
      title: 'Hover sample',
      summary:
          'Up to $glossMotdMaxSampleLines lines under the player count. '
          'Paper only.',
      docKey: 'motd.entries.sample',
      node: _motdSampleNode,
    ),
    GlossJsonField(
      key: 'online',
      type: GlossJsonType.string,
      title: 'Online count',
      summary: 'Text that has to render to a number. Paper only.',
      docKey: 'motd.entries.online',
    ),
    GlossJsonField(
      key: 'max',
      type: GlossJsonType.string,
      title: 'Max players',
      summary: 'Text that has to render to a number. Works on Spigot too.',
      docKey: 'motd.entries.max',
    ),
    GlossJsonField(
      key: 'version',
      type: GlossJsonType.string,
      title: 'Version label',
      summary:
          'Shown only to clients with an incompatible protocol. '
          'Does not replace ping bars or change compatibility. Needs Paper.',
      docKey: 'motd.entries.version',
    ),
  ],
);

const GlossJsonArray _motdSampleNode = GlossJsonArray(
  itemType: GlossJsonType.string,
  itemTitle: 'Hover line',
  itemSummary: 'One line of the hover list, through the Gloss text pipeline.',
);

const GlossJsonObject _motdLinkNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'type',
      type: GlossJsonType.string,
      title: 'Link type',
      summary: 'One of the ten kinds the client labels itself.',
      docKey: 'motd.links.type',
      values: _motdLinkTypeValues,
    ),
    GlossJsonField(
      key: 'label',
      type: GlossJsonType.string,
      title: 'Link label',
      summary: 'Your own wording, for a link with no type.',
      docKey: 'motd.links.label',
    ),
    GlossJsonField(
      key: 'url',
      type: GlossJsonType.string,
      title: 'Link url',
      summary: 'Required http or https address with a host.',
      docKey: 'motd.links.url',
    ),
  ],
);

const List<GlossJsonValue> _motdLinkTypeValues = <GlossJsonValue>[
  GlossJsonValue('"report_bug"'),
  GlossJsonValue('"community_guidelines"'),
  GlossJsonValue('"support"'),
  GlossJsonValue('"status"'),
  GlossJsonValue('"feedback"'),
  GlossJsonValue('"community"'),
  GlossJsonValue('"website"'),
  GlossJsonValue('"forums"'),
  GlossJsonValue('"news"'),
  GlossJsonValue('"announcements"'),
];

final GlossJsonObject glossMotdJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _schemaVersionField(1),
    _revisionField,
    glossShowField,
    const GlossJsonField(
      key: 'rotation',
      type: GlossJsonType.object,
      title: 'Rotation policy',
      summary: 'Selects one eligible response and its icon.',
      node: _motdRotationNode,
    ),
    const GlossJsonField(
      key: 'icons',
      type: GlossJsonType.array,
      title: 'Document icon set',
      summary: 'Up to 64 icons used when an entry has no icon override.',
      node: _motdIconsNode,
    ),
    const GlossJsonField(
      key: 'state',
      type: GlossJsonType.string,
      title: 'Server state',
      summary: 'Nonblank state matched by entry selectors.',
      defaultLiteral: '"normal"',
    ),
    const GlossJsonField(
      key: 'serverLinks',
      type: GlossJsonType.object,
      title: 'Independent server links',
      summary:
          'When present, replaces the original links list independently of MOTD selection.',
      node: _motdServerLinksNode,
    ),
    const GlossJsonField(
      key: 'favicon',
      type: GlossJsonType.string,
      title: 'Server icon',
      summary:
          'The 64x64 server-list icon under plugins/Gloss/images/, used by '
          'every entry. Blank keeps the vanilla one.',
      docKey: 'motd.favicon',
    ),
    const GlossJsonField(
      key: 'entries',
      type: GlossJsonType.array,
      title: 'Entries',
      summary:
          'The response pool. One eligible entry per ping. Must not be empty.',
      docKey: 'motd.entries',
      node: GlossJsonArray(
        item: _motdEntryNode,
        itemType: GlossJsonType.object,
        itemTitle: 'Entry',
        itemSummary: 'One MOTD candidate.',
      ),
    ),
    const GlossJsonField(
      key: 'links',
      type: GlossJsonType.array,
      title: 'Server links',
      summary:
          'Up to $glossMotdMaxLinks pause-menu links, published once per '
          'revision.',
      docKey: 'motd.links',
      node: GlossJsonArray(
        item: _motdLinkNode,
        itemType: GlossJsonType.object,
        itemTitle: 'Server link',
        itemSummary: 'One pause-menu link: a type or a label, plus a url.',
      ),
    ),
  ],
);

// --- connections ------------------------------------------------------------

const GlossJsonObject _connectionsPresentationNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'text',
      type: GlossJsonType.string,
      title: 'Message',
      summary:
          'The chat line, rendered once per reader. {{ subject.name }} is who '
          'connected, {{ viewer.name }} is who is reading.',
      docKey: 'connections.text',
      defaultLiteral: '""',
    ),
  ],
);

const GlossJsonObject _connectionsVariantNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'priority',
      type: GlossJsonType.integer,
      title: 'Priority',
      summary: 'Highest matching priority replaces the base message.',
      docKey: 'connections.variants.priority',
      defaultLiteral: '0',
    ),
    GlossJsonField(
      key: 'when',
      type: GlossJsonType.string,
      title: 'Condition',
      summary: 'Typed boolean expression. Blank rejects the whole file.',
      docKey: 'connections.variants.when',
    ),
    GlossJsonField(
      key: 'presentation',
      type: GlossJsonType.object,
      title: 'Message',
      summary: 'The line this variant sends instead.',
      node: _connectionsPresentationNode,
    ),
  ],
);

const GlossJsonObject _connectionsSectionNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'enabled',
      type: GlossJsonType.boolean,
      title: 'Enabled',
      summary: 'A block that is here is on unless this says otherwise.',
      docKey: 'connections.enabled',
      defaultLiteral: 'true',
    ),
    glossShowField,
    GlossJsonField(
      key: 'audience',
      type: GlossJsonType.string,
      title: 'Audience',
      summary:
          'Proxy setting. A standalone server is the whole network and '
          'broadcasts either way.',
      docKey: 'connections.audience',
      values: <GlossJsonValue>[
        GlossJsonValue('"network"', summary: 'Everyone on the network.'),
        GlossJsonValue('"server"', summary: 'Only this backend server.'),
      ],
      defaultLiteral: '"network"',
    ),
    GlossJsonField(
      key: 'presentation',
      type: GlossJsonType.object,
      title: 'Message',
      summary: 'The line this event broadcasts.',
      node: _connectionsPresentationNode,
    ),
    GlossJsonField(
      key: 'variants',
      type: GlossJsonType.array,
      title: 'Conditional messages',
      summary: 'Alternative lines chosen per reader by condition and priority.',
      docKey: 'connections.variants',
      node: GlossJsonArray(
        item: _connectionsVariantNode,
        itemType: GlossJsonType.object,
        itemTitle: 'Conditional message',
        itemSummary: 'One condition and the line it sends.',
      ),
    ),
  ],
);

final GlossJsonObject glossConnectionsJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _schemaVersionField(1),
    _revisionField,
    glossShowField,
    const GlossJsonField(
      key: 'firstJoin',
      type: GlossJsonType.object,
      title: 'First join message',
      summary:
          'Server only: replaces join for a player joining this server for the first time.',
      node: _connectionsSectionNode,
    ),
    const GlossJsonField(
      key: 'join',
      type: GlossJsonType.object,
      title: 'Join message',
      summary: 'Broadcast when a player connects. Leave it out to say nothing.',
      docKey: 'connections.join',
      node: _connectionsSectionNode,
    ),
    const GlossJsonField(
      key: 'leave',
      type: GlossJsonType.object,
      title: 'Leave message',
      summary:
          'Broadcast when a player disconnects. Leave it out to say nothing.',
      docKey: 'connections.leave',
      node: _connectionsSectionNode,
    ),
    const GlossJsonField(
      key: 'switch',
      type: GlossJsonType.any,
      title: 'Server switch (proxy only)',
      summary:
          'Read and ignored here: a backend never sees a switch. Kept for the '
          'proxy that shares this file.',
      docKey: 'connections.switch',
    ),
  ],
);

// --- emoji ------------------------------------------------------------------

final GlossJsonObject glossEmojiJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _schemaVersionField(1),
    _revisionField,
    glossShowField,
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
    glossDisplayRefreshField,
    const GlossJsonField(
      key: 'overflow',
      type: GlossJsonType.string,
      title: 'Overflow',
      summary:
          'At the sender limit, replace the oldest bubble or reject the new message.',
      defaultLiteral: '"replace-oldest"',
      values: <GlossJsonValue>[
        GlossJsonValue('"replace-oldest"'),
        GlossJsonValue('"reject-new"'),
      ],
    ),
    const GlossJsonField(
      key: 'stackDistance',
      type: GlossJsonType.number,
      title: 'Stack spread',
      summary: 'Stack spread',
      defaultLiteral: '0.26',
    ),
    const GlossJsonField(
      key: 'maxPerSender',
      type: GlossJsonType.integer,
      title: 'Count',
      summary: 'Count',
      defaultLiteral: '4',
    ),
    const GlossJsonField(
      key: 'blacklistWorlds',
      type: GlossJsonType.array,
      title: 'World',
      summary: 'World',
      defaultLiteral: '[]',
    ),
    const GlossJsonField(
      key: 'format',
      type: GlossJsonType.string,
      title: 'Format',
      summary: 'Format',
      defaultLiteral: '"{message}"',
    ),

    _schemaVersionField(glossBubbleCurrentSchemaVersion),
    _revisionField,
    glossDisplayStyleField,
    glossHologramBoxField,
    glossShowField,
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
    glossParticleLayersField,
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
    glossShowField,
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
    glossShowField,
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

const GlossJsonObject _tabLayoutSlotNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'column',
      type: GlossJsonType.integer,
      title: 'Column',
      summary: 'Column. Range 0..3.',
    ),
    GlossJsonField(
      key: 'row',
      type: GlossJsonType.integer,
      title: 'Row',
      summary: 'Row. Range 0..19.',
    ),
    GlossJsonField(
      key: 'text',
      type: GlossJsonType.string,
      title: 'Text',
      summary: 'Text.',
    ),
    GlossJsonField(
      key: 'skin',
      type: GlossJsonType.string,
      title: 'Skin',
      summary: 'Skin.',
    ),
    GlossJsonField(
      key: 'ping',
      type: GlossJsonType.integer,
      title: 'Ping',
      summary: 'Ping. Range -1..10000.',
    ),
    GlossJsonField(
      key: 'hat',
      type: GlossJsonType.boolean,
      title: 'Hat',
      summary: 'Hat.',
    ),
  ],
);

const GlossJsonObject _tabLayoutSortKeyNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'expression',
      type: GlossJsonType.string,
      title: 'Expression',
      summary: 'Expression.',
    ),
    GlossJsonField(
      key: 'type',
      type: GlossJsonType.string,
      title: 'Type',
      summary: 'Type.',
      values: <GlossJsonValue>[
        GlossJsonValue('"number"'),
        GlossJsonValue('"text"'),
      ],
    ),
    GlossJsonField(
      key: 'direction',
      type: GlossJsonType.string,
      title: 'Direction',
      summary: 'Direction.',
      values: <GlossJsonValue>[
        GlossJsonValue('"ascending"'),
        GlossJsonValue('"descending"'),
      ],
    ),
  ],
);

const GlossJsonObject _tabLayoutSectionNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'id',
      type: GlossJsonType.string,
      title: 'Id',
      summary: 'Id.',
    ),
    GlossJsonField(
      key: 'column',
      type: GlossJsonType.integer,
      title: 'Column',
      summary: 'Column. Range 0..3.',
    ),
    GlossJsonField(
      key: 'row',
      type: GlossJsonType.integer,
      title: 'Row',
      summary: 'Row. Range 0..19.',
    ),
    GlossJsonField(
      key: 'columns',
      type: GlossJsonType.integer,
      title: 'Columns',
      summary: 'Columns. Range 1..4.',
    ),
    GlossJsonField(
      key: 'rows',
      type: GlossJsonType.integer,
      title: 'Rows',
      summary: 'Rows. Range 1..20.',
    ),
    GlossJsonField(
      key: 'filter',
      type: GlossJsonType.string,
      title: 'Filter',
      summary: 'Filter.',
    ),
    GlossJsonField(
      key: 'format',
      type: GlossJsonType.string,
      title: 'Format',
      summary: 'Format.',
    ),
    GlossJsonField(
      key: 'sort',
      type: GlossJsonType.array,
      title: 'Sort',
      summary: 'Sort.',
      node: GlossJsonArray(item: _tabLayoutSortKeyNode),
    ),
    GlossJsonField(
      key: 'overflow',
      type: GlossJsonType.string,
      title: 'Overflow',
      summary: 'Overflow.',
      values: <GlossJsonValue>[
        GlossJsonValue('"hide"'),
        GlossJsonValue('"count"'),
      ],
    ),
    GlossJsonField(
      key: 'overflowFormat',
      type: GlossJsonType.string,
      title: 'OverflowFormat',
      summary: 'OverflowFormat.',
    ),
    GlossJsonField(
      key: 'includeNpcs',
      type: GlossJsonType.boolean,
      title: 'IncludeNpcs',
      summary: 'IncludeNpcs.',
    ),
    GlossJsonField(
      key: 'skin',
      type: GlossJsonType.string,
      title: 'Skin',
      summary: 'Skin.',
    ),
    GlossJsonField(
      key: 'hat',
      type: GlossJsonType.boolean,
      title: 'Hat',
      summary: 'Hat.',
    ),
  ],
);

const GlossJsonObject _tabLayoutLayoutPresentationNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'entries',
      type: GlossJsonType.integer,
      title: 'Entries',
      summary: 'Entries. Range 1..80.',
    ),
    GlossJsonField(
      key: 'slots',
      type: GlossJsonType.array,
      title: 'Slots',
      summary: 'Slots.',
      node: GlossJsonArray(item: _tabLayoutSlotNode),
    ),
    GlossJsonField(
      key: 'sections',
      type: GlossJsonType.array,
      title: 'Sections',
      summary: 'Sections.',
      node: GlossJsonArray(item: _tabLayoutSectionNode),
    ),
    GlossJsonField(
      key: 'skins',
      type: GlossJsonType.object,
      title: 'Skins',
      summary: 'Skins.',
      node: GlossJsonObject(
        openKeyType: GlossJsonType.object,
        openKeySummary:
            'Named skin with value and optional signature, each up to 16384 characters.',
      ),
    ),
  ],
);

const GlossJsonObject _tabLayoutLayoutVariantNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'id',
      type: GlossJsonType.string,
      title: 'Id',
      summary: 'Id.',
    ),
    GlossJsonField(
      key: 'priority',
      type: GlossJsonType.integer,
      title: 'Priority',
      summary: 'Priority.',
    ),
    GlossJsonField(
      key: 'when',
      type: GlossJsonType.string,
      title: 'When',
      summary: 'When.',
    ),
    GlossJsonField(
      key: 'presentation',
      type: GlossJsonType.object,
      title: 'Presentation',
      summary: 'Presentation.',
      node: _tabLayoutLayoutPresentationNode,
    ),
  ],
);
const GlossJsonObject _tabLayoutNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'entries',
      type: GlossJsonType.integer,
      title: 'Entries',
      summary: 'Entries. Range 1..80.',
    ),
    GlossJsonField(
      key: 'slots',
      type: GlossJsonType.array,
      title: 'Slots',
      summary: 'Slots.',
      node: GlossJsonArray(item: _tabLayoutSlotNode),
    ),
    GlossJsonField(
      key: 'sections',
      type: GlossJsonType.array,
      title: 'Sections',
      summary: 'Sections.',
      node: GlossJsonArray(item: _tabLayoutSectionNode),
    ),
    GlossJsonField(
      key: 'skins',
      type: GlossJsonType.object,
      title: 'Skins',
      summary: 'Skins.',
      node: GlossJsonObject(
        openKeyType: GlossJsonType.object,
        openKeySummary:
            'Named skin with value and optional signature, each up to 16384 characters.',
      ),
    ),
    GlossJsonField(
      key: 'enabled',
      type: GlossJsonType.boolean,
      title: 'Enabled',
      summary: 'Enabled.',
    ),
    GlossJsonField(
      key: 'show',
      type: GlossJsonType.any,
      title: 'Show',
      summary: 'Show.',
    ),
    GlossJsonField(
      key: 'variants',
      type: GlossJsonType.array,
      title: 'Variants',
      summary: 'Variants.',
      node: GlossJsonArray(item: _tabLayoutLayoutVariantNode),
    ),
  ],
);

final GlossJsonObject glossTablistJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _schemaVersionField(glossTablistCurrentSchemaVersion),
    _revisionField,
    glossShowField,
    const GlossJsonField(
      key: 'layout',
      type: GlossJsonType.object,
      title: 'Layout',
      summary: 'Count-derived client grid and conditional roster sections.',
      node: _tabLayoutNode,
    ),
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

final GlossJsonObject _realDropLabelsNode = GlossJsonObject(
  fields: <GlossJsonField>[
    glossDisplayRefreshField,
    const GlossJsonField(
      key: 'show',
      type: GlossJsonType.any,
      title: 'Show condition',
      summary: 'Show condition',
      defaultLiteral: 'true',
    ),
    const GlossJsonField(
      key: 'preserveCustomNames',
      type: GlossJsonType.boolean,
      title: 'Custom name',
      summary: 'Custom name',
      defaultLiteral: 'true',
    ),

    const GlossJsonField(
      key: 'enabled',
      type: GlossJsonType.boolean,
      title: 'Enabled',
      summary: 'Shows the stack label.',
      defaultLiteral: 'true',
    ),
    const GlossJsonField(
      key: 'yOffset',
      type: GlossJsonType.number,
      title: 'Y offset',
      summary: 'Blocks above the stack the label floats. Clamped to -4..16.',
      defaultLiteral: '0.55',
    ),
    const GlossJsonField(
      key: 'format',
      type: GlossJsonType.string,
      title: 'Format',
      summary: 'Stack label text; {count} and {type} are replaced.',
      docKey: 'realDrops.labels.format',
      defaultLiteral: '"&7{count}x {type}"',
    ),
    const GlossJsonField(
      key: 'useItemDisplayNames',
      type: GlossJsonType.boolean,
      title: 'Use item display names',
      summary: 'A renamed item shows its own name as {type}.',
      docKey: 'realDrops.labels.useItemDisplayNames',
      defaultLiteral: 'false',
    ),
    const GlossJsonField(
      key: 'names',
      type: GlossJsonType.object,
      title: 'Names',
      summary: 'Per-material {type} names, keyed by Bukkit material.',
      docKey: 'realDrops.labels.names',
      defaultLiteral: '{}',
      node: _realDropLabelNamesNode,
    ),
    const GlossJsonField(
      key: 'bundle',
      type: GlossJsonType.object,
      title: 'Bundle',
      summary: 'Label text for a dropped bundle that carries stacks.',
      docKey: 'realDrops.labels.bundle',
      node: _realDropLabelBundleNode,
    ),
    glossDisplayStyleField,
    glossHologramBoxField,
  ],
);

const GlossJsonObject _realDropLabelNamesNode = GlossJsonObject(
  openKeyType: GlossJsonType.string,
  openKeyTitle: 'Material name',
  openKeySummary: 'The {type} text for this material.',
);

const GlossJsonObject _realDropLabelBundleNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'format',
      type: GlossJsonType.string,
      title: 'Format',
      summary: 'Single-line label; {total} and {contents} are replaced.',
      docKey: 'realDrops.labels.bundle.format',
      defaultLiteral: '"&7Bundle &8(&7{total} items&8): &7{contents}"',
    ),
    GlossJsonField(
      key: 'entryLimit',
      type: GlossJsonType.integer,
      title: 'Entry limit',
      summary: 'Materials listed before +N more. Clamped to 1..10.',
      docKey: 'realDrops.labels.bundle.entryLimit',
      defaultLiteral: '3',
    ),
    GlossJsonField(
      key: 'vertical',
      type: GlossJsonType.boolean,
      title: 'Vertical',
      summary: 'One line per material instead of a single line.',
      docKey: 'realDrops.labels.bundle.vertical',
      defaultLiteral: 'true',
    ),
    GlossJsonField(
      key: 'headerFormat',
      type: GlossJsonType.string,
      title: 'Header format',
      summary: 'First vertical line; {total} is replaced.',
      docKey: 'realDrops.labels.bundle.headerFormat',
      defaultLiteral: '"&eBundle &8(&e{total} items&8)"',
    ),
    GlossJsonField(
      key: 'entryFormat',
      type: GlossJsonType.string,
      title: 'Entry format',
      summary: 'One vertical line per material; {count} and {type}.',
      docKey: 'realDrops.labels.bundle.entryFormat',
      defaultLiteral: '"&7- &f{count}x {type}"',
    ),
    GlossJsonField(
      key: 'moreFormat',
      type: GlossJsonType.string,
      title: 'More format',
      summary: 'Last vertical line when materials are hidden; {remaining}.',
      docKey: 'realDrops.labels.bundle.moreFormat',
      defaultLiteral: '"&8+{remaining} more"',
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
    GlossJsonField(
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
    glossParticleLayersField,
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
    glossShowField,
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
      key: 'aggregationTicks',
      type: GlossJsonType.integer,
      title: 'Aggregation ticks',
      summary: 'Net health sampling window, 1 through 200 ticks.',
      defaultLiteral: '2',
    ),
    GlossJsonField(
      key: 'maxPendingSamples',
      type: GlossJsonType.integer,
      title: 'Maximum pending samples',
      summary:
          'Global pending target capacity, 1 through 16384. New targets are rejected when full.',
      defaultLiteral: '256',
    ),
    GlossJsonField(
      key: 'viewRange',
      type: GlossJsonType.number,
      title: 'View range',
      summary: 'View range',
      defaultLiteral: '48',
    ),
    GlossJsonField(
      key: 'debounceMs',
      type: GlossJsonType.integer,
      title: 'Lifetime',
      summary: 'Lifetime',
      defaultLiteral: '150',
    ),

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

final GlossJsonObject _damageIndicatorStyleNode = GlossJsonObject(
  fields: <GlossJsonField>[
    const GlossJsonField(
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

final GlossJsonObject _damageIndicatorCompletePresentationNode =
    GlossJsonObject(
      fields: <GlossJsonField>[
        glossDisplayRefreshField,
        glossDisplayStyleField,
        glossHologramBoxField,
        const GlossJsonField(
          key: 'format',
          type: GlossJsonType.string,
          title: 'Format',
          summary: 'Minecraft text. Use {amount} for the health change.',
        ),
        const GlossJsonField(
          key: 'offset',
          type: GlossJsonType.array,
          title: 'Offset',
          summary: 'Spawn offset from the entity as [x, y, z] blocks.',
          node: glossVector3Node,
        ),
        const GlossJsonField(
          key: 'motion',
          type: GlossJsonType.object,
          title: 'Motion',
          summary: 'Closed-form trajectory and roll.',
          node: _damageIndicatorMotionNode,
        ),
        const GlossJsonField(
          key: 'transform',
          type: GlossJsonType.object,
          title: 'Transform',
          summary: 'Scale interpolation and fade timing.',
          node: _damageIndicatorTransformNode,
        ),
        glossParticleLayersField,
      ],
    );

final GlossJsonObject _damageIndicatorVariantNode = GlossJsonObject(
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
      summary: 'Highest matching priority wins.',
      defaultLiteral: '0',
    ),
    const GlossJsonField(
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
    glossShowField,
    const GlossJsonField(
      key: 'limits',
      type: GlossJsonType.object,
      title: 'Limits',
      summary: 'Spawn admission, lifetime and number formatting.',
      node: _damageIndicatorLimitsNode,
    ),
    GlossJsonField(
      key: 'damage',
      type: GlossJsonType.object,
      title: 'Damage',
      summary: 'Conditional presentations for health loss.',
      node: _damageIndicatorStyleNode,
    ),
    GlossJsonField(
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

final GlossJsonObject _entityOverlayLineNode = GlossJsonObject(
  fields: <GlossJsonField>[
    const GlossJsonField(
      key: 'id',
      type: GlossJsonType.string,
      title: 'Line id',
      summary: 'Unique line id.',
    ),
    GlossJsonField(
      key: 'type',
      type: GlossJsonType.string,
      title: 'Line type',
      summary: 'Text, repeated Insight detail, or blank spacer.',
      values: <GlossJsonValue>[
        for (final String type in glossEntityOverlayLineTypes)
          GlossJsonValue('"$type"'),
      ],
      defaultLiteral: '"text"',
    ),
    const GlossJsonField(
      key: 'text',
      type: GlossJsonType.string,
      title: 'Line text',
      summary:
          'Gloss text with entity tokens, MiniMessage, expressions and animations.',
    ),
    const GlossJsonField(
      key: 'show',
      type: GlossJsonType.any,
      title: 'Line visibility',
      summary: 'Boolean or visibility expression.',
      defaultLiteral: 'true',
    ),
  ],
);

const GlossJsonObject glossHealthBarNode = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'glyph',
      type: GlossJsonType.string,
      title: 'Text',
      summary: 'Text',
      defaultLiteral: '"|"',
    ),
    GlossJsonField(
      key: 'emptyGlyph',
      type: GlossJsonType.string,
      title: 'Text',
      summary: 'Text',
      defaultLiteral: '"|"',
    ),
    GlossJsonField(
      key: 'healthyColor',
      type: GlossJsonType.string,
      title: 'Color',
      summary: 'Color',
      defaultLiteral: '"&a"',
    ),
    GlossJsonField(
      key: 'warningColor',
      type: GlossJsonType.string,
      title: 'Color',
      summary: 'Color',
      defaultLiteral: '"&e"',
    ),
    GlossJsonField(
      key: 'criticalColor',
      type: GlossJsonType.string,
      title: 'Color',
      summary: 'Color',
      defaultLiteral: '"&c"',
    ),
    GlossJsonField(
      key: 'damageColor',
      type: GlossJsonType.string,
      title: 'Color',
      summary: 'Color',
      defaultLiteral: '"&c"',
    ),
    GlossJsonField(
      key: 'emptyColor',
      type: GlossJsonType.string,
      title: 'Color',
      summary: 'Color',
      defaultLiteral: '"&8"',
    ),
    GlossJsonField(
      key: 'warningThreshold',
      type: GlossJsonType.number,
      title: 'Health',
      summary: 'Health',
      defaultLiteral: '0.5',
    ),
    GlossJsonField(
      key: 'criticalThreshold',
      type: GlossJsonType.number,
      title: 'Health',
      summary: 'Health',
      defaultLiteral: '0.25',
    ),
    GlossJsonField(
      key: 'decimals',
      type: GlossJsonType.integer,
      title: 'Decimals',
      summary: 'Decimals',
      defaultLiteral: '1',
    ),
  ],
);

final GlossJsonObject glossEntityOverlaysJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _displayVariantsField(overlay: true),
    const GlossJsonField(
      key: 'healthBar',
      type: GlossJsonType.object,
      title: 'Health and placement',
      summary: 'Health and placement',
      node: glossHealthBarNode,
    ),
    _schemaVersionField(glossEntityOverlaysCurrentSchemaVersion),
    _revisionField,
    const GlossJsonField(
      key: 'enabled',
      type: GlossJsonType.boolean,
      title: 'Enabled',
      summary: 'Enables nearby living-entity overlays.',
      defaultLiteral: 'true',
    ),
    const GlossJsonField(
      key: 'includePlayers',
      type: GlossJsonType.boolean,
      title: 'Include players',
      summary: 'Includes nearby players.',
      defaultLiteral: 'true',
    ),
    const GlossJsonField(
      key: 'overrideNametag',
      type: GlossJsonType.boolean,
      title: 'Override mob nametags',
      summary: 'Hides native mob nametags while Gloss displays their names.',
      defaultLiteral: 'false',
    ),
    for (final (
          String key,
          String title,
          String summary,
          String value,
          bool integer,
        )
        field
        in <(String, String, String, String, bool)>[
          (
            'range',
            'Display range',
            'Nearby radius in blocks. Gloss clamps to 1..64.',
            '16',
            false,
          ),
          (
            'updateIntervalTicks',
            'Update interval',
            'Ticks between updates. Gloss clamps to 1..40.',
            '5',
            true,
          ),
          (
            'maxEntitiesPerViewer',
            'Entity limit',
            'Overlays per viewer. Gloss clamps to 1..256.',
            '16',
            true,
          ),
          (
            'snapshotReadLimit',
            'Snapshot read limit',
            'Distinct captured reads per entity. Gloss clamps to 16..65536.',
            '4096',
            true,
          ),
          (
            'maxActiveOverlays',
            'Overlay limit',
            'Overlays tracked at once across every viewer. Gloss clamps to 16..16384.',
            '1024',
            true,
          ),
          (
            'verticalOffset',
            'Vertical offset',
            'Blocks above entity bounds. Gloss clamps to -2..8.',
            '0.35',
            false,
          ),
          (
            'healthSegments',
            'Health segments',
            'Segment count. Gloss clamps to 1..40.',
            '10',
            true,
          ),
          (
            'hitHighlightMs',
            'Hit highlight',
            'Recent-hit lifetime in milliseconds. Gloss clamps to 0..10000.',
            '750',
            true,
          ),
        ])
      GlossJsonField(
        key: field.$1,
        type: field.$5 ? GlossJsonType.integer : GlossJsonType.number,
        title: field.$2,
        summary: field.$3,
        defaultLiteral: field.$4,
      ),
    const GlossJsonField(
      key: 'blacklistWorlds',
      type: GlossJsonType.array,
      title: 'Excluded worlds',
      summary: 'World names where overlays are hidden.',
      node: _plainStringsNode,
    ),
    const GlossJsonField(
      key: 'excludedEntityTypes',
      type: GlossJsonType.array,
      title: 'Excluded entity types',
      summary: 'Excluded Bukkit entity types. ARMOR_STAND by default.',
      node: _plainStringsNode,
    ),
    const GlossJsonField(
      key: 'show',
      type: GlossJsonType.any,
      title: 'Pane visibility',
      summary: 'Boolean or visibility expression.',
      defaultLiteral: 'true',
    ),
    GlossJsonField(
      key: 'lines',
      type: GlossJsonType.array,
      title: 'Lines',
      summary: 'Ordered text, Insight and spacer rows.',
      node: GlossJsonArray(
        item: _entityOverlayLineNode,
        itemType: GlossJsonType.object,
        itemTitle: 'Line',
        itemSummary: 'Line',
      ),
    ),
    GlossJsonField(
      key: 'style',
      type: GlossJsonType.object,
      title: 'Display style',
      summary: 'Native Gloss display style.',
      node: glossIconStyleNode,
    ),
    const GlossJsonField(
      key: 'box',
      type: GlossJsonType.object,
      title: 'Box decoration',
      summary: 'A uniform box that follows the visible text size.',
      node: glossHologramBoxNode,
    ),
    glossParticleLayersField,
  ],
);
final GlossJsonObject glossNamesJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    _schemaVersionField(1),
    _revisionField,
    for (final GlossNameCategory category in GlossNameCategory.values)
      GlossJsonField(
        key: category.name,
        type: GlossJsonType.object,
        title: switch (category) {
          GlossNameCategory.materials => 'Materials',
          GlossNameCategory.entities => 'Entities',
          GlossNameCategory.worlds => 'World',
          GlossNameCategory.gameModes => 'Game modes',
          GlossNameCategory.dimensions => 'Dimensions',
          GlossNameCategory.damageCauses => 'Damage causes',
          GlossNameCategory.effects => 'Effects',
          GlossNameCategory.groups => 'Groups',
        },
        summary: 'Names',
        node: const GlossJsonObject(
          fields: <GlossJsonField>[],
          openKeyType: GlossJsonType.string,
        ),
      ),
  ],
);

const GlossJsonField _channelFilteringField = GlossJsonField(
  key: 'filtering',
  type: GlossJsonType.object,
  title: 'Filter policy',
  summary:
      'RE2 limits and policy for incomplete filtering; variants replace the whole block.',
  node: GlossJsonObject(
    fields: <GlossJsonField>[
      GlossJsonField(
        key: 'syntax',
        type: GlossJsonType.string,
        title: 'syntax',
        summary: 'syntax',
        values: <GlossJsonValue>[GlossJsonValue('"re2"')],
      ),
      GlossJsonField(
        key: 'maxInputCharacters',
        type: GlossJsonType.integer,
        title: 'maxInputCharacters',
        summary: 'maxInputCharacters',
      ),
      GlossJsonField(
        key: 'maxOutputCharacters',
        type: GlossJsonType.integer,
        title: 'maxOutputCharacters',
        summary: 'maxOutputCharacters',
      ),
      GlossJsonField(
        key: 'maxPatternCharacters',
        type: GlossJsonType.integer,
        title: 'maxPatternCharacters',
        summary: 'maxPatternCharacters',
      ),
      GlossJsonField(
        key: 'maxReplacementCharacters',
        type: GlossJsonType.integer,
        title: 'maxReplacementCharacters',
        summary: 'maxReplacementCharacters',
      ),
      GlossJsonField(
        key: 'maxFilters',
        type: GlossJsonType.integer,
        title: 'maxFilters',
        summary: 'maxFilters',
      ),
      GlossJsonField(
        key: 'maxMatches',
        type: GlossJsonType.integer,
        title: 'maxMatches',
        summary: 'maxMatches',
      ),
      GlossJsonField(
        key: 'maxProgramSize',
        type: GlossJsonType.integer,
        title: 'maxProgramSize',
        summary: 'maxProgramSize',
      ),
      GlossJsonField(
        key: 'maxNestingDepth',
        type: GlossJsonType.integer,
        title: 'maxNestingDepth',
        summary: 'maxNestingDepth',
      ),
      GlossJsonField(
        key: 'maxWorkUnits',
        type: GlossJsonType.integer,
        title: 'maxWorkUnits',
        summary: 'maxWorkUnits',
      ),
      GlossJsonField(
        key: 'budgetMicros',
        type: GlossJsonType.integer,
        title: 'budgetMicros',
        summary: 'budgetMicros',
      ),
      GlossJsonField(
        key: 'onLimit',
        type: GlossJsonType.string,
        title: 'onLimit',
        summary: 'onLimit',
        values: <GlossJsonValue>[
          GlossJsonValue('"drop"'),
          GlossJsonValue('"keep-completed"'),
        ],
      ),
    ],
  ),
);

const GlossJsonObject glossChannelJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'schemaVersion',
      type: GlossJsonType.integer,
      title: 'schemaVersion',
      summary: 'Channel schema version 2.',
      values: <GlossJsonValue>[GlossJsonValue('2')],
    ),
    GlossJsonField(
      key: 'revision',
      type: GlossJsonType.integer,
      title: 'revision',
      summary: 'revision',
    ),
    GlossJsonField(
      key: 'show',
      type: GlossJsonType.any,
      title: 'show',
      summary:
          'Boolean expression gating whether a sender may talk in this channel.',
    ),
    GlossJsonField(
      key: 'channel',
      type: GlossJsonType.object,
      title: 'channel',
      summary: 'channel',
      node: GlossJsonObject(
        fields: <GlossJsonField>[
          GlossJsonField(
            key: 'name',
            type: GlossJsonType.string,
            title: 'name',
            summary: 'name',
          ),
          GlossJsonField(
            key: 'aliases',
            type: GlossJsonType.array,
            title: 'aliases',
            summary: 'aliases',
            node: GlossJsonArray(
              itemType: GlossJsonType.string,
              itemTitle: 'Entry',
              itemSummary: 'Entry',
            ),
          ),
          GlossJsonField(
            key: 'default',
            type: GlossJsonType.boolean,
            title: 'default',
            summary:
                'The channel new players talk in; lowest priority wins when several are marked.',
          ),
          GlossJsonField(
            key: 'scope',
            type: GlossJsonType.string,
            title: 'scope',
            summary:
                'party is reserved and resolves to global until a party SPI exists.',
          ),
          GlossJsonField(
            key: 'radius',
            type: GlossJsonType.integer,
            title: 'radius',
            summary: 'Required and positive when scope is radius.',
          ),
          GlossJsonField(
            key: 'permission',
            type: GlossJsonType.string,
            title: 'permission',
            summary:
                'Gates sending; with scope permission it also gates hearing. Required for that scope.',
          ),
          GlossJsonField(
            key: 'priority',
            type: GlossJsonType.integer,
            title: 'priority',
            summary: 'priority',
          ),
          GlossJsonField(
            key: 'cooldownTicks',
            type: GlossJsonType.integer,
            title: 'cooldownTicks',
            summary: 'cooldownTicks',
          ),
        ],
      ),
    ),
    GlossJsonField(
      key: 'format',
      type: GlossJsonType.string,
      title: 'format',
      summary:
          'The per-viewer line. Reads sender.*, viewer.*, message, card and channel.*.',
    ),
    GlossJsonField(
      key: 'card',
      type: GlossJsonType.array,
      title: 'card',
      summary:
          'Hover-card lines rendered per viewer and joined with newlines into {{ card }}.',
      node: GlossJsonArray(
        itemType: GlossJsonType.string,
        itemTitle: 'Entry',
        itemSummary: 'Entry',
      ),
    ),
    GlossJsonField(
      key: 'mentions',
      type: GlossJsonType.object,
      title: 'mentions',
      summary: 'mentions',
      node: GlossJsonObject(
        fields: <GlossJsonField>[
          GlossJsonField(
            key: 'enabled',
            type: GlossJsonType.boolean,
            title: 'enabled',
            summary: 'enabled',
          ),
          GlossJsonField(
            key: 'pattern',
            type: GlossJsonType.string,
            title: 'pattern',
            summary:
                'Must contain {name}; the literal halves may carry regex metacharacters.',
          ),
          GlossJsonField(
            key: 'render',
            type: GlossJsonType.string,
            title: 'render',
            summary:
                'Rendered only for the mentioned viewer. mention.name is the selected nametag identity; mention.username is the typed account name.',
          ),
          GlossJsonField(
            key: 'messageFormat',
            type: GlossJsonType.string,
            title: 'messageFormat',
            summary:
                'Complete message format shown to the mentioned recipient. Uses the ordinary channel format variables.',
          ),
          GlossJsonField(
            key: 'sound',
            type: GlossJsonType.string,
            title: 'sound',
            summary:
                'Namespaced sound played to the mentioned viewer; empty plays nothing.',
          ),
          GlossJsonField(
            key: 'permission',
            type: GlossJsonType.string,
            title: 'permission',
            summary: 'permission',
          ),
        ],
      ),
    ),
    GlossJsonField(
      key: 'items',
      type: GlossJsonType.object,
      title: 'items',
      summary: 'items',
      node: GlossJsonObject(
        fields: <GlossJsonField>[
          GlossJsonField(
            key: 'enabled',
            type: GlossJsonType.boolean,
            title: 'enabled',
            summary: 'enabled',
          ),
          GlossJsonField(
            key: 'token',
            type: GlossJsonType.string,
            title: 'token',
            summary: 'token',
          ),
          GlossJsonField(
            key: 'permission',
            type: GlossJsonType.string,
            title: 'permission',
            summary: 'permission',
          ),
          GlossJsonField(
            key: 'render',
            type: GlossJsonType.string,
            title: 'render',
            summary:
                'Item label template with {{ item.name }}, {{ item.amount }}, {{ item.id }} and {{ item.countSuffix }}.',
          ),
        ],
      ),
    ),
    GlossJsonField(
      key: 'links',
      type: GlossJsonType.object,
      title: 'links',
      summary: 'links',
      node: GlossJsonObject(
        fields: <GlossJsonField>[
          GlossJsonField(
            key: 'enabled',
            type: GlossJsonType.boolean,
            title: 'enabled',
            summary: 'enabled',
          ),
          GlossJsonField(
            key: 'render',
            type: GlossJsonType.string,
            title: 'render',
            summary: 'Reads link.host and link.url.',
          ),
        ],
      ),
    ),
    GlossJsonField(
      key: 'filters',
      type: GlossJsonType.array,
      title: 'filters',
      summary:
          'Applied in order to the plain message; a match that empties it cancels the message.',
      node: GlossJsonArray(
        itemType: GlossJsonType.object,
        itemTitle: 'Entry',
        itemSummary: 'Entry',
        item: GlossJsonObject(
          fields: <GlossJsonField>[
            GlossJsonField(
              key: 'match',
              type: GlossJsonType.string,
              title: 'match',
              summary: 'RE2 pattern; no lookaround or backreferences.',
            ),
            GlossJsonField(
              key: 'replace',
              type: GlossJsonType.string,
              title: 'replace',
              summary: 'Literal replacement; captured groups are not expanded.',
            ),
          ],
        ),
      ),
    ),
    _channelFilteringField,
    GlossJsonField(
      key: 'throttle',
      type: GlossJsonType.object,
      title: 'throttle',
      summary: 'throttle',
      node: GlossJsonObject(
        fields: <GlossJsonField>[
          GlossJsonField(
            key: 'repeatWindowTicks',
            type: GlossJsonType.integer,
            title: 'repeatWindowTicks',
            summary: 'repeatWindowTicks',
          ),
          GlossJsonField(
            key: 'maxRepeats',
            type: GlossJsonType.integer,
            title: 'maxRepeats',
            summary: 'maxRepeats',
          ),
          GlossJsonField(
            key: 'minIntervalTicks',
            type: GlossJsonType.integer,
            title: 'minIntervalTicks',
            summary: 'minIntervalTicks',
          ),
        ],
      ),
    ),
    GlossJsonField(
      key: 'variants',
      type: GlossJsonType.array,
      title: 'variants',
      summary:
          'Highest priority matching variant replaces each provided block; omitted blocks inherit. Filters and throttle use sender conditions; presentation uses each viewer.',
      node: GlossJsonArray(
        itemType: GlossJsonType.object,
        itemTitle: 'Entry',
        itemSummary: 'Entry',
        item: GlossJsonObject(
          fields: <GlossJsonField>[
            GlossJsonField(
              key: 'id',
              type: GlossJsonType.string,
              title: 'id',
              summary: 'id',
            ),
            GlossJsonField(
              key: 'priority',
              type: GlossJsonType.integer,
              title: 'priority',
              summary: 'priority',
            ),
            GlossJsonField(
              key: 'when',
              type: GlossJsonType.string,
              title: 'when',
              summary: 'when',
            ),
            GlossJsonField(
              key: 'format',
              type: GlossJsonType.string,
              title: 'format',
              summary:
                  'The per-viewer line. Reads sender.*, viewer.*, message, card and channel.*.',
            ),
            GlossJsonField(
              key: 'card',
              type: GlossJsonType.array,
              title: 'card',
              summary:
                  'Hover-card lines rendered per viewer and joined with newlines into {{ card }}.',
              node: GlossJsonArray(
                itemType: GlossJsonType.string,
                itemTitle: 'Entry',
                itemSummary: 'Entry',
              ),
            ),
            GlossJsonField(
              key: 'mentions',
              type: GlossJsonType.object,
              title: 'mentions',
              summary: 'mentions',
              node: GlossJsonObject(
                fields: <GlossJsonField>[
                  GlossJsonField(
                    key: 'enabled',
                    type: GlossJsonType.boolean,
                    title: 'enabled',
                    summary: 'enabled',
                  ),
                  GlossJsonField(
                    key: 'pattern',
                    type: GlossJsonType.string,
                    title: 'pattern',
                    summary:
                        'Must contain {name}; the literal halves may carry regex metacharacters.',
                  ),
                  GlossJsonField(
                    key: 'render',
                    type: GlossJsonType.string,
                    title: 'render',
                    summary:
                        'Rendered only for the mentioned viewer. mention.name is the selected nametag identity; mention.username is the typed account name.',
                  ),
                  GlossJsonField(
                    key: 'messageFormat',
                    type: GlossJsonType.string,
                    title: 'messageFormat',
                    summary:
                        'Complete message format shown to the mentioned recipient. Uses the ordinary channel format variables.',
                  ),
                  GlossJsonField(
                    key: 'sound',
                    type: GlossJsonType.string,
                    title: 'sound',
                    summary:
                        'Namespaced sound played to the mentioned viewer; empty plays nothing.',
                  ),
                  GlossJsonField(
                    key: 'permission',
                    type: GlossJsonType.string,
                    title: 'permission',
                    summary: 'permission',
                  ),
                ],
              ),
            ),
            GlossJsonField(
              key: 'items',
              type: GlossJsonType.object,
              title: 'items',
              summary: 'items',
              node: GlossJsonObject(
                fields: <GlossJsonField>[
                  GlossJsonField(
                    key: 'enabled',
                    type: GlossJsonType.boolean,
                    title: 'enabled',
                    summary: 'enabled',
                  ),
                  GlossJsonField(
                    key: 'token',
                    type: GlossJsonType.string,
                    title: 'token',
                    summary: 'token',
                  ),
                  GlossJsonField(
                    key: 'permission',
                    type: GlossJsonType.string,
                    title: 'permission',
                    summary: 'permission',
                  ),
                  GlossJsonField(
                    key: 'render',
                    type: GlossJsonType.string,
                    title: 'render',
                    summary:
                        'Item label template with {{ item.name }}, {{ item.amount }}, {{ item.id }} and {{ item.countSuffix }}.',
                  ),
                ],
              ),
            ),
            GlossJsonField(
              key: 'links',
              type: GlossJsonType.object,
              title: 'links',
              summary: 'links',
              node: GlossJsonObject(
                fields: <GlossJsonField>[
                  GlossJsonField(
                    key: 'enabled',
                    type: GlossJsonType.boolean,
                    title: 'enabled',
                    summary: 'enabled',
                  ),
                  GlossJsonField(
                    key: 'render',
                    type: GlossJsonType.string,
                    title: 'render',
                    summary: 'Reads link.host and link.url.',
                  ),
                ],
              ),
            ),
            GlossJsonField(
              key: 'filters',
              type: GlossJsonType.array,
              title: 'filters',
              summary:
                  'Applied in order to the plain message; a match that empties it cancels the message.',
              node: GlossJsonArray(
                itemType: GlossJsonType.object,
                itemTitle: 'Entry',
                itemSummary: 'Entry',
                item: GlossJsonObject(
                  fields: <GlossJsonField>[
                    GlossJsonField(
                      key: 'match',
                      type: GlossJsonType.string,
                      title: 'match',
                      summary: 'RE2 pattern; no lookaround or backreferences.',
                    ),
                    GlossJsonField(
                      key: 'replace',
                      type: GlossJsonType.string,
                      title: 'replace',
                      summary:
                          'Literal replacement; captured groups are not expanded.',
                    ),
                  ],
                ),
              ),
            ),
            _channelFilteringField,
            GlossJsonField(
              key: 'throttle',
              type: GlossJsonType.object,
              title: 'throttle',
              summary: 'throttle',
              node: GlossJsonObject(
                fields: <GlossJsonField>[
                  GlossJsonField(
                    key: 'repeatWindowTicks',
                    type: GlossJsonType.integer,
                    title: 'repeatWindowTicks',
                    summary: 'repeatWindowTicks',
                  ),
                  GlossJsonField(
                    key: 'maxRepeats',
                    type: GlossJsonType.integer,
                    title: 'maxRepeats',
                    summary: 'maxRepeats',
                  ),
                  GlossJsonField(
                    key: 'minIntervalTicks',
                    type: GlossJsonType.integer,
                    title: 'minIntervalTicks',
                    summary: 'minIntervalTicks',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ],
);

// --- registry ---------------------------------------------------------------

/// Every kind this model covers, keyed by the workspace kind enum's `name`.
///
/// The two kinds deliberately absent are `panel`, which is an editor-only flow
/// map with no code view at all, and `containerPreview`, whose format is the
/// preview schema rather than a Gloss runtime document.
final Map<String, GlossJsonObject> glossJsonSchemas =
    <String, GlossJsonObject>{
      'channel': glossChannelJsonSchema,
      'names': glossNamesJsonSchema,
      'strings': glossStringsJsonSchema,
      'presets': glossPresetsJsonSchema,
      'inventory': glossInventoryJsonSchema,
      'waypoint': glossWaypointJsonSchema,
      'glyph': glossGlyphJsonSchema,
      'behavior': glossBehaviorJsonSchema,
      'menu': glossMenuJsonSchema,
      'hologram': glossHologramJsonSchema,
      'animation': glossAnimationJsonSchema,
      'scoreboard': glossScoreboardJsonSchema,
      'surface': glossSurfaceJsonSchema,
      'motd': glossMotdJsonSchema,
      'connections': glossConnectionsJsonSchema,
      'emoji': glossEmojiJsonSchema,
      'bubbleStyle': glossBubbleStyleJsonSchema,
      'tablist': glossTablistJsonSchema,
      'realDrops': glossRealDropsJsonSchema,
      'damageIndicators': glossDamageIndicatorsJsonSchema,
      'entityOverlays': glossEntityOverlaysJsonSchema,
    }.map(
      (
        String kind,
        GlossJsonObject schema,
      ) => MapEntry<String, GlossJsonObject>(
        kind,
        kind == 'presets'
            ? schema
            : GlossJsonObject(
                fields: <GlossJsonField>[
                  ...schema.fields,
                  const GlossJsonField(
                    key: 'preset',
                    type: GlossJsonType.string,
                    title: 'Preset',
                    summary:
                        'Named preset in this document collection. Authored fields override inherited values.',
                  ),
                ],
                discriminator: schema.discriminator,
                variants: schema.variants,
                openKeyType: schema.openKeyType,
                openKeyTitle: schema.openKeyTitle,
                openKeySummary: schema.openKeySummary,
              ),
      ),
    );

/// The model for [kindName], or null when this build has none for that kind.
GlossJsonObject? glossJsonSchemaFor(String kindName) =>
    glossJsonSchemas[kindName];
