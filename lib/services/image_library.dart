/// Local image library backing `textImage` / `animatedTextImage` icons.
///
/// The plugin resolves every icon path against `plugins/Gloss/images/`, so the
/// stored path IS the JSON value and IS the zip entry name — keeping those three
/// identical is the whole point of this class. Browser uploads are normalized
/// to PNG; server-sync imports preserve supported source formats losslessly.
/// Data URIs are persisted at [ImageLibrary.storageKey]; writes that exceed the
/// browser quota are rolled back instead of silently dropping the library, which
/// is how the previous editor lost documents.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:jaspr/jaspr.dart';

import '../l10n/hui_localizations.dart';
import 'image_library_stub.dart'
    if (dart.library.js_interop) 'image_library_web.dart';
import 'storage_service.dart';

/// Gloss reads paths with `new File(imagesFolder, path)`; anything longer than
/// this is rejected by common filesystems.
const int huiMaxImagePathLength = 256;

/// One `TextDisplay` per image row and one character per pixel. Text images are
/// intentionally limited to compact pixel art because glyphs are not a seamless
/// or inexpensive general-purpose image surface.
const int huiRecommendedMaxImageDimension = 16;

/// Hard ceiling for a single stored image. localStorage gives the whole origin
/// roughly 5 MB, so a single oversized upload must never be allowed to consume
/// it. Gloss images are a couple of KB.
const int huiMaxStoredImageBytes = 512 * 1024;
const int huiMaxDecodedImagePixels = 2048 * 2048;
const int huiMaxImportedAnimationFrames = maxDecodedAnimationFrames;
const String huiNormalizedPngDataUriPrefix = 'data:image/png;base64,';
final RegExp _animationFramePathPattern = RegExp(r'^(.*)/frame-\d{3}\.png$');

typedef ImageStorageWriter = bool Function(String key, String value);
typedef ImageLocalizedMessage = String Function();

bool _writeImageStorage(String key, String value) =>
    StorageService.write(key, value);

