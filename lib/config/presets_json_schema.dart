import '../logic/document_presets.dart';
import '../logic/json_schema.dart';

const GlossJsonObject _values = GlossJsonObject(openKeyType: GlossJsonType.any);
final GlossJsonObject glossPresetsJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    const GlossJsonField(
      key: 'schemaVersion',
      type: GlossJsonType.integer,
      title: 'Schema version',
      summary: 'Preset catalog schema version.',
      values: <GlossJsonValue>[GlossJsonValue('1')],
      defaultLiteral: '1',
    ),
    const GlossJsonField(
      key: 'revision',
      type: GlossJsonType.integer,
      title: 'Revision',
      summary: 'Server-owned revision.',
      defaultLiteral: '1',
    ),
    GlossJsonField(
      key: 'defaults',
      type: GlossJsonType.object,
      title: 'Defaults',
      summary: 'Values inherited by every document in the collection.',
      node: GlossJsonObject(
        fields: <GlossJsonField>[
          for (final String kind in DocumentPresets.kinds)
            GlossJsonField(
              key: kind,
              type: GlossJsonType.object,
              title: kind,
              summary: 'Collection defaults.',
              node: _values,
            ),
        ],
      ),
    ),
    GlossJsonField(
      key: 'presets',
      type: GlossJsonType.object,
      title: 'Presets',
      summary: 'Named presets grouped by collection.',
      node: GlossJsonObject(
        fields: <GlossJsonField>[
          for (final String kind in DocumentPresets.kinds)
            GlossJsonField(
              key: kind,
              type: GlossJsonType.object,
              title: kind,
              summary: 'Named presets in this collection.',
              node: const GlossJsonObject(
                openKeyType: GlossJsonType.object,
                openKeySummary:
                    'A preset contains optional extends and an object named values.',
              ),
            ),
        ],
      ),
    ),
  ],
);
