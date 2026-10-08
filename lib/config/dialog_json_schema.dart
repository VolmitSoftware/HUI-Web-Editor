import '../logic/json_schema.dart';

const GlossJsonArray _actions = GlossJsonArray(
  itemType: GlossJsonType.object,
  itemTitle: 'Action',
  itemSummary: 'An ordinary Gloss action.',
);
const GlossJsonObject _button = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'label',
      type: GlossJsonType.string,
      title: 'Label',
      summary: 'Button label.',
    ),
    GlossJsonField(
      key: 'tooltip',
      type: GlossJsonType.string,
      title: 'Tooltip',
      summary: 'Text shown on hover or keyboard focus.',
    ),
    GlossJsonField(
      key: 'width',
      type: GlossJsonType.integer,
      title: 'Width',
      summary: 'Native width, 1..1024.',
      defaultLiteral: '150',
    ),
    GlossJsonField(
      key: 'actions',
      type: GlossJsonType.array,
      title: 'Actions',
      summary: 'Runs once with validated input.<key> values.',
      node: _actions,
    ),
  ],
);
const GlossJsonObject _input = GlossJsonObject(
  fields: <GlossJsonField>[
    GlossJsonField(
      key: 'key',
      type: GlossJsonType.string,
      title: 'Key',
      summary: 'Unique 1..64 letters, digits or underscores.',
    ),
    GlossJsonField(
      key: 'type',
      type: GlossJsonType.string,
      title: 'Input type',
      summary: 'Native control.',
      defaultLiteral: '"text"',
      values: <GlossJsonValue>[
        GlossJsonValue('"text"'),
        GlossJsonValue('"boolean"'),
        GlossJsonValue('"single_option"'),
        GlossJsonValue('"number_range"'),
      ],
    ),
    GlossJsonField(
      key: 'label',
      type: GlossJsonType.string,
      title: 'Label',
      summary: 'Control label.',
    ),
    GlossJsonField(
      key: 'width',
      type: GlossJsonType.integer,
      title: 'Width',
      summary: 'Native width, 1..1024.',
      defaultLiteral: '200',
    ),
    GlossJsonField(
      key: 'labelVisible',
      type: GlossJsonType.boolean,
      title: 'Show label',
      summary: 'Text and option controls show their label.',
      defaultLiteral: 'true',
    ),
    GlossJsonField(
      key: 'initial',
      type: GlossJsonType.any,
      title: 'Initial value',
      summary: 'String, boolean or number matching the control.',
    ),
    GlossJsonField(
      key: 'maxLength',
      type: GlossJsonType.integer,
      title: 'Text length',
      summary: 'Text limit, 1..4096 characters.',
      defaultLiteral: '32',
    ),
    GlossJsonField(
      key: 'maxLines',
      type: GlossJsonType.integer,
      title: 'Line limit',
      summary: 'Enables multiline text with 1..4096 lines.',
    ),
    GlossJsonField(
      key: 'height',
      type: GlossJsonType.integer,
      title: 'Text height',
      summary: 'Enables multiline text with height 1..512.',
    ),
    GlossJsonField(
      key: 'options',
      type: GlossJsonType.array,
      title: 'Options',
      summary: '1..64 option objects with unique id and optional label.',
      node: GlossJsonArray(
        itemType: GlossJsonType.object,
        itemTitle: 'Option',
        item: GlossJsonObject(
          fields: <GlossJsonField>[
            GlossJsonField(
              key: 'id',
              type: GlossJsonType.string,
              title: 'Id',
              summary: 'Value returned on submit.',
            ),
            GlossJsonField(
              key: 'label',
              type: GlossJsonType.string,
              title: 'Label',
              summary: 'Text displayed in the selector.',
            ),
          ],
        ),
      ),
    ),
    GlossJsonField(
      key: 'start',
      type: GlossJsonType.number,
      title: 'Start',
      summary: 'Finite slider value at the left edge.',
    ),
    GlossJsonField(
      key: 'end',
      type: GlossJsonType.number,
      title: 'End',
      summary: 'Finite slider value at the right edge, different from start.',
    ),
    GlossJsonField(
      key: 'step',
      type: GlossJsonType.number,
      title: 'Step',
      summary: 'Optional positive step relative to initial.',
    ),
    GlossJsonField(
      key: 'labelFormat',
      type: GlossJsonType.string,
      title: 'Label translation',
      summary: 'Native translation key.',
      defaultLiteral: '"options.generic_value"',
    ),
  ],
);

