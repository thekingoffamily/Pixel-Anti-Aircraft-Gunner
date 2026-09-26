import 'package:flutter/material.dart';

import '../engine/game.dart';
import '../engine/palette.dart';
import '../engine/upgrades.dart';
import '../services/sfx.dart';
import '../services/storage.dart';

/// Заголовок экрана в ретро-стиле.
class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFFE9C35B),
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    );
  }
}

/// Непрозрачная подложка, которая перехватывает касания,
/// чтобы случайный тап не выстрелил под меню.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(
        color: P.alpha(1, 0.94),
        child: SafeArea(child: child),
      ),
    );
  }
}

/// Главное меню.
class TitleOverlay extends StatefulWidget {
  const TitleOverlay({super.key, required this.engine});

  final GameEngine engine;

  @override
  State<TitleOverlay> createState() => _TitleOverlayState();
}

class _TitleOverlayState extends State<TitleOverlay> {
  @override
  Widget build(BuildContext context) {
    final GameEngine engine = widget.engine;
    return _Backdrop(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 210, maxWidth: 210),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset('logo-app.png', fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Защити базу от роя автономных дронов',
                textAlign: TextAlign.center,
                style: TextStyle(color: P.get(6), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text(
                'РЕКОРД: ${engine.bestScore}',
                style: const TextStyle(color: Color(0xFFE9C35B), fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: P.get(3),
                    foregroundColor: P.get(0),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    Sfx.ui();
                    engine.newGame();
                  },
                  child: const Text('ИГРАТЬ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showHelp(context),
                      child: const Text('КАК ИГРАТЬ'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          Sfx.sound = !Sfx.sound;
                        });
                        GameStore.saveSound(Sfx.sound);
                      },
                      child: Text(Sfx.sound ? 'ЗВУК: ВКЛ' : 'ЗВУК: ВЫКЛ'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    Sfx.vibro = !Sfx.vibro;
                  });
                  GameStore.saveVibro(Sfx.vibro);
                },
                child: Text(Sfx.vibro ? 'ВИБРАЦИЯ: ВКЛ' : 'ВИБРАЦИЯ: ВЫКЛ'),
              ),
              const SizedBox(height: 14),
              Text(
                'v0.1.0 • бесплатная версия',
                style: TextStyle(color: P.get(11), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: P.get(1),
          title: const _Title('Как играть'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const <Widget>[
                Text(
                  'Тапайте по дронам — установка наводится и стреляет по точке касания. '
                  'Не дайте дронам дойти до энергоядра базы.',
                  style: TextStyle(color: Color(0xFFEEEEEE), height: 1.4),
                ),
                SizedBox(height: 10),
                Text('Типы противников', style: TextStyle(color: Color(0xFFE9C35B), fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text(
                  '• Разведчик — медленный, базовый\n'
                  '• Перехватчик — быстрый, меняет траекторию\n'
                  '• Бронированный — держит несколько попаданий\n'
                  '• Роевик — приходит группами\n'
                  '• Маскировщик — почти растворяется в небе\n'
                  '• Матка — босс каждой 5-й волны, выпускает малых дронов',
                  style: TextStyle(color: Color(0xFFEEEEEE), height: 1.4),
                ),
                SizedBox(height: 10),
                Text('Управление', style: TextStyle(color: Color(0xFFE9C35B), fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text(
                  '• Тап по экрану — выстрел\n'
                  '• ПЕРЕЗАРЯДКА — заполнить обойму досрочно\n'
                  '• EMP — импульс, когда шкала заполнена\n'
                  '• После каждой волны выбирайте улучшение',
                  style: TextStyle(color: Color(0xFFEEEEEE), height: 1.4),
                ),
                SizedBox(height: 10),
                Text(
                  'Ретро-вид вдохновлён движком Pyxel (kitao/pyxel): 16 цветов, '
                  'пиксельная сетка и спрайты-карты символов.',
                  style: TextStyle(color: Color(0xFFA3A3A3), height: 1.4, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ПОНЯТНО'),
            ),
          ],
        );
      },
    );
  }
}

/// Экран выбора улучшения между волнами.
class UpgradeOverlay extends StatelessWidget {
  const UpgradeOverlay({super.key, required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    final List<Upgrade> choices = engine.choices;
    return _Backdrop(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _Title('ВОЛНА ОТБИТА'),
              Text(
                'Волна ${engine.wave - 1} отбита',
                style: TextStyle(color: P.get(6), fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text(
                'Выберите улучшение',
                style: TextStyle(color: Color(0xFFEEEEEE), fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < choices.length; i++) _card(context, i, choices[i]),
              const SizedBox(height: 6),
              Text(
                'Очки: ${engine.score} • Прочность базы: ${engine.baseHp.round()}',
                style: TextStyle(color: P.get(11), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, int index, Upgrade upgrade) {
    final int level = engine.lvl(upgrade.id);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: P.get(5),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Sfx.ui();
            engine.chooseUpgrade(index);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: P.get(6), width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        upgrade.title,
                        style: const TextStyle(
                          color: Color(0xFFE9C35B),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (upgrade.maxLevel < 90)
                      Text(
                        '${level + 1}/${upgrade.maxLevel}',
                        style: TextStyle(color: P.get(6), fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  upgrade.desc,
                  style: const TextStyle(color: Color(0xFFEEEEEE), fontSize: 13, height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Экран окончания игры.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key, required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    final bool isRecord = engine.newRecord;
    return _Backdrop(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'БАЗА УНИЧТОЖЕНА',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD4186C), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
              const SizedBox(height: 14),
              Text(
                'ОЧКИ: ${engine.score}',
                style: const TextStyle(color: Color(0xFFEEEEEE), fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text('ВОЛНА: ${engine.wave}   СБИТО: ${engine.kills}', style: TextStyle(color: P.get(6), fontSize: 14)),
              const SizedBox(height: 6),
              Text(
                isRecord ? 'НОВЫЙ РЕКОРД!' : 'РЕКОРД: ${engine.bestScore}',
                style: const TextStyle(color: Color(0xFFE9C35B), fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: P.get(3),
                    foregroundColor: P.get(0),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    Sfx.ui();
                    engine.newGame();
                  },
                  child: const Text('ЗАНОВО', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Sfx.ui();
                    engine.toTitle();
                  },
                  child: const Text('В МЕНЮ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Оверлей паузы.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    return _Backdrop(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'ПАУЗА',
              style: TextStyle(color: Color(0xFFEEEEEE), fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 220,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: P.get(3), foregroundColor: P.get(0)),
                onPressed: () {
                  Sfx.ui();
                  engine.togglePause();
                },
                child: const Text('ПРОДОЛЖИТЬ'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 220,
              child: OutlinedButton(
                onPressed: () {
                  Sfx.ui();
                  engine.toTitle();
                },
                child: const Text('В МЕНЮ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Кнопки поверх боя: пауза, перезарядка, EMP.
class HudButtons extends StatelessWidget {
  const HudButtons({super.key, required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // Слушаем ui, а не сам движок: движок уведомляет каждый кадр, а кнопкам
      // достаточно реакции на смену сцены, паузы и готовности EMP.
      listenable: engine.ui,
      builder: (BuildContext context, Widget? child) {
        if (engine.scene != GameScene.playing) {
          return const SizedBox.shrink();
        }
        final bool ready = engine.empReady;
        return SafeArea(
          child: Stack(
            children: <Widget>[
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  tooltip: 'Пауза',
                  icon: const Icon(Icons.pause_circle_outline, size: 30),
                  color: P.get(7),
                  onPressed: () {
                    Sfx.ui();
                    engine.togglePause();
                  },
                ),
              ),
              Positioned(
                left: 10,
                bottom: 12,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: P.get(7),
                    side: BorderSide(color: P.get(6), width: 2),
                  ),
                  onPressed: () => engine.reloadNow(),
                  child: const Text('ПЕРЕЗАРЯДКА', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
              Positioned(
                right: 10,
                bottom: 12,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: ready ? P.get(3) : P.get(1),
                    foregroundColor: ready ? P.get(0) : P.get(11),
                    side: BorderSide(color: ready ? P.get(7) : P.get(5), width: 2),
                  ),
                  onPressed: ready ? () => engine.useEmp() : null,
                  child: const Text('EMP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
