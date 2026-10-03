library;

import 'dart:convert';
import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'inspector_widgets.dart';
import 'particle_layers_editor.dart';

class MenuVariantsEditor extends StatefulWidget {
  const MenuVariantsEditor({required this.store, super.key});
  final EditorStore store;
  @override
  State<MenuVariantsEditor> createState() => _MenuVariantsEditorState();
}

class _MenuVariantsEditorState extends State<MenuVariantsEditor> {
  final Map<int, String> drafts = <int, String>{};
  final Map<int, String> errors = <int, String>{};
  EditorStore get store => component.store;
  void edit(int index, String label, void Function(HuiMenuVariant) change) =>
      store.mutate(label, (HuiMenu menu) => change(menu.variants[index]));
  Widget input(String label, String value, void Function(String) change) =>
      HuiField(
        label: huiText(label),
        control: TextInput(
          value: value,
          size: ComponentSize.sm,
          fullWidth: true,
          onChanged: change,
          attributes: <String, String>{'aria-label': huiText(label)},
        ),
      );

  void components(int index, String source) {
    setState(() {
      drafts[index] = source;
      errors.remove(index);
    });
    try {
      final Object? value = jsonDecode(source);
      if (value is! List) {
        throw const FormatException('Enter a component array.');
      }
      final List<HuiComponent> parsed = <HuiComponent>[
        for (final Object? item in value) HuiComponent.fromJson(item),
      ];
      setState(() => drafts.remove(index));
      edit(
        index,
        'variant components',
        (HuiMenuVariant variant) => variant.components = parsed,
      );
    } catch (error) {
      setState(() => errors[index] = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => InspectorSection(
    title: huiText('Conditional variants'),
    children: <Widget>[
      for (int index = 0; index < store.menu.variants.length; index++)
        variant(index),
      Button(
        label: huiText('Add variant'),
        variant: ButtonVariant.outline,
        size: ButtonSize.sm,
        onPressed: () => store.mutate('add menu variant', (HuiMenu menu) {
          int suffix = menu.variants.length + 1;
          while (menu.variants.any(
            (HuiMenuVariant variant) => variant.id == 'variant-$suffix',
          )) {
            suffix++;
          }
          menu.variants.add(
            HuiMenuVariant(
              id: 'variant-$suffix',
              components: <HuiComponent>[
                for (final HuiComponent item in menu.components) item.copy(),
              ],
            ),
          );
        }),
      ),
    ],
  );

  Widget variant(int index) {
    final HuiMenuVariant value = store.menu.variants[index];
    return InspectorSection(
      title: value.id,
      sectionKey: 'menu.variant.$index',
      children: <Widget>[
        input(
          'Variant id',
          value.id,
          (String text) => edit(
            index,
            'variant id',
            (HuiMenuVariant variant) => variant.id = text,
          ),
        ),
        input('Priority', '${value.priority}', (String text) {
          final int? priority = int.tryParse(text);
          if (priority != null) {
            edit(
              index,
              'variant priority',
              (HuiMenuVariant variant) => variant.priority = priority,
            );
          }
        }),
        input(
          'Condition',
          '${value.when ?? ''}',
          (String text) => edit(
            index,
            'variant condition',
            (HuiMenuVariant variant) => variant.when = text,
          ),
        ),
        HuiField(
          label: huiText('Components (JSON)'),
          help: huiText(
            'Replacement components use the same format as the base menu.',
          ),
          control: TextArea(
            value:
                drafts[index] ??
                const JsonEncoder.withIndent('  ').convert(
                  value.components
                      .map((HuiComponent item) => item.toJson())
                      .toList(),
                ),
            onChanged: (String text) => components(index, text),
          ),
        ),
        if (errors[index] != null)
          HuiNote(errors[index]!, tone: HuiNoteTone.warning),
        Button(
          label: huiText('Copy base components'),
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          onPressed: () {
            setState(() {
              drafts.remove(index);
              errors.remove(index);
            });
            edit(
              index,
              'copy base components',
              (HuiMenuVariant variant) => variant.components = <HuiComponent>[
                for (final HuiComponent item in store.menu.components)
                  item.copy(),
              ],
            );
          },
        ),
        HuiSwitchRow(
          label: huiText('Override particle layers'),
          value: value.particleLayers != null,
          onChanged: (bool enabled) => edit(
            index,
            'variant particles',
            (HuiMenuVariant variant) => variant.particleLayers = enabled
                ? <GlossParticleLayer>[]
                : null,
          ),
        ),
        if (value.particleLayers != null)
          ParticleLayersEditor(
            layers: value.particleLayers!,
            sectionKey: 'menu.variant.$index.particles',
            mutate:
                (
                  String label,
                  void Function(List<GlossParticleLayer>) change,
                ) => edit(
                  index,
                  label,
                  (HuiMenuVariant variant) => change(variant.particleLayers!),
                ),
          ),
        Button(
          label: huiText('Remove variant'),
          variant: ButtonVariant.ghost,
          size: ButtonSize.sm,
          onPressed: () {
            setState(() {
              drafts.clear();
              errors.clear();
            });
            store.mutate(
              'remove menu variant',
              (HuiMenu menu) => menu.variants.removeAt(index),
            );
          },
        ),
      ],
    );
  }
}
