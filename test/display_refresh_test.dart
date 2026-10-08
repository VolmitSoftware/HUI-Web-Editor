import 'package:gloss_editor/config/gloss_templates.dart';
import 'package:gloss_editor/logic/display_refresh_validation.dart';
import 'package:gloss_editor/logic/validation.dart';
import 'package:gloss_editor/model/model.dart';
import 'package:test/test.dart';

void main() {
  final GlossDisplayRefresh refresh = GlossDisplayRefresh(contentTicks: 20, visibilityTicks: 5, motionTicks: 2,
    extras: <String, Object?>{'custom': <String, Object?>{'enabled': true}});
  test('independent display refresh fields survive every owning document and copy', () {
    final GlossHologramDoc hologram = GlossHologramDoc()..refresh = refresh.copy();
    expect(decodeGlossHologramDoc(encodeGlossHologramDoc(hologram)).copy().refresh.toJson(), refresh.toJson());
    final GlossBubbleStyleDoc bubble = buildDefaultGlossBubbleStyle()..refresh = refresh.copy();
    expect(decodeGlossBubbleStyleDoc(encodeGlossBubbleStyleDoc(bubble)).copy().refresh.toJson(), refresh.toJson());
    final GlossDamageIndicatorsDoc indicator = buildDefaultGlossDamageIndicators();
    indicator.damage.presentation.refresh = refresh.copy();
    expect(decodeGlossDamageIndicatorsDoc(encodeGlossDamageIndicatorsDoc(indicator)).damage.presentation.copy().refresh.toJson(), refresh.toJson());
    final GlossRealDropSettingsDoc drop = buildDefaultGlossRealDrops();
    drop.presentation.labels.refresh = refresh.copy();
    expect(decodeGlossRealDropSettingsDoc(encodeGlossRealDropSettingsDoc(drop)).presentation.labels.copy().refresh.toJson(), refresh.toJson());
  });
  test('omitted cadence remains omitted and only explicit bounds validate', () {
    expect(GlossDisplayRefresh.fromJson(null).isEmpty, isTrue);
    expect(GlossHologramDoc().toJson().containsKey('refresh'), isFalse);
    expect(validateDisplayRefresh(refresh), isEmpty);
    final GlossDisplayRefresh invalid = GlossDisplayRefresh(contentTicks: 0, visibilityTicks: 1201);
    expect(validateDisplayRefresh(invalid).map((HuiIssue issue) => issue.path),
      <String>[r'$.refresh.contentTicks', r'$.refresh.visibilityTicks']);
  });
}
