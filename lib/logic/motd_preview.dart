/// What a server-list ping carries besides the MOTD line, resolved the way
/// `MotdService` resolves it.
///
/// `applyExtras` sends four things past the text: the icon (`motd_view`'s own
/// slot), the player counts, the hover sample and the version label. The
/// counts and the version go through `renderStatic` first, so they are
/// authored text like everything else — which is why they are computed here,
/// DOM-free, rather than inside the preview component.
///
/// The server edition splits along Paper: `max` is plain Bukkit
/// (`event.setMaxPlayers`), while the sample, the online count and the version
/// reach the client only through the Paper ping bridge. The preview draws all
/// four, because the editor cannot know which server the document will land
/// on; the inspector's help says which is which.
library;

import '../model/gloss_motd.dart';
import 'gloss_text.dart';

/// The player count the mock row falls back to, standing in for the figure a
/// real server reports. Cosmetic: the plugin never writes it.
const int glossMotdSampledOnline = 17;

/// The slot count behind the same fallback.
const int glossMotdSampledMax = 100;

/// `online/max` for the row's right-hand slot.
///
/// `MotdService.number` renders the authored text and parses the result; blank
/// or unparseable leaves the server's own figure alone, so the sampled count
/// stands in here for exactly the cases the ping would leave untouched.
String glossMotdPlayerCount(
  GlossMotdEntry? entry, {
  GlossAnimationResolver animations = const GlossNoAnimations(),
  GlossEmojiResolver emoji = const GlossNoEmoji(),
  int nowMs = 0,
}) {
  final int online =
      _number(entry?.online, animations, emoji, nowMs) ??
      glossMotdSampledOnline;
  final int max =
      _number(entry?.max, animations, emoji, nowMs) ?? glossMotdSampledMax;
  return '$online/$max';
}

/// The hover list under the count: the entry's own lines, still authored, cut
/// at `MotdDoc.MAX_SAMPLE_LINES` because a longer list never reaches a client
/// — the document does not load at all.
List<String> glossMotdSampleLines(GlossMotdEntry? entry) {
  final List<String> sample = entry?.sample ?? const <String>[];
  return sample.take(glossMotdMaxSampleLines).toList();
}

/// The version label, authored, or null when the entry names none. The client
/// draws it where the ping bars sit, and only when the protocol does not
/// match, so the preview always shows that slot taken.
String? glossMotdVersionLabel(GlossMotdEntry? entry) {
  final String? version = entry?.version;
  if (version == null || version.trim().isEmpty) return null;
  return version;
}

/// `MotdService.number`: render, then `(int) Double.parseDouble`. The render
/// keeps its colour codes, which is why `&a100` is not a number here either.
int? _number(
  String? raw,
  GlossAnimationResolver animations,
  GlossEmojiResolver emoji,
  int nowMs,
) {
  if (raw == null || raw.trim().isEmpty) return null;
  final String rendered = renderGlossLine(
    raw,
    animations: animations,
    emoji: emoji,
    nowMs: nowMs,
    viewerAware: false,
  ).renderedText;
  if (rendered.trim().isEmpty) return null;
  return double.tryParse(rendered.trim())?.toInt();
}
