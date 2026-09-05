/// Numeric input with optional step buttons.
///
/// arcane_jaspr has no number widget, so this wraps `TextInput` with
/// `type: number`. The editing text is local state: an unparseable or empty
/// entry is never committed, and it reverts to the last good value on blur, so
/// the document can never receive NaN. The framework's renderer already reads
/// the DOM value for us (`onChanged` receives the string), so no `package:web`
/// import is needed here.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../l10n/hui_localizations.dart';
import 'class_names.dart';

class HuiNumberField extends StatefulWidget {
  const HuiNumberField({
    required this.value,
    required this.onChanged,
    this.min,
    this.max,
    this.step = 0.05,
    this.decimals = 3,
    this.suffix,
    this.integer = false,
    this.steppers = true,
    this.disabled = false,
    this.placeholder,
    this.prefixLabel,
    this.ariaLabel,
    this.error,
    this.size = ComponentSize.sm,
    this.fullWidth = true,
    this.classes = '',
    super.key,
  });

  final double value;
  final void Function(double value) onChanged;

  /// Null means unbounded — the inspector deliberately allows out-of-range
  /// entry for fields the plugin clamps itself, and validation warns instead.
  final double? min;
  final double? max;

  /// Increment applied by the step buttons.
  final double step;

  /// Digits kept when the value is normalized (on blur and on step).
  final int decimals;
  final String? suffix;
  final bool integer;
  final bool steppers;
  final bool disabled;
  final String? placeholder;

  /// Short leading label rendered inside the control, e.g. the axis letter.
  final String? prefixLabel;
  final String? ariaLabel;
  final String? error;
  final ComponentSize size;
  final bool fullWidth;
  final String classes;

  @override
  State<HuiNumberField> createState() => _HuiNumberFieldState();
}

class _HuiNumberFieldState extends State<HuiNumberField> {
  late String _text;

  @override
  void initState() {
    super.initState();
    _text = _format(component.value);
  }

  @override
  void didUpdateComponent(HuiNumberField oldComponent) {
    super.didUpdateComponent(oldComponent);
    // Only overwrite what the user is typing when the incoming value genuinely
    // differs from it, so a commit round trip never fights the caret.
    final double? parsed = _parse(_text);
    if (parsed == null || _format(parsed) != _format(component.value)) {
      _text = _format(component.value);
    }
  }

  double? _parse(String raw) {
    final double? parsed = double.tryParse(raw.trim());
    if (parsed == null || !parsed.isFinite) return null;
    return parsed;
  }

  double _clamp(double value) {
    double out = value;
    final double? min = component.min;
    final double? max = component.max;
    if (min != null && out < min) out = min;
    if (max != null && out > max) out = max;
    return out;
  }

  double _normalize(double value) {
    if (component.integer) return value.roundToDouble();
    final int decimals = component.decimals.clamp(0, 10);
    final double factor = _pow10(decimals);
    return (value * factor).roundToDouble() / factor;
  }

  static double _pow10(int exponent) {
    double out = 1;
    for (int i = 0; i < exponent; i++) {
      out *= 10;
    }
    return out;
  }

  String _format(double value) {
    if (!value.isFinite) return '0';
    if (component.integer) return value.round().toString();
    String out = value.toStringAsFixed(component.decimals.clamp(0, 10));
    if (out.contains('.')) {
      while (out.endsWith('0')) {
        out = out.substring(0, out.length - 1);
      }
      if (out.endsWith('.')) out = out.substring(0, out.length - 1);
    }
    return out == '-0' ? '0' : out;
  }

  void _onInput(String raw) {
    _text = raw;
    final double? parsed = _parse(raw);
    if (parsed == null) return;
    final double next = _clamp(_normalize(parsed));
    if (next != component.value) component.onChanged(next);
  }

  void _onBlur() {
    final double? parsed = _parse(_text);
    if (parsed == null) {
      setState(() => _text = _format(component.value));
      return;
    }
    final double next = _clamp(_normalize(parsed));
    if (next != component.value) component.onChanged(next);
    final String formatted = _format(next);
    if (formatted != _text) setState(() => _text = formatted);
  }

  void _step(int direction) {
    final double base = component.value.isFinite ? component.value : 0;
    final double next = _clamp(_normalize(base + component.step * direction));
    setState(() => _text = _format(next));
    if (next != component.value) component.onChanged(next);
  }

  Widget _stepButton(String label, ArcaneGlyph icon, int direction) => Button(
    variant: ButtonVariant.outline,
    size: ButtonSize.iconSm,
    disabled: component.disabled,
    onPressed: component.disabled ? null : () => _step(direction),
    attributes: <String, String>{'aria-label': label},
    icon: icon,
  );

  @override
  Widget build(BuildContext context) {
    final Widget input = TextInput(
      type: TextInputType.number,
      value: _text,
      onInput: _onInput,
      onBlur: _onBlur,
      disabled: component.disabled,
      size: component.size,
      fullWidth: component.fullWidth,
      error: component.error,
      placeholder: component.placeholder,
      prefix: component.prefixLabel == null
          ? null
          : Text(component.prefixLabel!, color: TextColor.muted),
      suffix: component.suffix == null
          ? null
          : Text(component.suffix!, color: TextColor.muted),
      attributes: <String, String>{
        if (component.ariaLabel != null) 'aria-label': component.ariaLabel!,
        'inputmode': component.integer ? 'numeric' : 'decimal',
        'autocomplete': 'off',
        'step': component.integer ? '1' : _format(component.step),
        if (component.min != null) 'min': _format(component.min!),
        if (component.max != null) 'max': _format(component.max!),
      },
    );

    if (!component.steppers) {
      return dom.div(
        classes: classNames(<String?>['hui-number', component.classes]),
        <Widget>[input],
      );
    }

    return dom.div(
      classes: classNames(<String?>[
        'hui-number',
        'has-steppers',
        component.classes,
      ]),
      styles: const dom.Styles(
        raw: <String, String>{
          'display': 'flex',
          'align-items': 'center',
          'gap': '4px',
          'min-width': '0',
        },
      ),
      <Widget>[
        _stepButton(
          huiText('Decrease'),
          ArcaneIcon.minus(size: IconSize.sm),
          -1,
        ),
        dom.div(
          styles: const dom.Styles(
            raw: <String, String>{'flex': '1 1 auto', 'min-width': '0'},
          ),
          <Widget>[input],
        ),
        _stepButton(huiText('Increase'), ArcaneIcon.plus(size: IconSize.sm), 1),
      ],
    );
  }
}
