import '../logic/json_schema.dart';
import '../model/gloss_inventory.dart';
import 'gloss_menu_json_schema.dart';

const GlossJsonObject _components = GlossJsonObject(
  openKeyType: GlossJsonType.object,
  openKeySummary: 'A component body: decoration, button, or toggle.',
);
const GlossJsonArray _mask = GlossJsonArray(
  itemType: GlossJsonType.string,
  itemTitle: 'Mask row',
  itemSummary: 'Exactly one character per column.',
);
const GlossJsonObject _selection = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'priority',
      type: GlossJsonType.integer,
      title: 'Priority',
      summary: 'Selection priority.',
    ),
    GlossJsonField(
      key: 'when',
      type: GlossJsonType.string,
      title: 'Condition',
      summary: 'Boolean expression.',
    ),
  ],
);

final GlossJsonObject glossInventoryJsonSchema = GlossJsonObject(
  fields: <GlossJsonField>[
    const GlossJsonField(
      key: 'actions',
      type: GlossJsonType.object,
      title: 'Named actions',
      summary:
          'Up to 256 reusable action lists; call by name. Cycles and more than 32 nested calls are rejected.',
      node: GlossJsonObject(
        openKeyType: GlossJsonType.array,
        openKeySummary: 'An ordinary action list.',
      ),
    ),
    const GlossJsonField(
      key: 'schemaVersion',
      type: GlossJsonType.integer,
      title: 'Schema version',
      summary: 'Inventory schema version.',
      values: <GlossJsonValue>[GlossJsonValue('1')],
    ),
    const GlossJsonField(
      key: 'revision',
      type: GlossJsonType.integer,
      title: 'Revision',
      summary: 'Server-owned revision.',
    ),
    const GlossJsonField(
      key: 'title',
      type: GlossJsonType.string,
      title: 'Title',
      summary: 'Rendered native window title.',
    ),
    GlossJsonField(
      key: 'resolution',
      type: GlossJsonType.string,
      title: 'Resolution',
      summary: 'Supported native container size.',
      values: <GlossJsonValue>[
        for (final String size in glossInventoryResolutions)
          GlossJsonValue('"$size"'),
      ],
    ),
    const GlossJsonField(
      key: 'mask',
      type: GlossJsonType.array,
      title: 'Mask',
      summary: 'Slot layout.',
      node: _mask,
    ),
    const GlossJsonField(
      key: 'keys',
      type: GlossJsonType.object,
      title: 'Keys',
      summary: 'Mask character to component body.',
      node: _components,
    ),
    const GlossJsonField(
      key: 'slots',
      type: GlossJsonType.object,
      title: 'Slots',
      summary: 'Zero-based slot index overrides.',
      node: _components,
    ),
    const GlossJsonField(
      key: 'show',
      type: GlossJsonType.any,
      title: 'Show',
      summary: 'Visibility condition; false closes the window.',
    ),
    const GlossJsonField(
      key: 'closeOnTeleport',
      type: GlossJsonType.boolean,
      title: 'Close on teleport',
      summary: 'Close when the player teleports.',
    ),
    const GlossJsonField(
      key: 'select',
      type: GlossJsonType.object,
      title: 'Selection',
      summary: 'Condition-selected inventory.',
      node: _selection,
    ),
    GlossJsonField(
      key: 'refresh',
      type: GlossJsonType.object,
      title: 'Refresh',
      summary: 'Independent category cadences.',
      node: GlossJsonObject(
        fields: <GlossJsonField>[
          const GlossJsonField(
            key: 'mode',
            type: GlossJsonType.string,
            title: 'Mode',
            summary:
                'Dynamic skips static categories; always refreshes every enabled category.',
            values: <GlossJsonValue>[
              GlossJsonValue('"dynamic"'),
              GlossJsonValue('"always"'),
            ],
          ),
          for (final String key in <String>[
            'titleTicks',
            'slotsTicks',
            'conditionsTicks',
            'listTicks',
          ])
            GlossJsonField(
              key: key,
              type: GlossJsonType.integer,
              title: key,
              summary:
                  '0–1200 ticks; 0 disables automatic refresh. listTicks defaults to list.refreshTicks; others default to 20.',
            ),
        ],
      ),
    ),
    GlossJsonField(
      key: 'list',
      type: GlossJsonType.object,
      title: 'List',
      summary: 'Paged template content.',
      node: GlossJsonObject(
        fields: <GlossJsonField>[
          const GlossJsonField(
            key: 'area',
            type: GlossJsonType.string,
            title: 'Area',
            summary: 'One mask character occupied by list entries.',
          ),
          const GlossJsonField(
            key: 'var',
            type: GlossJsonType.string,
            title: 'Variable',
            summary: 'Entry variable, available in icons and actions.',
          ),
          const GlossJsonField(
            key: 'source',
            type: GlossJsonType.string,
            title: 'Source',
            summary: 'Expression returning a list.',
          ),
          const GlossJsonField(
            key: 'pageSize',
            type: GlossJsonType.integer,
            title: 'Page size',
            summary: 'Positive entries per page; defaults to mask area size.',
          ),
          const GlossJsonField(
            key: 'refreshTicks',
            type: GlossJsonType.integer,
            title: 'Refresh ticks',
            summary:
                '0–1200 ticks, default 20; root refresh.listTicks overrides.',
          ),
          GlossJsonField(
            key: 'template',
            type: GlossJsonType.object,
            title: 'Template',
            summary: 'Component body for each list entry.',
            node: glossComponentDataNode,
          ),
        ],
      ),
    ),
    const GlossJsonField(
      key: 'variants',
      type: GlossJsonType.array,
      title: 'Variants',
      summary: 'Conditional layouts.',
      node: GlossJsonArray(
        item: GlossJsonObject(
          fields: <GlossJsonField>[
            GlossJsonField(
              key: 'id',
              type: GlossJsonType.string,
              title: 'Id',
              summary: 'Unique variant id.',
            ),
            GlossJsonField(
              key: 'priority',
              type: GlossJsonType.integer,
              title: 'Priority',
              summary: 'Higher priorities select first.',
            ),
            GlossJsonField(
              key: 'when',
              type: GlossJsonType.string,
              title: 'When',
              summary: 'Boolean expression.',
            ),
            GlossJsonField(
              key: 'presentation',
              type: GlossJsonType.object,
              title: 'Presentation',
              summary: 'Variant layout.',
              node: GlossJsonObject(
                fields: <GlossJsonField>[
                  GlossJsonField(
                    key: 'title',
                    type: GlossJsonType.string,
                    title: 'Title',
                    summary: 'Native title; empty inherits base.',
                  ),
                  GlossJsonField(
                    key: 'mask',
                    type: GlossJsonType.array,
                    title: 'Mask',
                    summary: 'Empty inherits base mask.',
                    node: _mask,
                  ),
                  GlossJsonField(
                    key: 'keys',
                    type: GlossJsonType.object,
                    title: 'Keys',
                    summary: 'Empty inherits base keys.',
                    node: _components,
                  ),
                  GlossJsonField(
                    key: 'slots',
                    type: GlossJsonType.object,
                    title: 'Slots',
                    summary: 'Replaces base slot overrides.',
                    node: _components,
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
