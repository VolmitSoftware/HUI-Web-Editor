library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../services/editor_sync.dart';
import 'dialog_parts.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

bool editorSyncImportDialogShouldOpen({
  required Uri? relayEndpoint,
  required bool loading,
  required String? error,
  required EditorSyncSession? session,
}) => relayEndpoint != null || loading || error != null || session != null;

class EditorSyncImportDialog extends StatelessWidget {
  const EditorSyncImportDialog({
    required this.session,
    required this.loading,
    required this.error,
    required this.hasLocalConflicts,
    required this.relayEndpoint,
    required this.onExportBackup,
    required this.onConfirm,
    required this.onCancel,
    super.key,
  });

  final EditorSyncSession? session;
  final bool loading;
  final String? error;
  final bool hasLocalConflicts;
  final Uri? relayEndpoint;
  final VoidCallback onExportBackup;
  final VoidCallback? onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final EditorSyncProject? project = session?.project;
    return ArcaneDialog(
      id: 'hui-editor-sync-import-dialog',
      isOpen: editorSyncImportDialogShouldOpen(
        relayEndpoint: relayEndpoint,
        loading: loading,
        error: error,
        session: session,
      ),
      onClose: onCancel,
      title: huiText('Connect server workspace'),
      maxWidth: 720,
      actions: <Widget>[
        Button(
          variant: ButtonVariant.outline,
          onPressed: onExportBackup,
          icon: ArcaneIcon.download(size: IconSize.sm),
          label: huiText('Export backup'),
        ),
        Button(
          variant: ButtonVariant.outline,
          onPressed: onCancel,
          label: huiText('Cancel'),
        ),
        Button(
          variant: ButtonVariant.primary,
          disabled: loading || onConfirm == null,
          onPressed: onConfirm,
          icon: ArcaneIcon.link(size: IconSize.sm),
          label: project != null
              ? huiText('Replace workspace & connect')
              : error != null
              ? huiText('Retry relay')
              : huiText('Read from relay'),
        ),
      ],
      children: <Widget>[
        dom.div(classes: 'hui-dialog-body hui-stagger', <Widget>[
          if (loading)
            ArcaneAlert.info(
              message: huiText(
                'Reading the project from the configured relay…',
              ),
            ),
          if (error != null) ArcaneAlert.error(message: error!),
          if (!loading && project == null && relayEndpoint != null)
            ArcaneAlert.warning(
              title: huiText('Approve relay connection'),
              message: huiText(
                'This capability will make a bounded request to {relayEndpoint}. '
                'Continue only if you trust the server that gave you this link.',
                <String, Object?>{'relayEndpoint': relayEndpoint},
              ),
            ),
          if (project != null) ...<Widget>[
            ArcaneAlert.warning(
              message: huiText(
                'Connecting replaces the local server-backed workspace. Export a backup first if needed. Local autosave never publishes; only Publish to Server does.',
              ),
            ),
            if (hasLocalConflicts)
              ArcaneAlert.error(
                message: huiText(
                  'This local workspace contains documents or images. Continuing replaces its server-backed contents after this confirmation.',
                ),
              ),
            HuiDialogSection(
              title: huiText('Server workspace'),
              description: huiText(
                'All supported runtime document kinds and image assets round-trip as one project.',
              ),
              children: <Widget>[
                dom.dl(classes: 'hui-handoff-details', <Widget>[
                  dom.dt(<Widget>[Text(huiText('Server id'))]),
                  dom.dd(<Widget>[
                    dom.code(<Widget>[Text(project.subjectId)]),
                  ]),
                  dom.dt(<Widget>[Text(huiText('Documents'))]),
                  dom.dd(<Widget>[
                    Text(
                      huiText("{length}", <String, Object?>{
                        'length': project.documents.length,
                      }),
                    ),
                  ]),
                  dom.dt(<Widget>[Text(huiText('Images'))]),
                  dom.dd(<Widget>[
                    Text(
                      huiText("{length}", <String, Object?>{
                        'length': project.images.length,
                      }),
                    ),
                  ]),
                  dom.dt(<Widget>[Text(huiText('Document kinds'))]),
                  dom.dd(<Widget>[
                    dom.code(<Widget>[
                      Text(project.constraints.documentKinds.join(', ')),
                    ]),
                  ]),
                  dom.dt(<Widget>[Text(huiText('Deletes'))]),
                  dom.dd(<Widget>[
                    dom.code(<Widget>[
                      Text(
                        project.constraints.allowDeletes
                            ? huiText('permitted')
                            : huiText('not permitted'),
                      ),
                    ]),
                  ]),
                  dom.dt(<Widget>[Text(huiText('Expires'))]),
                  dom.dd(<Widget>[
                    Text(session!.expiresAt.toLocal().toString()),
                  ]),
                ]),
              ],
            ),
            for (final String warning in project.warnings)
              ArcaneAlert.warning(message: warning),
          ],
        ]),
      ],
    );
  }
}

class EditorSyncConflictDialog extends StatelessWidget {
  const EditorSyncConflictDialog({
    required this.isOpen,
    required this.message,
    required this.onRefresh,
    required this.onExport,
    required this.onClose,
    super.key,
  });

  final bool isOpen;
  final String? message;
  final VoidCallback onRefresh;
  final VoidCallback onExport;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => ArcaneDialog(
    id: 'hui-editor-sync-conflict-dialog',
    isOpen: isOpen,
    onClose: onClose,
    title: huiText('Server project changed'),
    maxWidth: 620,
    actions: <Widget>[
      Button(
        variant: ButtonVariant.outline,
        onPressed: onExport,
        label: huiText('Export local work'),
      ),
      Button(
        variant: ButtonVariant.destructive,
        onPressed: onRefresh,
        label: huiText('Replace with server copy'),
      ),
      Button(onPressed: onClose, label: huiText('Keep editing')),
    ],
    children: <Widget>[
      dom.div(classes: 'hui-dialog-body', <Widget>[
        ArcaneAlert.error(
          message:
              message ??
              huiText(
                'The server revision no longer matches. Your local edits are still safe. Export them, or explicitly replace this bound scope with the latest server copy.',
              ),
        ),
      ]),
    ],
  );
}
