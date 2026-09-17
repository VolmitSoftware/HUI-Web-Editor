/// Inspector body for a Gloss connection-message document: the document
/// visibility, then the join and leave blocks with their own enable switch,
/// visibility, audience, message and conditional variants.
///
/// No `$player` in any placeholder on purpose. That token belongs to the tab
/// list; a connection message is rendered per recipient
/// (`ConnectionsService.render`), so the scoped names are the ones that work
/// — `{{ subject.name }}` for whoever connected, `{{ viewer.name }}` for
/// whoever is reading.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/connections_validation.dart';
import '../../logic/gloss_show.dart';
import '../../logic/gloss_text.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../../state/editor_store.dart';
import '../common/common.dart';
import '../gloss/gloss_text_line.dart';
import 'field_help.dart';
import 'gloss_visibility_editor.dart';
import 'inspector_widgets.dart';
import 'line_list_section.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class ConnectionsInspector extends StatefulWidget {
  const ConnectionsInspector({required this.store, super.key});

  final EditorStore store;

  @override
  State<ConnectionsInspector> createState() => _ConnectionsInspectorState();
}

class _ConnectionsInspectorState extends State<ConnectionsInspector> {
  EditorStore get _store => component.store;

  List<HuiIssue> _issuesFor(String path) => _store.issues
      .where((HuiIssue issue) => issue.path.startsWith(path))
      .toList();

  @override
  Widget build(BuildContext context) {
    final GlossConnectionsDoc? doc = _store.connectionsDoc;
    if (doc == null) return const dom.div(<Widget>[]);
    return dom.div(classes: 'hui-inspector-body is-connections', <Widget>[
      _header(doc),
      GlossVisibilityEditor(
        raw: doc.extras['show'],
        sectionKey: 'connections.visibility',
        issues: _store.issues
            .where((HuiIssue issue) => issue.path == r'$.show')
            .toList(),
        onChanged: (Object? value) => _store.mutateConnections(
          'visibility',
          (GlossConnectionsDoc edited) => setGlossShow(edited.extras, value),
        ),
      ),
      for (final String key in glossConnectionsSectionKeys) _section(doc, key),
    ]);
  }

  Widget _header(GlossConnectionsDoc doc) =>
      dom.div(classes: 'hui-inspector-headgroup', <Widget>[
        dom.div(classes: 'hui-inspector-header is-connections', <Widget>[
          HuiEyebrow(huiText('Connection messages')),
          dom.div(classes: 'hui-inspector-title-row', <Widget>[
            dom.h2(classes: 'hui-inspector-title hui-ltr', <Widget>[
              Text(_store.menuId),
            ]),
            const HuiFieldHelp('connections.id'),
          ]),
        ]),
        dom.p(classes: 'hui-inspector-lede', <Widget>[
          Text(
            huiText(
              'The join and leave lines. Each one is rendered separately for '
              'every player who reads it.',
            ),
          ),
        ]),
        HuiRevisionRow(revision: doc.revision),
      ]);

  String _sectionTitle(String key) =>
      key == 'leave' ? huiText('Leave message') : huiText('Join message');

