library;

import 'dart:convert';

import 'gloss_doc.dart';
import 'json_codec.dart';

const List<String> glossDialogTypes = <String>[
  'notice',
  'confirmation',
  'multi_action',
  'server_links',
  'dialog_list',
];

const List<String> glossDialogAfterActions = <String>[
  'close',
  'none',
  'wait_for_response',
];

const int glossDialogMaxBody = 64;
const int glossDialogMaxInputs = 32;
const int glossDialogMaxButtons = 128;
const int glossDialogMaxColumns = 16;
const int glossDialogDefaultColumns = 2;
const int glossDialogDefaultButtonWidth = 150;

bool looksLikeDialogDoc(Object? json) {
  if (json is! Map || json['schemaVersion'] is! num) return false;
  if (json.containsKey('resolution') || json.containsKey('mask')) return false;
  final Object? type = json['type'];
  if (type is String && glossDialogTypes.contains(type)) return true;
  return json.containsKey('afterAction') ||
      json.containsKey('externalTitle') ||
      json.containsKey('canCloseWithEscape') ||
      json.containsKey('inputs');
}

GlossDialogDoc decodeGlossDialogDoc(String json) {
  final Object? raw;
  try {
    raw = jsonDecode(json);
  } on FormatException catch (e) {
    throw HuiFormatException('Invalid JSON: {error}', r'$', <String, Object?>{
      'error': e.message,
    });
  }
  return GlossDialogDoc.fromJson(raw);
}

String encodeGlossDialogDoc(GlossDialogDoc doc) => huiWriteJson(doc.toJson());

GlossDialogDoc cloneGlossDialogDoc(GlossDialogDoc doc) =>
    GlossDialogDoc.fromJson(huiDeepCopy(doc.toJson()));

const Set<String> _docKnown = <String>{
  'schemaVersion',
  'revision',
  'type',
  'title',
  'externalTitle',
  'canCloseWithEscape',
  'pause',
  'afterAction',
  'body',
  'inputs',
  'buttons',
  'yes',
  'no',
  'exit',
  'columns',
  'buttonWidth',
  'dialogs',
  'fallback',
  'select',
  'variants',
};

final class GlossDialogBody {
  GlossDialogBody({
    this.type = 'text',
    this.text = '',
    this.width,
    this.height,
    this.description,
    this.showTooltip = true,
    this.showDecorations = true,
    Map<String, dynamic>? item,
    Map<String, dynamic>? extras,
  }) : item = item ?? <String, dynamic>{},
       extras = extras ?? <String, dynamic>{};

  String type;
  String text;
  int? width;
  int? height;
  String? description;
  bool showTooltip;
  bool showDecorations;
  Map<String, dynamic> item;
  Map<String, dynamic> extras;

