import '../logic/behavior_validation.dart';
import '../logic/json_schema.dart';
import 'gloss_menu_json_schema.dart';

final GlossJsonObject glossBehaviorJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    const GlossJsonField(
      key: 'schemaVersion',
      type: GlossJsonType.integer,
      title: 'Schema version',
      summary: 'Behavior schema 2.',
      defaultLiteral: '2',
    ),
    const GlossJsonField(
      key: 'revision',
      type: GlossJsonType.integer,
      title: 'Revision',
      summary: 'Server-owned positive revision.',
    ),
    const GlossJsonField(
      key: 'enabled',
      type: GlossJsonType.boolean,
      title: 'Enabled',
      summary: 'Enable trigger subscriptions.',
      defaultLiteral: 'true',
    ),
    const GlossJsonField(
      key: 'allowServerCommands',
      type: GlossJsonType.boolean,
      title: 'Allow server commands',
      summary: 'Required before actions execute console commands.',
      defaultLiteral: 'false',
    ),
    GlossJsonField(
      key: 'matching',
      type: GlossJsonType.object,
      title: 'Chat matching',
      summary:
          'RE2 matching limits; exhausted budgets skip behavior matching and retain chat.',
      node: GlossJsonObject(
        fields: <GlossJsonField>[
          const GlossJsonField(
            key: 'syntax',
            type: GlossJsonType.string,
            title: 'Syntax',
            summary: 'RE2 only; no lookaround or backreferences.',
            defaultLiteral: '"re2"',
          ),
          for (final (String, int, int, int) limit in <(String, int, int, int)>[
            ('maxInputCharacters', 1, 32768, 4096),
            ('maxPatternCharacters', 1, 4096, 1024),
            ('maxProgramSize', 16, 1000000, 16384),
            ('maxNestingDepth', 1, 128, 32),
            ('maxWorkUnits', 1, 100000000, 2000000),
          ])
            GlossJsonField(
              key: limit.$1,
              type: GlossJsonType.integer,
              title: limit.$1,
              summary: '${limit.$2} through ${limit.$3}.',
              defaultLiteral: '${limit.$4}',
            ),
        ],
      ),
    ),
    const GlossJsonField(
      key: 'state',
      type: GlossJsonType.object,
      title: 'State declarations',
      summary: 'Named state with scope, type and optional default.',
      node: GlossJsonObject(
        openKeyType: GlossJsonType.object,
        openKeySummary: 'A state declaration.',
      ),
    ),
    GlossJsonField(
      key: 'on',
      type: GlossJsonType.array,
      title: 'Triggers',
      summary: 'At most 256 event entries.',
      node: GlossJsonArray(
        item: GlossJsonObject(
          fields: <GlossJsonField>[
            GlossJsonField(
              key: 'trigger',
              type: GlossJsonType.string,
              title: 'Trigger',
              summary: 'Event name.',
              values: <GlossJsonValue>[
                for (final String key in behaviorTriggerOptions.keys)
                  GlossJsonValue('"$key"'),
              ],
            ),
            const GlossJsonField(
              key: 'pattern',
              type: GlossJsonType.string,
              title: 'Chat pattern',
              summary: 'RE2 search; omit to match every line within limits.',
            ),
            for (final String key in <String>[
              'when',
              'permission',
              'name',
              'region',
              'material',
              'menu',
              'component',
              'scope',
            ])
              GlossJsonField(
                key: key,
                type: GlossJsonType.string,
                title: key,
                summary: 'Trigger-specific condition or selector.',
              ),
            const GlossJsonField(
              key: 'everyTicks',
              type: GlossJsonType.integer,
              title: 'Interval',
              summary: 'Interval trigger period, 1 through 1728000 ticks.',
            ),
            GlossJsonField(
              key: 'do',
              type: GlossJsonType.array,
              title: 'Actions',
              summary: 'Actions run in order after conditions pass.',
              node: GlossJsonArray(item: glossActionNode),
            ),
          ],
        ),
      ),
    ),
  ],
);
