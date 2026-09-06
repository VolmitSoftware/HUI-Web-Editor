library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import '../../l10n/hui_localizations.dart';
import '../../logic/gloss_show.dart';
import '../../logic/validation.dart';
import 'inspector_widgets.dart';
import 'preview_expr_field.dart';

class GlossVisibilityEditor extends StatelessWidget {
  const GlossVisibilityEditor({
    required this.raw,
    required this.onChanged,
    this.issues = const <HuiIssue>[],
    this.sectionKey,
    super.key,
  });
  final Object? raw;
  final void Function(Object?) onChanged;
  final List<HuiIssue> issues;
  final String? sectionKey;

  @override
  Widget build(BuildContext context) => InspectorSection(
    title: huiText('Visibility'),
    sectionKey: sectionKey,
    children: <Widget>[
      PreviewExprField(
        label: huiText('Show condition'),
        raw: raw,
        kind: PreviewExprKind.boolean,
        showCondition: true,
        scope: glossShowVariables.toSet(),
        categoryVariableNames: glossShowVariables,
        help: huiText('Boolean or expression. Leave blank to always show.'),
        issues: issues,
        onChanged: onChanged,
      ),
    ],
  );
}
