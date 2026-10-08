import 'dart:convert';

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../doctype/document_type_registry.dart';
import '../../l10n/hui_localizations.dart';
import '../../logic/document_presets.dart';
import '../../state/editor_store.dart';
import '../../state/workspace.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';

class DocumentPresetPicker extends StatelessWidget {
  const DocumentPresetPicker({required this.store, super.key});
  final EditorStore store;

  @override
  Widget build(BuildContext context) {
    final String? collection = DocumentPresets.collection(
      store.docType.syncWireKind,
    );
    if (collection == null) {
      return const dom.div(<Widget>[]);
    }
    try {
      String? context = store.workspace.active?.presetContext;
      for (final WorkspaceDoc document in store.workspace.docs) {
        if (context == null &&
            DocumentTypeRegistry.of(document.kind).syncWireKind == 'presets') {
          context = document.json;
          break;
        }
      }
      final Object? decoded = jsonDecode(store.exportJson());
      if (decoded is! Map<String, Object?>) {
        return const dom.div(<Widget>[]);
      }
      final String selected = decoded['preset'] is String
          ? decoded['preset'] as String
          : '';
      final List<String> names = <String>[];
      if (context != null) {
        final Object? catalog = jsonDecode(context);
        if (catalog is Map<String, Object?> &&
            catalog['presets'] is Map<String, Object?>) {
          final Object? definitions =
              (catalog['presets']! as Map<String, Object?>)[collection];
          if (definitions is Map<String, Object?>) {
            names.addAll(definitions.keys);
          }
        }
      }
      if (context == null && selected.isEmpty) {
        return const dom.div(<Widget>[]);
      }
      if (selected.isNotEmpty && !names.contains(selected)) {
        names.add(selected);
      }
      names.sort();
      return InspectorSection(
        title: huiText('Inheritance'),
        children: <Widget>[
          HuiField(
            label: huiText('Preset'),
            help: huiText(
              'Authored document fields override the selected preset. Clear an override in Code view to inherit it.',
            ),
            error: store.codeError,
            control: ArcaneSelect(
              value: selected,
              options: <ArcaneSelectOption>[
                ArcaneSelectOption(
                  value: '',
                  label: huiText('Collection defaults only'),
                ),
                for (final String name in names)
                  ArcaneSelectOption(value: name, label: name),
              ],
              onChanged: (String value) {
                if (value.isEmpty) {
                  decoded.remove('preset');
                } else {
                  decoded['preset'] = value;
                }
                store.applyCode(jsonEncode(decoded));
              },
            ),
          ),
        ],
      );
    } on FormatException catch (error) {
      return Text(
        huiText('Preset catalog cannot be read: {message}', <String, Object?>{
          'message': error.message,
        }),
      );
    }
  }
}
