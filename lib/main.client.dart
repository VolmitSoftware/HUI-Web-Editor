/// The entrypoint for the HoloUI editor client app.
library;

import 'package:fast_log/fast_log.dart';
import 'package:jaspr/client.dart';
import 'package:web/web.dart' as web;

import 'app.dart';
import 'main.client.options.dart';
import 'state/workspace.dart';
import 'state/workspace_repository.dart';

Future<void> main() async {
  info('holoui_editor starting...');

  Jaspr.initializeApp(options: defaultClientOptions);

  try {
    final Workspace workspace = await Workspace.open(
      repository: createDefaultWorkspaceRepository(),
    );
    final App app = App(workspace: workspace);
    runApp(app);

    web.document.getElementById('loading')?.remove();

    success('holoui_editor running');
  } catch (e, stack) {
    error('Exception: $e');
    error('Stack: $stack');
  }
}
