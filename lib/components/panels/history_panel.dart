/// Bottom sheet listing the versions the server keeps of each synced document.
///
/// The index rides along with the sync project; the bytes of one version are
/// asked for only when somebody opens it, which is why a row is a button rather
/// than a preview. A loaded version can be dropped into the workspace as one
/// undoable edit, which is what makes this a recovery tool rather than a log.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/sync_history.dart';
import '../common/class_names.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class HistoryPanel extends StatelessWidget {
  const HistoryPanel({
    required this.history,
    required this.isOpen,
    required this.onClose,
    this.loadedVersion,
    this.loadedJson,
    this.loadingVersion,
    this.failure,
    this.onLoadVersion,
    this.onRestoreVersion,
    super.key,
  });

  final SyncHistory history;
  final bool isOpen;
  final VoidCallback onClose;

  /// The version whose bytes are on screen, or null while none is open.
  final SyncHistoryVersion? loadedVersion;
  final String? loadedJson;

  /// The version currently being fetched, so its row can say so.
  final SyncHistoryVersion? loadingVersion;

  final String? failure;
  final void Function(SyncHistoryVersion version)? onLoadVersion;
  final void Function(SyncHistoryVersion version, String json)?
  onRestoreVersion;

  @override
  Widget build(BuildContext context) => ArcaneSheet.bottom(
    id: 'hui-history-sheet',
    isOpen: isOpen,
    onClose: onClose,
    size: SheetSize.md,
    title: huiText('Version history'),
    description: huiText(
      'Copies the server kept when a document changed on disk, through the editor, or through a pack.',
    ),
    showCloseButton: false,
    footer: dom.div(classes: 'hui-validation-footer', <Widget>[
      Button.outline(label: huiText('Close'), onPressed: onClose),
    ]),
    child: _body(),
  );

  Widget _body() {
    final List<SyncHistoryDocument> documents = history.documents;
    if (documents.isEmpty) {
      return dom.div(classes: 'hui-validation hui-validation-clean', <Widget>[
        ArcaneEmptyState(
          title: huiText('No stored versions'),
          description: huiText(
            'The server keeps a copy each time a document changes. Nothing has changed yet.',
          ),
          icon: ArcaneIcon.history(size: IconSize.lg),
        ),
      ]);
    }
    return dom.div(classes: 'hui-validation', <Widget>[
      if (failure != null)
        dom.p(classes: 'hui-validation-fix', <Widget>[Text(failure!)]),
      // The version somebody just opened goes first: it is the thing they
      // asked for, and the list they picked it from is still below it.
      if (loadedVersion != null && loadedJson != null) _loaded(),
      for (final SyncHistoryDocument document in documents) _document(document),
    ]);
  }

  Widget _document(SyncHistoryDocument document) => dom.div(
    classes: 'hui-validation-group',
    <Widget>[
      dom.div(classes: 'hui-validation-group-head', <Widget>[
        ArcaneIcon.fileText(size: IconSize.sm),
        dom.span(classes: 'hui-eyebrow', <Widget>[
          Text(
            huiText("{severityLabel} ({length})", <String, Object?>{
              'severityLabel': '${document.kind} ${document.id}',
              'length': document.versions.length,
            }),
          ),
        ]),
      ]),
      dom.ul(classes: 'hui-validation-list', <Widget>[
        for (final SyncHistoryVersion version in document.versions)
          _row(version),
      ]),
    ],
  );

  Widget _row(SyncHistoryVersion version) {
    final bool loading =
        loadingVersion != null &&
        loadingVersion!.version == version.version &&
        loadingVersion!.kind == version.kind &&
        loadingVersion!.id == version.id;
    return dom.li(
      classes: classNames(<String?>[
        'hui-validation-row',
        loading ? 'is-info' : null,
      ]),
      <Widget>[
        dom.div(classes: 'hui-validation-body', <Widget>[
          dom.p(classes: 'hui-validation-message', <Widget>[
            Text(version.sourceLabel),
          ]),
          dom.code(classes: 'hui-validation-path', <Widget>[
            Text(
              huiText("{value} bytes", <String, Object?>{
                'value': version.bytes,
              }),
            ),
          ]),
        ]),
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.small,
          onPressed: onLoadVersion == null || loading
              ? null
              : () => onLoadVersion!(version),
          icon: ArcaneIcon.eye(size: IconSize.sm),
          label: loading ? huiText('Loading') : huiText('View'),
        ),
      ],
    );
  }

  Widget _loaded() => dom.div(classes: 'hui-validation-group', <Widget>[
    dom.div(classes: 'hui-validation-group-head', <Widget>[
      ArcaneIcon.eye(size: IconSize.sm),
      dom.span(classes: 'hui-eyebrow', <Widget>[
        Text(
          huiText("{severityLabel} ({length})", <String, Object?>{
            'severityLabel': '${loadedVersion!.kind} ${loadedVersion!.id}',
            'length': loadedJson!.split('\n').length,
          }),
        ),
      ]),
      if (onRestoreVersion != null)
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.small,
          onPressed: () => onRestoreVersion!(loadedVersion!, loadedJson!),
          icon: ArcaneIcon.history(size: IconSize.sm),
          label: huiText('Restore into workspace'),
        ),
    ]),
    dom.pre(classes: 'hui-history-source', <Widget>[Text(loadedJson!)]),
  ]);
}
