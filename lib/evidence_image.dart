import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

// Parse bounded metadata before invoking a pixel decoder. ImageDescriptor's
// encoded width/height getters are unsupported in Flutter's web implementation.
(int, int) _imageDimensions(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final n = bytes.length;
  if (data.getUint32(0) == 0x89504e47 &&
      data.getUint32(4) == 0x0d0a1a0a &&
      data.getUint32(8) == 13 &&
      data.getUint32(12) == 0x49484452) {
    var offset = 8;
    var sawData = false;
    while (offset + 12 <= n) {
      final size = data.getUint32(offset);
      if (size > n - offset - 12) break;
      final type = data.getUint32(offset + 4);
      if (type == 0x6163544c || (type == 0x49484452 && offset != 8)) {
        throw const FormatException('Invalid or animated evidence');
      }
      if (type == 0x49444154) sawData = true;
      offset += size + 12;
      if (type == 0x49454e44) {
        if (sawData && size == 0 && offset == n) {
          return (data.getUint32(16), data.getUint32(20));
        }
        break;
      }
    }
  } else if (data.getUint16(0) == 0xffd8) {
    var offset = 2;
    while (offset < n) {
      if (bytes[offset] != 255) break;
      while (offset < n && bytes[offset] == 255) {
        offset++;
      }
      if (offset >= n) break;
      final marker = bytes[offset++];
      if ([0, 216, 217, 218].contains(marker)) break;
      if (marker == 1 || (marker >= 208 && marker <= 215)) continue;
      if (offset + 2 > n) break;
      final size = data.getUint16(offset);
      if (size < 2 || size > n - offset) break;
      if ([
        192,
        193,
        194,
        195,
        197,
        198,
        199,
        201,
        202,
        203,
        205,
        206,
        207,
      ].contains(marker)) {
        if (size < 8) break;
        return (data.getUint16(offset + 5), data.getUint16(offset + 3));
      }
      offset += size;
    }
  }
  throw const FormatException('Invalid image metadata');
}

// Evidence is untrusted, including rows uploaded before server hardening.
Future<void> validateEvidenceImage(Uint8List bytes) async {
  if (bytes.length < 24 || bytes.length > 524288) {
    throw const FormatException('Invalid evidence');
  }
  final (width, height) = _imageDimensions(bytes);
  if (width < 1 || height < 1 || width > 4096 || height > 4096) {
    throw const FormatException('Image dimensions exceed limit');
  }
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: width > 1024 ? 1024 : width,
    targetHeight: height > 1024 ? 1024 : height,
    allowUpscaling: false,
  );
  try {
    if (codec.frameCount != 1) {
      throw const FormatException('Animated evidence is unsupported');
    }
    final frame = await codec.getNextFrame();
    frame.image.dispose();
  } finally {
    codec.dispose();
  }
}

Future<Uint8List> decodeEvidenceImage(String data) async {
  if (data.length > 699052) throw const FormatException('Invalid evidence');
  final bytes = base64Decode(data);
  await validateEvidenceImage(bytes);
  return bytes;
}
