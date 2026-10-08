import 'dart:typed_data';

/// Bounded mono PCM16 buffer for the Needle 16 kHz / 30-second input contract.
class Pcm16Buffer {
  Pcm16Buffer({this.maxBytes = 16_000 * 2 * 30});

  final int maxBytes;
  final BytesBuilder _builder = BytesBuilder(copy: false);
  var _length = 0;
  var truncated = false;

  int get length => _length;
  bool get isEmpty => _length == 0;

  void add(Uint8List chunk) {
    final remaining = maxBytes - _length;
    if (remaining <= 0) {
      truncated = true;
      return;
    }
    var size = chunk.length < remaining ? chunk.length : remaining;
    size &= ~1;
    if (size > 0) {
      _builder.add(size == chunk.length ? chunk : chunk.sublist(0, size));
      _length += size;
    }
    if (size < chunk.length) truncated = true;
  }

  Uint8List takeBytes() => _builder.takeBytes();
}
