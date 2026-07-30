/// Local image library backing `textImage` / `animatedTextImage` icons.
///
/// The plugin resolves every icon path against `plugins/holoui/images/`, so the
/// stored path IS the JSON value and IS the zip entry name — keeping those three
/// identical is the whole point of this class. Images are normalized to PNG data
/// URIs and persisted at [ImageLibrary.storageKey]; writes that exceed the
/// browser quota are rolled back instead of silently dropping the library, which
/// is how the previous editor lost documents.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:jaspr/jaspr.dart';

import 'image_library_stub.dart'
    if (dart.library.js_interop) 'image_library_web.dart';
import 'storage_service.dart';

/// HoloUI reads paths with `new File(imagesFolder, path)`; anything longer than
/// this is rejected by common filesystems.
const int huiMaxImagePathLength = 256;

/// One `TextDisplay` per image row and one character per pixel: a 64x64 image is
/// already 4096 characters across 64 displays. Beyond this the preview stays
/// correct but the server will not be happy.
const int huiRecommendedMaxImageDimension = 64;

/// Hard ceiling for a single stored image. localStorage gives the whole origin
/// roughly 5 MB, so a single oversized upload must never be allowed to consume
/// it. HoloUI images are a couple of KB.
const int huiMaxStoredImageBytes = 512 * 1024;

class StoredImage {
  const StoredImage({
    required this.path,
    required this.dataUri,
    required this.width,
    required this.height,
  });

  /// Path relative to `plugins/holoui/images/`, forward slashes, no leading `/`.
  final String path;

  /// Normalized `data:image/png;base64,...`.
  final String dataUri;
  final int width;
  final int height;

  int get pixelCount => width * height;

  bool get isOversized =>
      width > huiRecommendedMaxImageDimension || height > huiRecommendedMaxImageDimension;

  /// Approximate localStorage cost of this entry (UTF-16, key included).
  int get approximateBytes => (dataUri.length + path.length + 48) * 2;

  StoredImage copyWith({String? path, String? dataUri, int? width, int? height}) => StoredImage(
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
    if (path is! String || dataUri is! String || path.isEmpty || dataUri.isEmpty) {
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
  const ImagePixels({required this.width, required this.height, required this.rows});

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
    required this.errors,
    required this.warnings,
    required this.quotaExceeded,
  });

  static const ImageAddOutcome empty = ImageAddOutcome(
    added: <StoredImage>[],
    errors: <String>[],
    warnings: <String>[],
    quotaExceeded: false,
  );

  final List<StoredImage> added;
  final List<String> errors;
  final List<String> warnings;
  final bool quotaExceeded;

  bool get isSuccess => added.isNotEmpty && errors.isEmpty && !quotaExceeded;
}

/// Applies HoloUI's path rules without rejecting the input: backslashes become
/// forward slashes, `..`/`.`/empty segments and `:` are dropped, leading slashes
/// are removed.
String sanitizeImagePath(String raw) {
  final String normalized = raw.replaceAll('\\', '/').replaceAll(':', '').trim();
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
    final String extension = dot > 0 && path.length - dot <= 8 ? path.substring(dot) : '';
    path = path.substring(0, huiMaxImagePathLength - extension.length) + extension;
  }
  return path;
}