final class StoredPngData {
  const StoredPngData({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

final class StoredImageData {
  const StoredImageData({
    required this.bytes,
    required this.width,
    required this.height,
    required this.mediaType,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final String mediaType;
}

final class NormalizedImageData {
  const NormalizedImageData({
    required this.dataUri,
    required this.width,
    required this.height,
  });

  final String dataUri;
  final int width;
  final int height;
}

NormalizedImageData? normalizeUploadedPng(
  String dataUri, {
  int maxDimension = huiRecommendedMaxImageDimension,
}) {
  if (maxDimension <= 0) return null;
  final Uint8List? bytes = decodeDataUriBytes(dataUri);
  if (bytes == null) return null;
  final img.Image? decoded = img.decodePng(bytes);
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) return null;
  final ({int width, int height}) dimensions = fitImageDimensions(
    decoded.width,
    decoded.height,
    maxDimension,
  );
  final img.Image normalized =
      dimensions.width == decoded.width && dimensions.height == decoded.height
      ? decoded
      : img.copyResize(
          decoded,
          width: dimensions.width,
          height: dimensions.height,
          interpolation: img.Interpolation.average,
        );
  final Uint8List png = img.encodePng(normalized);
  return NormalizedImageData(
    dataUri: '$huiNormalizedPngDataUriPrefix${base64Encode(png)}',
    width: normalized.width,
    height: normalized.height,
  );
}

({int width, int height}) fitImageDimensions(
  int width,
  int height,
  int maxDimension,
) {
  if (width <= 0 || height <= 0 || maxDimension <= 0) {
    return (width: 0, height: 0);
  }
  if (width <= maxDimension && height <= maxDimension) {
    return (width: width, height: height);
  }
  final double scale = maxDimension / (width > height ? width : height);
  return (
    width: (width * scale).round().clamp(1, maxDimension),
    height: (height * scale).round().clamp(1, maxDimension),
  );
}

NormalizedImageData? minecraftHeadFromSkinPng(String dataUri) {
  final Uint8List? bytes = decodeDataUriBytes(dataUri);
  if (bytes == null) return null;
  final img.Image? skin = img.decodePng(bytes);
  if (skin == null || skin.width < 64 || skin.width % 64 != 0) return null;
  final int scale = skin.width ~/ 64;
  if (skin.height != 32 * scale && skin.height != 64 * scale) return null;
  img.Image face = img.copyCrop(
    skin,
    x: 8 * scale,
    y: 8 * scale,
    width: 8 * scale,
    height: 8 * scale,
  );
  img.Image hat = img.copyCrop(
    skin,
    x: 40 * scale,
    y: 8 * scale,
    width: 8 * scale,
    height: 8 * scale,
  );
  if (scale != 1) {
    face = img.copyResize(
      face,
      width: 8,
      height: 8,
      interpolation: img.Interpolation.nearest,
    );
    hat = img.copyResize(
      hat,
      width: 8,
      height: 8,
      interpolation: img.Interpolation.nearest,
    );
  }
  if (_skinHasUsableHatLayer(skin, scale)) {
    img.compositeImage(face, hat);
  }
  final Uint8List png = img.encodePng(face);
  return NormalizedImageData(
    dataUri: '$huiNormalizedPngDataUriPrefix${base64Encode(png)}',
    width: 8,
    height: 8,
  );
}

/// The client's own legacy-skin transparency rule, so an old 64x32 skin does not
/// composite to a solid black head.
///
/// A 64x32 skin predates alpha in the format: accounts from that era encode "no
/// hat" as an opaque strip rather than a transparent one, and skin CDNs hand
/// those bytes back unchanged. Minecraft's own downloader checks the whole hat
/// strip (x 32..64, y 0..16) and, when every pixel in it is opaque, discards the
/// overlay entirely instead of drawing it. A 64x64 skin always has a real alpha
/// channel, so the rule never applies to one.
bool _skinHasUsableHatLayer(img.Image skin, int scale) {
  if (skin.height != 32 * scale) return true;
  for (int y = 0; y < 16 * scale; y++) {
    for (int x = 32 * scale; x < 64 * scale; x++) {
      if (skin.getPixel(x, y).a < 128) return true;
    }
  }
  return false;
}

class StoredImage {
  const StoredImage({
    required this.path,
    required this.dataUri,
    required this.width,
    required this.height,
  });

  /// Path relative to `plugins/Gloss/images/`, forward slashes, no leading `/`.
  final String path;

  /// Validated base64 data URI. Uploads are PNG; synced assets may retain JPEG,
  /// GIF, WebP or BMP bytes.
  final String dataUri;
  final int width;
  final int height;

  int get pixelCount => width * height;

  bool get isOversized =>
      width > huiRecommendedMaxImageDimension ||
      height > huiRecommendedMaxImageDimension;

  /// Approximate localStorage cost of this entry (UTF-16, key included).
  int get approximateBytes => (dataUri.length + path.length + 48) * 2;

  StoredImage copyWith({
    String? path,
    String? dataUri,
    int? width,
    int? height,
  }) => StoredImage(
    path: path ?? this.path,
    dataUri: dataUri ?? this.dataUri,
    width: width ?? this.width,
    height: height ?? this.height,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'path': path,
    'dataUri': dataUri,
    'width': width,
    'height': height,
  };

  static StoredImage? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) {
      return null;
    }
    final Object? path = raw['path'];
    final Object? dataUri = raw['dataUri'];
    if (path is! String ||
        dataUri is! String ||
        path.isEmpty ||
        dataUri.isEmpty) {
      return null;
    }
    final Object? width = raw['width'];
    final Object? height = raw['height'];
    return StoredImage(
      path: path,
      dataUri: dataUri,
      width: width is num ? width.toInt() : 0,
      height: height is num ? height.toInt() : 0,
    );
  }
}

/// Row-major pixel grid, `rows[y][x]` packed as 0xAARRGGBB — the exact shape the
/// canvas needs to emit one block character per source pixel.
class ImagePixels {
  const ImagePixels({
    required this.width,
    required this.height,
    required this.rows,
  });

  final int width;
  final int height;
  final List<List<int>> rows;

  /// Transparent black outside the grid so callers can skip bounds checks.
  int at(int x, int y) {
    if (x < 0 || y < 0 || y >= rows.length) {
      return 0;
    }
    final List<int> row = rows[y];
    if (x >= row.length) {
      return 0;
    }
    return row[x];
  }
}

/// Result of an upload batch: what landed, what did not, and whether the browser
/// refused the write (in which case nothing was kept).
class ImageAddOutcome {
  const ImageAddOutcome({
    required this.added,
    required List<String> errors,
    required List<String> warnings,
    required this.quotaExceeded,
  }) : _literalErrors = errors,
       _literalWarnings = warnings,
       _localizedErrors = null,
       _localizedWarnings = null;

  ImageAddOutcome._localized({
    required this.added,
    required List<ImageLocalizedMessage> errors,
    required List<ImageLocalizedMessage> warnings,
    required this.quotaExceeded,
  }) : _literalErrors = null,
       _literalWarnings = null,
       _localizedErrors = errors,
       _localizedWarnings = warnings;

  static const ImageAddOutcome empty = ImageAddOutcome(
    added: <StoredImage>[],
    errors: <String>[],
    warnings: <String>[],
    quotaExceeded: false,
  );

  final List<StoredImage> added;
  final List<String>? _literalErrors;
  final List<String>? _literalWarnings;
  final List<ImageLocalizedMessage>? _localizedErrors;
  final List<ImageLocalizedMessage>? _localizedWarnings;
  final bool quotaExceeded;

  List<String> get errors {
    final List<ImageLocalizedMessage>? messages = _localizedErrors;
    if (messages == null) return _literalErrors!;
    return messages
        .map((ImageLocalizedMessage message) => message())
        .toList(growable: false);
  }

  List<String> get warnings {
    final List<ImageLocalizedMessage>? messages = _localizedWarnings;
    if (messages == null) return _literalWarnings!;
    return messages
        .map((ImageLocalizedMessage message) => message())
        .toList(growable: false);
  }

  List<ImageLocalizedMessage> get errorMessages {
    final List<ImageLocalizedMessage>? messages = _localizedErrors;
    if (messages != null) return messages;
    return _literalErrors!
        .map(
          (String message) =>
              () => message,
        )
        .toList(growable: false);
  }

  List<ImageLocalizedMessage> get warningMessages {
    final List<ImageLocalizedMessage>? messages = _localizedWarnings;
    if (messages != null) return messages;
    return _literalWarnings!
        .map(
          (String message) =>
              () => message,
        )
        .toList(growable: false);
  }

  bool get hasErrors =>
      _localizedErrors?.isNotEmpty ?? _literalErrors!.isNotEmpty;

  bool get hasWarnings =>
      _localizedWarnings?.isNotEmpty ?? _literalWarnings!.isNotEmpty;

  bool get isSuccess => added.isNotEmpty && !hasErrors && !quotaExceeded;
}

/// Applies Gloss's path rules without rejecting the input: backslashes become
/// forward slashes, `..`/`.`/empty segments and `:` are dropped, leading slashes
/// are removed.
String sanitizeImagePath(String raw) {
  final String normalized = raw
      .replaceAll('\\', '/')
      .replaceAll(':', '')
      .trim();
  final List<String> segments = <String>[];
  for (final String segment in normalized.split('/')) {
    final String trimmed = segment.trim();
    if (trimmed.isEmpty || trimmed == '.' || trimmed == '..') {
      continue;
    }
    segments.add(trimmed);
  }
  String path = segments.join('/');
  if (path.isEmpty) {
    path = 'image.png';
  }
  if (path.length > huiMaxImagePathLength) {
    final int dot = path.lastIndexOf('.');
    final String extension = dot > 0 && path.length - dot <= 8
        ? path.substring(dot)
        : '';
    path =
        path.substring(0, huiMaxImagePathLength - extension.length) + extension;
  }
  return path;
}

/// Null when [path] is a legal Gloss image path, otherwise the reason.
String? validateImagePath(String path) {
  return _validateImagePathMessage(path)?.call();
}

ImageLocalizedMessage? _validateImagePathMessage(String path) {
  if (path.trim().isEmpty) {
    return () => huiText('Image path must not be empty.');
  }
  if (path.length > huiMaxImagePathLength) {
    return () => huiText(
      'Image path must be at most {count} characters.',
      <String, Object?>{'count': huiMaxImagePathLength},
    );
  }
  if (path.startsWith('/')) {
    return () => huiText(
      'Image path must be relative to plugins/Gloss/images (no leading slash).',
    );
  }
  if (path.contains('\\')) {
    return () => huiText('Image path must use forward slashes.');
  }
  if (path.contains(':')) {
    return () => huiText('Image path must not contain ":".');
  }
  if (path.endsWith('/')) {
    return () => huiText('Image path must point at a file.');
  }
  for (final String segment in path.split('/')) {
    if (segment == '..') {
      return () => huiText('Image path must not contain "..".');
    }
    if (segment.trim().isEmpty) {
      return () => huiText('Image path must not contain empty segments.');
    }
  }
  return null;
}

/// Bytes behind a `data:` URI, or null when it is not decodable.
Uint8List? decodeDataUriBytes(String dataUri) {
  final int comma = dataUri.indexOf(',');
  if (comma < 0) {
    return null;
  }
  final String meta = dataUri.substring(0, comma);
  final String payload = dataUri.substring(comma + 1);
  try {
    if (meta.contains(';base64')) {
      return base64Decode(payload);
    }
    return Uint8List.fromList(utf8.encode(Uri.decodeComponent(payload)));
  } catch (_) {
    return null;
  }
}

StoredPngData? decodeNormalizedPngData(String dataUri) {
  if (!dataUri.startsWith(huiNormalizedPngDataUriPrefix)) return null;
  final String payload = dataUri.substring(
    huiNormalizedPngDataUriPrefix.length,
  );
  final Uint8List bytes;
  try {
    bytes = base64Decode(payload);
  } catch (_) {
    return null;
  }
  if (base64Encode(bytes) != payload || bytes.length < 33) return null;
  const List<int> signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  for (int index = 0; index < signature.length; index++) {
    if (bytes[index] != signature[index]) return null;
  }
  if (_pngUint32(bytes, 8) != 13 ||
      bytes[12] != 73 ||
      bytes[13] != 72 ||
      bytes[14] != 68 ||
      bytes[15] != 82) {
    return null;
  }
  if (!_hasValidPngChunks(bytes)) return null;
  final int width = _pngUint32(bytes, 16);
  final int height = _pngUint32(bytes, 20);
  if (width <= 0 || height <= 0 || width * height > huiMaxDecodedImagePixels) {
    return null;
  }
  return StoredPngData(bytes: bytes, width: width, height: height);
}

bool isValidStoredImageData(StoredImage image) {
  final StoredImageData? decoded = decodeSupportedImageData(image.dataUri);
  return decoded != null &&
      decoded.bytes.length <= huiMaxStoredImageBytes &&
      decoded.width == image.width &&
      decoded.height == image.height;
}

StoredImageData? decodeSupportedImageData(String dataUri) {
  final RegExpMatch? match = RegExp(
    r'^data:(image/(?:png|jpeg|gif|webp|bmp));base64,([A-Za-z0-9+/]*={0,2})$',
  ).firstMatch(dataUri);
  if (match == null) return null;
  final String mediaType = match.group(1)!;
  final Uint8List bytes;
  try {
    bytes = base64Decode(match.group(2)!);
  } catch (_) {
    return null;
  }
  if (base64Encode(bytes) != match.group(2) ||
      bytes.isEmpty ||
      bytes.length > huiMaxStoredImageBytes) {
    return null;
  }
  final ({int width, int height})? dimensions = switch (mediaType) {
    'image/png' => _pngDimensions(bytes),
    'image/jpeg' => _jpegDimensions(bytes),
    'image/gif' => _gifDimensions(bytes),
    'image/webp' => _webpDimensions(bytes),
    'image/bmp' => _bmpDimensions(bytes),
    _ => null,
  };
  if (dimensions == null ||
      dimensions.width <= 0 ||
      dimensions.height <= 0 ||
      dimensions.width * dimensions.height > huiMaxDecodedImagePixels) {
    return null;
  }
  return StoredImageData(
    bytes: bytes,
    width: dimensions.width,
    height: dimensions.height,
    mediaType: mediaType,
  );
}

({int width, int height})? _pngDimensions(Uint8List bytes) {
  final String dataUri = '$huiNormalizedPngDataUriPrefix${base64Encode(bytes)}';
  final StoredPngData? png = decodeNormalizedPngData(dataUri);
  return png == null ? null : (width: png.width, height: png.height);
}

({int width, int height})? _gifDimensions(Uint8List bytes) {
  if (bytes.length < 10) return null;
  final String header = ascii.decode(bytes.sublist(0, 6), allowInvalid: true);
  if (header != 'GIF87a' && header != 'GIF89a') return null;
  return (
    width: bytes[6] | (bytes[7] << 8),
    height: bytes[8] | (bytes[9] << 8),
  );
}

({int width, int height})? _bmpDimensions(Uint8List bytes) {
  if (bytes.length < 26 || bytes[0] != 0x42 || bytes[1] != 0x4d) return null;
  final int headerSize = _littleUint32(bytes, 14);
  if (headerSize == 12) {
    return (
      width: bytes[18] | (bytes[19] << 8),
      height: bytes[20] | (bytes[21] << 8),
    );
  }
  if (headerSize < 40 || bytes.length < 26) return null;
  final int width = _signedLittleInt32(bytes, 18).abs();
  final int height = _signedLittleInt32(bytes, 22).abs();
  return (width: width, height: height);
}

({int width, int height})? _jpegDimensions(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xff || bytes[1] != 0xd8) return null;
  int offset = 2;
  while (offset + 4 <= bytes.length) {
    while (offset < bytes.length && bytes[offset] == 0xff) {
      offset++;
    }
    if (offset >= bytes.length) return null;
    final int marker = bytes[offset++];
    if (marker == 0xd9 || marker == 0xda) return null;
    if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
    if (offset + 2 > bytes.length) return null;
    final int length = (bytes[offset] << 8) | bytes[offset + 1];
    if (length < 2 || offset + length > bytes.length) return null;
    if (_jpegSofMarkers.contains(marker)) {
      if (length < 7) return null;
      return (
        width: (bytes[offset + 5] << 8) | bytes[offset + 6],
        height: (bytes[offset + 3] << 8) | bytes[offset + 4],
      );
    }
    offset += length;
  }
  return null;
}

({int width, int height})? _webpDimensions(Uint8List bytes) {
  if (bytes.length < 30 ||
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) != 'WEBP') {
    return null;
  }
  final String chunk = ascii.decode(bytes.sublist(12, 16), allowInvalid: true);
  if (chunk == 'VP8X') {
    return (
      width: 1 + bytes[24] + (bytes[25] << 8) + (bytes[26] << 16),
      height: 1 + bytes[27] + (bytes[28] << 8) + (bytes[29] << 16),
    );
  }
  if (chunk == 'VP8L' && bytes.length >= 25 && bytes[20] == 0x2f) {
    final int bits = _littleUint32(bytes, 21);
    return (width: (bits & 0x3fff) + 1, height: ((bits >> 14) & 0x3fff) + 1);
  }
  if (chunk == 'VP8 ' &&
      bytes.length >= 30 &&
      bytes[23] == 0x9d &&
      bytes[24] == 0x01 &&
      bytes[25] == 0x2a) {
    return (
      width: (bytes[26] | (bytes[27] << 8)) & 0x3fff,
      height: (bytes[28] | (bytes[29] << 8)) & 0x3fff,
    );
  }
  return null;
}

