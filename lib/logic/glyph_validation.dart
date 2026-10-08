import '../model/gloss_glyph.dart';
import '../model/gloss_doc.dart';
import 'validation.dart';

List<HuiIssue> validateGlyphDoc(GlossGlyphDoc doc) {
  final List<HuiIssue> issues = <HuiIssue>[?glossRevisionIssue(doc.revision)];
  void error(String path, String message) => issues.add(
    HuiIssue(severity: HuiSeverity.error, path: path, message: message),
  );
  void id(String value, String path) {
    if (value.length > 64 ||
        !RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(value.trim())) {
      error(
        path,
        'Use at most 64 lowercase letters, digits, underscores or hyphens; start with a letter or digit.',
      );
    }
  }

  void image(String value, String path) {
    final String normalized = value.trim().replaceAll('\\', '/');
    if (!RegExp(r'^[A-Za-z0-9_.\-/]+$').hasMatch(normalized) ||
        normalized.startsWith('/') ||
        normalized.contains('..') ||
        normalized.contains('//') ||
        !normalized.toLowerCase().endsWith('.png')) {
      error(path, 'Use a relative PNG path inside images/.');
    }
  }

  void bitmap(String value, int height, int ascent, String path) {
    image(value, '$path.image');
    if (height < 1 || height > 256) {
      error('$path.height', 'Height must be 1 through 256.');
    }
    if (ascent > height) {
      error('$path.ascent', 'Ascent must not exceed height.');
    }
  }

  for (final MapEntry<String, String> entry in <String, String>{
    'namespace': doc.namespace,
    'font': doc.font,
  }.entries) {
    if (entry.value.trim().isNotEmpty &&
        !RegExp(r'^[a-z0-9_.-]+$').hasMatch(entry.value.trim().toLowerCase())) {
      error(
        '\$.${entry.key}',
        'Use letters, digits, underscores, dots or hyphens.',
      );
    }
  }
  if (doc.glyphs.length + doc.overlays.length > 1024) {
    error(
      r'$.glyphs',
      'A document supports at most 1024 glyphs and overlays combined.',
    );
  }
  final Set<String> ids = <String>{};
  for (int index = 0; index < doc.glyphs.length; index++) {
    final GlossGlyph glyph = doc.glyphs[index];
    final String path = '\$.glyphs[$index]';
    id(glyph.id, '$path.id');
    if (!ids.add(glyph.id.trim())) {
      error('$path.id', 'Glyph and overlay IDs must be unique.');
    }
    bitmap(glyph.image, glyph.height, glyph.ascent, path);
    if (glyph.frames < 1 || glyph.frames > 256) {
      error('$path.frames', 'Frames must be 1 through 256.');
    }
    if (glyph.width != null && (glyph.width! < 0 || glyph.width! > 1024)) {
      error('$path.width', 'Width must be 0 through 1024, or absent.');
    }
  }
  for (int index = 0; index < doc.overlays.length; index++) {
    final GlossGlyphOverlay overlay = doc.overlays[index];
    final String path = '\$.overlays[$index]';
    id(overlay.id, '$path.id');
    if (!ids.add(overlay.id.trim())) {
      error('$path.id', 'Glyph and overlay IDs must be unique.');
    }
    bitmap(overlay.image, overlay.height, overlay.ascent, path);
    if (!const <String>{
      'top',
      'center',
      'bottom',
    }.contains(overlay.anchor.trim().toLowerCase())) {
      error('$path.anchor', 'Choose top, center or bottom.');
    }
  }
  if (doc.space.range.length != 2 ||
      doc.space.range.first < -256 ||
      doc.space.range.last > 256 ||
      doc.space.range.first > doc.space.range.last) {
    error(r'$.space.range', 'Use [minimum, maximum] within -256 through 256.');
  }
  if (doc.waypointStyles.length > 128) {
    error(
      r'$.waypointStyles',
      'A document supports at most 128 waypoint styles.',
    );
  }
  final Set<String> styles = <String>{};
  for (int index = 0; index < doc.waypointStyles.length; index++) {
    final GlossWaypointStyleAsset style = doc.waypointStyles[index];
    final String path = '\$.waypointStyles[$index]';
    id(style.id, '$path.id');
    if (!styles.add(style.id.trim())) {
      error('$path.id', 'Waypoint style IDs must be unique.');
    }
    if (!style.nearDistance.isFinite ||
        !style.farDistance.isFinite ||
        style.nearDistance < 0 ||
        style.farDistance <= style.nearDistance) {
      error(
        '$path.farDistance',
        'Distances must satisfy 0 <= near distance < far distance.',
      );
    }
    if (style.sprites.isEmpty || style.sprites.length > 64) {
      error('$path.sprites', 'A waypoint style requires 1 through 64 sprites.');
    }
    final Map<String, String> spriteImages = <String, String>{};
    for (
      int spriteIndex = 0;
      spriteIndex < style.sprites.length;
      spriteIndex++
    ) {
      final GlossWaypointSprite sprite = style.sprites[spriteIndex];
      id(sprite.id, '$path.sprites[$spriteIndex].id');
      image(sprite.image, '$path.sprites[$spriteIndex].image');
      final String? prior = spriteImages[sprite.id];
      if (prior != null && prior != sprite.image) {
        error(
          '$path.sprites[$spriteIndex].id',
          'A sprite ID must use the same image within its style.',
        );
      }
      spriteImages[sprite.id] = sprite.image;
    }
  }
  return issues;
}
