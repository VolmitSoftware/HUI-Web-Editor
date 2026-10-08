library;

import '../model/gloss_channel.dart';
import '../services/channel_filters_stub.dart'
    if (dart.library.js_interop) '../services/channel_filters_web.dart'
    as platform;

final class ChannelFilterResult {
  const ChannelFilterResult(this.message, {this.notice});
  final String? message;
  final String? notice;
}

ChannelFilterResult previewChannelFilters(GlossChannelDoc doc, String message) {
  if (doc.filters.isEmpty) return ChannelFilterResult(message);
  final Map<String, Object?> result = platform.run(doc.toJson(), message);
  return ChannelFilterResult(
    result['message'] as String?,
    notice: result['notice'] as String?,
  );
}

String? validateChannelFilterSyntax(GlossChannelDoc doc) =>
    platform.validate(doc.toJson());