  Widget _section(GlossConnectionsDoc doc, String key) {
    final GlossConnectionsSection section = doc.section(key);
    final String path = r'$.' + key;
    return InspectorSection(
      title: _sectionTitle(key),
      children: <Widget>[
        if (!section.present)
          HuiNote(
            huiText(
              'This file has no block for it, so nothing is broadcast. Adding '
              'the block is how you start.',
            ),
            tone: HuiNoteTone.info,
          ),
        if (!section.present)
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            icon: ArcaneIcon.plus(size: IconSize.sm),
            onPressed: () => _store.mutateConnections(
              'add connection message',
              (GlossConnectionsDoc edited) {
                final GlossConnectionsSection added = edited.section(key)
                  ..present = true
                  ..enabled = true;
                if (added.presentation.text.isEmpty) {
                  added.presentation.text = key == 'leave'
                      ? r'&c- &f{{ subject.name }} &7left'
                      : r'&a+ &f{{ subject.name }} &7joined';
                }
              },
            ),
            label: huiText('Add the block'),
          ),
        if (section.present) ...<Widget>[
          HuiSwitchRow(
            label: huiText('Enabled'),
            trailing: const HuiFieldHelp('connections.enabled'),
            value: section.enabled,
            onChanged: (bool value) => _store.mutateConnections(
              'connection message enabled',
              (GlossConnectionsDoc edited) =>
                  edited.section(key).enabled = value,
            ),
          ),
          GlossVisibilityEditor(
            raw: section.extras['show'],
            sectionKey: 'connections.$key.visibility',
            issues: _issuesFor('$path.show'),
            onChanged: (Object? value) => _store.mutateConnections(
              'visibility',
              (GlossConnectionsDoc edited) =>
                  setGlossShow(edited.section(key).extras, value),
            ),
          ),
          _audienceField(section, path, key),
          _messageField(
            value: section.presentation.text,
            path: '$path.presentation.text',
            onChanged: (String value) => _store.mutateConnections(
              'connection message text',
              (GlossConnectionsDoc edited) =>
                  edited.section(key).presentation.text = value,
            ),
          ),
          for (int index = 0; index < section.variants.length; index++)
            _variant(section, key, path, index),
          Button(
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            icon: ArcaneIcon.plus(size: IconSize.sm),
            onPressed: () => _store.mutateConnections(
              'add connection message variant',
              (GlossConnectionsDoc edited) {
                final GlossConnectionsSection target = edited.section(key);
                target.variants.add(
                  GlossConnectionsVariant(
                    priority: 10,
                    when: "inGroup('subject', 'staff')",
                    presentation: target.presentation.copy(),
                  ),
                );
              },
            ),
            label: huiText('Add a conditional message'),
          ),
        ],
      ],
    );
  }

  Widget _audienceField(
    GlossConnectionsSection section,
    String path,
    String key,
  ) => HuiField(
    label: huiText('Audience'),
    trailing: const HuiFieldHelp('connections.audience'),
    help: huiText(
      'A proxy setting. This server broadcasts to everyone either way.',
    ),
    control: dom.div(<Widget>[
      HuiSegmented(
        value: section.audience,
        segments: <HuiSegment>[
          HuiSegment(
            value: glossConnectionsAudienceNetwork,
            label: huiText('Whole network'),
          ),
          HuiSegment(
            value: glossConnectionsAudienceServer,
            label: huiText('This server only'),
          ),
        ],
        onChanged: (String value) => _store.mutateConnections(
          'connection message audience',
          (GlossConnectionsDoc edited) => edited.section(key).audience = value,
        ),
      ),
      HuiInlineIssues(_issuesFor('$path.audience')),
    ]),
  );

  Widget _variant(
    GlossConnectionsSection section,
    String key,
    String path,
    int index,
  ) {
    final GlossConnectionsVariant variant = section.variants[index];
    final String variantPath = '$path.variants[$index]';
    return dom.div(classes: 'hui-connections-variant', <Widget>[
      dom.div(classes: 'hui-inspector-title-row', <Widget>[
        HuiEyebrow(
          huiText('Conditional message {index}', <String, Object?>{
            'index': index + 1,
          }),
        ),
        HuiIconButton(
          label: huiText('Delete conditional message'),
          icon: ArcaneIcon.trash2(size: IconSize.sm),
          onPressed: () => _store.mutateConnections(
            'delete connection message variant',
            (GlossConnectionsDoc edited) {
              final GlossConnectionsSection target = edited.section(key);
              if (index < target.variants.length) {
                target.variants.removeAt(index);
              }
            },
          ),
        ),
      ]),
      HuiField(
        label: huiText('Priority'),
        trailing: const HuiFieldHelp('connections.variants.priority'),
        control: dom.div(<Widget>[
          TextInput(
            value: '${variant.priority}',
            size: ComponentSize.sm,
            fullWidth: true,
            onChanged: (String raw) {
              final int? parsed = int.tryParse(raw);
              if (parsed == null) return;
              _store.mutateConnections(
                'connection message variant priority',
                (GlossConnectionsDoc edited) =>
                    edited.section(key).variants[index].priority = parsed,
              );
            },
            styles: huiTechnicalInputStyles,
            attributes: <String, String>{
              ...huiTechnicalInputAttributes,
              'inputmode': 'numeric',
            },
          ),
          HuiInlineIssues(_issuesFor('$variantPath.priority')),
        ]),
      ),
      HuiField(
        label: huiText('When'),
        trailing: const HuiFieldHelp('connections.variants.when'),
        control: dom.div(<Widget>[
          TextInput(
            value: variant.when,
            size: ComponentSize.sm,
            fullWidth: true,
            placeholder: huiText("inGroup('subject', 'staff')"),
            onChanged: (String value) => _store.mutateConnections(
              'connection message variant condition',
              (GlossConnectionsDoc edited) =>
                  edited.section(key).variants[index].when = value,
            ),
            styles: huiTechnicalInputStyles,
            attributes: huiTechnicalInputAttributes,
          ),
          HuiInlineIssues(_issuesFor('$variantPath.when')),
        ]),
      ),
      _messageField(
        value: variant.presentation.text,
        path: '$variantPath.presentation.text',
        onChanged: (String value) => _store.mutateConnections(
          'connection message variant text',
          (GlossConnectionsDoc edited) =>
              edited.section(key).variants[index].presentation.text = value,
        ),
      ),
    ]);
  }

  Widget _messageField({
    required String value,
    required String path,
    required void Function(String) onChanged,
  }) => HuiField(
    label: huiText('Message'),
    trailing: const HuiFieldHelp('connections.text'),
    control: dom.div(<Widget>[
      TextInput(
        value: value,
        size: ComponentSize.sm,
        fullWidth: true,
        placeholder: huiText(r'&a+ &f{{ subject.name }} &7joined'),
        onChanged: onChanged,
        styles: huiTechnicalInputStyles,
        attributes: huiTechnicalInputAttributes,
      ),
      GlossTextLine(
        render: renderGlossLine(
          value,
          animations: _store.workspaceAnimations,
          emoji: _store.workspaceEmoji,
          expressionSamples: glossConnectionsSamples,
        ),
      ),
      dom.div(classes: 'hui-connections-chips', <Widget>[
        ...huiMissingAnimationChips(
          value,
          _store.workspaceAnimations,
          where: 'in chat',
        ),
      ]),
      HuiInlineIssues(_issuesFor(path)),
    ]),
  );
}
