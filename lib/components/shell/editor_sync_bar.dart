library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../services/editor_sync.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

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

  String get publishLabel =>
      busy ? huiText('Publishing…') : huiText('Publish to Server');

  String get publishHint => switch (status) {
    EditorSyncStatus.connected => huiText(
      'Publish the connected {subject} project for server validation and apply.',
      <String, Object?>{'subject': subjectId},
    ),
    EditorSyncStatus.applied => huiText(
      'Publish new changes to the connected {subject} server project.',
      <String, Object?>{'subject': subjectId},
    ),
    EditorSyncStatus.rejected => huiText(
      'The last publication was rejected. Fix the reported issue, then publish again.',
    ),
    EditorSyncStatus.pending => huiText(
      'The server is still validating and applying the current publication.',
    ),
    EditorSyncStatus.conflict => huiText(
      'Resolve the server revision conflict before publishing again.',
    ),
    EditorSyncStatus.expired => huiText(
      'This server capability expired. Create a new link in Minecraft.',
    ),
    EditorSyncStatus.revoked => huiText(
      'This server capability was revoked. Create a new link in Minecraft.',
    ),
    EditorSyncStatus.disconnected => huiText(
      'This tab is disconnected from the server project.',
    ),
    EditorSyncStatus.unavailable => huiText(
      'The configured sync relay is currently unavailable.',
    ),
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
        Button(
          variant: controls.canPublish
              ? ButtonVariant.primary
              : ButtonVariant.outline,
          size: ButtonSize.sm,
          disabled: controls.canPublish == false,
          onPressed: controls.onPublish,
          icon: ArcaneIcon.cloudUpload(size: IconSize.sm),
          label: controls.publishLabel,
          attributes: <String, String>{'title': controls.publishHint},
        ),
        Button.ghost(
          size: ButtonSize.sm,
          onPressed: controls.onCopyLink,
          icon: ArcaneIcon.copy(size: IconSize.sm),
          label: huiText('Copy link'),
        ),
        Button.ghost(
          size: ButtonSize.sm,
          onPressed: controls.onDisconnect,
          icon: ArcaneIcon.unlink(size: IconSize.sm),
          label: huiText('Disconnect'),
        ),
      ]),
    ],
  );
}

String _label(EditorSyncStatus status) => switch (status) {
  EditorSyncStatus.connected => huiText('Connected'),
  EditorSyncStatus.pending => huiText('Pending server apply'),
  EditorSyncStatus.applied => huiText('Applied'),
  EditorSyncStatus.conflict => huiText('Conflict'),
  EditorSyncStatus.rejected => huiText('Rejected'),
  EditorSyncStatus.expired => huiText('Expired'),
  EditorSyncStatus.revoked => huiText('Revoked'),
  EditorSyncStatus.disconnected => huiText('Disconnected'),
  EditorSyncStatus.unavailable => huiText('Relay unavailable'),
};
