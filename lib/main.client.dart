/// The entrypoint for the HoloUI editor client app.
library;

import 'package:fast_log/fast_log.dart';
import 'package:jaspr/client.dart';
import 'package:web/web.dart' as web;

import 'app.dart';
import 'main.client.options.dart';

void main() {
  info('holoui_editor starting...');

  Jaspr.initializeApp(options: defaultClientOptions);

  try {
    const App app = App();
    runApp(app);

    web.document.getElementById('loading')?.remove();

    success('holoui_editor running');
  } catch (e, stack) {
    error('Exception: $e');
    error('Stack: $stack');
  }
}
