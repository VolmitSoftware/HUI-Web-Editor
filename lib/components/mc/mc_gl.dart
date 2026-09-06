/// The only file that talks to WebGL2. Programs, buffers, textures and
/// context loss; nothing here knows what a block is.
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../mc/mesh/mc_mesh.dart';

const String mcVertexShader = '''#version 300 es
precision highp float;
in vec3 aPosition;
in vec2 aUv;
in float aShade;
in vec3 aTint;
uniform mat4 uProjection;
uniform mat4 uView;
uniform mat4 uModel;
out vec2 vUv;
out float vShade;
out vec3 vTint;
out float vDepth;
void main() {
  vec4 world = uModel * vec4(aPosition, 1.0);
  vec4 view = uView * world;
  vDepth = -view.z;
  gl_Position = uProjection * view;
  vUv = aUv;
  vShade = aShade;
  vTint = aTint;
}
''';

const String mcFragmentShader = '''#version 300 es
precision mediump float;
uniform sampler2D uTexture;
uniform float uAlphaCutoff;
uniform vec4 uOverlay;
uniform vec3 uFogColor;
uniform float uFogStart;
uniform float uFogEnd;
uniform float uOpacity;
uniform vec4 uFlat;
in vec2 vUv;
in float vShade;
in vec3 vTint;
in float vDepth;
out vec4 fragColor;
void main() {
  vec4 t = texture(uTexture, vUv);
  if (t.a < uAlphaCutoff) discard;
  vec3 c = t.rgb * vTint * vShade;
  c = mix(c, uOverlay.rgb, uOverlay.a);
  c = mix(c, uFlat.rgb, uFlat.a);
  float f = clamp((vDepth - uFogStart) / (uFogEnd - uFogStart), 0.0, 1.0);
  c = mix(c, uFogColor, f);
  fragColor = vec4(c, t.a * uOpacity);
}
''';

const List<String> _uniformNames = <String>[
  'uProjection',
  'uView',
  'uModel',
  'uTexture',
  'uAlphaCutoff',
  'uOverlay',
  'uFogColor',
  'uFogStart',
  'uFogEnd',
  'uOpacity',
  'uFlat',
];

const List<String> _attributeNames = <String>['aPosition', 'aUv', 'aShade', 'aTint'];

/// One uploaded [McMesh]: always indexed triangles (the block grid is strips
/// and fins, not lines).
final class McGlBuffer {
  McGlBuffer(this.vao, this.indexCount, this._buffers);
  final web.WebGLVertexArrayObject vao;
  final int indexCount;
  final List<web.WebGLBuffer> _buffers;
}

final class McGlTexture {
  McGlTexture(this.texture, this.width, this.height);
  final web.WebGLTexture texture;
  final int width;
  final int height;
}

final class McGlProgram {
  McGlProgram(this.program, this.uniforms, this.attributes);
  final web.WebGLProgram program;
  final Map<String, web.WebGLUniformLocation?> uniforms;
  final Map<String, int> attributes;
}

final class McGl {
  McGl._(this.canvas, this.gl);

  /// Null when the browser has no WebGL2; the stage then shows the still.
  static McGl? create(web.HTMLCanvasElement canvas) {
    final JSAny? options = <String, Object?>{
      'antialias': false,
      'alpha': true,
      'premultipliedAlpha': true,
      'preserveDrawingBuffer': false,
      'stencil': true,
    }.jsify();
    final JSObject? raw;
    try {
      raw = canvas.getContext('webgl2', options);
    } catch (_) {
      return null;
    }
    if (raw == null) return null;
    final McGl gl = McGl._(canvas, raw as web.WebGL2RenderingContext);
    gl._program = gl._compile(mcVertexShader, mcFragmentShader);
    gl._white = gl._whiteTexture();
    gl._listen();
    return gl;
  }

  final web.HTMLCanvasElement canvas;
  final web.WebGL2RenderingContext gl;
  late McGlProgram _program;
  late McGlTexture _white;
  bool _lost = false;
  final List<void Function()> _restored = <void Function()>[];

  McGlProgram get program => _program;
  bool get lost => _lost;

  /// A 1x1 opaque white texel for flat-coloured draws (grid lines).
  McGlTexture get white => _white;

  void onRestored(void Function() callback) => _restored.add(callback);

  void _listen() {
    canvas.addEventListener(
      'webglcontextlost',
      ((web.Event event) {
        event.preventDefault();
        _lost = true;
      }).toJS,
    );
    canvas.addEventListener(
      'webglcontextrestored',
      ((web.Event event) {
        _lost = false;
        _program = _compile(mcVertexShader, mcFragmentShader);
        _white = _whiteTexture();
        for (final void Function() callback in _restored) {
          callback();
        }
      }).toJS,
    );
  }

  McGlProgram _compile(String vertex, String fragment) {
    web.WebGLShader shader(int type, String source) {
      final web.WebGLShader s = gl.createShader(type)!;
      gl.shaderSource(s, source);
      gl.compileShader(s);
      final JSAny? ok = gl.getShaderParameter(s, web.WebGL2RenderingContext.COMPILE_STATUS);
      if (ok == null || !(ok as JSBoolean).toDart) {
        throw StateError('shader: ${gl.getShaderInfoLog(s)}');
      }
      return s;
    }

    final web.WebGLProgram program = gl.createProgram()!;
    gl.attachShader(program, shader(web.WebGL2RenderingContext.VERTEX_SHADER, vertex));
    gl.attachShader(program, shader(web.WebGL2RenderingContext.FRAGMENT_SHADER, fragment));
    gl.linkProgram(program);
    final JSAny? linked = gl.getProgramParameter(program, web.WebGL2RenderingContext.LINK_STATUS);
    if (linked == null || !(linked as JSBoolean).toDart) {
      throw StateError('program: ${gl.getProgramInfoLog(program)}');
    }
    final Map<String, web.WebGLUniformLocation?> uniforms = <String, web.WebGLUniformLocation?>{
      for (final String name in _uniformNames) name: gl.getUniformLocation(program, name),
    };
    final Map<String, int> attributes = <String, int>{
      for (final String name in _attributeNames) name: gl.getAttribLocation(program, name),
    };
    return McGlProgram(program, uniforms, attributes);
  }

