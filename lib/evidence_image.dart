import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

// Evidence is untrusted, including rows uploaded before server hardening.
Future<void> validateEvidenceImage(Uint8List bytes) async {
  if (bytes.length < 24 || bytes.length > 524288) {
    throw const FormatException('Invalid evidence');
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      if (descriptor.width < 1 ||
          descriptor.height < 1 ||
          descriptor.width > 4096 ||
          descriptor.height > 4096) {
        throw const FormatException('Image dimensions exceed limit');
      }
      // Decode only a bounded thumbnail to reject corrupt/animated images.
      final codec = await descriptor.instantiateCodec(
        targetWidth: descriptor.width > 1024 ? 1024 : descriptor.width,
        targetHeight: descriptor.height > 1024 ? 1024 : descriptor.height,
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
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}

Future<Uint8List> decodeEvidenceImage(String data) async {
  if (data.length > 699052) throw const FormatException('Invalid evidence');
  final bytes = base64Decode(data);
  await validateEvidenceImage(bytes);
  return bytes;
}
