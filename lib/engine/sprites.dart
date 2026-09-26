import 'dart:ui';

import 'palette.dart';

/// Спрайт, описанный «картой символов» — как `pyxel.images[0].set(...)` в Pyxel.
///
/// Каждый символ строки — индекс цвета палитры в hex (0..9, a..f),
/// точка или пробел — прозрачный пиксель.
///
/// Контуры всех цветов спрайта заранее собираются в [Path] в виртуальных
/// координатах: при отрисовке остаётся один drawPath на цвет, а не сотни
/// drawRect на пиксель.
class Sprite {
  Sprite(List<String> rows)
      : h = rows.length,
        w = _maxWidth(rows),
        _paths = _buildPaths(rows);

  final int w;
  final int h;
  final List<MapEntry<int, Path>> _paths;
  final Map<int, List<Paint>> _paintCache = <int, List<Paint>>{};

  static int _maxWidth(List<String> rows) {
    int maxW = 0;
    for (final String row in rows) {
      if (row.length > maxW) {
        maxW = row.length;
      }
    }
    return maxW;
  }

  static List<MapEntry<int, Path>> _buildPaths(List<String> rows) {
    final Map<int, Path> byColor = <int, Path>{};
    for (int y = 0; y < rows.length; y++) {
      final String row = rows[y];
      for (int x = 0; x < row.length; x++) {
        final int? color = _hexValue(row.codeUnitAt(x));
        if (color == null) {
          continue;
        }
        final Path path = byColor.putIfAbsent(color, () => Path());
        path.addRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1));
      }
    }
    return byColor.entries.toList(growable: false);
  }

  static int? _hexValue(int code) {
    if (code >= 0x30 && code <= 0x39) {
      return code - 0x30; // 0-9
    }
    if (code >= 0x61 && code <= 0x66) {
      return code - 0x61 + 10; // a-f
    }
    if (code >= 0x41 && code <= 0x46) {
      return code - 0x41 + 10; // A-F
    }
    return null;
  }

  List<Paint> _paints(double alpha) {
    final int a20 = (alpha * 20).round();
    final int safeA = a20 < 0 ? 0 : (a20 > 20 ? 20 : a20);
    final List<Paint>? cached = _paintCache[safeA];
    if (cached != null) {
      return cached;
    }
    final double a = safeA / 20.0;
    final List<Paint> paints = <Paint>[
      for (final MapEntry<int, Path> entry in _paths)
        Paint()
          ..isAntiAlias = false
          ..style = PaintingStyle.fill
          ..color = a >= 1.0 ? P.get(entry.key) : P.alpha(entry.key, a),
    ];
    _paintCache[safeA] = paints;
    return paints;
  }

  List<Paint> _overridePaints(int color, double alpha) {
    final int key = 100 + (color & 15) * 32 + (alpha * 20).round();
    final List<Paint>? cached = _paintCache[key];
    if (cached != null) {
      return cached;
    }
    final Paint paint = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.fill
      ..color = alpha >= 1.0 ? P.get(color) : P.alpha(color, alpha);
    final List<Paint> paints = <Paint>[for (int i = 0; i < _paths.length; i++) paint];
    _paintCache[key] = paints;
    return paints;
  }

  /// Нарисовать спрайт левым верхним углом в точке ([x], [y]).
  ///
  /// [flip] — зеркальное отражение по горизонтали,
  /// [alpha] — прозрачность (используется маскировщиком),
  /// [override] — цвет заливки всего спрайта (вспышка от попадания).
  void draw(
    Canvas canvas,
    double x,
    double y, {
    bool flip = false,
    double alpha = 1.0,
    int? override,
  }) {
    if (_paths.isEmpty) {
      return;
    }
    final List<Paint> paints = override == null ? _paints(alpha) : _overridePaints(override, alpha);
    canvas.save();
    canvas.translate(x.roundToDouble(), y.roundToDouble());
    if (flip) {
      canvas.translate(w.toDouble(), 0);
      canvas.scale(-1, 1);
    }
    for (int i = 0; i < _paths.length && i < paints.length; i++) {
      canvas.drawPath(_paths[i].value, paints[i]);
    }
    canvas.restore();
  }
}

