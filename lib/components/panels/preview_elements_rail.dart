/// Left rail for a container-preview document: the ordered element list.
///
/// Paint order is document order (later elements draw in front at equal
/// `z`), so reordering is a document edit like it is for a menu component.
/// Delete lives here — deliberately not on the pixel-card surface, per E6's
/// deferral — with the same two-step arm/confirm every destructive control in
/// this editor uses; there is no browser `confirm()` anywhere.
///
/// Simpler than [ComponentsRail] on purpose: elements have no id, no
/// right-click menu and no drag handle — up/down arrows are reorder enough for
/// a list authors keep short (the format caps at 4096 compiled elements, but a
/// hand-authored document rarely has more than a dozen).
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:arcane_jaspr/core/dom_value.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show ListenableBuilder;

import '../../config/defaults.dart';
import '../../logic/validation.dart';
import '../../model/preview_doc.dart';
import '../../services/showcase_randomizer.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class PreviewElementsRail extends StatefulWidget {
  const PreviewElementsRail({required this.store, super.key});

  final EditorStore store;

  @override
  State<PreviewElementsRail> createState() => _PreviewElementsRailState();
}

class _PreviewElementsRailState extends State<PreviewElementsRail> {
  int? _armedDeleteIndex;
  int? _menuIndex;
  HuiActionMenuPoint _menuPoint = const HuiActionMenuPoint(8, 8);
  bool _typesOpen = false;

  EditorStore get _store => component.store;

  void _add(String type) {
    setState(() => _typesOpen = false);
    _store.addPreviewElement(type);
  }

  void _delete(int index) {
    setState(() => _armedDeleteIndex = null);
    _store.deletePreviewElement(index);
  }

  @override
  Widget build(BuildContext context) =>
      dom.div(classes: 'hui-rail-pane', <Widget>[
        ListenableBuilder(
          listenable: _store,
          builder: (BuildContext inner) => _body(),
        ),
      ]);

  Widget _body() {
    final HuiPreviewDoc? doc = _store.previewDoc;
    if (doc == null) return const dom.div(<Widget>[]);
    final List<HuiPreviewElement> elements = doc.elements;
    return dom.div(classes: 'hui-rail-inner', <Widget>[
      _header(elements.length),
      if (_typesOpen) _typeChooser(),
      if (elements.isEmpty)
        _empty()
      else
        dom.div(
          classes: 'hui-rail-list',
          attributes: const <String, String>{'role': 'list'},
          <Widget>[
            for (int i = 0; i < elements.length; i++)
              _row(i, elements[i], elements.length),
          ],
        ),
      if (_menuIndex != null && _menuIndex! < elements.length)
        _elementMenu(elements.length),
    ]);
  }

  Widget _header(int count) => dom.div(classes: 'hui-rail-header', <Widget>[
    dom.div(classes: 'hui-rail-heading', <Widget>[
      HuiEyebrow(huiText('Elements')),
      dom.span(classes: 'hui-rail-count', <Widget>[
        Text(huiText("{count}", <String, Object?>{'count': count})),
      ]),
    ]),
    dom.div(classes: 'hui-rail-add', <Widget>[
      Button(
        variant: ButtonVariant.primary,
        size: ButtonSize.small,
        onPressed: () => _add('cell'),
        icon: ArcaneIcon.plus(size: IconSize.sm),
        label: huiText('Add'),
        attributes: <String, String>{
          'aria-label': huiText('Add a cell element'),
        },
      ),
      Button(
        key: ValueKey<bool>(_typesOpen),
        variant: ButtonVariant.primary,
        size: ButtonSize.small,
        onPressed: () => setState(() => _typesOpen = !_typesOpen),
        styles: const ArcaneStyleData(
          raw: <String, String>{'padding': '0 4px !important'},
        ),
        attributes: <String, String>{
          'aria-label': huiText('Choose an element type'),
          'aria-expanded': _typesOpen ? 'true' : 'false',
          'data-arcane-interactive': 'true',
        },
        child: _typesOpen
            ? ArcaneIcon.chevronUp(size: IconSize.sm)
            : ArcaneIcon.chevronDown(size: IconSize.sm),
      ),
    ]),
  ]);

  Widget _typeChooser() => dom.div(
    classes: 'hui-rail-types',
    styles: const dom.Styles(
      raw: <String, String>{
        'display': 'flex',
        'flex-direction': 'column',
        'gap': '2px',
        'padding': '6px',
        'margin': '0 0 8px',
        'border': '1px solid var(--hui-border-soft)',
        'border-radius': 'var(--hui-radius)',
        'background': 'var(--hui-panel-soft)',
      },
    ),
    attributes: <String, String>{
      'role': 'group',
      'aria-label': huiText('Element types'),
    },
    <Widget>[
      for (final String type in previewElementTypes)
        dom.button(
          classes: 'hui-rail-type',
          styles: const dom.Styles(
            raw: <String, String>{
              'display': 'flex',
              'align-items': 'center',
              'gap': '8px',
              'width': '100%',
              'padding': '7px 8px',
              'border': '0',
              'border-radius': '0',
              'background': 'transparent',
              'color': 'var(--hui-text)',
              'text-align': 'left',
              'cursor': 'pointer',
              'font': 'inherit',
            },
          ),
          attributes: <String, String>{
            'type': 'button',
            'data-no-tooltip': 'true',
            'title': huiText(previewElementTypeDescriptions[type] ?? ''),
          },
          events: <String, void Function(Object)>{
            'click': (Object _) => _add(type),
          },
          <Widget>[
            _typeIcon(type),
            dom.span(<Widget>[Text(_typeLabel(type))]),
          ],
        ),
    ],
  );

