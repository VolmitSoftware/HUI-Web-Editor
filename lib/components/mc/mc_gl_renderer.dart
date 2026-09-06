/// Scene nodes to draw calls.
///
/// Per frame: clear to the sky, sun and clouds (fog off, depth writes off),
/// the world chunks (opaque + cutout, alpha test 0.1), the block grid when
/// asked, then every opaque node in the order the stage listed them, then
/// the translucent pass (the world's pool, water, shadows, particles) sorted
/// far to near with depth writes off, then glow outlines: a second draw of
/// the node's mesh scaled about its centre in flat colour, depth test off,
/// masked by the stencil the node itself wrote so only the rim shows. Meshes
/// are cached per (model id, pose) and GPU buffers per scene key; a node
/// whose structural equality changed re-uploads only if its signature
/// changed, otherwise only its uniforms move. A node that could not be built
/// (its sprite still decoding) is retried on every sync until it can.
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../mc/assets/mc_display_pose.dart';
import '../../mc/assets/mc_model_resolver.dart';
import '../../mc/assets/mc_tint.dart';
import '../../mc/mesh/mc_element_mesher.dart';
import '../../mc/mesh/mc_generated_mesher.dart';
import '../../mc/mesh/mc_mesh.dart';
import '../../mc/raster/mc_software_raster.dart' show mcSkyHorizon;
import '../../mc/rigs/mc_player_rig.dart';
import '../../mc/rigs/mc_rig.dart';
import '../../mc/rigs/mc_rig_mesher.dart';
import '../../mc/rigs/mc_rigs.dart';
import '../../mc/scene/mc_camera.dart';
import '../../mc/scene/mc_math.dart';
import '../../mc/scene/mc_projection_bridge.dart';
import '../../mc/scene/mc_scene.dart';
import '../../mc/scene/mc_world_scene.dart';
import 'mc_asset_loader.dart';
import 'mc_gl.dart';

const double _fogStart = 18;
const double _fogEnd = 34;
const double _fogOff = 1e6;
const double _cutoff = 0.1;
const double _translucentCutoff = 0.01;
const List<double> _noOverlay = <double>[0, 0, 0, 0];
const List<double> _noFlat = <double>[0, 0, 0, 0];

final class _Drawable {
  _Drawable(this.buffer, this.texture, this.translucent, {this.owned = true});
  final McGlBuffer buffer;
  final McGlTexture texture;
  final bool translucent;

  /// Shared statics (unit quad, disc, water, cape) are never freed here.
  final bool owned;
  McMat4 model = McMat4.identity();
  List<double> overlay = _noOverlay;
  List<double> flat = _noFlat;
  double opacity = 1;
  int glowArgb = 0;
  McVec3 centre = McVec3.zero;
  double depth = 0;
  String signature = '';

  /// Drawn with this node's uniforms right after it (cape, wool overlay).
  List<_Drawable> extras = const <_Drawable>[];
}

final class McGlRenderer {
  McGlRenderer(this._gl, this._pack) {
    _gl.onRestored(_rebuildAll);
    _uploadStatics();
  }

  final McGl _gl;
  final McAssetPackData _pack;
  final Map<String, _Drawable> _nodes = <String, _Drawable>{};

  /// Keys whose last `_build` returned null; retried on every sync.
  final Set<String> _unbuilt = <String>{};
  final Map<String, McMesh> _meshCache = <String, McMesh>{};
  final List<McGlBuffer> _world = <McGlBuffer>[];
  late McGlTexture _blocks;
  late McGlTexture _items;
  final Map<String, McGlTexture> _textures = <String, McGlTexture>{};
  late McGlBuffer _unitQuad;
  late McGlBuffer _disc;
  late McGlBuffer _water;
  late McGlBuffer _grid;
  late McGlBuffer _cape;
  late _Drawable _pool;
  McScene _last = McScene.empty;
  McMat4 _view = McMat4.identity();

