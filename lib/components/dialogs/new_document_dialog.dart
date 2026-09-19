import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../doctype/doctype.dart';
import '../../l10n/hui_localizations.dart';

class NewDocumentDialog extends StatelessWidget {
  const NewDocumentDialog({
    required this.onCreate,
    required this.onClose,
    super.key,
  });

  static const String dialogId = 'hui-new-document-dialog';
  static const String triggerId = 'hui-library-new-document';
  static const String firstChoiceId = 'hui-new-document-first-choice';

  final ValueChanged<DocumentTypeAdapter> onCreate;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final List<DocumentTypeAdapter> types = DocumentTypeRegistry.tabs;
    return ArcaneDialog(
      id: dialogId,
      isOpen: true,
      title: huiText('New document'),
      onClose: onClose,
      barrierDismissible: false,
      actions: <Widget>[
        Button(
          variant: ButtonVariant.outline,
          label: huiText('Cancel'),
          onPressed: onClose,
        ),
      ],
      children: <Widget>[
        dom.div(classes: 'hui-new-document-grid', <Widget>[
          for (final DocumentTypeAdapter type in types)
            Button(
              id: identical(type, types.first) ? firstChoiceId : null,
              variant: ButtonVariant.outline,
              icon: type.createIcon(),
              label: type.createLabel,
              onPressed: () => onCreate(type),
            ),
        ]),
      ],
    );
  }
}
