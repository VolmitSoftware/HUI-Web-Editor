import 'dart:math' as math;

import '../model/model.dart';
import 'gloss_text.dart';
import 'preview_expr.dart';

final class ExpandedMenuComponent {
  const ExpandedMenuComponent(
    this.component,
    this.authoringId, [
    this.values = const <String, Object>{},
  ]);

  final HuiComponent component;
  final String authoringId;
  final Map<String, Object> values;
}

GlossTextExpressionSamples menuExpressionSamples(
  HuiMenu menu, {
  GlossTextExpressionSamples samples = const GlossTextExpressionSamples(),
}) {
  final Map<String, Object> values = <String, Object>{};
  final Object? declared = menu.extras['vars'];
  if (declared is Map) {
    final GlossTextExpressionScope scope = GlossTextExpressionScope(0, samples);
    for (final MapEntry<Object?, Object?> entry in declared.entries) {
      if (entry.key is! String || entry.value is! String) continue;
      try {
        final PExpr expression = parsePreviewExpr(entry.value as String);
        if (!isConstantExpr(expression)) continue;
        values['session.${entry.key}'] = evalPreviewExpr(expression, scope);
      } on PExprException {
        continue;
      }
    }
  }
  return GlossTextExpressionSamples(
    placeholders: samples.placeholders,
    metrics: samples.metrics,
    serverTps: samples.serverTps,
    names: samples.names,
    bedrockViewer: samples.bedrockViewer,
    values: <String, Object>{...values, ...samples.values},
  );
}

GlossTextExpressionSamples withMenuSampleValues(
  GlossTextExpressionSamples samples,
  Map<String, Object> values,
) => GlossTextExpressionSamples(
  placeholders: samples.placeholders,
  metrics: samples.metrics,
  serverTps: samples.serverTps,
  names: samples.names,
  bedrockViewer: samples.bedrockViewer,
  values: <String, Object>{...samples.values, ...values},
);

List<ExpandedMenuComponent> expandMenuComponents(
  List<HuiComponent> components, {
  GlossTextExpressionSamples samples = const GlossTextExpressionSamples(),
  int maxListEntries = 64,
}) {
  final List<ExpandedMenuComponent> expanded = <ExpandedMenuComponent>[];
  for (final HuiComponent component in components) {
    final HuiComponentData data = component.data;
    if (data is HuiTabsData) {
      final List<HuiTab> tabs = data.tabs ?? <HuiTab>[];
      final double spacing = (data.spacing ?? 1) > 0 ? data.spacing ?? 1 : 1;
      final double span = spacing * (tabs.length - 1) / 2;
      for (int index = 0; index < tabs.length; index++) {
        final HuiComponent tab = component.copy()
          ..id = '${component.id}#$index'
          ..offset.x += index * spacing - span;
        expanded.add(ExpandedMenuComponent(tab, component.id));
      }
    } else if (data is HuiListData) {
      if (data.template == null || data.source == null) continue;
      final Object source;
      try {
        source = evalPreviewExpr(
          parsePreviewExpr(data.source!),
          GlossTextExpressionScope(0, samples),
        );
      } on PExprException {
        continue;
      }
      if (source is! List) continue;
      final Map<String, Object?> flow = data.flow ?? <String, Object?>{};
      final int columns = math.max(1, (flow['columns'] as num?)?.toInt() ?? 3);
      final double spacingX = (flow['spacingX'] as num?)?.toDouble() ?? 1;
      final double spacingY = (flow['spacingY'] as num?)?.toDouble() ?? 0.5;
      final double x = (flow['x'] as num?)?.toDouble() ?? 0;
      final double y = (flow['y'] as num?)?.toDouble() ?? 0;
      final int count = math.min(
        source.length,
        math.min(math.max(1, data.pageSize ?? 6), math.max(1, maxListEntries)),
      );
      for (int index = 0; index < count; index++) {
        final HuiComponent entry = component.copy()
          ..id = '${component.id}[$index]'
          ..data = data.template!.copy()
          ..offset.x += x + (index % columns) * spacingX
          ..offset.y += y - (index ~/ columns) * spacingY;
        expanded.add(
          ExpandedMenuComponent(entry, component.id, <String, Object>{
            if (data.variable != null && source[index] != null)
              data.variable!: source[index] as Object,
          }),
        );
      }
    } else {
      expanded.add(ExpandedMenuComponent(component, component.id));
    }
  }
  return expanded;
}

HuiIcon? menuFormIcon(HuiRuntimeComponentData data, String componentId) {
  if (data is HuiSliderData) {
    return HuiTextIcon(data.label ?? '')..style = data.style?.copy();
  }
  if (data is HuiFieldData) {
    return HuiTextIcon(data.label ?? '')..style = data.style?.copy();
  }
  if (data is HuiTabsData) {
    final int index = int.tryParse(componentId.split('#').last) ?? 0;
    final List<HuiTab> tabs = data.tabs ?? <HuiTab>[];
    final String label = index < tabs.length
        ? tabs[index].label ?? tabs[index].id
        : '';
    return HuiTextIcon(label)..style = data.style?.copy();
  }
  return null;
}