  void _uploadStatics() {
    _blocks = _gl.texture(_pack.blocksImage);
    _items = _gl.texture(_pack.itemsImage);
    _textures.clear();
    _world
      ..clear()
      ..addAll(mcMeshWorldChunks(McWorldScene.standard, _pack.resolver, _pack.manifest.blocks.uv).map(_gl.upload));
    final McUvRect water = _pack.manifest.blocks.uv('block/water_still') ?? McUvRect.missing;
    _unitQuad = _gl.upload(_quadMesh(const McUvRect(0, 0, 1, 1), const <double>[1, 1, 1]));
    _disc = _gl.upload(_quadMesh(const McUvRect(0, 0, 1, 1), const <double>[0, 0, 0]));
    _water = _gl.upload(_waterMesh(water));
    _grid = _gl.upload(_gridMesh);
    _cape = _gl.upload(mcMeshRig(mcCapeRig()));
    _pool = _Drawable(_gl.upload(_poolMesh(water)), _blocks, true, owned: false)..opacity = 0.8;
  }

  void _rebuildAll() {
    _nodes.clear();
    _unbuilt.clear();
    _uploadStatics();
    _last = McScene.empty;
  }

  McGlTexture _texture(String id) => _textures.putIfAbsent(id, () => _gl.texture(_pack.image(id)));

