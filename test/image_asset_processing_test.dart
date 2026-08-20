import 'dart:convert';
import 'dart:typed_data';

import 'package:gloss_editor/services/image_library.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

String _dataUri(img.Image image) {
  final Uint8List bytes = img.encodePng(image);
  return '$huiNormalizedPngDataUriPrefix${base64Encode(bytes)}';
}

void main() {
  group('fitImageDimensions', () {
    test('keeps small images and aspect-fits oversized images', () {
      expect(fitImageDimensions(32, 48, 64), (width: 32, height: 48));
      expect(fitImageDimensions(200, 100, 64), (width: 64, height: 32));
      expect(fitImageDimensions(100, 200, 64), (width: 32, height: 64));
    });

    test('rejects non-positive dimensions', () {
      expect(fitImageDimensions(0, 10, 64), (width: 0, height: 0));
      expect(fitImageDimensions(10, 10, 0), (width: 0, height: 0));
    });
  });

  test('uploaded PNGs are resized to the Gloss ceiling', () {
    final img.Image source = img.Image(width: 128, height: 64);
    source.clear(img.ColorRgba8(20, 40, 60, 255));
    final NormalizedImageData? normalized = normalizeUploadedPng(
      _dataUri(source),
    );

    expect(normalized, isNotNull);
    expect(normalized!.width, 64);
    expect(normalized.height, 32);
    final StoredPngData? decoded = decodeNormalizedPngData(normalized.dataUri);
    expect(decoded?.width, 64);
    expect(decoded?.height, 32);
  });

  test('animated uploads expose their ordered frame group to insertion UI', () {
    final String dataUri = _dataUri(img.Image(width: 1, height: 1));
    final ImageLibrary library = ImageLibrary(
      autoLoad: false,
      writer: (String _, String _) => true,
    );
    expect(
      library.upsertAll(<StoredImage>[
        StoredImage(
          path: 'effects/pulse/frame-002.png',
          dataUri: dataUri,
          width: 1,
          height: 1,
        ),
        StoredImage(
          path: 'effects/pulse/frame-001.png',
          dataUri: dataUri,
          width: 1,
          height: 1,
        ),
        StoredImage(
          path: 'effects/other/frame-001.png',
          dataUri: dataUri,
          width: 1,
          height: 1,
        ),
        StoredImage(
          path: 'effects/pulse/frame-extra/frame-001.png',
          dataUri: dataUri,
          width: 1,
          height: 1,
        ),
      ]),
      isTrue,
    );

    expect(
      library
          .animationFramesFor('effects/pulse/frame-002.png')
          .map((StoredImage image) => image.path),
      <String>['effects/pulse/frame-001.png', 'effects/pulse/frame-002.png'],
    );
    expect(library.animationFramesFor('effects/other.png'), isEmpty);
  });

  group('Minecraft skin heads', () {
    test('combines the face and translucent hat into an 8x8 asset', () {
      final img.Image skin = img.Image(width: 64, height: 64, numChannels: 4);
      for (int y = 8; y < 16; y++) {
        for (int x = 8; x < 16; x++) {
          skin.setPixelRgba(x, y, 220, 30, 40, 255);
        }
      }
      skin.setPixelRgba(40, 8, 10, 80, 240, 255);

      final NormalizedImageData? head = minecraftHeadFromSkinPng(
        _dataUri(skin),
      );

      expect(head, isNotNull);
      expect(head!.width, 8);
      expect(head.height, 8);
      final img.Image? decoded = img.decodePng(
        decodeDataUriBytes(head.dataUri)!,
      );
      expect(decoded, isNotNull);
      final img.Pixel overlayPixel = decoded!.getPixel(0, 0);
      final img.Pixel facePixel = decoded.getPixel(1, 0);
      expect(
        <int>[
          overlayPixel.r.toInt(),
          overlayPixel.g.toInt(),
          overlayPixel.b.toInt(),
        ],
        <int>[10, 80, 240],
      );
      expect(
        <int>[facePixel.r.toInt(), facePixel.g.toInt(), facePixel.b.toInt()],
        <int>[220, 30, 40],
      );
    });

    test('accepts high-resolution skins and rejects unrelated images', () {
      final img.Image highResolution = img.Image(
        width: 128,
        height: 128,
        numChannels: 4,
      );
      for (int y = 16; y < 32; y++) {
        for (int x = 16; x < 32; x++) {
          highResolution.setPixelRgba(x, y, 30, 200, 90, 255);
        }
      }
      expect(minecraftHeadFromSkinPng(_dataUri(highResolution)), isNotNull);
      expect(
        minecraftHeadFromSkinPng(_dataUri(img.Image(width: 32, height: 32))),
        isNull,
      );
    });
  });
}