/// Собрать симметричный спрайт из левой половины.
///
/// Это гарантирует одинаковую ширину строк и симметрию — те же приёмы, что в
/// примерах Pyxel, только без ручного подсчёта длины каждой строки.
List<String> sym(List<String> half) {
  return <String>[for (final String row in half) row + _reversed(row)];
}

String _reversed(String value) {
  final StringBuffer buffer = StringBuffer();
  for (int i = value.length - 1; i >= 0; i--) {
    buffer.write(value[i]);
  }
  return buffer.toString();
}

// ---------------------------------------------------------------------------
// Дроны (все спрайты симметричны, ширина = 2 x длина половины)
// ---------------------------------------------------------------------------

/// Разведчик — медленный базовый дрон. 10x6.
final Sprite sprScout = Sprite(sym(<String>[
  '....0',
  '..0b0',
  '.0bbb',
  '0b888',
  '.0bbb',
  '..0..',
]));

/// Перехватчик — быстрый, с двумя соплами. 12x5.
final Sprite sprInterceptor = Sprite(sym(<String>[
  '...0..',
  '..0.0.',
  '.0dddd',
  '0dd878',
  '.00ddd',
]));

/// Бронированный дрон — тяжёлая броня, требует нескольких попаданий. 14x6.
final Sprite sprArmored = Sprite(sym(<String>[
  '....0.',
  '..0bb0',
  '.0bbbb',
  '0bbb4b',
  '0bbbbb',
  '.00000',
]));

/// Дрон-роевик — маленький и быстрый, появляется группами. 8x4.
final Sprite sprSwarmer = Sprite(sym(<String>[
  '..0.',
  '0999',
  '0990',
  '.00.',
]));

/// Маскировщик — то появляется, то почти растворяется в небе. 10x6.
final Sprite sprCloaker = Sprite(sym(<String>[
  '...00',
  '.0222',
  '022e2',
  '02222',
  '.0222',
  '..0.0',
]));

/// Дрон-матка — босс, выпускающий малые дроны. 24x10.
final Sprite sprMothership = Sprite(sym(<String>[
  '........0000',
  '......002222',
  '....00222222',
  '..0022222222',
  '002222222222',
  '0222222222ee',
  '0222222222ee',
  '002222222222',
  '..0022ee2222',
  '....00000000',
]));

// ---------------------------------------------------------------------------
// Оборудование базы
// ---------------------------------------------------------------------------

/// Купол зенитной установки (вращается только ствол). 18x8.
final Sprite sprTurret = Sprite(sym(<String>[
  '.........',
  '.....0000',
  '...00bbbb',
  '..0bb3333',
  '.0bb33333',
  '.0bb33333',
  '0bbbbbbbb',
  '000000000',
]));

/// Бункер базы с энергоядром. 30x9.
final Sprite sprBunker = Sprite(sym(<String>[
  '...............',
  '.........000000',
  '......00bbbbbbb',
  '....00bbbbbbbbb',
  '..00bbbbbbbbbbb',
  '.0bbbbbbbbbbbbb',
  '0bbbb3333bbbbbb',
  '0bbb3333333bbbb',
  '000000000000000',
]));

/// Ракета (ракетный залп и EMP-снаряд). 3x5.
final Sprite sprRocket = Sprite(<String>[
  '.9.',
  '999',
  '090',
  '080',
  '0.0',
]);

/// Прицел — рисуется в точке касания. 9x9, центр пустой, чтобы не закрывать цель.
final Sprite sprCrosshair = Sprite(<String>[
  '....0....',
  '....7....',
  '....0....',
  '....0....',
  '000...000',
  '....0....',
  '....0....',
  '....7....',
  '....0....',
]);