  Widget _empty() => dom.div(classes: 'hui-rail-empty', <Widget>[
    ArcaneEmptyState(
      title: huiText('No elements yet'),
      description: huiText(
        'A container preview needs at least one element to '
        'draw anything. Start with a cell or a label.',
      ),
      icon: ArcaneIcon.layers(size: IconSize.lg),
      action: Button(
        variant: ButtonVariant.primary,
        size: ButtonSize.small,
        onPressed: () => _add('cell'),
        icon: ArcaneIcon.plus(size: IconSize.sm),
        label: huiText('Add your first element'),
      ),
    ),
  ]);

  Widget _row(int index, HuiPreviewElement element, int total) {
    final bool selected = _store.previewSelectedIndex == index;
    final bool armed = _armedDeleteIndex == index;
    final List<HuiIssue> issues = _store.issuesForPreviewElement(index);
    final bool hasError = issues.any(
      (HuiIssue issue) => issue.severity == HuiSeverity.error,
    );
    final bool hasWarning = issues.any(
      (HuiIssue issue) => issue.severity == HuiSeverity.warning,
    );
    final String label = '${index + 1}. ${_typeLabel(element.type)}';

    return dom.div(
      classes: 'hui-rail-item',
      styles: const dom.Styles(raw: <String, String>{'min-width': '0'}),
      attributes: const <String, String>{'role': 'listitem'},
      <Widget>[
        dom.div(
          classes: classNames(<String?>[
            'hui-rail-row',
            selected ? 'is-selected' : null,
            armed ? 'is-armed' : null,
          ]),
          events: <String, void Function(Object)>{
            'contextmenu': (Object event) => _openElementMenu(
              index,
              triggerId: _menuTriggerId(index),
              event: event,
            ),
          },
          <Widget>[
            dom.button(
              classes: 'hui-rail-main',
              attributes: <String, String>{
                'type': 'button',
                'data-no-tooltip': 'true',
                'aria-pressed': selected ? 'true' : 'false',
                'title': huiText("{label}\n{summary}", <String, Object?>{
                  'label': label,
                  'summary': _summary(element),
                }),
              },
              events: <String, void Function(Object)>{
                'click': (Object _) => _store.selectPreviewElement(index),
              },
              <Widget>[
                dom.span(
                  classes: 'hui-rail-mark',
                  attributes: const <String, String>{'aria-hidden': 'true'},
                  <Widget>[_typeIcon(element.type)],
                ),
                dom.span(classes: 'hui-rail-text', <Widget>[
                  dom.span(classes: 'hui-rail-id', <Widget>[Text(label)]),
                  dom.span(classes: 'hui-rail-summary', <Widget>[
                    Text(_summary(element)),
                  ]),
                ]),
                if (hasError || hasWarning)
                  dom.span(
                    classes: classNames(<String?>[
                      'hui-rail-dot',
                      hasError ? 'is-error' : 'is-warning',
                    ]),
                    attributes: <String, String>{
                      'aria-label': hasError
                          ? huiText('Has errors')
                          : huiText('Has warnings'),
                    },
                    const <Widget>[],
                  ),
              ],
            ),
            if (armed)
              dom.div(classes: 'hui-rail-confirm', <Widget>[
                dom.span(classes: 'hui-rail-confirm-label', <Widget>[
                  Text(huiText('Delete?')),
                ]),
                Button(
                  variant: ButtonVariant.destructive,
                  size: ButtonSize.iconSm,
                  onPressed: () => _delete(index),
                  attributes: <String, String>{
                    'aria-label': huiText("Delete {label}", <String, Object?>{
                      'label': label,
                    }),
                  },
                  child: ArcaneIcon.check(size: IconSize.sm),
                ),
                Button(
                  variant: ButtonVariant.ghost,
                  size: ButtonSize.iconSm,
                  onPressed: () => setState(() => _armedDeleteIndex = null),
                  attributes: <String, String>{
                    'aria-label': huiText('Keep it'),
                  },
                  child: ArcaneIcon.x(size: IconSize.sm),
                ),
              ])
            else
              dom.div(classes: 'hui-rail-tools', <Widget>[
                Button(
                  variant: ButtonVariant.ghost,
                  size: ButtonSize.iconSm,
                  disabled: index == 0,
                  onPressed: index == 0
                      ? null
                      : () => _store.reorderPreviewElement(index, index - 1),
                  attributes: <String, String>{
                    'aria-label': huiText("Move {label} up", <String, Object?>{
                      'label': label,
                    }),
                  },
                  child: ArcaneIcon.chevronUp(size: IconSize.sm),
                ),
                Button(
                  variant: ButtonVariant.ghost,
                  size: ButtonSize.iconSm,
                  disabled: index >= total - 1,
                  onPressed: index >= total - 1
                      ? null
                      : () => _store.reorderPreviewElement(index, index + 1),
                  attributes: <String, String>{
                    'aria-label': huiText(
                      "Move {label} down",
                      <String, Object?>{'label': label},
                    ),
                  },
                  child: ArcaneIcon.chevronDown(size: IconSize.sm),
                ),
                Button(
                  variant: ButtonVariant.ghost,
                  size: ButtonSize.iconSm,
                  id: _menuTriggerId(index),
                  onPressed: () =>
                      _openElementMenu(index, triggerId: _menuTriggerId(index)),
                  attributes: <String, String>{
                    'aria-label': huiText(
                      "Actions for {label}",
                      <String, Object?>{'label': label},
                    ),
                    'aria-haspopup': 'menu',
                    'aria-expanded': _menuIndex == index ? 'true' : 'false',
                    'data-arcane-interactive': 'true',
                  },
                  child: ArcaneIcon.ellipsisVertical(size: IconSize.sm),
                ),
              ]),
          ],
        ),
      ],
    );
  }

