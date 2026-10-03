library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';
import 'package:jaspr/dom.dart' as dom;
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import 'gloss_visibility_editor.dart';
import 'inspector_widgets.dart';
import 'channel_fields_editor.dart';

class ChannelInspector extends StatelessWidget {
  const ChannelInspector({required this.store, super.key});
  final EditorStore store;

  void _edit(String label, void Function(GlossChannelDoc) edit) =>
      store.mutateGloss(label, (GlossDoc doc) {
        if (doc is GlossChannelDoc) edit(doc);
      });

  Widget _text(
    String label,
    String value,
    void Function(GlossChannelDoc, String) edit, {
    String? help,
  }) => HuiField(
    label: huiText(label),
    help: help == null ? null : huiText(help),
    control: TextInput(
      value: value,
      size: ComponentSize.sm,
      fullWidth: true,
      onChanged: (String value) =>
          _edit(label, (GlossChannelDoc doc) => edit(doc, value)),
      styles: huiTechnicalInputStyles,
      attributes: <String, String>{
        ...huiTechnicalInputAttributes,
        'aria-label': huiText(label),
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final GlossDoc? active = store.glossDoc;
    if (active is! GlossChannelDoc) return const dom.div(<Widget>[]);
    final GlossChannelDoc doc = active;
    return dom.div(classes: 'hui-inspector-body is-channel', <Widget>[
      InspectorSection(
        title: huiText('Chat channel'),
        children: <Widget>[
          HuiRevisionRow(revision: doc.revision),
          _text(
            'Channel name',
            doc.channel.name,
            (GlossChannelDoc doc, String value) => doc.channel.name = value,
          ),
          HuiSwitchRow(
            label: huiText('Default chat channel'),
            value: doc.channel.defaultChannel,
            onChanged: (bool value) => _edit(
              'default channel',
              (GlossChannelDoc doc) => doc.channel.defaultChannel = value,
            ),
          ),
          _text(
            'Aliases',
            doc.channel.aliases.join(', '),
            (GlossChannelDoc doc, String value) => doc.channel.aliases = value
                .split(',')
                .map((String alias) => alias.trim())
                .where((String alias) => alias.isNotEmpty)
                .toList(),
          ),
          HuiField(
            label: huiText('Audience'),
            control: HuiSegmented(
              value: doc.channel.scope,
              segments: <HuiSegment>[
                for (final String scope in <String>[
                  'global',
                  'world',
                  'radius',
                  'permission',
                  'direct',
                ])
                  HuiSegment(value: scope, label: huiText(scope)),
              ],
              onChanged: (String value) => _edit(
                'channel audience',
                (GlossChannelDoc doc) => doc.channel.scope = value,
              ),
            ),
          ),
          if (doc.channel.scope == 'permission')
            _text(
              'Audience permission',
              doc.channel.permission,
              (GlossChannelDoc doc, String value) =>
                  doc.channel.permission = value,
            ),
          if (doc.channel.scope == 'radius')
            _text('Radius in blocks', '${doc.channel.radius}', (
              GlossChannelDoc doc,
              String value,
            ) {
              final int? parsed = int.tryParse(value);
              if (parsed != null) doc.channel.radius = parsed;
            }),
          _text(
            'Normal message format',
            doc.format,
            (GlossChannelDoc doc, String value) => doc.format = value,
            help:
                '{{ sender.name }} is the sender; {{ message }} is the chat text.',
          ),
        ],
      ),
      GlossVisibilityEditor(
        raw: doc.show,
        sectionKey: 'channel.visibility',
        issues: const [],
        onChanged: (Object? value) => _edit(
          'channel visibility',
          (GlossChannelDoc doc) => doc.show = value,
        ),
      ),
      InspectorSection(
        title: huiText('Player mentions'),
        children: <Widget>[
          HuiSwitchRow(
            label: huiText('Enable @mentions'),
            value: doc.mentions.enabled,
            onChanged: (bool value) => _edit(
              'mentions enabled',
              (GlossChannelDoc doc) => doc.mentions.enabled = value,
            ),
          ),
          _text(
            'Sender permission',
            doc.mentions.permission,
            (GlossChannelDoc doc, String value) =>
                doc.mentions.permission = value,
          ),
          _text(
            'Mention pattern',
            doc.mentions.pattern,
            (GlossChannelDoc doc, String value) => doc.mentions.pattern = value,
            help: huiText(
              'Include {name} once. Matching uses the account name.',
            ),
          ),
          _text(
            'Tagged name style',
            doc.mentions.render,
            (GlossChannelDoc doc, String value) => doc.mentions.render = value,
            help: huiText('{{ mention.name }} is the tagged player.'),
          ),
          _text(
            'Tagged message format',
            doc.mentions.messageFormat,
            (GlossChannelDoc doc, String value) =>
                doc.mentions.messageFormat = value,
            help:
                'Only the tagged player sees this format. Use {{ sender.name }} and {{ message }}.',
          ),
          _text(
            'Mention sound',
            doc.mentions.sound,
            (GlossChannelDoc doc, String value) => doc.mentions.sound = value,
            help: huiText(
              'Minecraft sound key. Leave blank for silent mentions.',
            ),
          ),
        ],
      ),
      ChannelFieldsEditor(
        value: doc.toJson(),
        mentions: false,
        onChanged: (Map<String, Object?> value) =>
            _edit('channel settings', (GlossChannelDoc edited) {
              final GlossChannelDoc next = GlossChannelDoc.fromJson(value);
              edited.card = next.card;
              edited.items = next.items;
              edited.links = next.links;
              edited.filters = next.filters;
              edited.throttle = next.throttle;
            }),
      ),
      InspectorSection(
        title: huiText('Conditional variants'),
        children: <Widget>[
          for (int index = 0; index < doc.variants.length; index++)
            _variant(doc, index),
          Button(
            label: huiText('Add variant'),
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            onPressed: () => _edit('add channel variant', (
              GlossChannelDoc edited,
            ) {
              int suffix = edited.variants.length + 1;
              while (edited.variants.any(
                (GlossChannelVariant variant) =>
                    variant.id == 'variant-$suffix',
              )) {
                suffix++;
              }
              edited.variants.add(GlossChannelVariant(id: 'variant-$suffix'));
            }),
          ),
        ],
      ),
      HuiInlineIssues(store.issues),
    ]);
  }

  Widget _variant(GlossChannelDoc doc, int index) {
    final GlossChannelVariant variant = doc.variants[index];
    return InspectorSection(
      title: variant.id,
      sectionKey: 'channel.variant.$index',
      children: <Widget>[
        _text(
          'Variant id',
          variant.id,
          (GlossChannelDoc edited, String value) =>
              edited.variants[index].id = value,
        ),
        _text('Priority', '${variant.priority}', (
          GlossChannelDoc edited,
          String value,
        ) {
          final int? priority = int.tryParse(value);
          if (priority != null) edited.variants[index].priority = priority;
        }),
        _text(
          'Condition',
          variant.when,
          (GlossChannelDoc edited, String value) =>
              edited.variants[index].when = value,
        ),
        ChannelFieldsEditor(
          value: variant.toJson(),
          fallback: doc.toJson(),
          inherited: true,
          onChanged: (Map<String, Object?> value) => _edit(
            'channel variant settings',
            (GlossChannelDoc edited) =>
                edited.variants[index] = GlossChannelVariant.fromJson(value),
          ),
        ),
        Button(
          label: huiText('Remove variant'),
          variant: ButtonVariant.ghost,
          size: ButtonSize.sm,
          onPressed: () => _edit(
            'remove channel variant',
            (GlossChannelDoc edited) => edited.variants.removeAt(index),
          ),
        ),
      ],
    );
  }
}
