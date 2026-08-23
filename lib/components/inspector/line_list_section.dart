/// The list-of-text-lines section, shared by every document kind that has one.
///
/// Holograms, animations, scoreboards and MOTD entries all edit the same thing:
/// an ordered list of pipeline strings, each row an input, a rendered preview
/// and a delete. Four hand-rolled copies of that row had already drifted — only
/// two mounted field help, only two carried the reference chips — so this is
/// one row and one list, with the per-kind parts (the label, the doc key, the
/// pickers, what a preview looks like) passed in.
///
/// The DOM class names are the ones the four copies already used, because the
/// stylesheet that draws them lives in `10-gloss.css`, outside this file's
/// reach. They read as hologram-specific and are not.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../logic/gloss_text.dart';
import '../../logic/validation.dart';
import '../common/common.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';
import 'reorder_list.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

/// One chip per `|animation.<id>|` reference no document in this workspace
/// answers. The text stays literal in game, which the rendered preview beside
/// it cannot show on its own — it has nothing to substitute, so it prints the
/// reference and looks like a deliberate choice.
///
/// [where] finishes the sentence: `in game`, `in the server list`.
List<Widget> huiMissingAnimationChips(
  String line,
  GlossAnimationResolver animations, {
  required String where,
}) => <Widget>[
  for (final String reference in glossLineMissingAnimationRefs(
    line,
    animations,
  ))
    dom.span(
      classes: 'hui-gloss-chip is-missing',
      attributes: <String, String>{
        'title': huiText(
          "No animation document named \"{substring}\" exists in this workspace; the text shows literally {where}.",
          <String, Object?>{
            'substring': reference.substring(
              glossAnimationFunctionPrefix.length,
            ),
            'where': where,
          },
        ),
      },
      <Widget>[
        Text(
          huiText("missing {reference}", <String, Object?>{
            'reference': reference,
          }),
        ),
      ],
    ),
];

/// One row: the input, whatever the kind renders as its preview, and the
/// remove button.
class HuiLineRow extends StatelessWidget {
  const HuiLineRow({
    required this.value,
    required this.placeholder,
    required this.onChanged,
    required this.onRemove,
    required this.removeLabel,
    this.onFocus,
    this.preview,
    this.chips = const <Widget>[],
    this.beyondRender = false,
    super.key,
  });

  final String value;
  final String placeholder;
  final void Function(String value) onChanged;
  final void Function() onRemove;

  /// Accessible name for the delete button — `Delete line 3`, not `Delete`.
  final String removeLabel;

  /// Tells the owning inspector which row a picker should insert into.
  final void Function()? onFocus;

  /// The rendered line, when the kind has a preview pipeline for it.
  final Widget? preview;

  /// Warnings that belong beside the preview rather than under the field: a
  /// missing animation reference, a row past the kind's render limit.
  final List<Widget> chips;

  /// Marks the row as one the server will not draw. Styling only; the note
  /// itself belongs in [chips], where it can say why.
  final bool beyondRender;

  @override
  Widget build(BuildContext context) => dom.div(
    classes: classNames(<String?>[
      'hui-hologram-line-row',
      beyondRender ? 'is-beyond-render' : null,
    ]),
    <Widget>[
      TextInput(
        value: value,
        size: ComponentSize.sm,
        fullWidth: true,
        placeholder: placeholder,
        onInput: onChanged,
        onFocus: onFocus,
        attributes: const <String, String>{
          'autocomplete': 'off',
          'spellcheck': 'false',
        },
      ),
      if (preview != null || chips.isNotEmpty)
        dom.div(classes: 'hui-hologram-line-preview', <Widget>[
          ?preview,
          ...chips,
        ]),
      HuiIconButton(
        label: removeLabel,
        icon: ArcaneIcon.trash2(size: IconSize.sm),
        onPressed: onRemove,
      ),
    ],
  );
}

/// The section around those rows: add button, kind-specific pickers, the
/// reorderable list, and the empty state that says what silence looks like in
/// game.
class HuiLineListSection extends StatelessWidget {
  const HuiLineListSection({
    required this.title,
    required this.addLabel,
    required this.onAdd,
    required this.itemCount,
    required this.itemBuilder,
    required this.emptyBody,
    this.onReorder,
    this.docKey,
    this.description,
    this.tools = const <Widget>[],
    this.footer = const <Widget>[],
    this.issues = const <HuiIssue>[],
    this.emptyTone = HuiNoteTone.neutral,
    this.sectionKey,
    super.key,
  });

  final String title;
  final String addLabel;
  final void Function() onAdd;
  final int itemCount;
  final Widget Function(int index) itemBuilder;

  /// What an empty list means in game. Never "no lines yet": the consequence
  /// first, so the note is information rather than a scold.
  final String emptyBody;

  /// Null keeps the list in document order with no drag handles — the MOTD
  /// entry's own one-or-two lines are not worth reordering.
  final void Function(int from, int to)? onReorder;

  /// Key into the field docs, mounted in the section header. This is the fix
  /// for the four written-but-never-rendered list docs.
  final String? docKey;
  final String? description;

  /// Pickers and other controls beside the add button.
  final List<Widget> tools;

  /// Rendered under the list, inside the section.
  final List<Widget> footer;
  final List<HuiIssue> issues;
  final HuiNoteTone emptyTone;
  final String? sectionKey;

  @override
  Widget build(BuildContext context) => InspectorSection(
    title: title,
    description: description,
    sectionKey: sectionKey,
    trailing: dom.div(classes: 'hui-field-tools', <Widget>[
      dom.span(classes: 'hui-count-chip', <Widget>[
        Text(huiText("{itemCount}", <String, Object?>{'itemCount': itemCount})),
      ]),
      if (docKey != null) HuiFieldHelp(docKey!),
    ]),
    children: <Widget>[
      dom.div(classes: 'hui-hologram-lines-tools', <Widget>[
        Button(
          variant: ButtonVariant.outline,
          size: ButtonSize.sm,
          icon: ArcaneIcon.plus(size: IconSize.sm),
          onPressed: onAdd,
          child: Text(addLabel),
        ),
        ...tools,
      ]),
      if (itemCount == 0)
        HuiEmptyState(
          icon: ArcaneIcon.listIcon(size: IconSize.md),
          title: huiText('Nothing here yet'),
          body: emptyBody,
          tone: emptyTone,
          actions: <Widget>[
            Button(
              variant: ButtonVariant.outline,
              size: ButtonSize.sm,
              icon: ArcaneIcon.plus(size: IconSize.sm),
              onPressed: onAdd,
              child: Text(addLabel),
            ),
          ],
        )
      else if (onReorder == null)
        dom.div(classes: 'hui-line-list', <Widget>[
          for (int index = 0; index < itemCount; index++) itemBuilder(index),
        ])
      else
        HuiReorderList(
          itemCount: itemCount,
          onReorder: onReorder!,
          itemBuilder: itemBuilder,
        ),
      ...footer,
      HuiInlineIssues(issues),
    ],
  );
}
