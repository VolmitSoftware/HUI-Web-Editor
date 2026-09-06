/// Fetches `web/assets/mc/<version>/` once per session and hands every
/// stage the same decoded pack. Lazy: nothing loads until the first 3D
/// stage mounts. Failure is sticky and observable so a stage can show the
/// still instead of retrying forever.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../mc/assets/mc_model_resolver.dart';
import '../../mc/assets/mc_model_store.dart';
import '../../mc/assets/mc_pack_manifest.dart';
import '../../mc/mesh/mc_generated_mesher.dart';
import '../../mc/mesh/mc_mesh.dart';

final class _TilePixels implements McPixelSource {
  _TilePixels(this.width, this.height, this._alpha);

  @override
  final int width;
  @override
  final int height;
  final Uint8List _alpha;

  @override
  int alphaAt(int x, int y) =>
      x < 0 || y < 0 || x >= width || y >= height ? 0 : _alpha[y * width + x];
}

final class McAssetPackData {
  McAssetPackData._(
    this.manifest,
    this.resolver,
    this.blocksImage,
    this.itemsImage,
    this._images,
    this._blocksAlpha,
    this._itemsAlpha,
  );

  final McPackManifest manifest;
  final McModelResolver resolver;
  final web.HTMLImageElement blocksImage;
  final web.HTMLImageElement itemsImage;
  final Map<String, web.HTMLImageElement> _images;
  final Map<String, Future<void>> _decoding = <String, Future<void>>{};
  final Uint8List _blocksAlpha;
  final Uint8List _itemsAlpha;

  String get baseUrl => mcPackBaseUrl(manifest.version);

  /// A decoded image by logical id (`sun`, `zombie`, `player`, `shadow`) or by
  /// any URL previously registered through [prefetch].
  web.HTMLImageElement image(String id) {
    final web.HTMLImageElement? found = _images[id];
    if (found == null) throw StateError('no pack image $id');
    return found;
  }

  bool hasImage(String id) => _images.containsKey(id);

  /// Registers an out-of-pack image (a catalog data URI for a sprite
  /// billboard) so the renderer can bind it. Resolves when decoded; a URL
  /// already decoding shares that decode, so a view may ask every build.
  Future<void> prefetch(String url) {
    if (_images.containsKey(url)) return Future<void>.value();
    return _decoding.putIfAbsent(url, () async {
      _images[url] = await _decode(url);
      _decoding.remove(url);
    });
  }

  /// Frame 0 of a texture wherever it lives, items first: a generated item's
  /// `block/` layer is copied into the items atlas by the pack, and the item
  /// drawable binds that atlas ([mcUsesItemAtlas]).
  McUvRect? uvAny(String textureId) => manifest.items.uv(textureId) ?? manifest.blocks.uv(textureId);

  /// Alpha of one texture tile (frame 0), read once from the atlas the id is
  /// in, items first like [uvAny].
  McPixelSource pixels(String textureId) {
    final bool inItems = manifest.items.entries.containsKey(textureId);
    final McAtlas atlas = inItems ? manifest.items : manifest.blocks;
    final Uint8List alpha = inItems ? _itemsAlpha : _blocksAlpha;
    final McAtlasEntry? entry = atlas.entries[textureId];
    if (entry == null) return const McListPixels(16, 16, <int>[]);
    final int h = entry.height ~/ entry.frames;
    final Uint8List tile = Uint8List(entry.width * h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < entry.width; x++) {
        tile[y * entry.width + x] = alpha[(entry.y + y) * atlas.width + entry.x + x];
      }
    }
    return _TilePixels(entry.width, h, tile);
  }
}

final class McAssetLoader {
  static const String version = '26.2';
  static Future<McAssetPackData>? _loading;
  static McAssetPackData? _loaded;
  static bool _failed = false;
  static final List<void Function()> _listeners = <void Function()>[];

  static McAssetPackData? get loaded => _loaded;
  static bool get failed => _failed;

  static void addListener(void Function() listener) => _listeners.add(listener);
  static void removeListener(void Function() listener) => _listeners.remove(listener);

  static Future<McAssetPackData> load() => _loading ??= _load().then(
        (McAssetPackData data) {
          _loaded = data;
          _notify();
          return data;
        },
        onError: (Object error) {
          _failed = true;
          _notify();
          throw error;
        },
      );

  static void _notify() {
    for (final void Function() l in List<void Function()>.of(_listeners)) {
      l();
    }
  }

  static Future<McAssetPackData> _load() async {
    final String base = mcPackBaseUrl(version);
    final McPackManifest manifest = McPackManifest.fromJson(await _json('$base/pack.json'));
    final McJsonModelStore store = McJsonModelStore.fromJson(await _json('$base/${manifest.modelsPath}'));
    final web.HTMLImageElement blocks = await _decode('$base/${manifest.blocks.image}');
    final web.HTMLImageElement items = await _decode('$base/${manifest.items.image}');
    final Map<String, web.HTMLImageElement> images = <String, web.HTMLImageElement>{};
    Future<void> put(String id, String path) async => images[id] = await _decode('$base/$path');
    await Future.wait(<Future<void>>[
      for (final MapEntry<String, String> e in manifest.environment.entries) put(e.key, e.value),
      for (final MapEntry<String, String> e in manifest.entityTextures.entries) put(e.key, e.value),
      put('player', manifest.player.skinPath),
      if (manifest.player.cape) put('player_cape', manifest.player.capePath),
    ]);
    images['shadow'] = await _shadowImage();
    return McAssetPackData._(
      manifest,
      McModelResolver(store),
      blocks,
      items,
      images,
      _alphaOf(blocks),
      _alphaOf(items),
    );
  }

  static Future<Map<String, Object?>> _json(String url) async {
    final web.Response response = await web.window.fetch(url.toJS).toDart;
    if (!response.ok) throw StateError('GET $url: HTTP ${response.status}');
    final String text = (await response.text().toDart).toDart;
    return jsonDecode(text) as Map<String, Object?>;
  }

  static Uint8List _alphaOf(web.HTMLImageElement image) {
    final web.HTMLCanvasElement canvas = web.HTMLCanvasElement()
      ..width = image.naturalWidth
      ..height = image.naturalHeight;
    final web.CanvasRenderingContext2D ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(image, 0, 0);
    final web.ImageData data = ctx.getImageData(0, 0, canvas.width, canvas.height);
    final Uint8ClampedList raw = data.data.toDart;
    final Uint8List alpha = Uint8List(canvas.width * canvas.height);
    for (int i = 0; i < alpha.length; i++) {
      alpha[i] = raw[i * 4 + 3];
    }
    return alpha;
  }

  /// A 64x64 radial alpha disc; the shadow node's texture.
  static Future<web.HTMLImageElement> _shadowImage() {
    final web.HTMLCanvasElement canvas = web.HTMLCanvasElement()
      ..width = 64
      ..height = 64;
    final web.CanvasRenderingContext2D ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    final web.CanvasGradient gradient = ctx.createRadialGradient(32, 32, 0, 32, 32, 32);
    gradient.addColorStop(0, 'rgba(0,0,0,1)');
    gradient.addColorStop(0.72, 'rgba(0,0,0,0.85)');
    gradient.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, 64, 64);
    return _decode(canvas.toDataURL());
  }
}

Future<web.HTMLImageElement> _decode(String url) async {
  final web.HTMLImageElement element = web.HTMLImageElement()
    ..decoding = 'async'
    ..src = url;
  await element.decode().toDart;
  return element;
}