  void render(
    McScene scene,
    McCamera camera, {
    required double widthPx,
    required double heightPx,
    required double dpr,
    required double perspectivePx,
    McVec3 worldOffset = McVec3.zero,
  }) {
    if (_gl.lost) return;
    final web.WebGL2RenderingContext gl = _gl.gl;
    final int w = (widthPx * dpr).round(), h = (heightPx * dpr).round();
    if (w <= 0 || h <= 0) return;
    if (_gl.canvas.width != w) _gl.canvas.width = w;
    if (_gl.canvas.height != h) _gl.canvas.height = h;
    gl.viewport(0, 0, w, h);
    _view = camera.view();
    _sync(scene);
    final McMat4 projection = mcGlProjection(
      viewportWidthPx: widthPx,
      viewportHeightPx: heightPx,
      perspectivePx: perspectivePx,
    );

    gl.enable(web.WebGL2RenderingContext.DEPTH_TEST);
    gl.depthFunc(web.WebGL2RenderingContext.LEQUAL);
    gl.disable(web.WebGL2RenderingContext.CULL_FACE);
    gl.enable(web.WebGL2RenderingContext.BLEND);
    gl.blendFunc(web.WebGL2RenderingContext.SRC_ALPHA, web.WebGL2RenderingContext.ONE_MINUS_SRC_ALPHA);
    gl.disable(web.WebGL2RenderingContext.STENCIL_TEST);
    gl.stencilMask(0xFF);
    gl.depthMask(true);
    gl.clearColor(mcSkyHorizon[0], mcSkyHorizon[1], mcSkyHorizon[2], 1);
    gl.clearStencil(0);
    gl.clear(
      web.WebGL2RenderingContext.COLOR_BUFFER_BIT |
          web.WebGL2RenderingContext.DEPTH_BUFFER_BIT |
          web.WebGL2RenderingContext.STENCIL_BUFFER_BIT,
    );

    final McGlProgram p = _gl.program;
    gl.useProgram(p.program);
    gl.uniformMatrix4fv(p.uniforms['uProjection'], false, projection.toFloat32().toJS);
    gl.uniformMatrix4fv(p.uniforms['uView'], false, _view.toFloat32().toJS);
    gl.uniform3f(p.uniforms['uFogColor'], mcSkyHorizon[0], mcSkyHorizon[1], mcSkyHorizon[2]);
    gl.uniform1i(p.uniforms['uTexture'], 0);
    gl.activeTexture(web.WebGL2RenderingContext.TEXTURE0);

    _setFog(false);
    _sky(camera);
    _setFog(true);

    if (scene.worldVisible) {
      _setDraw(McMat4.translation(worldOffset.x, worldOffset.y, worldOffset.z), _noOverlay, 1, _noFlat, _cutoff);
      gl.bindTexture(web.WebGL2RenderingContext.TEXTURE_2D, _blocks.texture);
      for (final McGlBuffer chunk in _world) {
        _gl.draw(chunk);
      }
    }
    if (scene.gridVisible) {
      _setDraw(
        McMat4.translation(worldOffset.x, worldOffset.y, worldOffset.z),
        _noOverlay,
        0.35,
        const <double>[1, 1, 1, 1],
        _translucentCutoff,
      );
      gl.bindTexture(web.WebGL2RenderingContext.TEXTURE_2D, _gl.white.texture);
      _gl.draw(_grid);
    }

    final List<_Drawable> translucent = <_Drawable>[];
    if (scene.worldVisible) {
      // The pool is part of the world (spec 3.4): its 3x3 surface sits at
      // `mcWorldWaterLevel` over blocks x 6..8, z 4..6 and sorts with the
      // other translucent draws; the drop stage's flood is a node of its own.
      _pool.model = McMat4.translation(
        McWorldPool.minX + worldOffset.x,
        mcWorldWaterLevel + worldOffset.y,
        McWorldPool.minZ + worldOffset.z,
      );
      _pool.centre = McVec3(
        McWorldPool.minX + McWorldPool.size / 2 + worldOffset.x,
        mcWorldWaterLevel + worldOffset.y,
        McWorldPool.minZ + McWorldPool.size / 2 + worldOffset.z,
      );
      _pool.depth = -_view.transformPoint(_pool.centre).z;
      translucent.add(_pool);
    }
    bool anyGlow = false;
    for (final McSceneNode node in scene.nodes) {
      final _Drawable? d = _nodes[node.key];
      if (d == null) continue;
      if (d.translucent) {
        d.depth = -_view.transformPoint(d.centre).z;
        translucent.add(d);
        continue;
      }
      if (d.glowArgb != 0) {
        anyGlow = true;
        gl.enable(web.WebGL2RenderingContext.STENCIL_TEST);
        gl.stencilFunc(web.WebGL2RenderingContext.ALWAYS, 1, 0xFF);
        gl.stencilOp(
          web.WebGL2RenderingContext.KEEP,
          web.WebGL2RenderingContext.KEEP,
          web.WebGL2RenderingContext.REPLACE,
        );
      }
      _drawNode(d, d.model, d.opacity, d.flat, _cutoff);
      if (d.glowArgb != 0) gl.disable(web.WebGL2RenderingContext.STENCIL_TEST);
    }

    gl.depthMask(false);
    translucent.sort((_Drawable a, _Drawable b) => b.depth.compareTo(a.depth));
    for (final _Drawable d in translucent) {
      _drawNode(d, d.model, d.opacity, d.flat, _translucentCutoff);
    }
    gl.depthMask(true);

    if (anyGlow) {
      gl.disable(web.WebGL2RenderingContext.DEPTH_TEST);
      gl.enable(web.WebGL2RenderingContext.STENCIL_TEST);
      gl.stencilFunc(web.WebGL2RenderingContext.NOTEQUAL, 1, 0xFF);
      gl.stencilOp(
        web.WebGL2RenderingContext.KEEP,
        web.WebGL2RenderingContext.KEEP,
        web.WebGL2RenderingContext.KEEP,
      );
      for (final McSceneNode node in scene.nodes) {
        final _Drawable? d = _nodes[node.key];
        if (d == null || d.glowArgb == 0) continue;
        final List<double> rgb = mcArgbToRgb(d.glowArgb);
        final McMat4 outline = McMat4.translation(d.centre.x, d.centre.y, d.centre.z)
            .multiply(McMat4.scale(1.06, 1.06, 1.06))
            .multiply(McMat4.translation(-d.centre.x, -d.centre.y, -d.centre.z))
            .multiply(d.model);
        _drawNode(d, outline, 0.55, <double>[rgb[0], rgb[1], rgb[2], 1], _cutoff);
      }
      gl.disable(web.WebGL2RenderingContext.STENCIL_TEST);
      gl.enable(web.WebGL2RenderingContext.DEPTH_TEST);
    }
  }

