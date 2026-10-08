import '../model/gloss_presets.dart';
import 'document_presets.dart';
import 'validation.dart';

List<HuiIssue> validatePresetsDoc(GlossPresetsDoc doc) {
  try {
    DocumentPresets.parse(encodeGlossPresetsDoc(doc));
    return const <HuiIssue>[];
  } on FormatException catch (error) {
    return <HuiIssue>[
      HuiIssue(severity: HuiSeverity.error, path: r'$', message: error.message),
    ];
  }
}
