library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:gloss_editor/services/gif_frame_codec.dart';
import 'package:test/test.dart';

const String _animatedGif =
    'R0lGODlhCAAIAIEAAP8A/wAAAAAAAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQADAAAACwAAAAACAAIAAAIDwABCBxIsKDBgwgTKkwYEAAh+QQBDAABACwAAAAACAAIAIEA//8AAAAAAAAAAAAIDwABCBxIsKDBgwgTKkwYEAAh+QQBDAABACwAAAAACAAIAIH//1UAAAAAAAAAAAAIDwABCBxIsKDBgwgTKkwYEAA7';

void main() {
  test('an animated GIF expands into ordered full-size PNG frames', () {
    final Uint8List bytes = base64Decode(_animatedGif);
    final GifPngAnimation? animation = decodeGifPngAnimation(bytes);

    expect(animation, isNotNull);
    expect(animation!.totalFrames, 3);
    expect(animation.frames, hasLength(3));
    expect(
      animation.frames.map((GifPngFrame frame) => (frame.width, frame.height)),
      everyElement((8, 8)),
    );
    for (final GifPngFrame frame in animation.frames) {
      expect(frame.bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4e, 0x47]);
    }
    expect(
      base64Encode(animation.frames[0].bytes),
      isNot(base64Encode(animation.frames[1].bytes)),
    );
    expect(
      base64Encode(animation.frames[1].bytes),
      isNot(base64Encode(animation.frames[2].bytes)),
    );
  });

  test('invalid bytes are rejected', () {
    expect(decodeGifPngAnimation(Uint8List.fromList(<int>[1, 2, 3])), isNull);
  });
}