  void _drawNode(_Drawable d, McMat4 model, double opacity, List<double> flat, double cutoff) {
    final web.WebGL2RenderingContext gl = _gl.gl;
    _setDraw(model, d.overlay, opacity, flat, cutoff);
    gl.bindTexture(web.WebGL2RenderingContext.TEXTURE_2D, d.texture.texture);
    _gl.draw(d.buffer);
    for (final _Drawable extra in d.extras) {
      gl.bindTexture(web.WebGL2RenderingContext.TEXTURE_2D, extra.texture.texture);
      _gl.draw(extra.buffer);
    }
  }

  void _setDraw(McMat4 model, List<double> overlay, double opacity, List<double> flat, double cutoff) {
    final web.WebGL2RenderingContext gl = _gl.gl;
    final McGlProgram p = _gl.program;
    gl.uniformMatrix4fv(p.uniforms['uModel'], false, model.toFloat32().toJS);
    gl.uniform4f(p.uniforms['uOverlay'], overlay[0], overlay[1], overlay[2], overlay[3]);
    gl.uniform4f(p.uniforms['uFlat'], flat[0], flat[1], flat[2], flat[3]);
    gl.uniform1f(p.uniforms['uOpacity'], opacity);
    gl.uniform1f(p.uniforms['uAlphaCutoff'], cutoff);
  }

  void _setFog(bool on) {
    final web.WebGL2RenderingContext gl = _gl.gl;
    final McGlProgram p = _gl.program;
    gl.uniform1f(p.uniforms['uFogStart'], on ? _fogStart : _fogOff);
    gl.uniform1f(p.uniforms['uFogEnd'], on ? _fogEnd : _fogOff + 1);
  }

  /// Sun: a camera-facing quad far along the fixed sun direction, drawn
  /// before the world with depth writes off. Clouds: the clouds texture on a
  /// plane at y = 24, alpha 0.7, scrolled by wall time.
  void _sky(McCamera camera) {
    final web.WebGL2RenderingContext gl = _gl.gl;
    gl.depthMask(false);
    final McVec3 sunDir = const McVec3(0.5, 0.707, -0.5).normalized;
    final McVec3 sunAt = camera.eye + sunDir * 60;
    _setDraw(_billboardAt(sunAt - const McVec3(0, 6, 0), 12, 12), _noOverlay, 1, _noFlat, _translucentCutoff);
    gl.bindTexture(web.WebGL2RenderingContext.TEXTURE_2D, _texture('sun').texture);
    _gl.draw(_unitQuad);
    final double scroll = (DateTime.now().millisecondsSinceEpoch % 600000) / 600000;
    final McMat4 clouds = McMat4.translation(-96 + scroll * 32, 24, 96)
        .multiply(McMat4.rotationX(-90))
        .multiply(McMat4.scale(192, 192, 1));
    _setDraw(clouds, _noOverlay, 0.7, _noFlat, _translucentCutoff);
    gl.bindTexture(web.WebGL2RenderingContext.TEXTURE_2D, _texture('clouds').texture);
    _gl.draw(_unitQuad);
    gl.depthMask(true);
  }

  void _sync(McScene scene) {
    final McSceneDiff diff = scene.diff(_last);
    for (final String key in diff.removed) {
      final _Drawable? d = _nodes.remove(key);
      if (d != null) _free(d);
      _unbuilt.remove(key);
    }
    for (final String key in <String>{...diff.added, ...diff.changed, ..._unbuilt}) {
      final McSceneNode? node = scene.byKey[key];
      if (node == null) {
        _unbuilt.remove(key);
        continue;
      }
      final _Drawable? existing = _nodes[key];
      final String signature = _signature(node);
      if (existing != null && existing.signature == signature) {
        _place(existing, node);
        continue;
      }
      if (existing != null) _free(existing);
      final _Drawable? built = _build(node);
      if (built == null) {
        _nodes.remove(key);
        _unbuilt.add(key);
        continue;
      }
      _unbuilt.remove(key);
      built.signature = signature;
      _place(built, node);
      _nodes[key] = built;
    }
    _last = scene;
  }