  static GlossDialogBody fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossDialogBody(
      type: huiReadString(map, 'type', fallback: 'text'),
      text: huiReadString(map, 'text'),
      width: map['width'] == null ? null : huiReadInt(map, 'width'),
      height: map['height'] == null ? null : huiReadInt(map, 'height'),
      description: map['description'] is String
          ? map['description'] as String
          : null,
      showTooltip: map['showTooltip'] == null
          ? true
          : huiReadBool(map, 'showTooltip'),
      showDecorations: map['showDecorations'] == null
          ? true
          : huiReadBool(map, 'showDecorations'),
      item: map['item'] is Map
          ? huiDeepCopyMap(huiReadObject(map['item'], '$path.item'))
          : <String, dynamic>{},
      extras: huiCollectExtras(map, const <String>{
        'type',
        'text',
        'width',
        'height',
        'description',
        'showTooltip',
        'showDecorations',
        'item',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'type': type,
    if (text.isNotEmpty) 'text': text,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (description != null && description!.trim().isNotEmpty)
      'description': description,
    if (item.isNotEmpty) 'item': huiDeepCopyMap(item),
    if (!showTooltip) 'showTooltip': false,
    if (!showDecorations) 'showDecorations': false,
  }, extras);

  GlossDialogBody copy() => GlossDialogBody(
    type: type,
    text: text,
    width: width,
    height: height,
    description: description,
    showTooltip: showTooltip,
    showDecorations: showDecorations,
    item: huiDeepCopyMap(item),
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossDialogInputOption {
  GlossDialogInputOption({
    this.id = '',
    this.label = '',
    this.initial = false,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? <String, dynamic>{};

  String id;
  String label;
  bool initial;
  Map<String, dynamic> extras;

  static GlossDialogInputOption fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossDialogInputOption(
      id: huiReadString(map, 'id'),
      label: huiReadString(map, 'label'),
      initial: huiReadBool(map, 'initial'),
      extras: huiCollectExtras(map, const <String>{'id', 'label', 'initial'}),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'id': id,
    if (label.isNotEmpty) 'label': label,
    if (initial) 'initial': true,
  }, extras);

  GlossDialogInputOption copy() => GlossDialogInputOption(
    id: id,
    label: label,
    initial: initial,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossDialogInput {
  GlossDialogInput({
    this.type = 'text',
    this.key = '',
    this.label = '',
    this.width,
    this.initial,
    this.start,
    this.end,
    this.step,
    this.maxLength,
    List<GlossDialogInputOption>? options,
    Map<String, dynamic>? extras,
  }) : options = options ?? <GlossDialogInputOption>[],
       extras = extras ?? <String, dynamic>{};

  String type;
  String key;
  String label;
  int? width;
  Object? initial;
  num? start;
  num? end;
  num? step;
  int? maxLength;
  List<GlossDialogInputOption> options;
  Map<String, dynamic> extras;

  static GlossDialogInput fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossDialogInput(
      type: huiReadString(map, 'type', fallback: 'text'),
      key: huiReadString(map, 'key'),
      label: huiReadString(map, 'label'),
      width: map['width'] == null ? null : huiReadInt(map, 'width'),
      initial: map['initial'],
      start: map['start'] is num ? map['start'] as num : null,
      end: map['end'] is num ? map['end'] as num : null,
      step: map['step'] is num ? map['step'] as num : null,
      maxLength: map['maxLength'] == null ? null : huiReadInt(map, 'maxLength'),
      options: <GlossDialogInputOption>[
        for (final (int index, Object? option) in huiReadList(
          map['options'],
        ).indexed)
          GlossDialogInputOption.fromJson(option, '$path.options[$index]'),
      ],
      extras: huiCollectExtras(map, const <String>{
        'type',
        'key',
        'label',
        'width',
        'initial',
        'start',
        'end',
        'step',
        'maxLength',
        'options',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'type': type,
    'key': key,
    if (label.isNotEmpty) 'label': label,
    if (width != null) 'width': width,
    if (initial != null) 'initial': initial,
    if (start != null) 'start': start,
    if (end != null) 'end': end,
    if (step != null) 'step': step,
    if (maxLength != null) 'maxLength': maxLength,
    if (options.isNotEmpty)
      'options': <Map<String, dynamic>>[
        for (final GlossDialogInputOption option in options) option.toJson(),
      ],
  }, extras);

  GlossDialogInput copy() => GlossDialogInput(
    type: type,
    key: key,
    label: label,
    width: width,
    initial: initial,
    start: start,
    end: end,
    step: step,
    maxLength: maxLength,
    options: <GlossDialogInputOption>[
      for (final GlossDialogInputOption option in options) option.copy(),
    ],
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossDialogButton {
  GlossDialogButton({
    this.label = '',
    this.tooltip,
    this.width,
    List<Map<String, dynamic>>? actions,
    Map<String, dynamic>? extras,
  }) : actions = actions ?? <Map<String, dynamic>>[],
       extras = extras ?? <String, dynamic>{};

  String label;
  String? tooltip;
  int? width;
  List<Map<String, dynamic>> actions;
  Map<String, dynamic> extras;

  static GlossDialogButton fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossDialogButton(
      label: huiReadString(map, 'label'),
      tooltip: map['tooltip'] is String ? map['tooltip'] as String : null,
      width: map['width'] == null ? null : huiReadInt(map, 'width'),
      actions: <Map<String, dynamic>>[
        for (final Object? action in huiReadList(map['actions']))
          if (action is Map)
            huiDeepCopyMap(huiReadObject(action, '$path.actions')),
      ],
      extras: huiCollectExtras(map, const <String>{
        'label',
        'tooltip',
        'width',
        'actions',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'label': label,
    if (tooltip != null && tooltip!.trim().isNotEmpty) 'tooltip': tooltip,
    if (width != null) 'width': width,
    if (actions.isNotEmpty)
      'actions': <Map<String, dynamic>>[
        for (final Map<String, dynamic> action in actions)
          huiDeepCopyMap(action),
      ],
  }, extras);

  GlossDialogButton copy() => GlossDialogButton(
    label: label,
    tooltip: tooltip,
    width: width,
    actions: <Map<String, dynamic>>[
      for (final Map<String, dynamic> action in actions) huiDeepCopyMap(action),
    ],
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossDialogFallback {
  GlossDialogFallback({this.inventory, this.menu, Map<String, dynamic>? extras})
    : extras = extras ?? <String, dynamic>{};

  String? inventory;
  String? menu;
  Map<String, dynamic> extras;

  static GlossDialogFallback fromJson(Object? raw, String path) {
    final Map<String, dynamic> map = huiReadObject(raw, path);
    return GlossDialogFallback(
      inventory: map['inventory'] is String
          ? map['inventory'] as String
          : null,
      menu: map['menu'] is String ? map['menu'] as String : null,
      extras: huiCollectExtras(map, const <String>{'inventory', 'menu'}),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    if (inventory != null && inventory!.trim().isNotEmpty)
      'inventory': inventory,
    if (menu != null && menu!.trim().isNotEmpty) 'menu': menu,
  }, extras);

  GlossDialogFallback copy() => GlossDialogFallback(
    inventory: inventory,
    menu: menu,
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossDialogVariant {
  GlossDialogVariant({
    this.id = '',
    this.priority = 0,
    this.when = 'false',
    this.title = '',
    List<GlossDialogBody>? body,
    List<GlossDialogButton>? buttons,
    Map<String, dynamic>? extras,
  }) : body = body ?? <GlossDialogBody>[],
       buttons = buttons ?? <GlossDialogButton>[],
       extras = extras ?? <String, dynamic>{};

  String id;
  int priority;
  String when;
  String title;
  List<GlossDialogBody> body;
  List<GlossDialogButton> buttons;
  Map<String, dynamic> extras;

  static GlossDialogVariant fromJson(Object? raw, int index) {
    final String path = r'$.variants[' + '$index]';
    final Map<String, dynamic> map = huiReadObject(raw, path);
    final Map<String, dynamic> presentation = map['presentation'] is Map
        ? huiReadObject(map['presentation'], '$path.presentation')
        : <String, dynamic>{};
    return GlossDialogVariant(
      id: huiReadString(map, 'id'),
      priority: huiReadInt(map, 'priority'),
      when: huiReadString(map, 'when', fallback: 'false'),
      title: huiReadString(presentation, 'title'),
      body: <GlossDialogBody>[
        for (final (int bodyIndex, Object? block) in huiReadList(
          presentation['body'],
        ).indexed)
          GlossDialogBody.fromJson(
            block,
            '$path.presentation.body[$bodyIndex]',
          ),
      ],
      buttons: <GlossDialogButton>[
        for (final (int buttonIndex, Object? button) in huiReadList(
          presentation['buttons'],
        ).indexed)
          GlossDialogButton.fromJson(
            button,
            '$path.presentation.buttons[$buttonIndex]',
          ),
      ],
      extras: huiCollectExtras(map, const <String>{
        'id',
        'priority',
        'when',
        'presentation',
      }),
    );
  }

  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'id': id,
    'priority': priority,
    'when': when,
    'presentation': <String, dynamic>{
      'title': title,
      'body': <Map<String, dynamic>>[
        for (final GlossDialogBody block in body) block.toJson(),
      ],
      'buttons': <Map<String, dynamic>>[
        for (final GlossDialogButton button in buttons) button.toJson(),
      ],
    },
  }, extras);

  GlossDialogVariant copy() => GlossDialogVariant(
    id: id,
    priority: priority,
    when: when,
    title: title,
    body: <GlossDialogBody>[for (final GlossDialogBody block in body) block.copy()],
    buttons: <GlossDialogButton>[
      for (final GlossDialogButton button in buttons) button.copy(),
    ],
    extras: huiDeepCopyMap(extras),
  );
}

final class GlossDialogDoc extends GlossDoc {
  GlossDialogDoc({
    super.schemaVersion = glossCurrentSchemaVersion,
    super.revision = glossInitialRevision,
    this.type = 'notice',
    this.title = '',
    this.externalTitle,
    this.canCloseWithEscape = true,
    this.pause = false,
    this.afterAction = 'close',
    List<GlossDialogBody>? body,
    List<GlossDialogInput>? inputs,
    List<GlossDialogButton>? buttons,
    this.yes,
    this.no,
    this.exit,
    this.columns = glossDialogDefaultColumns,
    this.buttonWidth = glossDialogDefaultButtonWidth,
    List<String>? dialogs,
    this.fallback,
    GlossPrioritySelect? select,
    List<GlossDialogVariant>? variants,
    Map<String, dynamic>? extras,
  }) : body = body ?? <GlossDialogBody>[],
       inputs = inputs ?? <GlossDialogInput>[],
       buttons = buttons ?? <GlossDialogButton>[],
       dialogs = dialogs ?? <String>[],
       select = select ?? GlossPrioritySelect(),
       variants = variants ?? <GlossDialogVariant>[],
       extras = extras ?? <String, dynamic>{};

  String type;
  String title;
  String? externalTitle;
  bool canCloseWithEscape;
  bool pause;
  String afterAction;
  List<GlossDialogBody> body;
  List<GlossDialogInput> inputs;
  List<GlossDialogButton> buttons;
  GlossDialogButton? yes;
  GlossDialogButton? no;
  GlossDialogButton? exit;
  int columns;
  int buttonWidth;
  List<String> dialogs;
  GlossDialogFallback? fallback;
  GlossPrioritySelect select;
  List<GlossDialogVariant> variants;
  Map<String, dynamic> extras;

  static GlossDialogDoc fromJson(Object? raw) {
    final Map<String, dynamic> map = huiReadObject(raw, r'$');
    glossReadSchemaVersion(map, 'dialog');
    return GlossDialogDoc(
      schemaVersion: glossCurrentSchemaVersion,
      revision: glossReadRevision(map),
      type: huiReadString(map, 'type', fallback: 'notice'),
      title: huiReadString(map, 'title'),
      externalTitle: map['externalTitle'] is String
          ? map['externalTitle'] as String
          : null,
      canCloseWithEscape: map['canCloseWithEscape'] == null
          ? true
          : huiReadBool(map, 'canCloseWithEscape'),
      pause: huiReadBool(map, 'pause'),
      afterAction: huiReadString(map, 'afterAction', fallback: 'close'),
      body: <GlossDialogBody>[
        for (final (int index, Object? block) in huiReadList(
          map['body'],
        ).indexed)
          GlossDialogBody.fromJson(block, 'body[$index]'),
      ],
      inputs: <GlossDialogInput>[
        for (final (int index, Object? input) in huiReadList(
          map['inputs'],
        ).indexed)
          GlossDialogInput.fromJson(input, 'inputs[$index]'),
      ],
      buttons: <GlossDialogButton>[
        for (final (int index, Object? button) in huiReadList(
          map['buttons'],
        ).indexed)
          GlossDialogButton.fromJson(button, 'buttons[$index]'),
      ],
      yes: map['yes'] == null
          ? null
          : GlossDialogButton.fromJson(map['yes'], r'$.yes'),
      no: map['no'] == null
          ? null
          : GlossDialogButton.fromJson(map['no'], r'$.no'),
      exit: map['exit'] == null
          ? null
          : GlossDialogButton.fromJson(map['exit'], r'$.exit'),
      columns: map['columns'] == null
          ? glossDialogDefaultColumns
          : huiReadInt(map, 'columns', fallback: glossDialogDefaultColumns),
      buttonWidth: map['buttonWidth'] == null
          ? glossDialogDefaultButtonWidth
          : huiReadInt(
              map,
              'buttonWidth',
              fallback: glossDialogDefaultButtonWidth,
            ),
      dialogs: glossReadStringList(map['dialogs']),
      fallback: map['fallback'] == null
          ? null
          : GlossDialogFallback.fromJson(map['fallback'], r'$.fallback'),
      select: map['select'] == null
          ? GlossPrioritySelect()
          : GlossPrioritySelect.fromJson(map['select']),
      variants: <GlossDialogVariant>[
        for (final (int index, Object? variant) in huiReadList(
          map['variants'],
        ).indexed)
          GlossDialogVariant.fromJson(variant, index),
      ],
      extras: huiCollectExtras(map, _docKnown),
    );
  }

  @override
  Map<String, dynamic> toJson() => huiMergeExtras(<String, dynamic>{
    'schemaVersion': schemaVersion,
    'revision': revision,
    'type': type,
    'title': title,
    if (externalTitle != null && externalTitle!.trim().isNotEmpty)
      'externalTitle': externalTitle,
    'canCloseWithEscape': canCloseWithEscape,
    'pause': pause,
    'afterAction': afterAction,
    if (body.isNotEmpty)
      'body': <Map<String, dynamic>>[
        for (final GlossDialogBody block in body) block.toJson(),
      ],
    if (inputs.isNotEmpty)
      'inputs': <Map<String, dynamic>>[
        for (final GlossDialogInput input in inputs) input.toJson(),
      ],
    if (buttons.isNotEmpty)
      'buttons': <Map<String, dynamic>>[
        for (final GlossDialogButton button in buttons) button.toJson(),
      ],
    if (yes != null) 'yes': yes!.toJson(),
    if (no != null) 'no': no!.toJson(),
    if (exit != null) 'exit': exit!.toJson(),
    'columns': columns,
    'buttonWidth': buttonWidth,
    if (dialogs.isNotEmpty) 'dialogs': List<String>.of(dialogs),
    if (fallback != null) 'fallback': fallback!.toJson(),
    'select': select.toJson(),
    'variants': <Map<String, dynamic>>[
      for (final GlossDialogVariant variant in variants) variant.toJson(),
    ],
  }, extras);
}
