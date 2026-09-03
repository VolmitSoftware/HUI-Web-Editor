/// Bottom status strip: issues, pointer readout, zoom, autosave state.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Listenable;

import '../../config/build_info.dart';
import '../../model/model.dart';
import '../../services/page_reload.dart';
import '../../doctype/doctype.dart';
import '../../state/editor_store.dart';
import '../../state/workspace.dart';
import '../common/class_names.dart';
import 'shell_status.dart';
import 'store_selector.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({
    required this.store,
    this.status,
    this.onOpenValidation,
    super.key,
  });

  final EditorStore store;

  /// Canvas-owned readouts. Null renders dashes instead of numbers.
  final ShellStatus? status;
  final void Function()? onOpenValidation;

  @override
  Widget build(BuildContext context) => dom.footer(
    classes: 'hui-status',
    attributes: <String, String>{'aria-label': huiText('Editor status')},
    <Widget>[
      StoreSelector<String>(
        listenable: store,
        selector: _documentSignature,
        builder: (BuildContext context, String signature) => dom.div(
          classes: 'hui-status-left',
          <Widget>[_issuesChip(), _selectionReadout()],
        ),
      ),
      const dom.div(classes: 'hui-status-spacer', <Widget>[]),
      _canvasReadout(),
      StoreSelector<String>(
        listenable: Listenable.merge(<Listenable?>[store, store.workspace]),
        selector: _saveSignature,
        builder: (BuildContext context, String signature) => _saveNote(),
      ),
      // Not const: constant span instances skip attribute patching, which
      // drops the tooltip (same shape as the footer above).
      // ignore: prefer_const_constructors
      dom.span(
        classes: 'hui-status-item hui-status-version',
        attributes: <String, String>{'title': huiText('Editor build')},
        // ignore: prefer_const_literals_to_create_immutables
        <Widget>[const Text(huiBuildBadge)],
      ),
    ],
  );

  // The whole selection, not its size and primary: swapping one member for
  // another leaves both of those unchanged while the hover text changes.
  String _documentSignature() =>
      '${store.docKind.name}|'
      '${store.workspace.docs.length}|${store.errorCount}|${store.warningCount}|'
      '${store.infoCount}|${store.selectionIds.join(',')}|'
      '${store.isMenuDoc ? store.menu.components.length : 0}';

  String _saveSignature() =>
      '${store.hasUnsavedChanges}|'
      '${store.lastSavedAt?.millisecondsSinceEpoch}|'
      '${store.workspace.lastError}';

  Widget _issuesChip() {
    if (store.isPanelDoc) {
      return dom.span(classes: 'hui-status-item', <Widget>[
        Text(huiText('Flow diagnostics shown on map')),
      ]);
    }
    final int errors = store.errorCount;
    final int warnings = store.warningCount;
    final bool clean = errors == 0 && warnings == 0;
    final String label = clean
        ? huiText('No issues')
        : <String>[
            if (errors > 0)
              huiPlural(
                'status.errors.count',
                errors,
                oneEnglish: '{count} error',
                otherEnglish: '{count} errors',
              ),
            if (warnings > 0)
              huiPlural(
                'status.warnings.count',
                warnings,
                oneEnglish: '{count} warning',
                otherEnglish: '{count} warnings',
              ),
          ].join(', ');
    final ArcaneGlyph icon = clean
        ? ArcaneIcon.circleCheck(size: IconSize.sm)
        : errors > 0
        ? ArcaneIcon.circleAlert(size: IconSize.sm)
        : ArcaneIcon.triangleAlert(size: IconSize.sm);
    return dom.span(
      classes: classNames(<String?>[
        'hui-status-chip',
        clean ? 'is-clean' : (errors > 0 ? 'is-error' : 'is-warning'),
      ]),
      <Widget>[
        Button.ghost(
          size: ButtonSize.sm,
          icon: icon,
          label: label,
          onPressed: onOpenValidation,
          attributes: <String, String>{
            'aria-label': clean
                ? huiText('No validation issues')
                : huiText(
                    '{label}. Open the validation panel.',
                    <String, Object?>{'label': label},
                  ),
          },
        ),
      ],
    );
  }

  /// A multi-selection names its size, not its primary: with eight components
  /// selected, naming one of them reads as though only that one is. The ids are
  /// still reachable — they move into the hover text, which is the only place
  /// eight of them fit in a 32px strip.
  Widget _selectionReadout() {
    if (store.isPanelDoc) {
      final int menus = store.workspace.docs
          .where((WorkspaceDoc doc) => doc.kind == DocumentTypes.menu.kind)
          .length;
      return dom.span(classes: 'hui-status-item hui-status-selection', <Widget>[
        Text(
          huiPlural(
            'status.workspace_menu_count',
            menus,
            oneEnglish: '{count} menu in workspace',
            otherEnglish: '{count} menus in workspace',
          ),
        ),
      ]);
    }
    if (!store.isMenuDoc && !store.isPreviewDoc) {
      return dom.span(classes: 'hui-status-item hui-status-selection', <Widget>[
        Text(
          huiText("{noun} document", <String, Object?>{
            'noun': store.docType.noun,
          }),
        ),
      ]);
    }
    final int selectedCount = store.selectionIds.length;
    final int count = store.menu.components.length;
    final String text = switch (selectedCount) {
      0 => huiPlural(
        'status.component-count',
        count,
        oneEnglish: '{count} component',
        otherEnglish: '{count} components',
      ),
      1 => huiText('Selected {id}', <String, Object?>{'id': store.selectedId}),
      _ => huiText('{selected} of {total} selected', <String, Object?>{
        'selected': selectedCount,
        'total': count,
      }),
    };
    if (selectedCount < 2) {
      return dom.span(classes: 'hui-status-item hui-status-selection', <Widget>[
        Text(text),
      ]);
    }
    return dom.span(
      classes: 'hui-status-item hui-status-selection',
      // `data-no-tooltip` keeps Arcane's title-to-tooltip upgrade away: it
      // re-parents the element behind Jaspr's back, and this span rebuilds on
      // every selection change.
      attributes: <String, String>{
        'data-no-tooltip': 'true',
        'title': _selectionTitle(),
      },
      <Widget>[Text(text)],
    );
  }

  /// Document order, matching the rail, so the list can be read against it.
  String _selectionTitle() {
    const int shown = 12;
    final List<String> ids = <String>[
      for (final HuiComponent component in store.selectedComponents)
        component.id.isEmpty ? huiText('(no id)') : component.id,
    ];
    if (ids.length <= shown) return ids.join(', ');
    return huiText('{ids} and {count} more', <String, Object?>{
      'ids': ids.take(shown).join(', '),
      'count': ids.length - shown,
    });
  }

  Widget _canvasReadout() {
    final ShellStatus? live = status;
    if (live == null) {
      return const dom.div(classes: 'hui-status-right', <Widget>[]);
    }
    return StoreSelector<String>(
      listenable: Listenable.merge(<Listenable?>[store, live]),
      selector: () =>
          '${store.docKind.name}|${live.pointerX}|${live.pointerY}|'
          '${live.zoom}|${live.hint}',
      builder: (BuildContext context, String signature) {
        if (!store.isMenuDoc && !store.isPreviewDoc) {
          return const dom.div(classes: 'hui-status-right', <Widget>[]);
        }
        return dom.div(classes: 'hui-status-right', <Widget>[
          if (live.hint != null)
            dom.span(classes: 'hui-status-item is-hint', <Widget>[
              Text(live.hint!),
            ]),
          dom.span(classes: 'hui-status-item is-numeric', <Widget>[
            Text(
              live.hasPointer
                  ? 'x ${_block(live.pointerX!)}  y ${_block(live.pointerY!)}'
                  : 'x --  y --',
            ),
          ]),
          dom.span(classes: 'hui-status-item is-numeric', <Widget>[
            Text(
              huiText("{round}%", <String, Object?>{
                'round': (live.zoom * 100).round(),
              }),
            ),
          ]),
        ]);
      },
    );
  }

  Widget _saveNote() {
    final String? failure = store.workspace.lastError;
    if (failure != null) {
      return dom.span(
        classes: 'hui-status-item is-error',
        attributes: const <String, String>{
          'role': 'status',
          'aria-live': 'polite',
          'aria-atomic': 'true',
        },
        <Widget>[
          Text(failure),
          if (store.workspace.requiresReload)
            Button.ghost(
              size: ButtonSize.sm,
              label: huiText('Reload'),
              onPressed: reloadEditorPage,
            )
          else if (store.hasUnsavedChanges)
            Button.ghost(
              size: ButtonSize.sm,
              label: huiText('Retry'),
              onPressed: _retryAutosave,
            ),
        ],
      );
    }
    final DateTime? saved = store.lastSavedAt;
    final String text = store.hasUnsavedChanges
        ? huiText('Saving…')
        : saved == null
        ? huiText('Autosaved locally')
        : huiText('Autosaved locally {time}', <String, Object?>{
            'time': _clock(saved),
          });
    return dom.span(
      classes: 'hui-status-item is-muted',
      attributes: const <String, String>{
        'role': 'status',
        'aria-live': 'polite',
        'aria-atomic': 'true',
      },
      <Widget>[Text(text)],
    );
  }

  static String _block(double value) => value.toStringAsFixed(2);

  static String _clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<void> _retryAutosave() async {
    final bool saved = await store.retryAutosave();
    if (saved) {
      toast.success(huiText('Workspace saved.'));
      return;
    }
    toast.error(store.workspace.lastError ?? huiText('Workspace save failed.'));
  }
}