  void _free(_Drawable d) {
    if (d.owned) _gl.free(d.buffer);
    for (final _Drawable extra in d.extras) {
      if (extra.owned) _gl.free(extra.buffer);
    }
  }

  String _signature(McSceneNode node) => switch (node) {
    McBlockModelNode(:final String blockId) => 'block:$blockId',
    McItemModelNode(:final String itemId, :final McDisplayPose pose) => 'item:$itemId:${pose.name}',
    McRigNode(
      :final String rigId,
      :final String textureId,
      :final int poseTimeMs,
      :final String? capeTextureId,
      :final String? overlayTextureId,
    ) =>
      'rig:$rigId:$textureId:${poseTimeMs ~/ 50}:$capeTextureId:$overlayTextureId',
    McBillboardNode(:final String textureUrl) => 'billboard:$textureUrl',
    McShadowNode() => 'shadow',
    McWaterNode() => 'water',
    McParticleNode(:final String textureId) => 'particle:$textureId',
  };

  _Drawable? _build(McSceneNode node) {
    switch (node) {
      case McBlockModelNode(:final String blockId):
        final McResolvedModel? model = _pack.resolver.resolveBlock(blockId);
        if (model == null) return null;
        final McMesh mesh = _meshCache.putIfAbsent(
          'block:$blockId',
          () => mcMeshElements(
            model,
            uv: _pack.manifest.blocks.uv,
            tint: (int? i) => mcTintForBlock(blockId, i),
          ),
        );
        return _Drawable(_gl.upload(mesh), _blocks, false);
      case McItemModelNode(:final String itemId, :final McDisplayPose pose):
        final McItemModelResult result = _pack.resolver.resolveItem(itemId);
        if (result is! McItemModelResolved) return null;
        final bool itemAtlas = mcUsesItemAtlas(result.model);
        final McMesh mesh = _meshCache.putIfAbsent('item:$itemId:${pose.name}', () {
          final McMat4 poseMatrix = mcDisplayPoseMatrix(mcDisplayTransform(result.model, pose));
          final McMesh raw = result.model.generated
              ? mcMeshGenerated(
                  <McGeneratedLayer>[
                    for (int i = 0; i < result.model.layers.length; i++)
                      McGeneratedLayer(
                        _pack.pixels(result.model.layers[i]),
                        _pack.uvAny(result.model.layers[i]) ?? McUvRect.missing,
                        i < result.tints.length ? i : null,
                      ),
                  ],
                  tint: mcTintLookup(result.tints),
                )
              : mcMeshElements(
                  result.model,
                  uv: itemAtlas ? _pack.manifest.items.uv : _pack.manifest.blocks.uv,
                  tint: mcTintLookup(result.tints),
                );
          return raw.transformed(poseMatrix);
        });
        return _Drawable(_gl.upload(mesh), itemAtlas ? _items : _blocks, false);
      case McRigNode(
        :final String rigId,
        :final String textureId,
        :final int poseTimeMs,
        :final String? capeTextureId,
        :final String? overlayTextureId,
      ):
        final McRig? rig = mcRigById(rigId, slim: _pack.manifest.player.slim);
        if (rig == null || !_pack.hasImage(textureId)) return null;
        final McRigPose pose = mcIdlePose(rig, poseTimeMs);
        final _Drawable d = _Drawable(_gl.upload(mcMeshRig(rig, pose: pose)), _texture(textureId), false);
        d.extras = <_Drawable>[
          if (capeTextureId != null && _pack.hasImage(capeTextureId))
            _Drawable(_cape, _texture(capeTextureId), false, owned: false),
          if (overlayTextureId != null && _pack.hasImage(overlayTextureId))
            _Drawable(_gl.upload(mcMeshRig(rig, pose: pose, overlayOnly: true)), _texture(overlayTextureId), false),
        ];
        return d;
      case McBillboardNode(:final String textureUrl):
        if (!_pack.hasImage(textureUrl)) return null;
        return _Drawable(_unitQuad, _texture(textureUrl), false, owned: false);
      case McShadowNode():
        return _Drawable(_disc, _texture('shadow'), true, owned: false);
      case McWaterNode():
        return _Drawable(_water, _blocks, true, owned: false)
          ..flat = <double>[mcTintWater[0], mcTintWater[1], mcTintWater[2], 0.85];
      case McParticleNode(:final String textureId):
        if (!_pack.hasImage(textureId)) return null;
        return _Drawable(_unitQuad, _texture(textureId), true, owned: false);
    }
  }

