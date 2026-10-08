import '../logic/json_schema.dart';

const List<GlossJsonField> _envelope = <GlossJsonField>[
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
    summary:
        'Server-owned counter, 1 through 9007199254740991. Leave it alone.',
    defaultLiteral: '1',
  ),
];

const GlossJsonObject glossStringsJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    ..._envelope,
    GlossJsonField(
      key: 'locale',
      type: GlossJsonType.string,
      title: 'Locale',
      summary: 'Use a language_COUNTRY locale.',
      defaultLiteral: '"en_US"',
    ),
    GlossJsonField(
      key: 'fallback',
      type: GlossJsonType.string,
      title: 'Fallback',
      summary: 'Locale used for missing entries before en_US.',
      defaultLiteral: '""',
    ),
    GlossJsonField(
      key: 'entries',
      type: GlossJsonType.object,
      title: 'Entries',
      summary: 'Authored text templates addressed by lang().',
      node: GlossJsonObject(openKeyType: GlossJsonType.string),
    ),
  ],
);

const GlossJsonObject glossWaypointJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    ..._envelope,
    GlossJsonField(
      key: 'show',
      type: GlossJsonType.any,
      title: 'Visibility',
      summary: 'Boolean or expression. Leave blank to always show.',
      defaultLiteral: 'true',
    ),
    GlossJsonField(
      key: 'anchor',
      type: GlossJsonType.object,
      title: 'Anchor',
      summary:
          'Choose a complete world position, an entity UUID, or a player name.',
      node: GlossJsonObject(
        fields: <GlossJsonField>[
          GlossJsonField(
            key: 'world',
            type: GlossJsonType.string,
            title: 'World',
            summary: 'World',
          ),
          GlossJsonField(
            key: 'x',
            type: GlossJsonType.number,
            title: 'X',
            summary: 'X',
          ),
          GlossJsonField(
            key: 'y',
            type: GlossJsonType.number,
            title: 'Y',
            summary: 'Y',
          ),
          GlossJsonField(
            key: 'z',
            type: GlossJsonType.number,
            title: 'Z',
            summary: 'Z',
          ),
          GlossJsonField(
            key: 'entity',
            type: GlossJsonType.string,
            title: 'Entity',
            summary: 'Enter an entity UUID.',
          ),
          GlossJsonField(
            key: 'player',
            type: GlossJsonType.string,
            title: 'Player',
            summary: 'Player',
          ),
        ],
      ),
    ),
    GlossJsonField(
      key: 'color',
      type: GlossJsonType.string,
      title: 'Color',
      summary: 'Use a #RRGGBB color.',
      defaultLiteral: '"#ffffff"',
    ),
    GlossJsonField(
      key: 'style',
      type: GlossJsonType.string,
      title: 'Style',
      summary:
          'Use default, bowtie, or a namespaced style from the loaded Gloss pack.',
      defaultLiteral: '"default"',
    ),
    GlossJsonField(
      key: 'fallbackStyle',
      type: GlossJsonType.string,
      title: 'Fallback style',
      summary:
          'Vanilla icon while the custom style or current pack is unavailable.',
      defaultLiteral: '"default"',
      values: <GlossJsonValue>[
        GlossJsonValue('"default"'),
        GlossJsonValue('"bowtie"'),
      ],
    ),
    GlossJsonField(
      key: 'range',
      type: GlossJsonType.number,
      title: 'Range',
      summary: 'Range must be zero or greater.',
      defaultLiteral: '0',
    ),
    GlossJsonField(
      key: 'audience',
      type: GlossJsonType.object,
      title: 'Audience',
      summary: 'Audience',
      node: GlossJsonObject(
        fields: <GlossJsonField>[
          GlossJsonField(
            key: 'when',
            type: GlossJsonType.any,
            title: 'Condition',
            summary: 'Boolean or expression. Leave blank to always show.',
            defaultLiteral: 'true',
          ),
        ],
      ),
    ),
  ],
);
