/// Three-axis block-space vector editor.
///
/// HoloUI vectors are always three numbers, so this always renders three
/// fields. [axisHints] carries the meaning of each axis (right / up / forward)
/// as a tooltip, because that mapping is the single most common authoring
/// mistake.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../model/vec3.dart';
import 'class_names.dart';
import 'hui_number_field.dart';

/// Default hints for a menu- or component-space offset.
const List<String> huiVec3OffsetHints = <String>[
  'x: right of the player',
  'y: up (1.7 is roughly eye level)',
  'z: forward, away from the player',
];

class HuiVec3Field extends StatelessWidget {
  const HuiVec3Field({
    required this.value,
    required this.onChanged,
    this.axisHints = huiVec3OffsetHints,
    this.labels = const <String>['X', 'Y', 'Z'],
    this.step = 0.05,
    this.decimals = 3,
    this.disabled = false,
    this.classes = '',
    super.key,
  });

  final Vec3 value;
  final void Function(Vec3 value) onChanged;

  /// Tooltip per axis; shorter lists simply leave later axes without a hint.
  final List<String> axisHints;
  final List<String> labels;
  final double step;
  final int decimals;
  final bool disabled;
  final String classes;

  String _label(int index) =>
      index < labels.length ? labels[index] : <String>['X', 'Y', 'Z'][index];

  String? _hint(int index) =>
      index < axisHints.length && axisHints[index].isNotEmpty
      ? axisHints[index]
      : null;

  Widget _axis(int index, double axisValue, void Function(double) apply) {
    final Widget field = HuiNumberField(
      value: axisValue,
      onChanged: apply,
      step: step,
      decimals: decimals,
      disabled: disabled,
      steppers: false,
      prefixLabel: _label(index),
    );
    final String? hint = _hint(index);
    return hint == null ? field : ArcaneTooltip(text: hint, child: field);
  }

  @override
  Widget build(BuildContext context) => dom.div(
    classes: classNames(<String?>['hui-vec3', classes]),
    styles: const dom.Styles(
      raw: <String, String>{
        'display': 'grid',
        'grid-template-columns': 'repeat(3, minmax(0, 1fr))',
        'gap': '6px',
        'min-width': '0',
      },
    ),
    <Widget>[
      _axis(0, value.x, (double v) => onChanged(Vec3(v, value.y, value.z))),
      _axis(1, value.y, (double v) => onChanged(Vec3(value.x, v, value.z))),
      _axis(2, value.z, (double v) => onChanged(Vec3(value.x, value.y, v))),
    ],
  );
}