  void _place(_Drawable d, McSceneNode node) {
    switch (node) {
      case McBlockModelNode(:final McMat4 transform, :final int glowArgb):
        d.model = transform;
        d.glowArgb = glowArgb;
        d.centre = transform.transformPoint(const McVec3(0.5, 0.5, 0.5));
      case McItemModelNode(:final McMat4 transform, :final int glowArgb):
        d.model = transform;
        d.glowArgb = glowArgb;
        d.centre = transform.transformPoint(const McVec3(0.5, 0.5, 0.5));
      case McRigNode(:final McMat4 transform, :final double hurt):
        d.model = transform;
        d.overlay = <double>[1, 0, 0, hurt * 0.3];
        d.centre = transform.transformPoint(const McVec3(0, 1, 0));
      case McBillboardNode(:final McVec3 position, :final double widthBlocks, :final double heightBlocks):
        d.model = _billboardAt(position, widthBlocks, heightBlocks);
        d.centre = position;
      case McShadowNode(:final McVec3 position, :final double radiusBlocks, :final double alpha):
        d.model = McMat4.translation(position.x, position.y + 0.005, position.z)
            .multiply(McMat4.rotationX(-90))
            .multiply(McMat4.scale(radiusBlocks * 2, radiusBlocks * 2, 1))
            .multiply(McMat4.translation(-0.5, -0.5, 0));
        d.opacity = alpha;
        d.centre = position;
      case McWaterNode(:final double levelBlocks, :final double halfExtentBlocks):
        d.model = McMat4.translation(-halfExtentBlocks, levelBlocks, halfExtentBlocks)
            .multiply(McMat4.rotationX(-90))
            .multiply(McMat4.scale(halfExtentBlocks * 2, halfExtentBlocks * 2, 1));
        d.opacity = 0.6;
        d.centre = McVec3(0, levelBlocks, 0);
      case McParticleNode(:final McVec3 position, :final double sizeBlocks, :final double alpha):
        d.model = _billboardAt(position, sizeBlocks, sizeBlocks);
        d.opacity = alpha;
        d.centre = position;
    }
  }

  /// Bottom-centred quad facing the camera (uses the current view matrix).
  McMat4 _billboardAt(McVec3 position, double width, double height) {
    final Float64List v = _view.m;
    // Inverse rotation of the view: its upper 3x3 is orthonormal.
    final McMat4 face = McMat4(
      Float64List.fromList(<double>[
        v[0], v[4], v[8], 0, //
        v[1], v[5], v[9], 0, //
        v[2], v[6], v[10], 0, //
        0, 0, 0, 1, //
      ]),
    );
    return McMat4.translation(position.x, position.y, position.z)
        .multiply(face)
        .multiply(McMat4.scale(width, height, 1))
        .multiply(McMat4.translation(-0.5, 0, 0));
  }

  /// A unit quad in the z = 0 plane, texture top-left at (0, 1).
  static McMesh _quadMesh(McUvRect r, List<double> tint) {
    final McMeshBuilder b = McMeshBuilder();
    b.quad(
      <List<double>>[
        <double>[0, 1, 0],
        <double>[1, 1, 0],
        <double>[1, 0, 0],
        <double>[0, 0, 0],
      ],
      <List<double>>[
        <double>[r.u0, r.v0],
        <double>[r.u1, r.v0],
        <double>[r.u1, r.v1],
        <double>[r.u0, r.v1],
      ],
      1,
      tint,
    );
    return b.build();
  }

