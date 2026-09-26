import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Звуковые эффекты и вибрация.
///
/// Эффекты — короткие 8-bit сэмплы из assets/audio (генерируются
/// tool/gen_sounds.dart). На каждый звук держится пул проигрывателей, чтобы
/// выстрелы и взрывы накладывались друг на друга, а не обрывали предыдущий.
class Sfx {
  Sfx._();

  static bool sound = true;
  static bool vibro = true;

  static bool _broken = false;
  static bool _ready = false;
  static bool _initializing = false;

  /// Сколько одновременных копий звука допустимо.
  static const Map<String, int> _poolSize = <String, int>{
    'shoot': 6,
    'hit': 4,
    'explode': 3,
    'ui': 3,
    'reload': 2,
    'wave': 1,
    'emp': 1,
    'baseHit': 2,
    'gameOver': 1,
  };

  static const Map<String, double> _volume = <String, double>{
    'shoot': 0.45,
    'hit': 0.55,
    'explode': 0.65,
    'ui': 0.45,
    'reload': 0.55,
    'wave': 0.55,
    'emp': 0.65,
    'baseHit': 0.75,
    'gameOver': 0.75,
  };

  static final Map<String, List<AudioPlayer>> _players = <String, List<AudioPlayer>>{};
  static final Map<String, int> _cursor = <String, int>{};

  /// Прогревает сэмплы. Безопасно вызывать повторно и в юнит-тестах.
  static Future<void> init() async {
    if (_ready || _broken || _initializing) {
      return;
    }
    _initializing = true;
    try {
      for (final MapEntry<String, int> entry in _poolSize.entries) {
        final List<AudioPlayer> list = <AudioPlayer>[];
        for (int i = 0; i < entry.value; i++) {
          final AudioPlayer player = AudioPlayer();
          await _configure(player, entry.key);
          list.add(player);
        }
        _players[entry.key] = list;
        _cursor[entry.key] = 0;
      }
      await AudioCache.instance.loadAll(
        _poolSize.keys.map((String name) => 'audio/$name.wav').toList(),
      );
      _ready = true;
    } catch (_) {
      // Плагин недоступен (например, в тестах) — просто молчим.
      _broken = true;
    } finally {
      _initializing = false;
    }
  }

  static Future<void> _configure(AudioPlayer player, String name) async {
    try {
      await player.setPlayerMode(PlayerMode.lowLatency);
    } catch (_) {
      // Режим поддерживается не везде — не критично.
    }
    try {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(_volume[name] ?? 0.6);
    } catch (_) {
      // Игнорируем: настройка применится по умолчанию.
    }
  }

  static void dispose() {
    for (final List<AudioPlayer> pool in _players.values) {
      for (final AudioPlayer player in pool) {
        try {
          player.dispose();
        } catch (_) {
          // Некритично.
        }
      }
    }
    _players.clear();
    _cursor.clear();
    _ready = false;
  }

  static void _play(String name) {
    if (!sound || _broken || !_ready) {
      return;
    }
    final List<AudioPlayer>? pool = _players[name];
    if (pool == null || pool.isEmpty) {
      return;
    }
    final int index = _cursor[name] ?? 0;
    _cursor[name] = (index + 1) % pool.length;
    final AudioPlayer player = pool[index];
    try {
      player.stop().catchError((Object _) {});
      player.play(AssetSource('audio/$name.wav')).catchError((Object _) {});
    } catch (_) {
      _broken = true;
    }
  }

  static void _haptic(Future<void> Function() action) {
    if (!vibro) {
      return;
    }
    try {
      action().catchError((Object _) {});
    } catch (_) {
      // Платформенный канал недоступен — не критично.
    }
  }

  static void shoot() => _play('shoot');

  static void ui() => _play('ui');

  static void reload() => _play('reload');

  static void hit() {
    _play('hit');
    _haptic(HapticFeedback.selectionClick);
  }

  static void explode() {
    _play('explode');
    _haptic(HapticFeedback.lightImpact);
  }

  static void wave() {
    _play('wave');
    _haptic(HapticFeedback.mediumImpact);
  }

  static void emp() {
    _play('emp');
    _haptic(HapticFeedback.heavyImpact);
  }

  static void baseHit() {
    _play('baseHit');
    _haptic(HapticFeedback.heavyImpact);
  }

  static void gameOver() {
    _play('gameOver');
    _haptic(HapticFeedback.heavyImpact);
  }
}
