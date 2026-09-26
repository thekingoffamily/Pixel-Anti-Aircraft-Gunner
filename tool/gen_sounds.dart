// Генератор 8-bit звуковых эффектов «Пиксельного Зенитчика».
//
// Ассеты не скачиваются: все сэмплы синтезируются кодом (квадрат, шум,
// огибающие) и сохраняются в assets/audio/*.wav как PCM 16-bit mono.
// Запуск: dart tool/gen_sounds.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int _sampleRate = 22050;
const String _outDir = 'assets/audio';

void main() {
  Directory(_outDir).createSync(recursive: true);
  _write('shoot', _shoot());
  _write('ui', _ui());
  _write('reload', _reload());
  _write('hit', _hit());
  _write('explode', _explode());
  _write('wave', _wave());
  _write('emp', _emp());
  _write('baseHit', _baseHit());
  _write('gameOver', _gameOver());
  stdout.writeln('Готово: $_outDir');
}

/// Длина буфера в сэмплах для заданной длительности.
Float64List _buffer(double seconds) => Float64List((seconds * _sampleRate).round());

/// Прямоугольная волна (duty 50%) по накопленной фазе.
double _square(double phase) => (phase - phase.floorToDouble()) < 0.5 ? 1.0 : -1.0;

Float64List _shoot() {
  const double dur = 0.10;
  final Float64List b = _buffer(dur);
  const double f0 = 950;
  const double f1 = 280;
  double phase = 0;
  for (int i = 0; i < b.length; i++) {
    final double t = i / _sampleRate;
    final double p = t / dur;
    final double f = f0 * pow(f1 / f0, p).toDouble();
    phase += f / _sampleRate;
    b[i] = _square(phase) * pow(1 - p, 2).toDouble() * 0.4;
  }
  return b;
}

Float64List _ui() {
  const double dur = 0.06;
  final Float64List b = _buffer(dur);
  const double f0 = 780;
  const double f1 = 1180;
  double phase = 0;
  for (int i = 0; i < b.length; i++) {
    final double t = i / _sampleRate;
    final double p = t / dur;
    phase += (f0 + (f1 - f0) * p) / _sampleRate;
    b[i] = _square(phase) * pow(1 - p, 1.5).toDouble() * 0.32;
  }
  return b;
}

Float64List _reload() {
  const double dur = 0.20;
  final Float64List b = _buffer(dur);
  final Random rng = Random(7);
  double phase = 0;
  for (int i = 0; i < b.length; i++) {
    final double t = i / _sampleRate;
    double tau;
    double freq;
    if (t < 0.05) {
      tau = t;
      freq = 260;
    } else if (t > 0.10 && t < 0.15) {
      tau = t - 0.10;
      freq = 180;
    } else {
      continue;
    }
    phase += freq / _sampleRate;
    final double env = exp(-tau * 60).toDouble();
    final double noise = rng.nextDouble() * 2 - 1;
    b[i] = (noise * 0.5 + _square(phase) * 0.5) * env * 0.4;
  }
  return b;
}

Float64List _hit() {
  const double dur = 0.08;
  final Float64List b = _buffer(dur);
  final Random rng = Random(11);
  double phase = 0;
  for (int i = 0; i < b.length; i++) {
    final double t = i / _sampleRate;
    phase += 320 / _sampleRate;
    final double env = exp(-t * 45).toDouble();
    final double noise = rng.nextDouble() * 2 - 1;
    b[i] = (noise * 0.6 + _square(phase) * 0.4) * env * 0.4;
  }
  return b;
}

Float64List _explode() {
  const double dur = 0.5;
  final Float64List b = _buffer(dur);
  final Random rng = Random(23);
  const double f0 = 90;
  const double f1 = 50;
  double lp = 0;
  double phase = 0;
  for (int i = 0; i < b.length; i++) {
    final double t = i / _sampleRate;
    final double p = t / dur;
    final double f = f0 * pow(f1 / f0, p).toDouble();
    phase += f / _sampleRate;
    final double noise = rng.nextDouble() * 2 - 1;
    lp += (noise - lp) * 0.25;
    final double env = exp(-t * 7).toDouble();
    b[i] = (lp * 0.7 + _square(phase) * 0.5) * env * 0.5;
  }
  return b;
}

