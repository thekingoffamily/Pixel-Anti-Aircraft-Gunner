import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../engine/game.dart';
import '../engine/palette.dart';
import '../engine/view_transform.dart';
import '../services/sfx.dart';
import '../services/storage.dart';
import 'overlays.dart';
import 'pixel_view.dart';

/// Игровой экран: цикл кадров, ввод и слои интерфейса.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final GameEngine _engine;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = GameEngine();
    _engine.onBestChanged = (int score) {
      GameStore.saveBest(score);
    };
    _restoreSettings();
    _ticker = createTicker(_onTick)..start();
  }

  Future<void> _restoreSettings() async {
    final int best = await GameStore.loadBest();
    final bool sound = await GameStore.loadSound();
    final bool vibro = await GameStore.loadVibro();
    if (!mounted) {
      return;
    }
    _engine.bestScore = best;
    Sfx.sound = sound;
    Sfx.vibro = vibro;
    _engine.ui.emit();
  }

  void _onTick(Duration elapsed) {
    double dt = (elapsed - _last).inMicroseconds / 1000000.0;
    _last = elapsed;
    if (dt < 0) {
      dt = 0;
    }
    if (dt > 0.05) {
      dt = 0.05;
    }
    _engine.update(dt);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _engine.scene == GameScene.playing && !_engine.paused) {
      _engine.togglePause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _engine.ui.dispose();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: P.get(0),
      body: ListenableBuilder(
        listenable: _engine.ui,
        builder: (BuildContext context, Widget? child) {
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final ViewTransform transform = ViewTransform(
                Size(constraints.maxWidth, constraints.maxHeight),
              );
              _engine.resizeWorld(transform.worldH);

              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (TapDownDetails details) {
                      final Offset point = transform.toVirtual(details.localPosition);
                      _engine.tapAt(point.dx, point.dy);
                    },
                    onPanUpdate: (DragUpdateDetails details) {
                      final Offset point = transform.toVirtual(details.localPosition);
                      _engine.setAim(point.dx, point.dy);
                    },
                    child: PixelView(engine: _engine, transform: transform),
                  ),
                  HudButtons(engine: _engine),
                  if (_engine.scene == GameScene.title) TitleOverlay(engine: _engine),
                  if (_engine.scene == GameScene.upgrade) UpgradeOverlay(engine: _engine),
                  if (_engine.scene == GameScene.gameOver) GameOverOverlay(engine: _engine),
                  if (_engine.scene == GameScene.playing && _engine.paused) PauseOverlay(engine: _engine),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