/// Null when [path] is a legal HoloUI image path, otherwise the reason.
String? validateImagePath(String path) {
  if (path.trim().isEmpty) {
    return 'Image path must not be empty.';
  }
  if (path.length > huiMaxImagePathLength) {
    return 'Image path must be at most $huiMaxImagePathLength characters.';
  }
  if (path.startsWith('/')) {
    return 'Image path must be relative to plugins/holoui/images (no leading slash).';
  }
  if (path.contains('\\')) {
    return 'Image path must use forward slashes.';
  }
  if (path.contains(':')) {
    return 'Image path must not contain ":".';
  }
  if (path.endsWith('/')) {
    return 'Image path must point at a file.';
  }
  for (final String segment in path.split('/')) {
    if (segment == '..') {
      return 'Image path must not contain "..".';
    }
    if (segment.trim().isEmpty) {
      return 'Image path must not contain empty segments.';
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

class ImageLibrary extends ChangeNotifier {
  ImageLibrary({bool autoLoad = true}) {
    if (autoLoad) {
      load();
    }
  }

  static const String storageKey = 'holoui.images.v1';

  final List<StoredImage> _images = <StoredImage>[];
  late final List<StoredImage> _imagesView = UnmodifiableListView<StoredImage>(_images);
  final Set<String> _paths = <String>{};
  late final Set<String> _pathsView = UnmodifiableSetView<String>(_paths);
  final Map<String, ImagePixels> _pixels = <String, ImagePixels>{};
  final Map<String, Future<ImagePixels?>> _pending = <String, Future<ImagePixels?>>{};
  bool _quotaExceeded = false;
  String? _lastError;

  List<StoredImage> get images => _imagesView;

  /// Live set of known paths — feed it to `validateHuiMenu(knownImagePaths:)`.
  Set<String> get paths => _pathsView;

  bool get isEmpty => _images.isEmpty;

  bool get quotaExceeded => _quotaExceeded;

  String? get lastError => _lastError;

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
        } else if (decoded is Map<String, Object?> && decoded['images'] is List<Object?>) {
          entries = decoded['images']! as List<Object?>;
        }
        for (final Object? entry in entries) {
          final StoredImage? image = StoredImage.fromJson(entry);
          if (image != null && !_images.any((StoredImage e) => e.path == image.path)) {
            _images.add(image);
          }
        }
      } catch (_) {
        _lastError = 'The stored image library was unreadable and was ignored.';
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
    final List<String> errors = <String>[];
    final List<String> warnings = <String>[];
    for (final Object file in files) {
      final DecodedImageFile? decoded = await decodeImageFileToPng(file);
      if (decoded == null) {
        errors.add('A file could not be decoded as an image and was skipped.');
        continue;
      }
      final int bytes = decodeDataUriBytes(decoded.dataUri)?.length ?? 0;
      String path = _withPngExtension(sanitizeImagePath(decoded.name));
      if (bytes > huiMaxStoredImageBytes) {
        errors.add(
          '"$path" is ${(bytes / 1024).round()} KB after conversion; the limit is '
          '${huiMaxStoredImageBytes ~/ 1024} KB. Scale it down before uploading.',
        );
        continue;
      }
      if (!replaceExisting && (_paths.contains(path) || candidates.any((StoredImage c) => c.path == path))) {
        path = _uniquePath(path, candidates);
      }
      final StoredImage image = StoredImage(
        path: path,
        dataUri: decoded.dataUri,
        width: decoded.width,
        height: decoded.height,
      );
      if (image.isOversized) {
        warnings.add(
          '"$path" is ${image.width}x${image.height}. HoloUI renders one text display '
          'per row and one character per pixel; keep images at or under '
          '${huiRecommendedMaxImageDimension}x$huiRecommendedMaxImageDimension.',
        );
      }
      candidates.removeWhere((StoredImage c) => c.path == path);
      candidates.add(image);
    }
    if (candidates.isEmpty) {
      return ImageAddOutcome(
        added: const <StoredImage>[],
        errors: errors,
        warnings: warnings,
        quotaExceeded: false,
      );
    }
    final bool stored = _commit(() {
      for (final StoredImage image in candidates) {
        final int index = _images.indexWhere((StoredImage e) => e.path == image.path);
        if (index >= 0) {
          _images[index] = image;
        } else {
          _images.add(image);
        }
      }
    });
    if (!stored) {
      return ImageAddOutcome(
        added: const <StoredImage>[],
        errors: <String>[...errors, _quotaMessage],
        warnings: warnings,
        quotaExceeded: true,
      );
    }
    return ImageAddOutcome(
      added: candidates,
      errors: errors,
      warnings: warnings,
      quotaExceeded: false,
    );
  }

  /// False when the target path is invalid, unknown, or already taken; the
  /// reason is left in [lastError].
  bool rename(String oldPath, String newPath) {
    final int index = _images.indexWhere((StoredImage e) => e.path == oldPath);
    if (index < 0) {
      _lastError = 'No image stored at "$oldPath".';
      return false;
    }
    final String sanitized = _withPngExtension(sanitizeImagePath(newPath));
    if (sanitized == oldPath) {
      return true;
    }
    final String? problem = validateImagePath(sanitized);
    if (problem != null) {
      _lastError = problem;
      return false;
    }
    if (_paths.contains(sanitized)) {
      _lastError = 'An image named "$sanitized" already exists.';
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

  void clear() {
    if (_images.isEmpty) {
      return;
    }
    _commit(_images.clear);
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
        (int y) => decoded.argb.sublist(y * decoded.width, (y + 1) * decoded.width),
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
  /// `plugins/holoui/images/` resolves every icon.
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

  String get _quotaMessage =>
      'Browser storage is full, so nothing was saved. Remove images or shrink them '
      '(HoloUI images are usually under ${huiRecommendedMaxImageDimension}x$huiRecommendedMaxImageDimension pixels).';

  /// Runs [mutation], persists, and restores the previous list when the browser
  /// refuses the write so memory never drifts from storage.
  bool _commit(void Function() mutation) {
    final List<StoredImage> snapshot = List<StoredImage>.of(_images);
    mutation();
    final String payload = jsonEncode(
      _images.map((StoredImage image) => image.toJson()).toList(growable: false),
    );
    final bool stored = StorageService.write(storageKey, payload);
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
      if (!_paths.contains(candidate) && !pending.any((StoredImage c) => c.path == candidate)) {
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
}
