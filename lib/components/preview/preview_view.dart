/// The preview view shell: toolbar, readout strip, stage, action log.
///
/// The stage is imperative DOM and must never be re-patched, so every
/// rebuilding surface around it is a separate widget under its own
/// [ListenableBuilder] — and the stage itself sits under none of them. Nothing
/// in this file reaches into the stage; it talks to it through
/// [PreviewPose.controller].
///
/// The three notifiers are subscribed to separately on purpose (see
/// `preview_pose.dart`): the toolbar needs the store, the pose and the log; the
/// readout needs the per-tick live state and nothing else; the log dock needs
/// the buffer. A 60 fps orbit drag writes none of them and rebuilds nothing.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show ListenableBuilder;

import '../../services/catalogs.dart';
import '../../services/image_library.dart';
import '../../state/editor_store.dart';
import 'preview_hud.dart';
import 'preview_log_view.dart';
import 'preview_pose.dart';
import 'preview_stage.dart';
import 'preview_toolbar.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class PreviewView extends StatelessWidget {
  const PreviewView({
    required this.store,
    required this.images,
    this.catalogs,
    super.key,
  });

  final EditorStore store;
  final ImageLibrary images;

  /// Null until the boot fetch lands; item sprites degrade to placeholders.
  final HuiCatalogs? catalogs;

  @override
  Widget build(BuildContext context) {
    final PreviewPose pose = huiPreviewPose;
    return dom.div(
      classes: 'hui-preview',
      attributes: <String, String>{
        'role': 'region',
        'aria-label': huiText('Menu preview'),
      },
      <Widget>[
        ListenableBuilder(
          listenable: store,
          builder: (BuildContext _) => ListenableBuilder(
            listenable: pose,
            builder: (BuildContext _) => ListenableBuilder(
              // The Clear log button's enabled state is the only thing here
              // that depends on the buffer, and it is cheap.
              listenable: pose.log,
              builder: (BuildContext _) =>
                  PreviewToolbar(store: store, pose: pose),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: store,
          builder: (BuildContext _) => ListenableBuilder(
            listenable: pose.live,
            builder: (BuildContext _) => PreviewHud(store: store, pose: pose),
          ),
        ),
        PreviewStage(
          store: store,
          images: images,
          pose: pose,
          catalogs: catalogs,
        ),
        ListenableBuilder(
          listenable: store,
          builder: (BuildContext _) => ListenableBuilder(
            listenable: pose.log,
            builder: (BuildContext _) =>
                PreviewLogView(store: store, log: pose.log),
          ),
        ),
      ],
    );
  }
}
