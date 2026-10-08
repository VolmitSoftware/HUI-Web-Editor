import '../logic/json_schema.dart';

const GlossJsonField _id = GlossJsonField(
  key: 'id',
  type: GlossJsonType.string,
  title: 'ID',
  summary:
      'Up to 64 lowercase letters, digits, underscores or hyphens; starts with a letter or digit.',
);
const GlossJsonField _image = GlossJsonField(
  key: 'image',
  type: GlossJsonType.string,
  title: 'Image',
  summary: 'Relative PNG path under images/.',
);
const List<GlossJsonField> _bitmap = <GlossJsonField>[
  _id,
  _image,
  GlossJsonField(
    key: 'height',
    type: GlossJsonType.integer,
    title: 'Height',
    summary: 'Display height, 1 through 256 pixels.',
    defaultLiteral: '8',
  ),
  GlossJsonField(
    key: 'ascent',
    type: GlossJsonType.integer,
    title: 'Ascent',
    summary:
        'Vertical offset at or below height. Defaults to height minus one.',
  ),
];

const GlossJsonObject glossGlyphJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'schemaVersion',
      type: GlossJsonType.integer,
      title: 'Schema version',
      summary: 'Schema version',
      defaultLiteral: '1',
      values: <GlossJsonValue>[GlossJsonValue('1')],
    ),
    GlossJsonField(
      key: 'revision',
      type: GlossJsonType.integer,
      title: 'Revision',
      summary: 'Server-owned revision.',
      defaultLiteral: '1',
    ),
    GlossJsonField(
      key: 'namespace',
      type: GlossJsonType.string,
      title: 'Namespace',
      summary:
          'Resource namespace: lowercase letters, digits, underscores, dots and hyphens.',
      defaultLiteral: '"gloss"',
    ),
    GlossJsonField(
      key: 'font',
      type: GlossJsonType.string,
      title: 'Font',
      summary: 'Font name within the namespace.',
      defaultLiteral: '"glyphs"',
    ),
    GlossJsonField(
      key: 'glyphs',
      type: GlossJsonType.array,
      title: 'Glyphs',
      summary: 'Bitmap glyphs; at most 1024 glyphs and overlays combined.',
      node: GlossJsonArray(
        itemType: GlossJsonType.object,
        itemTitle: 'Glyph',
        itemSummary: 'One bitmap glyph.',
        item: GlossJsonObject(
          fields: <GlossJsonField>[
            ..._bitmap,
            GlossJsonField(
              key: 'emoji',
              type: GlossJsonType.string,
              title: 'Emoji',
              summary: 'Optional emoji ID substituted for pack viewers.',
            ),
            GlossJsonField(
              key: 'fallback',
              type: GlossJsonType.string,
              title: 'Fallback',
              summary: 'Text shown without the loaded pack.',
              defaultLiteral: '""',
            ),
            GlossJsonField(
              key: 'width',
              type: GlossJsonType.integer,
              title: 'Width',
              summary: 'Optional advance-width override, 0 through 1024.',
            ),
            GlossJsonField(
              key: 'frames',
              type: GlossJsonType.integer,
              title: 'Frames',
              summary: 'Equal-width horizontal cells, 1 through 256.',
              defaultLiteral: '1',
            ),
          ],
        ),
      ),
    ),
    GlossJsonField(
      key: 'overlays',
      type: GlossJsonType.array,
      title: 'Overlays',
      summary: 'Overlay bitmaps used by overlay(id).',
      node: GlossJsonArray(
        itemType: GlossJsonType.object,
        itemTitle: 'Overlay',
        itemSummary: 'One overlay bitmap.',
        item: GlossJsonObject(
          fields: <GlossJsonField>[
            ..._bitmap,
            GlossJsonField(
              key: 'anchor',
              type: GlossJsonType.string,
              title: 'Anchor',
              summary: 'Line anchor.',
              defaultLiteral: '"center"',
              values: <GlossJsonValue>[
                GlossJsonValue('"top"'),
                GlossJsonValue('"center"'),
                GlossJsonValue('"bottom"'),
              ],
            ),
          ],
        ),
      ),
    ),
    GlossJsonField(
      key: 'space',
      type: GlossJsonType.object,
      title: 'Space provider',
      summary: 'Spacing range used by shift().',
      node: GlossJsonObject(
        fields: <GlossJsonField>[
          GlossJsonField(
            key: 'enabled',
            type: GlossJsonType.boolean,
            title: 'Enabled',
            summary: 'Include the spacing provider.',
            defaultLiteral: 'true',
          ),
          GlossJsonField(
            key: 'range',
            type: GlossJsonType.array,
            title: 'Range',
            summary: 'Ordered [minimum, maximum] within -256 through 256.',
            defaultLiteral: '[-256, 256]',
            node: GlossJsonArray(
              itemType: GlossJsonType.integer,
              itemTitle: 'Bound',
              itemSummary: 'Spacing range bound.',
            ),
          ),
        ],
      ),
    ),
    GlossJsonField(
      key: 'waypointStyles',
      type: GlossJsonType.array,
      title: 'Waypoint styles',
      summary: 'At most 128 custom locator bar styles.',
      node: GlossJsonArray(
        itemType: GlossJsonType.object,
        itemTitle: 'Style',
        itemSummary: 'A custom waypoint style.',
        item: GlossJsonObject(
          fields: <GlossJsonField>[
            _id,
            GlossJsonField(
              key: 'nearDistance',
              type: GlossJsonType.number,
              title: 'Near distance',
              summary: 'Nonnegative near distance, below farDistance.',
              defaultLiteral: '128',
            ),
            GlossJsonField(
              key: 'farDistance',
              type: GlossJsonType.number,
              title: 'Far distance',
              summary: 'Far distance, greater than nearDistance.',
              defaultLiteral: '332',
            ),
            GlossJsonField(
              key: 'sprites',
              type: GlossJsonType.array,
              title: 'Sprites',
              summary: '1 through 64 distance-ordered sprites.',
              node: GlossJsonArray(
                itemType: GlossJsonType.object,
                itemTitle: 'Sprite',
                itemSummary: 'Waypoint sprite asset.',
                item: GlossJsonObject(fields: <GlossJsonField>[_id, _image]),
              ),
            ),
          ],
        ),
      ),
    ),
  ],
);