Float64List _wave() {
  const double dur = 0.6;
  final Float64List b = _buffer(dur);
  const List<double> notes = <double>[523.25, 659.25, 783.99, 1046.5];
  final double seg = dur / notes.length;
  double phase = 0;
  for (int i = 0; i < b.length; i++) {
    final double t = i / _sampleRate;
    final int idx = (t / seg).floor().clamp(0, notes.length - 1);
    final double tau = t - idx * seg;
    phase += notes[idx] / _sampleRate;
    b[i] = _square(phase) * exp(-tau * 10).toDouble() * 0.35;
  }
  return b;
}

Float64List _emp() {
  const double dur = 0.6;
  final Float64List b = _buffer(dur);
  const double f0 = 1500;
  const double f1 = 100;
  double phase = 0;
  for (int i = 0; i < b.length; i++) {
    final double t = i / _sampleRate;
    final double p = t / dur;
    final double f = f0 * pow(f1 / f0, p).toDouble();
    phase += f / _sampleRate;
    final double attack = min(1.0, t * 40);
    final double env = attack * exp(-t * 3.5).toDouble();
    final double tremolo = 1 + 0.4 * sin(2 * pi * 30 * t);
    b[i] = _square(phase) * env * tremolo * 0.32;
  }
  return b;
}

Float64List _baseHit() {
  const double dur = 0.3;
  final Float64List b = _buffer(dur);
  final Random rng = Random(31);
  const double f0 = 130;
  const double f1 = 60;
  double lp = 0;
  double phase = 0;
  for (int i = 0; i < b.length; i++) {
    final double t = i / _sampleRate;
    final double p = t / dur;
    final double f = f0 * pow(f1 / f0, p).toDouble();
    phase += f / _sampleRate;
    final double noise = rng.nextDouble() * 2 - 1;
    lp += (noise - lp) * 0.15;
    final double env = exp(-t * 10).toDouble();
    b[i] = (_square(phase) * 0.6 + lp * 0.5) * env * 0.45;
  }
  return b;
}

Float64List _gameOver() {
  const double dur = 1.0;
  final Float64List b = _buffer(dur);
  const List<double> notes = <double>[523.25, 415.30, 329.63, 261.63, 196.00];
  final double seg = dur / notes.length;
  double phase = 0;
  for (int i = 0; i < b.length; i++) {
    final double t = i / _sampleRate;
    final int idx = (t / seg).floor().clamp(0, notes.length - 1);
    final double tau = t - idx * seg;
    phase += notes[idx] / _sampleRate;
    b[i] = _square(phase) * exp(-tau * 6).toDouble() * 0.35;
  }
  return b;
}

void _write(String name, Float64List samples) {
  final int dataLen = samples.length * 2;
  final ByteData data = ByteData(44 + dataLen);

  void ascii(int offset, String tag) {
    for (int i = 0; i < tag.length; i++) {
      data.setUint8(offset + i, tag.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + dataLen, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, _sampleRate, Endian.little);
  data.setUint32(28, _sampleRate * 2, Endian.little); // byte rate
  data.setUint16(32, 2, Endian.little); // block align
  data.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  data.setUint32(40, dataLen, Endian.little);

  for (int i = 0; i < samples.length; i++) {
    double s = samples[i];
    if (s > 1) {
      s = 1;
    } else if (s < -1) {
      s = -1;
    }
    data.setInt16(44 + i * 2, (s * 32767).round(), Endian.little);
  }

  final File file = File('$_outDir/$name.wav');
  file.writeAsBytesSync(data.buffer.asUint8List());
  stdout.writeln('  $name.wav (${dataLen + 44} байт)');
}
