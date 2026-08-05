/// The preview's readout strip.
///
/// Reads [PreviewLiveState], which the stage writes once per 50 ms simulation
/// tick and which notifies only when a value actually changed — so a parked
/// pointer over a static menu rebuilds nothing.
///
/// It is chrome, not an overlay: it sits in the view's grid rather than floating
/// over the scene, so it never covers the menu it is describing and it is
/// reachable by a screen reader. Only the session-state chip is a live region;
/// the distance readout changes twenty times a second and announcing it would
/// make the view unusable.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;
import 'package:jaspr/jaspr.dart' show Component;

import '../../model/model.dart';
import '../../state/editor_store.dart';
import 'preview_pose.dart';

class PreviewHud extends StatelessWidget {
  const PreviewHud({required this.store, required this.pose, super.key});

  final EditorStore store;
  final PreviewPose pose;

  @override
  Widget build(BuildContext context) {
    final PreviewLiveState live = pose.live;
    final HuiMenu menu = store.menu;
    return dom.div(
      classes: 'hui-preview-hudbar',
      attributes: const <String, String>{'aria-label': 'Preview readout'},
      <Widget>[
        _state(live),
        _hovered(live),
        _push(live),
        _distance(live, menu),
        if (live.movementLocked) _locked(),
        if (menu.followPlayer) _follows(),
      ],
    );
  }

  /// The session state, named with the runtime's own reason token so a search
  /// for what a player saw in chat lands here.
  Widget _state(PreviewLiveState live) {
    final String? reason = live.closeReason?.wireName;
    final String text = live.isOpen ? 'Open' : 'Closed — ${reason ?? 'CLOSED'}';
    return dom.div(
      classes:
          'hui-preview-hudbar-item is-state'
          '${live.isOpen ? ' is-open' : ' is-closed'}',
      // The one value here slow enough to announce.
      attributes: const <String, String>{'role': 'status'},
      <Widget>[
        _label('menu'),
        dom.span(classes: 'hui-preview-hudbar-value', <Widget>[
          Component.text(text),
        ]),
        if (!live.isOpen)
          const dom.span(classes: 'hui-preview-hudbar-note', <Widget>[
            Component.text('Reopen here starts a fresh session'),
          ]),
      ],
    );
  }

  /// The first hovered clickable in declaration order, plus how many are
  /// stacked behind it — because a single left click fires every one of them
  /// (`SessionHolder.java:145-159`).
  Widget _hovered(PreviewLiveState live) {
    final String? id = live.hoveredId;
    final int behind = live.hoveredIds > 1 ? live.hoveredIds - 1 : 0;
    return _item(
      label: 'hovered',
      value: id ?? 'nothing',
      muted: id == null,
      note: behind == 0
          ? null
          : '+$behind behind — one click fires all ${live.hoveredIds}',
      noteIsWarning: true,
    );
  }

  /// The hover displacement applied while the look ray remains in the plane.
  Widget _push(PreviewLiveState live) {
    if (live.hoveredId == null) {
      return _item(label: 'push', value: '—', muted: true);
    }
    return _item(
      label: 'push',
      value: '${_blocks(live.hoverPushBlocks)} blocks',
      note:
          'tick ${live.hoverTicks} — highlightModifier '
          '${_blocks(live.highlightModifier)}',
    );
  }

  /// Player to menu centre. The runtime measures against the centre, not the
  /// icons, and loosens the test by the menu offset's own length
  /// (`MenuSession.java:147-151`), so the raw numbers are worth showing.
  Widget _distance(PreviewLiveState live, HuiMenu menu) {
    final double? max = menu.maxDistance;
    return _item(
      label: 'distance',
      value: max == null
          ? '${live.distanceToCenter.toStringAsFixed(2)} blocks'
          : '${live.distanceToCenter.toStringAsFixed(2)} / '
                '${_blocks(max)} blocks',
      note: max == null
          ? 'no maxDistance — the menu never closes on range'
          : null,
    );
  }

  Widget _locked() => _item(
    label: 'movement',
    value: 'locked',
    note: 'lockPosition rewrites the move destination back to its origin',
    noteIsWarning: true,
  );

  Widget _follows() => _item(
    label: 'follow',
    value: 'on',
    note: 'followPlayer recentres the menu as the player walks',
  );

  Widget _item({
    required String label,
    required String value,
    String? note,
    bool muted = false,
    bool noteIsWarning = false,
  }) => dom.div(classes: 'hui-preview-hudbar-item', <Widget>[
    _label(label),
    dom.span(
      classes: 'hui-preview-hudbar-value${muted ? ' is-muted' : ''}',
      <Widget>[Component.text(value)],
    ),
    if (note != null)
      dom.span(
        classes: 'hui-preview-hudbar-note${noteIsWarning ? ' is-warning' : ''}',
        <Widget>[Component.text(note)],
      ),
  ]);

  static Widget _label(String text) => dom.span(
    classes: 'hui-preview-hudbar-label',
    <Widget>[Component.text(text)],
  );

  /// Whole values read as whole numbers; `1.00` in a readout is noise.
  static String _blocks(double value) {
    if (!value.isFinite) return '$value';
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
