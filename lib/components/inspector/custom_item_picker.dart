/// `customItem` icon editor: provider, the provider's own id, and stack count.
///
/// The editor is a static page with no connection to the server, so it can
/// never confirm an id. Every field here stays free text, the catalog is only
/// ever an aid, and nothing an unrecognised id produces is worse than an info.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../config/defaults.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../services/catalogs.dart';
import '../common/common.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';
import 'registry_picker.dart';

class CustomItemIconEditor extends StatelessWidget {
  const CustomItemIconEditor({
    required this.icon,
    required this.catalogs,
    required this.onChanged,
    this.issues = const <HuiIssue>[],
    super.key,
  });

  final HuiCustomItemIcon icon;
  final HuiCatalogs catalogs;

  /// Called with a mutation label and the edited copy.
  final void Function(String label, HuiCustomItemIcon icon) onChanged;
  final List<HuiIssue> issues;

  HuiCustomItemCatalog get _catalog => catalogs.customItems;

  HuiItemProviderInfo? get _info => huiItemProviderInfo[icon.provider];

  List<HuiIssue> _issuesFor(String suffix) =>
      issues.where((HuiIssue issue) => issue.path.endsWith(suffix)).toList();

  HuiCustomItemIcon _with({String? provider, String? item, int? count}) =>
      HuiCustomItemIcon(
        provider ?? icon.provider,
        item ?? icon.item,
        count ?? icon.count,
      )..extras = huiDeepCopyMap(icon.extras);

  /// Auto-detect first, then the adapters in declaration order. A provider the
  /// file already names but this build has no adapter for is kept as an option
  /// so opening the inspector cannot silently rewrite it.
  List<ArcaneSelectOption> get _providerOptions {
    final List<ArcaneSelectOption> options = <ArcaneSelectOption>[
      const ArcaneSelectOption(
        label: 'Auto-detect',
        value: huiAutoItemProvider,
      ),
      for (final String provider in huiCustomItemProviders)
        ArcaneSelectOption(
          label: huiItemProviderInfo[provider]?.label ?? provider,
          value: provider,
        ),
    ];
    if (icon.provider.isNotEmpty &&
        icon.provider != huiAutoItemProvider &&
        !huiCustomItemProviders.contains(icon.provider)) {
      options.add(
        ArcaneSelectOption(
          label: '${icon.provider} (unknown)',
          value: icon.provider,
        ),
      );
    }
    return options;
  }

  /// Entries for the current provider only: the same bare id can exist in two
  /// plugins, and picking the wrong one resolves to the wrong item.
  List<RegistryOption> _search(String query, int limit) => _catalog
      .search(query, provider: icon.provider, limit: limit)
      .map(
        (CustomItemEntry entry) => RegistryOption(
          entry.id,
          entry.material == null ? null : catalogs.textureFor(entry.material!),
          <String>[
            if (entry.name != null) entry.name!,
            entry.provider,
          ].join(' · '),
        ),
      )
      .toList();

  String? _textureFor(String id) {
    final String? material = _catalog.entry(icon.provider, id)?.material;
    return material == null ? null : catalogs.textureFor(material);
  }

  int get _catalogCount => _catalog.countFor(icon.provider);

  @override
  Widget build(BuildContext context) => dom.div(
    classes: 'hui-icon-custom',
    <Widget>[
      HuiField(
        label: 'Provider',
        help:
            'Auto-detect asks every installed provider in activation order and '
            'takes the first hit.',
        control: dom.div(<Widget>[
          ArcaneSelect(
            value: icon.provider,
            size: ComponentSize.sm,
            fullWidth: true,
            options: _providerOptions,
            onChange: (String value) =>
                onChanged('item provider', _with(provider: value)),
          ),
          HuiInlineIssues(_issuesFor('.provider')),
        ]),
      ),
      HuiField(
        label: 'Item id',
        required: true,
        help: _info == null
            ? 'Exactly as the plugin that owns the item spells it.'
            : '${_info!.idFormat}. Example: ${_info!.example}',
        control: dom.div(<Widget>[
          RegistryPicker(
            value: icon.item,
            placeholder: _info?.example ?? 'myitems:ruby',
            browseLabel: 'Browse catalog',
            searchPlaceholder: 'Search the exported catalog',
            emptyMessage:
                'No match in the exported catalog. The id is '
                'still used as typed.',
            catalogAvailable: _catalogCount > 0,
            lowercase: false,
            textureFor: _textureFor,
            search: _search,
            onChanged: (String value) =>
                onChanged('custom item id', _with(item: value)),
          ),
          HuiInlineIssues(_issuesFor('.item')),
        ]),
      ),
      HuiField(
        label: 'Count',
        trailing: const HuiFieldHelp('icon.customItem.count'),
        control: dom.div(<Widget>[
          HuiNumberField(
            value: icon.count.toDouble(),
            min: 1,
            max: 99,
            step: 1,
            integer: true,
            onChanged: (double value) =>
                onChanged('custom item count', _with(count: value.round())),
          ),
          HuiInlineIssues(_issuesFor('.count')),
        ]),
      ),
      _catalogNote(),
      const HuiMore(
        summary: 'How custom items resolve',
        children: <Widget>[
          HuiNote(
            'The server asks the provider plugin for the item when the '
            'menu opens and renders whatever stack it hands back, textures '
            'and model data included.',
          ),
          HuiNote(
            'Ids are case-sensitive for most providers, so they are stored '
            'exactly as typed.',
          ),
          HuiNote(
            'If the provider is missing or the id is unknown, HoloUI logs '
            'a warning naming both and draws its magenta/black '
            'placeholder. The rest of the menu still opens.',
          ),
        ],
      ),
    ],
  );

  Widget _catalogNote() {
    if (_catalog.isEmpty) {
      return const HuiNote(
        'No catalog loaded, so ids cannot be checked here. Run /holoui items '
        'export on your server and import the file from Settings to get '
        'autocomplete and canvas previews.',
      );
    }
    final int count = _catalogCount;
    return HuiNote(
      '$count item${count == 1 ? '' : 's'} in the catalog exported from your '
      'server${icon.provider == huiAutoItemProvider ? '' : ' for '
                '${_info?.label ?? icon.provider}'}. Ids missing from it are not '
      'errors - only the server can confirm one.',
    );
  }
}