  String _menuTriggerId(int index) => 'hui-preview-element-actions-$index';

  void _openElementMenu(int index, {required String triggerId, Object? event}) {
    if (event != null) {
      domPreventDefault(event);
      domStopPropagation(event);
    }
    final HuiActionMenuPoint point = event == null
        ? huiActionMenuAnchor(triggerId)
        : huiActionMenuEventPoint(event);
    _store.selectPreviewElement(index);
    setState(() {
      _menuIndex = index;
      _menuPoint = point;
      _armedDeleteIndex = null;
    });
    context.binding.addPostFrameCallback(() {
      if (mounted) focusHuiActionMenu('hui-preview-element-menu');
    });
  }

  Widget _elementMenu(int total) {
    final int index = _menuIndex!;
    return HuiActionMenu(
      id: 'hui-preview-element-menu',
      label: huiText("Actions for preview element {value}", <String, Object?>{
        'value': index + 1,
      }),
      point: _menuPoint,
      onClose: () => setState(() => _menuIndex = null),
      items: <HuiActionMenuItem>[
        HuiActionMenuItem(
          label: huiText("Randomize {toLowerCase}", <String, Object?>{
            'toLowerCase': _typeLabel(
              _store.previewDoc!.elements[index].type,
            ).toLowerCase(),
          }),
          icon: ArcaneIcon.dices(size: IconSize.sm),
          onSelect: () => randomizePreviewElement(_store, index),
        ),
        HuiActionMenuItem(
          label: huiText('Duplicate'),
          icon: ArcaneIcon.copy(size: IconSize.sm),
          separatorBefore: true,
          onSelect: () => _store.duplicatePreviewElement(index),
        ),
        HuiActionMenuItem(
          label: huiText('Move to top'),
          icon: ArcaneIcon.arrowUp(size: IconSize.sm),
          disabled: index == 0,
          onSelect: () => _store.reorderPreviewElement(index, 0),
        ),
        HuiActionMenuItem(
          label: huiText('Move to bottom'),
          icon: ArcaneIcon.arrowDown(size: IconSize.sm),
          disabled: index >= total - 1,
          onSelect: () => _store.reorderPreviewElement(index, total - 1),
        ),
        HuiActionMenuItem(
          label: huiText('Delete element'),
          icon: ArcaneIcon.trash2(size: IconSize.sm),
          destructive: true,
          separatorBefore: true,
          onSelect: () => setState(() => _armedDeleteIndex = index),
        ),
      ],
    );
  }

  Widget _typeIcon(String type) => switch (type) {
    'panel' => ArcaneIcon.square(size: IconSize.sm),
    'cell' => ArcaneIcon.grid2x2(size: IconSize.sm),
    'slot' => ArcaneIcon.package(size: IconSize.sm),
    'label' => ArcaneIcon.typeIcon(size: IconSize.sm),
    _ => ArcaneIcon.circleAlert(size: IconSize.sm),
  };

  static String _typeLabel(String type) => switch (type) {
    'panel' => huiText('Panel'),
    'cell' => huiText('Cell'),
    'slot' => huiText('Slot'),
    'label' => huiText('Label'),
    _ => type.isEmpty ? huiText('(no type)') : type,
  };

  String _summary(HuiPreviewElement element) {
    final String repeat = element.repeat == null ? '' : huiText(' × repeat');
    return switch (element.type) {
      'panel' => huiText('panel{repeat}', <String, Object?>{'repeat': repeat}),
      'cell' => huiText('cell{repeat}', <String, Object?>{'repeat': repeat}),
      'slot' => huiText('slot index {index}{repeat}', <String, Object?>{
        'index': element.index ?? '?',
        'repeat': repeat,
      }),
      'label' => huiText('label{repeat}', <String, Object?>{'repeat': repeat}),
      _ => huiText('unknown type{repeat}', <String, Object?>{'repeat': repeat}),
    };
  }
}
