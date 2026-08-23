/// `playerHead` icon editor: whose head, and how often the name is re-read.
///
/// The editor cannot resolve a skin — that is a Mojang lookup the server makes
/// and caches (`PlayerHeadService.java:102-122`) — so the canvas draws the
/// generic head for every name and this pane is where the authored string is
/// explained instead of previewed.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../config/defaults.dart';
import '../../logic/validation.dart';
import '../../model/model.dart';
import '../common/common.dart';
import 'field_help.dart';
import 'inspector_widgets.dart';
import 'package:gloss_editor/l10n/hui_localizations.dart';

class PlayerHeadIconEditor extends StatelessWidget {
  const PlayerHeadIconEditor({
    required this.icon,
    required this.onChanged,
    this.issues = const <HuiIssue>[],
    super.key,
  });

  final HuiPlayerHeadIcon icon;

  /// Called with a mutation label and the edited copy.
  final void Function(String label, HuiPlayerHeadIcon icon) onChanged;
  final List<HuiIssue> issues;

  List<HuiIssue> _issuesFor(String suffix) =>
      issues.where((HuiIssue issue) => issue.path.endsWith(suffix)).toList();

  HuiPlayerHeadIcon _with({String? player, int? refreshTicks}) =>
      HuiPlayerHeadIcon(
        player ?? icon.player,
        icon.style?.copy(),
        refreshTicks ?? icon.refreshTicks,
      )..extras = huiDeepCopyMap(icon.extras);

  int get _refreshTicks =>
      icon.refreshTicks ?? huiRuntimeDefaultPlayerHeadRefreshTicks;

  @override
  Widget build(
    BuildContext context,
  ) => dom.div(classes: 'hui-icon-player-head', <Widget>[
    HuiField(
      label: huiText('Player'),
      required: true,
      trailing: const HuiFieldHelp('icon.playerHead.player'),
      help: huiText(
        'A username, or a placeholder resolved once per viewer. '
        'Case does not matter to the lookup.',
      ),
      control: dom.div(<Widget>[
        TextInput(
          value: icon.player,
          size: ComponentSize.sm,
          fullWidth: true,
          placeholder: huiDefaultPlayerHeadSource,
          onInput: (String value) =>
              onChanged('player head name', _with(player: value)),
          styles: huiTechnicalInputStyles,
          attributes: huiTechnicalInputAttributes,
        ),
        HuiInlineIssues(_issuesFor('.player')),
      ]),
    ),
    HuiField(
      label: huiText('Refresh'),
      trailing: const HuiFieldHelp('icon.playerHead.refreshTicks'),
      help: huiText(
        'Ticks between re-reading the name and the profile cache; '
        '0 never re-reads it.',
      ),
      defaultValue: huiPlural(
        'duration.tick_count',
        huiRuntimeDefaultPlayerHeadRefreshTicks,
        oneEnglish: '{count} tick',
        otherEnglish: '{count} ticks',
      ),
      onReset: _refreshTicks == huiRuntimeDefaultPlayerHeadRefreshTicks
          ? null
          : () => onChanged(
              'player head refresh',
              _with(refreshTicks: huiRuntimeDefaultPlayerHeadRefreshTicks),
            ),
      control: dom.div(<Widget>[
        HuiNumberField(
          value: _refreshTicks.toDouble(),
          min: 0,
          max: 1200,
          step: 1,
          integer: true,
          suffix: huiText('ticks'),
          onChanged: (double value) => onChanged(
            'player head refresh',
            _with(refreshTicks: value.round()),
          ),
        ),
        HuiInlineIssues(_issuesFor('.refreshTicks')),
      ]),
    ),
    HuiNote(
      huiText(
        'The canvas draws the generic head for every name: a skin comes from '
        'a Mojang profile the server looks up and caches, and this editor has '
        'no server. Geometry is exact, because a head is drawn on the same '
        'item display an item icon uses.',
      ),
    ),
    HuiMore(
      summary: huiText('How a head resolves'),
      children: <Widget>[
        HuiNote(
          huiText(
            '%player_name%, %player% and {{ player.name }} always mean the '
            'viewer. Gloss answers those three itself, so each player sees '
            'their own head from one menu file and PlaceholderAPI is not '
            'needed for it.',
          ),
        ),
        HuiNote(
          huiText(
            'Any other placeholder goes through the text pipeline and needs '
            'whatever provides it. A token nothing expands still carries its '
            '% or {{ }}, which can never be a username, so it draws the '
            'fallback head without costing a request.',
          ),
        ),
        HuiNote(
          huiText(
            'The first render of a name is always the blank unowned head: the '
            'lookup is asynchronous and never blocks the server. A name that '
            'does not exist, or head resolution switched off in config.toml, '
            'draws the configured fallback block - a skeleton skull unless '
            'the operator changed it.',
          ),
        ),
      ],
    ),
  ]);
}