const List<GlossJsonField> glossDialogActionFields = <GlossJsonField>[
  GlossJsonField(
    key: 'title',
    type: GlossJsonType.string,
    title: 'Title',
    summary: 'Native dialog title.',
  ),
  GlossJsonField(
    key: 'kind',
    type: GlossJsonType.string,
    title: 'Dialog kind',
    summary:
        'Notice has one button, confirmation two, multi_action one or more.',
    defaultLiteral: '"notice"',
    values: <GlossJsonValue>[
      GlossJsonValue('"notice"'),
      GlossJsonValue('"confirmation"'),
      GlossJsonValue('"multi_action"'),
    ],
  ),
  GlossJsonField(
    key: 'body',
    type: GlossJsonType.array,
    title: 'Body',
    summary: 'Up to 64 text blocks.',
    node: GlossJsonArray(
      itemType: GlossJsonType.object,
      itemTitle: 'Body text',
      item: GlossJsonObject(
        fields: <GlossJsonField>[
          GlossJsonField(
            key: 'text',
            type: GlossJsonType.string,
            title: 'Text',
            summary: 'Rendered text.',
          ),
          GlossJsonField(
            key: 'width',
            type: GlossJsonType.integer,
            title: 'Width',
            summary: 'Native width, 1..1024.',
            defaultLiteral: '200',
          ),
        ],
      ),
    ),
  ),
  GlossJsonField(
    key: 'inputs',
    type: GlossJsonType.array,
    title: 'Inputs',
    summary: 'Up to 64 controls, combined text length budget 16000.',
    node: GlossJsonArray(
      itemType: GlossJsonType.object,
      itemTitle: 'Input',
      item: _input,
    ),
  ),
  GlossJsonField(
    key: 'buttons',
    type: GlossJsonType.array,
    title: 'Buttons',
    summary: '1..64 buttons, according to dialog kind.',
    node: GlossJsonArray(
      itemType: GlossJsonType.object,
      itemTitle: 'Button',
      item: _button,
    ),
  ),
  GlossJsonField(
    key: 'exitButton',
    type: GlossJsonType.object,
    title: 'Exit button',
    summary: 'Optional multi_action exit button.',
    node: _button,
  ),
  GlossJsonField(
    key: 'escape',
    type: GlossJsonType.boolean,
    title: 'Escape closes',
    summary: 'Allows closing with Escape.',
    defaultLiteral: 'true',
  ),
  GlossJsonField(
    key: 'columns',
    type: GlossJsonType.integer,
    title: 'Columns',
    summary: 'Multi_action columns, 1..64.',
    defaultLiteral: '2',
  ),
  GlossJsonField(
    key: 'timeoutTicks',
    type: GlossJsonType.integer,
    title: 'Timeout',
    summary: '1..72000 ticks before this form expires.',
    defaultLiteral: '1200',
  ),
  GlossJsonField(
    key: 'unsupported',
    type: GlossJsonType.array,
    title: 'Unsupported client',
    summary: 'Actions when native dialogs cannot open.',
    node: _actions,
  ),
  GlossJsonField(
    key: 'onTimeout',
    type: GlossJsonType.array,
    title: 'Timeout actions',
    summary: 'Actions when the current unanswered dialog expires.',
    node: _actions,
  ),
];
