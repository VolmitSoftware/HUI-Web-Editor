/// Arm-then-confirm destructive control.
///
/// The design language replaces confirm dialogs with a two-step button: the
/// first press arms the action and swaps in a destructive check plus a cancel,
/// and only the check runs it. Used by the components rail, the image manager,
/// the workspace switcher and the reset-local-data action.
library;

import 'package:arcane_jaspr/arcane_jaspr.dart';
import 'package:jaspr/dom.dart' as dom;

import '../../l10n/hui_localizations.dart';
import '../common/common.dart';

class HuiTwoStepButton extends StatefulWidget {
  const HuiTwoStepButton({
    required this.label,
    required this.icon,
    required this.onConfirm,
    this.confirmLabel,
    this.cancelLabel,
    this.iconOnly = false,
    this.size = ButtonSize.small,
    this.disabled = false,
    this.classes = '',
    super.key,
  });

  /// Resting label; also the `aria-label` when [iconOnly].
  final String label;
  final ArcaneGlyph icon;
  final void Function() onConfirm;
  final String? confirmLabel;
  final String? cancelLabel;
  final bool iconOnly;
  final ButtonSize size;
  final bool disabled;
  final String classes;

  @override
  State<HuiTwoStepButton> createState() => _HuiTwoStepButtonState();
}

class _HuiTwoStepButtonState extends State<HuiTwoStepButton> {
  bool _armed = false;

  void _arm() => setState(() => _armed = true);

  void _cancel() => setState(() => _armed = false);

  void _confirm() {
    setState(() => _armed = false);
    component.onConfirm();
  }

  @override
  Widget build(BuildContext context) {
    final String confirmLabel = component.confirmLabel ?? huiText('Confirm');
    final String cancelLabel = component.cancelLabel ?? huiText('Cancel');
    if (!_armed) {
      return dom.div(
        classes: classNames(<String?>['hui-two-step', component.classes]),
        <Widget>[
          if (component.iconOnly)
            ArcaneTooltip(
              text: component.label,
              child: Button(
                variant: ButtonVariant.ghost,
                size: component.size,
                disabled: component.disabled,
                onPressed: component.disabled ? null : _arm,
                attributes: <String, String>{'aria-label': component.label},
                icon: component.icon,
              ),
            )
          else
            Button(
              variant: ButtonVariant.outline,
              size: component.size,
              disabled: component.disabled,
              onPressed: component.disabled ? null : _arm,
              icon: component.icon,
              label: component.label,
            ),
        ],
      );
    }

    return dom.div(
      classes: classNames(<String?>[
        'hui-two-step',
        'is-armed',
        component.classes,
      ]),
      styles: const dom.Styles(
        raw: <String, String>{
          'display': 'flex',
          'align-items': 'center',
          'gap': '4px',
        },
      ),
      <Widget>[
        Button(
          variant: ButtonVariant.destructive,
          size: component.size,
          onPressed: _confirm,
          attributes: <String, String>{'aria-label': confirmLabel},
          icon: ArcaneIcon.check(size: IconSize.sm),
          label: component.iconOnly ? null : confirmLabel,
        ),
        ArcaneTooltip(
          text: cancelLabel,
          child: Button(
            variant: ButtonVariant.ghost,
            size: component.size,
            onPressed: _cancel,
            attributes: <String, String>{'aria-label': cancelLabel},
            icon: ArcaneIcon.x(size: IconSize.sm),
          ),
        ),
      ],
    );
  }
}
