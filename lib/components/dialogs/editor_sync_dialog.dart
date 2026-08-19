library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../services/editor_sync.dart';
import 'dialog_parts.dart';

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
    required this.onConfirm,
    required this.onCancel,
    super.key,
  });

  final EditorSyncSession? session;
  final bool loading;
  final String? error;
  final bool hasLocalConflicts;
  final Uri? relayEndpoint;
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
      title: 'Connect server project',
      maxWidth: 720,
      actions: <Widget>[
        Button(
          variant: ButtonVariant.outline,
          onPressed: onCancel,
          label: 'Cancel',
        ),
        Button(
          variant: ButtonVariant.primary,
          disabled: loading || onConfirm == null,
          onPressed: onConfirm,
          icon: ArcaneIcon.link(size: IconSize.sm),
          label: project != null
              ? hasLocalConflicts
                    ? 'Replace matching resources'
                    : 'Connect project'
              : error != null
              ? 'Retry relay'
              : 'Read from relay',
        ),
      ],
      children: <Widget>[
        dom.div(classes: 'hui-dialog-body hui-stagger', <Widget>[
          if (loading)
            const ArcaneAlert.info(
              message: 'Reading the project from the configured relay…',
            ),
          if (error != null) ArcaneAlert.error(message: error!),
          if (!loading && project == null && relayEndpoint != null)
            ArcaneAlert.warning(
              title: 'Approve relay connection',
              message:
                  'This capability will make a bounded request to '
                  '$relayEndpoint. Continue only if you trust the server '
                  'that gave you this link.',
            ),
          if (project != null) ...<Widget>[
            const ArcaneAlert.warning(
              message:
                  'Review this server-owned scope before importing it. Local '
                  'autosave never publishes; only Publish to Server does.',
            ),
            if (hasLocalConflicts)
              const ArcaneAlert.error(
                message:
                    'Matching runtime ids or asset paths already exist locally. '
                    'Continuing replaces only those matching resources after '
                    'this confirmation.',
              ),
            HuiDialogSection(
              title: project.kind == 'panel' ? 'World panel' : 'Menu',
              description:
                  'Exact menu source is retained. World panels use the strict '
                  'runtime panel contract.',
              children: <Widget>[
                dom.dl(classes: 'hui-handoff-details', <Widget>[
                  const dom.dt(<Widget>[Text('Server id')]),
                  dom.dd(<Widget>[
                    dom.code(<Widget>[Text(project.subjectId)]),
                  ]),
                  const dom.dt(<Widget>[Text('Menus')]),
                  dom.dd(<Widget>[Text('${project.menus.length}')]),
                  const dom.dt(<Widget>[Text('Images')]),
                  dom.dd(<Widget>[Text('${project.images.length}')]),
                  const dom.dt(<Widget>[Text('New menu ids')]),
                  dom.dd(<Widget>[
                    dom.code(<Widget>[
                      Text(
                        project.constraints.newMenuPrefix ?? 'not permitted',
                      ),
                    ]),
                  ]),
                  const dom.dt(<Widget>[Text('New image paths')]),
                  dom.dd(<Widget>[
                    dom.code(<Widget>[
                      Text(
                        project.constraints.newImagePrefix ?? 'not permitted',
                      ),
                    ]),
                  ]),
                  const dom.dt(<Widget>[Text('Expires')]),
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
    title: 'Server project changed',
    maxWidth: 620,
    actions: <Widget>[
      Button(
        variant: ButtonVariant.outline,
        onPressed: onExport,
        label: 'Export local work',
      ),
      Button(
        variant: ButtonVariant.destructive,
        onPressed: onRefresh,
        label: 'Replace with server copy',
      ),
      Button(onPressed: onClose, label: 'Keep editing'),
    ],
    children: <Widget>[
      dom.div(classes: 'hui-dialog-body', <Widget>[
        ArcaneAlert.error(
          message:
              message ??
              'The server revision no longer matches. Your local edits are '
                  'still safe. Export them, or explicitly replace this bound '
                  'scope with the latest server copy.',
        ),
      ]),
    ],
  );
}
