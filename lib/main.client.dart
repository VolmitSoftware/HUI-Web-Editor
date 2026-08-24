/// The entrypoint for the Gloss editor client app.
library;

import 'package:fast_log/fast_log.dart';
import 'package:jaspr/client.dart';
import 'package:web/web.dart' as web;

import 'app.dart';
import 'l10n/hui_locale_loader.dart';
import 'l10n/hui_locale_preferences.dart';
import 'l10n/hui_localizations.dart';
import 'main.client.options.dart';
import 'services/image_library.dart';
import 'state/workspace.dart';
import 'state/workspace_repository.dart';

Future<void> main() async {
  info('gloss_editor starting...');

  Jaspr.initializeApp(options: defaultClientOptions);

  try {
    final HuiLocaleController localeController = HuiLocaleController();
    final String initialLocale = loadInitialHuiLocale();
    HuiLocaleInstallResult localeResult = await localeController.activate(
      initialLocale,
    );
    if (!localeResult.applied && initialLocale != huiEnglishLocale) {
      localeResult = await localeController.activate(huiEnglishLocale);
    }
    final String activeLocale = localeController.activeLocale;
    if (localeResult.applied) persistHuiLocale(activeLocale);
    stampHuiLocaleDocument(activeLocale);
    final Workspace workspace = await Workspace.open(
      repository: createDefaultWorkspaceRepository(),
    );
    final ImageLibrary images = await ImageLibrary.open(
      workspaceId: workspace.id,
      repository: workspace.repository,
    );
    final App app = App(
      workspace: workspace,
      images: images,
      localeController: localeController,
    );
    runApp(app);

    web.document.getElementById('loading')?.remove();

    success('gloss_editor running');
  } catch (e, stack) {
    error('Exception: $e');
    error('Stack: $stack');
  }
}