  /// The unit quad tiled 32x32 so a 32-block plane repeats the water texture
  /// once per block (an atlas rect cannot wrap).
  static McMesh _waterMesh(McUvRect r) {
    const int tiles = 32;
    final McMeshBuilder b = McMeshBuilder();
    for (int y = 0; y < tiles; y++) {
      for (int x = 0; x < tiles; x++) {
        final double x0 = x / tiles, x1 = (x + 1) / tiles;
        final double y0 = y / tiles, y1 = (y + 1) / tiles;
        b.quad(
          <List<double>>[
            <double>[x0, y1, 0],
            <double>[x1, y1, 0],
            <double>[x1, y0, 0],
            <double>[x0, y0, 0],
          ],
          <List<double>>[
            <double>[r.u0, r.v0],
            <double>[r.u1, r.v0],
            <double>[r.u1, r.v1],
            <double>[r.u0, r.v1],
          ],
          1,
          const <double>[1, 1, 1],
        );
      }
    }
    return b.build();
  }

  /// The pool surface: one water tile per block over the 3x3 hole, on the
  /// y = 0 plane from the origin, tinted the plains water colour the way the
  /// client tints the block. Translation places it in [render].
  static McMesh _poolMesh(McUvRect r) {
    final McMeshBuilder b = McMeshBuilder();
    for (int z = 0; z < McWorldPool.size; z++) {
      for (int x = 0; x < McWorldPool.size; x++) {
        final double x0 = x.toDouble(), x1 = x + 1.0;
        final double z0 = z.toDouble(), z1 = z + 1.0;
        b.quad(
          <List<double>>[
            <double>[x0, 0, z1],
            <double>[x1, 0, z1],
            <double>[x1, 0, z0],
            <double>[x0, 0, z0],
          ],
          <List<double>>[
            <double>[r.u0, r.v1],
            <double>[r.u1, r.v1],
            <double>[r.u1, r.v0],
            <double>[r.u0, r.v0],
          ],
          1,
          mcTintWater,
        );
      }
    }
    return b.build();
  }

  /// 33 + 33 lines across the 32x32 patch, each one a flat strip lying on the
  /// ground plus a fin standing on it. A single ground quad thins to nothing
  /// at a grazing camera and the patch reads as a few stray horizontal lines;
  /// the fin gives every line a face to show from any angle. Built once for
  /// the process — every stage uploads the same geometry.
  static final McMesh _gridMesh = _buildGridMesh();

  static McMesh _buildGridMesh() {
    const double y = 0.005;
    const double thickness = 0.02;
    const double halfThickness = thickness / 2;
    const List<List<double>> uv = <List<double>>[
      <double>[0, 0],
      <double>[1, 0],
      <double>[1, 1],
      <double>[0, 1],
    ];
    const List<double> tint = <double>[1, 1, 1];
    final double edge = McWorldScene.halfExtent.toDouble();
    final McMeshBuilder b = McMeshBuilder();
    for (int i = -McWorldScene.halfExtent; i <= McWorldScene.halfExtent; i++) {
      final double at = i.toDouble();
      // Running along Z at x = at: the strip, then the fin over it.
      b.quad(<List<double>>[
        <double>[at - halfThickness, y, -edge],
        <double>[at + halfThickness, y, -edge],
        <double>[at + halfThickness, y, edge],
        <double>[at - halfThickness, y, edge],
      ], uv, 1, tint);
      b.quad(<List<double>>[
        <double>[at, y, -edge],
        <double>[at, y + thickness, -edge],
        <double>[at, y + thickness, edge],
        <double>[at, y, edge],
      ], uv, 1, tint);
      // Running along X at z = at.
      b.quad(<List<double>>[
        <double>[-edge, y, at - halfThickness],
        <double>[edge, y, at - halfThickness],
        <double>[edge, y, at + halfThickness],
        <double>[-edge, y, at + halfThickness],
      ], uv, 1, tint);
      b.quad(<List<double>>[
        <double>[-edge, y, at],
        <double>[-edge, y + thickness, at],
        <double>[edge, y + thickness, at],
        <double>[edge, y, at],
      ], uv, 1, tint);
    }
    return b.build();
  }
}
