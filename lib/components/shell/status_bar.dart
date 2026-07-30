/// Bottom status strip: issues, pointer readout, zoom, autosave state.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Listenable;

import '../../state/editor_store.dart';
import '../common/class_names.dart';
import 'shell_status.dart';
import 'store_selector.dart';

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
        attributes: const <String, String>{
          'role': 'status',
          'aria-live': 'polite',
        },
        <Widget>[
          StoreSelector<String>(
            listenable: store,
            selector: _documentSignature,
            builder: (BuildContext context, String signature) =>
                dom.div(classes: 'hui-status-left', <Widget>[
              _issuesChip(),
              _selectionReadout(),
            ]),
          ),
          const dom.div(classes: 'hui-status-spacer', <Widget>[]),
          _canvasReadout(),
          StoreSelector<String>(
            listenable: Listenable.merge(<Listenable?>[store, store.workspace]),
            selector: _saveSignature,
            builder: (BuildContext context, String signature) => _saveNote(),
          ),
        ],
      );

  String _documentSignature() => '${store.errorCount}|${store.warningCount}|'
      '${store.infoCount}|${store.selectedId}|${store.menu.components.length}';

  String _saveSignature() => '${store.hasUnsavedChanges}|'
      '${store.lastSavedAt?.millisecondsSinceEpoch}|'
      '${store.workspace.lastError}';

  Widget _issuesChip() {
    final int errors = store.errorCount;
    final int warnings = store.warningCount;
    final bool clean = errors == 0 && warnings == 0;
    final String label = clean
        ? 'No issues'
        : <String>[
            if (errors > 0) '$errors error${errors == 1 ? '' : 's'}',
            if (warnings > 0) '$warnings warning${warnings == 1 ? '' : 's'}',
          ].join(', ');
    final Widget icon = clean
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
                ? 'No validation issues'
                : '$label. Open the validation panel.',
          },
        ),
      ],
    );
  }

  Widget _selectionReadout() {
    final String? selected = store.selectedId;
    final int count = store.menu.components.length;
    final String text = selected == null
        ? '$count component${count == 1 ? '' : 's'}'
        : 'Selected $selected';
    return dom.span(classes: 'hui-status-item', <Widget>[Text(text)]);
  }

  Widget _canvasReadout() {
    final ShellStatus? live = status;
    if (live == null) {
      return const dom.div(classes: 'hui-status-right', <Widget>[]);
    }
    return StoreSelector<String>(
      listenable: live,
      selector: () => '${live.pointerX}|${live.pointerY}|'
          '${live.zoom}|${live.hint}',
      builder: (BuildContext context, String signature) => dom.div(
        classes: 'hui-status-right',
        <Widget>[
          if (live.hint != null)
            dom.span(
              classes: 'hui-status-item is-hint',
              <Widget>[Text(live.hint!)],
            ),
          dom.span(
            classes: 'hui-status-item is-numeric',
            <Widget>[
              Text(
                live.hasPointer
                    ? 'x ${_block(live.pointerX!)}  y ${_block(live.pointerY!)}'
                    : 'x --  y --',
              ),
            ],
          ),
          dom.span(
            classes: 'hui-status-item is-numeric',
            <Widget>[Text('${(live.zoom * 100).round()}%')],
          ),
        ],
      ),
    );
  }

  Widget _saveNote() {
    final String? failure = store.workspace.lastError;
    if (failure != null) {
      return dom.span(
        classes: 'hui-status-item is-error',
        <Widget>[Text(failure)],
      );
    }
    final DateTime? saved = store.lastSavedAt;
    final String text = store.hasUnsavedChanges
        ? 'Saving…'
        : saved == null
            ? 'Autosaved locally'
            : 'Autosaved locally ${_clock(saved)}';
    return dom.span(classes: 'hui-status-item is-muted', <Widget>[Text(text)]);
  }

  static String _block(double value) => value.toStringAsFixed(2);

  static String _clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}