int _littleUint32(Uint8List bytes, int offset) =>
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);

int _signedLittleInt32(Uint8List bytes, int offset) {
  final int value = _littleUint32(bytes, offset);
  return value >= 0x80000000 ? value - 0x100000000 : value;
}

const Set<int> _jpegSofMarkers = <int>{
  0xc0,
  0xc1,
  0xc2,
  0xc3,
  0xc5,
  0xc6,
  0xc7,
  0xc9,
  0xca,
  0xcb,
  0xcd,
  0xce,
  0xcf,
};

int _pngUint32(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

bool _hasValidPngChunks(Uint8List bytes) {
  int offset = 8;
  bool sawHeader = false;
  bool sawImageData = false;
  while (offset + 12 <= bytes.length) {
    final int length = _pngUint32(bytes, offset);
    final int typeOffset = offset + 4;
    final int dataEnd = typeOffset + 4 + length;
    final int chunkEnd = dataEnd + 4;
    if (dataEnd < typeOffset || chunkEnd > bytes.length) return false;
    final int expectedCrc = _pngUint32(bytes, dataEnd);
    final int actualCrc = getCrc32(bytes.sublist(typeOffset, dataEnd));
    if (actualCrc != expectedCrc) return false;
    final String type = String.fromCharCodes(
      bytes.sublist(typeOffset, typeOffset + 4),
    );
    if (!sawHeader) {
      if (type != 'IHDR' || length != 13) return false;
      sawHeader = true;
    } else if (type == 'IHDR') {
      return false;
    }
    if (type == 'IDAT') sawImageData = true;
    if (type == 'IEND') {
      return length == 0 && sawImageData && chunkEnd == bytes.length;
    }
    offset = chunkEnd;
  }
  return false;
}

class ImageLibrary extends ChangeNotifier {
  ImageLibrary({
    bool autoLoad = true,
    ImageStorageWriter writer = _writeImageStorage,
  }) : _writer = writer {
    if (autoLoad) {
      load();
    }
  }

  static const String storageKey = 'gloss.images.v1';

  final List<StoredImage> _images = <StoredImage>[];
  late final List<StoredImage> _imagesView = UnmodifiableListView<StoredImage>(
    _images,
  );
  final Set<String> _paths = <String>{};
  late final Set<String> _pathsView = UnmodifiableSetView<String>(_paths);
  final Map<String, ImagePixels> _pixels = <String, ImagePixels>{};
  final Map<String, Future<ImagePixels?>> _pending =
      <String, Future<ImagePixels?>>{};
  final ImageStorageWriter _writer;
  bool _quotaExceeded = false;
  ImageLocalizedMessage? _lastError;

  List<StoredImage> get images => _imagesView;

  /// Live set of known paths — feed it to `validateHuiMenu(knownImagePaths:)`.
  Set<String> get paths => _pathsView;

  bool get isEmpty => _images.isEmpty;

  bool get quotaExceeded => _quotaExceeded;

  String? get lastError => _lastError?.call();

  ImageLocalizedMessage? get lastErrorMessage => _lastError;

  void clearError() {
    _lastError = null;
    _quotaExceeded = false;
  }

  bool contains(String path) => _paths.contains(path);

  StoredImage? byPath(String path) {
    for (final StoredImage image in _images) {
      if (image.path == path) {
        return image;
      }
    }
    return null;
  }

  List<StoredImage> animationFramesFor(String path) {
    final RegExpMatch? match = _animationFramePathPattern.firstMatch(path);
    if (match == null) return const <StoredImage>[];
    final String directory = match.group(1)!;
    final List<StoredImage> frames = _images
        .where(
          (StoredImage image) =>
              _animationFramePathPattern.firstMatch(image.path)?.group(1) ==
              directory,
        )
        .toList(growable: false);
    frames.sort(
      (StoredImage first, StoredImage second) =>
          first.path.compareTo(second.path),
    );
    return List<StoredImage>.unmodifiable(frames);
  }

  /// Re-reads the persisted library, discarding caches.
  void load() {
    _images.clear();
    final String? raw = StorageService.read(storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(raw);
        List<Object?> entries = const <Object?>[];
        if (decoded is List<Object?>) {
          entries = decoded;
        } else if (decoded is Map<String, Object?> &&
            decoded['images'] is List<Object?>) {
          entries = decoded['images']! as List<Object?>;
        }
        for (final Object? entry in entries) {
          final StoredImage? image = StoredImage.fromJson(entry);
          if (image != null &&
              isValidStoredImageData(image) &&
              !_images.any((StoredImage e) => e.path == image.path)) {
            _images.add(image);
          }
        }
      } catch (_) {
        _lastError = () =>
            huiText('The stored image library was unreadable and was ignored.');
      }
    }
    _reindex();
    notifyListeners();
  }

  /// Decodes each browser `File`, normalizes it to PNG, and persists the batch
  /// in one write. Elements of [files] are `package:web` `File` objects, typed as
  /// [Object] so this library stays free of `dart:js_interop`.
  Future<ImageAddOutcome> addFromFiles(
    List<Object> files, {
    bool replaceExisting = true,
  }) async {
    if (files.isEmpty) {
      return ImageAddOutcome.empty;
    }
    final List<StoredImage> candidates = <StoredImage>[];
    final List<ImageLocalizedMessage> errors = <ImageLocalizedMessage>[];
    final List<ImageLocalizedMessage> warnings = <ImageLocalizedMessage>[];
    for (final Object file in files) {
      final DecodedImageBatch? decoded = await decodeImageFileToPngFrames(file);
      if (decoded == null || decoded.frames.isEmpty) {
        errors.add(
          () => huiText(
            'A file could not be decoded as an image and was skipped.',
          ),
        );
        continue;
      }
      final String decodedName = decoded.name;
      final bool animated = decoded.totalFrames > 1;
      final List<StoredImage> fileCandidates = <StoredImage>[];
      ImageLocalizedMessage? fileError;
      bool resized = false;
      int originalWidth = 0;
      int originalHeight = 0;
      int resizedWidth = 0;
      int resizedHeight = 0;
      for (int index = 0; index < decoded.frames.length; index++) {
        final DecodedImageFile frame = decoded.frames[index];
        final NormalizedImageData? normalized = normalizeUploadedPng(
          frame.dataUri,
        );
        if (normalized == null) {
          fileError = () => huiText(
            '"{name}" could not be normalized as a PNG.',
            <String, Object?>{'name': decodedName},
          );
          break;
        }
        if (frame.width != normalized.width ||
            frame.height != normalized.height) {
          resized = true;
          originalWidth = frame.width;
          originalHeight = frame.height;
          resizedWidth = normalized.width;
          resizedHeight = normalized.height;
        }
        final int bytes = decodeDataUriBytes(normalized.dataUri)?.length ?? 0;
        String path = animated
            ? animationFrameImagePath(decodedName, index)
            : _withPngExtension(sanitizeImagePath(decodedName));
        if (bytes > huiMaxStoredImageBytes) {
          final String oversizedPath = path;
          final int size = (bytes / 1024).round();
          fileError = () => huiText(
            '"{path}" is {size} KB after conversion; the limit is {limit} KB. Scale it down before uploading.',
            <String, Object?>{
              'path': oversizedPath,
              'size': size,
              'limit': huiMaxStoredImageBytes ~/ 1024,
            },
          );
          break;
        }
        if (!replaceExisting &&
            (_paths.contains(path) ||
                candidates.any((StoredImage image) => image.path == path) ||
                fileCandidates.any(
                  (StoredImage image) => image.path == path,
                ))) {
          path = _uniquePath(path, <StoredImage>[
            ...candidates,
            ...fileCandidates,
          ]);
        }
        fileCandidates.add(
          StoredImage(
            path: path,
            dataUri: normalized.dataUri,
            width: normalized.width,
            height: normalized.height,
          ),
        );
      }
      if (fileError != null) {
        errors.add(fileError);
        continue;
      }
      if (fileCandidates.any((StoredImage image) => image.isOversized)) {
        final StoredImage image = fileCandidates.firstWhere(
          (StoredImage candidate) => candidate.isOversized,
        );
        warnings.add(
          () => huiText(
            '"{name}" is {width}x{height}. Gloss renders one text display per row and one character per pixel; keep images at or under {maximum}x{maximum}.',
            <String, Object?>{
              'name': decodedName,
              'width': image.width,
              'height': image.height,
              'maximum': huiRecommendedMaxImageDimension,
            },
          ),
        );
      }
      if (resized) {
        warnings.add(
          () => huiText(
            'Resized "{name}" from {originalWidth}x{originalHeight} to {width}x{height} for Gloss.',
            <String, Object?>{
              'name': decodedName,
              'originalWidth': originalWidth,
              'originalHeight': originalHeight,
              'width': resizedWidth,
              'height': resizedHeight,
            },
          ),
        );
      }
      if (animated) {
        final int expandedFrameCount = decoded.frames.length;
        final int omittedFrameCount = decoded.totalFrames - expandedFrameCount;
        warnings.add(
          () => omittedFrameCount > 0
              ? huiPlural(
                  'image.animation_expanded_omitted.count',
                  expandedFrameCount,
                  oneEnglish:
                      'Expanded "{name}" into {count} PNG frame. Omitted frame count: {omitted}. The import limit is {limit} frames.',
                  otherEnglish:
                      'Expanded "{name}" into {count} PNG frames. Omitted frame count: {omitted}. The import limit is {limit} frames.',
                  arguments: <String, Object?>{
                    'name': decodedName,
                    'omitted': omittedFrameCount,
                    'limit': huiMaxImportedAnimationFrames,
                  },
                )
              : huiPlural(
                  'image.animation_expanded.count',
                  expandedFrameCount,
                  oneEnglish:
                      'Expanded "{name}" into {count} PNG frame for an animatedTextImage icon.',
                  otherEnglish:
                      'Expanded "{name}" into {count} PNG frames for an animatedTextImage icon.',
                  arguments: <String, Object?>{'name': decodedName},
                ),
        );
      }
      for (final StoredImage image in fileCandidates) {
        candidates.removeWhere(
          (StoredImage candidate) => candidate.path == image.path,
        );
        candidates.add(image);
      }
    }
    if (candidates.isEmpty) {
      return ImageAddOutcome._localized(
        added: const <StoredImage>[],
        errors: errors,
        warnings: warnings,
        quotaExceeded: false,
      );
    }
    final bool stored = _commit(() {
      for (final StoredImage image in candidates) {
        final int index = _images.indexWhere(
          (StoredImage e) => e.path == image.path,
        );
        if (index >= 0) {
          _images[index] = image;
        } else {
          _images.add(image);
        }
      }
    });
    if (!stored) {
      return ImageAddOutcome._localized(
        added: const <StoredImage>[],
        errors: <ImageLocalizedMessage>[...errors, _quotaMessage],
        warnings: warnings,
        quotaExceeded: true,
      );
    }
    return ImageAddOutcome._localized(
      added: candidates,
      errors: errors,
      warnings: warnings,
      quotaExceeded: false,
    );
  }

  Future<ImageAddOutcome> addPlayerHeadsFromFiles(
    List<Object> files, {
    bool replaceExisting = true,
  }) async {
    if (files.isEmpty) return ImageAddOutcome.empty;
    final List<StoredImage> candidates = <StoredImage>[];
    final List<ImageLocalizedMessage> errors = <ImageLocalizedMessage>[];
    for (final Object file in files) {
      final DecodedImageBatch? decoded = await decodeImageFileToPngFrames(file);
      if (decoded == null || decoded.frames.isEmpty) {
        errors.add(
          () => huiText('A skin file could not be decoded and was skipped.'),
        );
        continue;
      }
      final String decodedName = decoded.name;
      if (decoded.totalFrames != 1) {
        errors.add(
          () => huiText(
            '"{name}" is animated; player skins must be still images.',
            <String, Object?>{'name': decodedName},
          ),
        );
        continue;
      }
      final NormalizedImageData? head = minecraftHeadFromSkinPng(
        decoded.frames.first.dataUri,
      );
      if (head == null) {
        errors.add(
          () => huiText(
            '"{name}" is not a valid 64x32, 64x64, or high-resolution Minecraft skin.',
            <String, Object?>{'name': decodedName},
          ),
        );
        continue;
      }
      String path = _playerHeadPath(decodedName);
      if (!replaceExisting &&
          (_paths.contains(path) ||
              candidates.any((StoredImage image) => image.path == path))) {
        path = _uniquePath(path, candidates);
      }
      candidates.removeWhere((StoredImage candidate) => candidate.path == path);
      candidates.add(
        StoredImage(
          path: path,
          dataUri: head.dataUri,
          width: head.width,
          height: head.height,
        ),
      );
    }
    if (candidates.isEmpty) {
      return ImageAddOutcome._localized(
        added: const <StoredImage>[],
        errors: errors,
        warnings: const <ImageLocalizedMessage>[],
        quotaExceeded: false,
      );
    }
    final bool stored = _commit(() {
      for (final StoredImage image in candidates) {
        final int index = _images.indexWhere(
          (StoredImage current) => current.path == image.path,
        );
        if (index >= 0) {
          _images[index] = image;
        } else {
          _images.add(image);
        }
      }
    });
    if (!stored) {
      return ImageAddOutcome._localized(
        added: const <StoredImage>[],
        errors: <ImageLocalizedMessage>[...errors, _quotaMessage],
        warnings: const <ImageLocalizedMessage>[],
        quotaExceeded: true,
      );
    }
    return ImageAddOutcome._localized(
      added: candidates,
      errors: errors,
      warnings: <ImageLocalizedMessage>[
        () => huiText(
          'Extracted each face and translucent hat layer as an 8x8 pixel image.',
        ),
      ],
      quotaExceeded: false,
    );
  }

  /// Stores the head composed from an already-fetched skin PNG.
  ///
  /// The skin bytes come from [PlayerSkinSource]; the head comes from the same
  /// [minecraftHeadFromSkinPng] the file importer uses, so a head fetched by
  /// name and a head imported from a downloaded skin are byte-identical. The
  /// result is an ordinary image asset at `heads/<name>-head.png` with no
  /// memory of where it came from.
  ///
  /// Nothing is written unless the skin composes and the browser accepts the
  /// write, so a rejected fetch leaves the workspace exactly as it was.
  ImageAddOutcome addPlayerHeadFromSkin({
    required String username,
    required String skinPngDataUri,
    bool replaceExisting = true,
  }) {
    final NormalizedImageData? head = minecraftHeadFromSkinPng(skinPngDataUri);
    if (head == null) {
      return ImageAddOutcome._localized(
        added: const <StoredImage>[],
        errors: <ImageLocalizedMessage>[
          () => huiText(
            'The skin returned for "{username}" is not a valid 64x32, 64x64, or high-resolution Minecraft skin.',
            <String, Object?>{'username': username},
          ),
        ],
        warnings: const <ImageLocalizedMessage>[],
        quotaExceeded: false,
      );
    }

    // Lowercased: Mojang treats usernames case-insensitively and so does the
    // plugin's cache key (PlayerHeadService.java:110), so "Notch" and "notch"
    // must land on one asset rather than two heads of the same person.
    String path = _playerHeadPath(username.toLowerCase());
    if (_validateImagePathMessage(path) != null) {
      return ImageAddOutcome._localized(
        added: const <StoredImage>[],
        errors: <ImageLocalizedMessage>[
          () => huiText(
            '"{username}" does not make a usable image path.',
            <String, Object?>{'username': username},
          ),
        ],
        warnings: const <ImageLocalizedMessage>[],
        quotaExceeded: false,
      );
    }
    if (!replaceExisting && _paths.contains(path)) {
      path = _uniquePath(path, const <StoredImage>[]);
    }

    final StoredImage stored = StoredImage(
      path: path,
      dataUri: head.dataUri,
      width: head.width,
      height: head.height,
    );
    final bool committed = _commit(() {
      final int index = _images.indexWhere(
        (StoredImage current) => current.path == path,
      );
      if (index >= 0) {
        _images[index] = stored;
      } else {
        _images.add(stored);
      }
    });
    if (!committed) {
      return ImageAddOutcome._localized(
        added: const <StoredImage>[],
        errors: <ImageLocalizedMessage>[_quotaMessage],
        warnings: const <ImageLocalizedMessage>[],
        quotaExceeded: true,
      );
    }
    return ImageAddOutcome._localized(
      added: <StoredImage>[stored],
      errors: const <ImageLocalizedMessage>[],
      warnings: const <ImageLocalizedMessage>[],
      quotaExceeded: false,
    );
  }

  /// False when the target path is invalid, unknown, or already taken; the
  /// reason is left in [lastError].
  bool rename(String oldPath, String newPath) {
    final int index = _images.indexWhere((StoredImage e) => e.path == oldPath);
    if (index < 0) {
      _lastError = () => huiText(
        'No image stored at "{path}".',
        <String, Object?>{'path': oldPath},
      );
      return false;
    }
    final String sanitized = _withPngExtension(sanitizeImagePath(newPath));
    if (sanitized == oldPath) {
      return true;
    }
    final ImageLocalizedMessage? problem = _validateImagePathMessage(sanitized);
    if (problem != null) {
      _lastError = problem;
      return false;
    }
    if (_paths.contains(sanitized)) {
      _lastError = () => huiText(
        'An image named "{name}" already exists.',
        <String, Object?>{'name': sanitized},
      );
      return false;
    }
    return _commit(() {
      _images[index] = _images[index].copyWith(path: sanitized);
    });
  }

  void remove(String path) {
    if (!_paths.contains(path)) {
      return;
    }
    _commit(() => _images.removeWhere((StoredImage e) => e.path == path));
  }

  bool clear() => _commit(_images.clear);

  bool replaceAll(Iterable<StoredImage> replacements) {
    final List<StoredImage> next = List<StoredImage>.of(replacements);
    final Set<String> paths = <String>{};
    for (final StoredImage image in next) {
      if (_validateImagePathMessage(image.path) != null ||
          !paths.add(image.path) ||
          !isValidStoredImageData(image)) {
        _lastError = () =>
            huiText('The imported image library contains an invalid entry.');
        _quotaExceeded = false;
        notifyListeners();
        return false;
      }
    }
    return _commit(() {
      _images
        ..clear()
        ..addAll(next);
    });
  }

  bool upsertAll(Iterable<StoredImage> replacements) {
    final List<StoredImage> next = List<StoredImage>.of(replacements);
    final Set<String> paths = <String>{};
    for (final StoredImage image in next) {
      if (_validateImagePathMessage(image.path) != null ||
          !paths.add(image.path) ||
          !isValidStoredImageData(image)) {
        _lastError = () =>
            huiText('The server sync contains an invalid image.');
        _quotaExceeded = false;
        notifyListeners();
        return false;
      }
    }
    return _commit(() {
      for (final StoredImage image in next) {
        final int index = _images.indexWhere(
          (StoredImage current) => current.path == image.path,
        );
        if (index < 0) {
          _images.add(image);
        } else {
          _images[index] = image;
        }
      }
    });
  }

  /// Cached pixel grid, decoding it in the background on the first miss. Built
  /// for synchronous draw loops: null means "not ready yet, a repaint is coming".
  ImagePixels? pixelsFor(String path) {
    final ImagePixels? cached = _pixels[path];
    if (cached != null) {
      return cached;
    }
    unawaited(decode(path));
    return null;
  }

  Future<ImagePixels?> decode(String path) {
    final ImagePixels? cached = _pixels[path];
    if (cached != null) {
      return Future<ImagePixels?>.value(cached);
    }
    final Future<ImagePixels?>? pending = _pending[path];
    if (pending != null) {
      return pending;
    }
    final StoredImage? image = byPath(path);
    if (image == null) {
      return Future<ImagePixels?>.value();
    }
    final Future<ImagePixels?> future = _decode(image);
    _pending[path] = future;
    return future;
  }

  Future<ImagePixels?> _decode(StoredImage image) async {
    try {
      final DecodedPixels? decoded = await readImagePixels(image.dataUri);
      if (decoded == null) {
        return null;
      }
      final List<List<int>> rows = List<List<int>>.generate(
        decoded.height,
        (int y) =>
            decoded.argb.sublist(y * decoded.width, (y + 1) * decoded.width),
        growable: false,
      );
      final ImagePixels pixels = ImagePixels(
        width: decoded.width,
        height: decoded.height,
        rows: rows,
      );
      _pixels[image.path] = pixels;
      notifyListeners();
      return pixels;
    } catch (_) {
      return null;
    } finally {
      _pending.remove(image.path);
    }
  }

  /// Zip whose entry names are exactly the stored paths, so unzipping it into
  /// `plugins/Gloss/images/` resolves every icon.
  Future<List<int>> exportZipBytes() async {
    final Archive archive = Archive();
    for (final StoredImage image in _images) {
      final Uint8List? bytes = decodeDataUriBytes(image.dataUri);
      if (bytes == null) {
        continue;
      }
      archive.add(ArchiveFile.bytes(image.path, bytes));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  /// Approximate localStorage cost of the library alone.
  int estimateUsageBytes() {
    int total = storageKey.length * 2;
    for (final StoredImage image in _images) {
      total += image.approximateBytes;
    }
    return total;
  }

  ImageLocalizedMessage get _quotaMessage =>
      () => huiText(
        'Browser storage is full, so nothing was saved. Remove images or shrink them (Gloss images are usually under {maximum}x{maximum} pixels).',
        <String, Object?>{'maximum': huiRecommendedMaxImageDimension},
      );

  /// Runs [mutation], persists, and restores the previous list when the browser
  /// refuses the write so memory never drifts from storage.
  bool _commit(void Function() mutation) {
    final List<StoredImage> snapshot = List<StoredImage>.of(_images);
    mutation();
    final String payload = jsonEncode(
      _images
          .map((StoredImage image) => image.toJson())
          .toList(growable: false),
    );
    final bool stored = _writer(storageKey, payload);
    if (!stored) {
      _images
        ..clear()
        ..addAll(snapshot);
      _quotaExceeded = true;
      _lastError = _quotaMessage;
    } else {
      _quotaExceeded = false;
      _lastError = null;
    }
    _reindex();
    notifyListeners();
    return stored;
  }

  void _reindex() {
    _paths
      ..clear()
      ..addAll(_images.map((StoredImage image) => image.path));
    _pixels.removeWhere((String path, ImagePixels _) => !_paths.contains(path));
    _pending.clear();
  }

  String _uniquePath(String path, List<StoredImage> pending) {
    final int dot = path.lastIndexOf('.');
    final int slash = path.lastIndexOf('/');
    final String stem = dot > slash && dot > 0 ? path.substring(0, dot) : path;
    final String extension = dot > slash && dot > 0 ? path.substring(dot) : '';
    for (int i = 2; i < 1000; i++) {
      final String candidate = '$stem-$i$extension';
      if (!_paths.contains(candidate) &&
          !pending.any((StoredImage c) => c.path == candidate)) {
        return candidate;
      }
    }
    return path;
  }

  /// Uploads are re-encoded as PNG, so the stored path must say so.
  String _withPngExtension(String path) {
    final int dot = path.lastIndexOf('.');
    final int slash = path.lastIndexOf('/');
    if (dot > slash && dot > 0) {
      return '${path.substring(0, dot)}.png';
    }
    return '$path.png';
  }

  String _playerHeadPath(String sourceName) {
    final String path = sanitizeImagePath(sourceName);
    final int dot = path.lastIndexOf('.');
    final int slash = path.lastIndexOf('/');
    final String stem = dot > slash && dot > 0 ? path.substring(0, dot) : path;
    return _withPngExtension(sanitizeImagePath('heads/$stem-head'));
  }
}

String animationFrameImagePath(String sourceName, int frameIndex) {
  final String path = sanitizeImagePath(sourceName);
  final int dot = path.lastIndexOf('.');
  final int slash = path.lastIndexOf('/');
  String stem = dot > slash && dot > 0 ? path.substring(0, dot) : path;
  const int reserved = 14;
  if (stem.length > huiMaxImagePathLength - reserved) {
    stem = stem.substring(0, huiMaxImagePathLength - reserved);
  }
  final String number = (frameIndex + 1).toString().padLeft(3, '0');
  return '$stem/frame-$number.png';
}
