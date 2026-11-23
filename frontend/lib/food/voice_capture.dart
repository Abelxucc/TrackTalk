import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'food_service.dart';

typedef VoiceCapture = Future<Uint8List?> Function(
  Completer<bool> release,
  void Function() started,
  void Function(double level) onLevel,
);

const _sampleRate = 16000;
const _sampleBytes = 2;
const _bytesPerSecond = _sampleRate * _sampleBytes;
const _maxSeconds = 30;

Future<Uint8List?> captureVoice(
  Completer<bool> release,
  void Function() started,
  void Function(double level) onLevel,
) async {
  final recorder = AudioRecorder();
  try {
    if (!await recorder.hasPermission()) {
      throw const FoodException(
        'Allow microphone access to speak, or switch to typing.',
      );
    }
    // The user may have released the button while granting permission.
    if (release.isCompleted) return null;

    final stream = await recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
        audioRouteChange: AudioRouteChangeMode.stop,
      ),
    );
    final samples = BytesBuilder(copy: false);
    final interrupted = Completer<bool>();
    void interrupt() {
      if (!interrupted.isCompleted) interrupted.complete(false);
    }

    final subscription = stream.listen(
      (chunk) {
        final room = _bytesPerSecond * _maxSeconds - samples.length;
        if (room > 0) {
          final pcm = Uint8List.sublistView(chunk, 0, min(room, chunk.length));
          samples.add(pcm);
          if (pcm.length >= _sampleBytes) onLevel(_audioLevel(pcm));
        }
      },
      onError: (Object _) => interrupt(),
      onDone: interrupt,
    );
    final limit = Completer<bool>();
    final timer = Timer(
      const Duration(seconds: _maxSeconds),
      () => limit.complete(true),
    );
    try {
      if (!release.isCompleted) started();
      final shouldTranscribe = await Future.any([
        release.future,
        limit.future,
        interrupted.future,
      ]);
      if (!shouldTranscribe) {
        await recorder.cancel();
        if (!release.isCompleted) {
          throw const FoodException('Recording was interrupted. Try again.');
        }
        return null;
      }
      // stop() closes the stream after delivering its remaining samples.
      await recorder.stop();
      if (samples.length < _bytesPerSecond ~/ 4) {
        throw const FoodException('Hold the button while you speak.');
      }
      return _wav(samples.takeBytes());
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  } finally {
    await recorder.dispose();
  }
}

double _audioLevel(Uint8List pcm) {
  final data = ByteData.sublistView(pcm);
  final sampleCount = pcm.length ~/ _sampleBytes;
  var energy = 0.0;
  for (var i = 0; i < sampleCount; i++) {
    final sample = data.getInt16(i * _sampleBytes, Endian.little) / 32768;
    energy += sample * sample;
  }
  return (sqrt(energy / sampleCount) * 5).clamp(0.0, 1.0);
}

Uint8List _wav(Uint8List samples) {
  const headerSize = 44;
  final bytes = Uint8List(headerSize + samples.length)
    ..setRange(0, 4, 'RIFF'.codeUnits)
    ..setRange(8, 16, 'WAVEfmt '.codeUnits)
    ..setRange(36, 40, 'data'.codeUnits)
    ..setRange(headerSize, headerSize + samples.length, samples);
  ByteData.sublistView(bytes)
    ..setUint32(4, bytes.length - 8, Endian.little)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, 1, Endian.little) // Mono
    ..setUint32(24, _sampleRate, Endian.little)
    ..setUint32(28, _bytesPerSecond, Endian.little)
    ..setUint16(32, _sampleBytes, Endian.little)
    ..setUint16(34, _sampleBytes * 8, Endian.little)
    ..setUint32(40, samples.length, Endian.little);
  return bytes;
}
