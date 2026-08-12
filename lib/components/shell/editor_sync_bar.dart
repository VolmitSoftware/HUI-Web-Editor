library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../services/editor_sync.dart';

class EditorSyncBar extends StatelessWidget {
  const EditorSyncBar({
    required this.status,
    required this.subjectId,
    required this.busy,
    required this.onPublish,
    required this.onCopyLink,
    required this.onDisconnect,
    this.message,
    super.key,
  });

  final EditorSyncStatus status;
  final String subjectId;
  final bool busy;
  final String? message;
  final VoidCallback onPublish;
  final VoidCallback onCopyLink;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-sync-bar is-${status.name}',
    attributes: const <String, String>{'role': 'status', 'aria-live': 'polite'},
    <Widget>[
      dom.div(classes: 'hui-sync-identity', <Widget>[
        ArcaneIcon.cloud(size: IconSize.sm),
        dom.strong(<Widget>[Text(_label(status))]),
        dom.code(<Widget>[Text(subjectId)]),
        if (message != null) dom.span(<Widget>[Text(message!)]),
      ]),
      dom.div(classes: 'hui-sync-actions', <Widget>[
        Button.ghost(
          size: ButtonSize.sm,
          onPressed: onCopyLink,
          icon: ArcaneIcon.copy(size: IconSize.sm),
          label: 'Copy link',
        ),
        Button.ghost(
          size: ButtonSize.sm,
          onPressed: onDisconnect,
          icon: ArcaneIcon.unlink(size: IconSize.sm),
          label: 'Disconnect',
        ),
        Button(
          size: ButtonSize.sm,
          variant: ButtonVariant.primary,
          disabled: busy || !canPublishEditorSyncStatus(status),
          onPressed: busy ? null : onPublish,
          icon: ArcaneIcon.cloudUpload(size: IconSize.sm),
          label: busy ? 'Publishing…' : 'Publish to Server',
        ),
      ]),
    ],
  );
}

String _label(EditorSyncStatus status) => switch (status) {
  EditorSyncStatus.connected => 'Connected',
  EditorSyncStatus.pending => 'Pending server apply',
  EditorSyncStatus.applied => 'Applied',
  EditorSyncStatus.conflict => 'Conflict',
  EditorSyncStatus.rejected => 'Rejected',
  EditorSyncStatus.expired => 'Expired',
  EditorSyncStatus.revoked => 'Revoked',
  EditorSyncStatus.disconnected => 'Disconnected',
  EditorSyncStatus.unavailable => 'Relay unavailable',
};
