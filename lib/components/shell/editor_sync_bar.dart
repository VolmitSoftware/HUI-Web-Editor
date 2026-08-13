library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../services/editor_sync.dart';

class EditorSyncControls {
  const EditorSyncControls({
    required this.status,
    required this.subjectId,
    required this.busy,
    required this.onPublish,
    required this.onCopyLink,
    required this.onDisconnect,
    this.message,
  });

  final EditorSyncStatus status;
  final String subjectId;
  final bool busy;
  final String? message;
  final VoidCallback onPublish;
  final VoidCallback onCopyLink;
  final VoidCallback onDisconnect;

  bool get canPublish => busy == false && canPublishEditorSyncStatus(status);

  String get publishLabel => busy ? 'Publishing…' : 'Publish to Server';

  String get publishHint => switch (status) {
    EditorSyncStatus.connected =>
      'Publish the connected $subjectId project for server validation and apply.',
    EditorSyncStatus.applied =>
      'Publish new changes to the connected $subjectId server project.',
    EditorSyncStatus.rejected =>
      'The last publication was rejected. Fix the reported issue, then publish again.',
    EditorSyncStatus.pending =>
      'The server is still validating and applying the current publication.',
    EditorSyncStatus.conflict =>
      'Resolve the server revision conflict before publishing again.',
    EditorSyncStatus.expired =>
      'This server capability expired. Create a new link in Minecraft.',
    EditorSyncStatus.revoked =>
      'This server capability was revoked. Create a new link in Minecraft.',
    EditorSyncStatus.disconnected =>
      'This tab is disconnected from the server project.',
    EditorSyncStatus.unavailable =>
      'The configured sync relay is currently unavailable.',
  };
}

class EditorSyncBar extends StatelessWidget {
  const EditorSyncBar({required this.controls, super.key});

  final EditorSyncControls controls;

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-sync-bar is-${controls.status.name}',
    attributes: const <String, String>{'role': 'status', 'aria-live': 'polite'},
    <Widget>[
      dom.div(classes: 'hui-sync-identity', <Widget>[
        ArcaneIcon.cloud(size: IconSize.sm),
        dom.strong(<Widget>[Text(_label(controls.status))]),
        dom.code(<Widget>[Text(controls.subjectId)]),
        if (controls.message != null)
          dom.span(<Widget>[Text(controls.message!)]),
      ]),
      dom.div(classes: 'hui-sync-actions', <Widget>[
        Button.ghost(
          size: ButtonSize.sm,
          onPressed: controls.onCopyLink,
          icon: ArcaneIcon.copy(size: IconSize.sm),
          label: 'Copy link',
        ),
        Button.ghost(
          size: ButtonSize.sm,
          onPressed: controls.onDisconnect,
          icon: ArcaneIcon.unlink(size: IconSize.sm),
          label: 'Disconnect',
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