  McGlBuffer upload(McMesh mesh) {
    final web.WebGLVertexArrayObject vao = gl.createVertexArray()!;
    gl.bindVertexArray(vao);
    final List<web.WebGLBuffer> buffers = <web.WebGLBuffer>[];
    void attribute(String name, Float32List data, int size) {
      final web.WebGLBuffer buffer = gl.createBuffer()!;
      buffers.add(buffer);
      gl.bindBuffer(web.WebGL2RenderingContext.ARRAY_BUFFER, buffer);
      gl.bufferData(web.WebGL2RenderingContext.ARRAY_BUFFER, data.toJS, web.WebGL2RenderingContext.STATIC_DRAW);
      final int location = _program.attributes[name]!;
      if (location < 0) return;
      gl.enableVertexAttribArray(location);
      gl.vertexAttribPointer(location, size, web.WebGL2RenderingContext.FLOAT, false, 0, 0);
    }

    attribute('aPosition', mesh.positions, 3);
    attribute('aUv', mesh.uvs, 2);
    attribute('aShade', mesh.shades, 1);
    attribute('aTint', mesh.tints, 3);
    final web.WebGLBuffer index = gl.createBuffer()!;
    buffers.add(index);
    gl.bindBuffer(web.WebGL2RenderingContext.ELEMENT_ARRAY_BUFFER, index);
    gl.bufferData(
      web.WebGL2RenderingContext.ELEMENT_ARRAY_BUFFER,
      mesh.indices.toJS,
      web.WebGL2RenderingContext.STATIC_DRAW,
    );
    gl.bindVertexArray(null);
    return McGlBuffer(vao, mesh.indices.length, buffers);
  }

  void free(McGlBuffer buffer) {
    for (final web.WebGLBuffer b in buffer._buffers) {
      gl.deleteBuffer(b);
    }
    gl.deleteVertexArray(buffer.vao);
  }

  /// Nearest-neighbour, clamped, no mipmaps: pixel art stays pixel art.
  McGlTexture texture(web.HTMLImageElement image) {
    final web.WebGLTexture texture = gl.createTexture()!;
    gl.bindTexture(web.WebGL2RenderingContext.TEXTURE_2D, texture);
    gl.pixelStorei(web.WebGL2RenderingContext.UNPACK_PREMULTIPLY_ALPHA_WEBGL, 0);
    gl.pixelStorei(web.WebGL2RenderingContext.UNPACK_FLIP_Y_WEBGL, 0);
    gl.pixelStorei(
      web.WebGL2RenderingContext.UNPACK_COLORSPACE_CONVERSION_WEBGL,
      web.WebGL2RenderingContext.NONE,
    );
    gl.texImage2D(
      web.WebGL2RenderingContext.TEXTURE_2D,
      0,
      web.WebGL2RenderingContext.RGBA,
      web.WebGL2RenderingContext.RGBA.toJS,
      web.WebGL2RenderingContext.UNSIGNED_BYTE.toJS,
      image,
    );
    _nearest();
    return McGlTexture(texture, image.naturalWidth, image.naturalHeight);
  }

  McGlTexture _whiteTexture() {
    final web.WebGLTexture texture = gl.createTexture()!;
    gl.bindTexture(web.WebGL2RenderingContext.TEXTURE_2D, texture);
    gl.texImage2D(
      web.WebGL2RenderingContext.TEXTURE_2D,
      0,
      web.WebGL2RenderingContext.RGBA,
      1.toJS,
      1.toJS,
      0.toJS,
      web.WebGL2RenderingContext.RGBA,
      web.WebGL2RenderingContext.UNSIGNED_BYTE,
      Uint8List.fromList(<int>[255, 255, 255, 255]).toJS,
    );
    _nearest();
    return McGlTexture(texture, 1, 1);
  }

  void _nearest() {
    const int target = web.WebGL2RenderingContext.TEXTURE_2D;
    gl.texParameteri(target, web.WebGL2RenderingContext.TEXTURE_MIN_FILTER, web.WebGL2RenderingContext.NEAREST);
    gl.texParameteri(target, web.WebGL2RenderingContext.TEXTURE_MAG_FILTER, web.WebGL2RenderingContext.NEAREST);
    gl.texParameteri(target, web.WebGL2RenderingContext.TEXTURE_WRAP_S, web.WebGL2RenderingContext.CLAMP_TO_EDGE);
    gl.texParameteri(target, web.WebGL2RenderingContext.TEXTURE_WRAP_T, web.WebGL2RenderingContext.CLAMP_TO_EDGE);
  }

  void draw(McGlBuffer buffer) {
    gl.bindVertexArray(buffer.vao);
    gl.drawElements(
      web.WebGL2RenderingContext.TRIANGLES,
      buffer.indexCount,
      web.WebGL2RenderingContext.UNSIGNED_SHORT,
      0,
    );
    gl.bindVertexArray(null);
  }

  void dispose() {
    final JSObject? ext = gl.getExtension('WEBGL_lose_context');
    if (ext != null) (ext as web.WEBGL_lose_context).loseContext();
  }
}
