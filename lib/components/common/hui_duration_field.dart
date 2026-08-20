/// A duration entered in the plugin's own unit, read back in seconds.
///
/// Gloss measures time in two units and never says which one a field uses:
/// ticks for anything driven by the server loop, milliseconds for anything
/// driven by wall time. Both are numbers a builder has to convert in their head
/// before they know whether 4 is a blink or a pause, so this keeps the stored
/// unit in the input and puts the human number next to it.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import 'class_names.dart';
import 'hui_number_field.dart';

/// The unit the document stores.
enum HuiDurationUnit {
  /// Server ticks. One tick is 50 ms, and the server never subdivides one.
  ticks,

  /// Wall-clock milliseconds.
  milliseconds,
}

extension HuiDurationUnitNames on HuiDurationUnit {
  /// Suffix shown inside the input.
  String get suffix => this == HuiDurationUnit.ticks ? 'ticks' : 'ms';

  /// Milliseconds one unit is worth.
  double get millisecondsEach => this == HuiDurationUnit.ticks ? 50 : 1;
}

/// `4` ticks reads as `0.2s`; `60000` ms reads as `60s`. Sub-millisecond
/// precision is never useful here, and neither is a trailing `.00`.
String huiFormatDuration(double value, HuiDurationUnit unit) {
  final double seconds = value * unit.millisecondsEach / 1000;
  if (seconds == 0) return 'instant';
  if (seconds < 1) return '${(seconds * 1000).round()}ms';
  final String text = seconds.toStringAsFixed(seconds < 10 ? 2 : 1);
  return '${text.replaceFirst(RegExp(r'\.?0+$'), '')}s';
}

class HuiDurationField extends StatelessWidget {
  const HuiDurationField({
    required this.value,
    required this.onChanged,
    required this.unit,
    this.min,
    this.max,
    this.step = 1,
    this.disabled = false,
    this.perLabel,
    this.classes = '',
    super.key,
  });

  /// The stored number, in [unit].
  final double value;
  final void Function(double value) onChanged;
  final HuiDurationUnit unit;

  /// Null keeps the entry unbounded — the inspector deliberately allows values
  /// the plugin clamps itself, so validation can explain the clamp rather than
  /// the control hiding it.
  final double? min;
  final double? max;
  final double step;
  final bool disabled;

  /// Appended to the readout when the duration is per something, e.g.
  /// `per frame`.
  final String? perLabel;
  final String classes;

  @override
  Widget build(BuildContext context) => dom.div(
    classes: classNames(<String?>['hui-duration-field', classes]),
    styles: const dom.Styles(
      raw: <String, String>{
        'display': 'flex',
        'align-items': 'center',
        'gap': '8px',
        'min-width': '0',
      },
    ),
    <Widget>[
      dom.div(
        styles: const dom.Styles(
          raw: <String, String>{'flex': '1 1 auto', 'min-width': '0'},
        ),
        <Widget>[
          HuiNumberField(
            value: value,
            onChanged: onChanged,
            min: min,
            max: max,
            step: step,
            decimals: 0,
            integer: true,
            steppers: false,
            disabled: disabled,
            suffix: unit.suffix,
          ),
        ],
      ),
      dom.span(
        classes: 'hui-unit-chip hui-duration-readout',
        attributes: const <String, String>{'aria-hidden': 'true'},
        <Widget>[
          Text(
            perLabel == null
                ? huiFormatDuration(value, unit)
                : '${huiFormatDuration(value, unit)} $perLabel',
          ),
        ],
      ),
    ],
  );
}
