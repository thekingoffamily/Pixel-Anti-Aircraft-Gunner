import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/constants.dart';
import '../engine/drone.dart';
import '../engine/effects.dart';
import '../engine/game.dart';
import '../engine/palette.dart';
import '../engine/pixels.dart';
import '../engine/sprites.dart';
import '../engine/view_transform.dart';

/// Отрисовка игрового мира.
///
/// Мир рисуется в виртуальном разрешении [kWorldW] x [ViewTransform.worldH]
/// и масштабируется целым числом — как экран ретро-консоли.
class PixelView extends StatelessWidget {
  const PixelView({super.key, required this.engine, required this.transform});

  final GameEngine engine;
  final ViewTransform transform;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: PixelPainter(engine, transform),
      size: Size.infinite,
    );
  }
}

/// Художник кадра: мир в виртуальных пикселях + HUD в пикселях экрана.
class PixelPainter extends CustomPainter {
  PixelPainter(this.engine, this.transform) : super(repaint: engine);

  final GameEngine engine;
  final ViewTransform transform;
  final math.Random _rnd = math.Random();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = P.get(0));

    canvas.save();
    canvas.translate(transform.offsetX, transform.offsetY);
    canvas.scale(transform.scale);
    if (engine.shake > 0) {
      final double amount = engine.shake * 2.5;
      canvas.translate((_rnd.nextDouble() - 0.5) * amount, (_rnd.nextDouble() - 0.5) * amount);
    }
    _drawWorld(canvas);
    canvas.restore();

    _drawHud(canvas);
  }

  // --- Мир -----------------------------------------------------------------

  void _drawWorld(Canvas canvas) {
    final double worldH = engine.worldH;
    final double groundY = engine.groundY;

    Px.skyBands(canvas, kWorldW, groundY, <int>[1, 5, 13, 6]);

    for (final Star star in engine.stars) {
      final double twinkle = 0.5 + 0.5 * math.sin(engine.time * 3.0 + star.x);
      Px.px(canvas, star.x, star.y, star.color, 0.35 + 0.65 * twinkle);
    }

    for (final Cloud cloud in engine.clouds) {
      _drawCloud(canvas, cloud);
    }

    _drawHills(canvas, groundY);

    Px.rect(canvas, 0, groundY, kWorldW, worldH - groundY, 12);
    Px.rect(canvas, 0, groundY, kWorldW, 2, 3);
    for (double x = 0; x < kWorldW; x += 6) {
      Px.rect(canvas, x, groundY + 6, 3, 1, 3, 0.7);
    }

    _drawBase(canvas);
    _drawTurret(canvas);
    _drawDrones(canvas);
    _drawShells(canvas);

    for (final Blast blast in engine.blasts) {
      if (blast.ring) {
        Px.ring(canvas, blast.x, blast.y, blast.radius, blast.thickness, blast.color, 0.9);
      } else {
        Px.circle(canvas, blast.x, blast.y, blast.radius, blast.color, 0.85);
      }
    }

    for (final Particle particle in engine.particles) {
      Px.px(canvas, particle.x, particle.y, particle.color);
    }

    if (engine.scene == GameScene.playing && engine.aiming && !engine.paused) {
      sprCrosshair.draw(
        canvas,
        engine.aimX - sprCrosshair.w / 2,
        engine.aimY - sprCrosshair.h / 2,
      );
    }
  }

  void _drawCloud(Canvas canvas, Cloud cloud) {
    final double x = cloud.x;
    final double y = cloud.y;
    final double w = cloud.w.toDouble();
    final double h = cloud.h.toDouble();
    Px.rect(canvas, x, y + 2, w, h - 2, 7, 0.85);
    Px.rect(canvas, x + 3, y, w - 6, 2, 7, 0.85);
    Px.rect(canvas, x + 1, y + h - 2, w - 2, 2, 6, 0.9);
  }

  void _drawHills(Canvas canvas, double groundY) {
    final int width = kWorldW.toInt();
    for (int x = 0; x < width; x++) {
      final double far = 11 + 6 * math.sin(x * 0.055) + 3 * math.sin(x * 0.17);
      Px.rect(canvas, x.toDouble(), groundY - far, 1, far, 5);
      final double near = 5 + 3 * math.sin(x * 0.09 + 1.7);
      Px.rect(canvas, x.toDouble(), groundY - near, 1, near, 1);
    }
  }

  void _drawBase(Canvas canvas) {
    final double groundY = engine.groundY;
    final double bunkerX = engine.coreX - sprBunker.w / 2;
    final double bunkerY = groundY - sprBunker.h + 3;
    sprBunker.draw(canvas, bunkerX, bunkerY);

    final double pulse = 0.6 + 0.4 * math.sin(engine.time * 4.0);
    Px.circle(canvas, engine.coreX, bunkerY + 6, 2 + pulse, 3, 0.95);
    Px.px(canvas, engine.coreX, bunkerY + 6, 7, 0.8);

    final double ratio = engine.baseHp / engine.baseMaxHp;
    const double barW = 26.0;
    final double barX = engine.coreX - barW / 2;
    Px.frame(canvas, barX, bunkerY - 7, barW, 4, 0);
    final int color = ratio > 0.6 ? 12 : (ratio > 0.3 ? 10 : 8);
    Px.rect(canvas, barX + 1, bunkerY - 6, (barW - 2) * ratio, 2, color);
  }

  void _drawTurret(Canvas canvas) {
    final double px = engine.turretX;
    final double py = engine.turretY;
    const double length = 14.0;
    final double a = engine.angle;
    final double dx = math.cos(a);
    final double dy = math.sin(a);
    final double nx = -dy;
    final double ny = dx;

    for (double t = 0; t <= length; t += 0.5) {
      final double x = px + dx * t;
      final double y = py + dy * t;
      Px.px(canvas, x, y, 0);
      Px.px(canvas, x + nx, y + ny, 11);
      Px.px(canvas, x + nx * 1.6, y + ny * 1.6, 11);
    }

    if (engine.muzzle > 0) {
      final double mx = px + dx * (length + 2);
      final double my = py + dy * (length + 2);
      Px.circle(canvas, mx, my, 3.5, 10);
      Px.circle(canvas, mx, my, 1.8, 7);
    }

    sprTurret.draw(canvas, px - sprTurret.w / 2, py - 4);
  }

  void _drawDrones(Canvas canvas) {
    for (final Drone drone in engine.drones) {
      final double left = drone.x - drone.spec.w / 2;
      final double top = drone.y - drone.spec.h / 2;
      final double alpha = drone.kind == DroneKind.cloaker ? drone.cloak : 1.0;
      drone.spec.sprite.draw(
        canvas,
        left,
        top,
        alpha: alpha,
        override: drone.hitTimer > 0 ? 7 : null,
      );

      if (drone.stunTimer > 0) {
        Px.ring(canvas, drone.x, drone.y, 7, 1, 6, 0.9);
        Px.px(canvas, drone.x + 3, drone.y - 6, 7, 0.9);
      }

      if (drone.isBoss) {
        const double barW = 24.0;
        final double ratio = drone.hp / drone.maxHp;
        Px.frame(canvas, drone.x - barW / 2, top - 6, barW, 4, 0);
        Px.rect(canvas, drone.x - barW / 2 + 1, top - 5, (barW - 2) * ratio, 2, 8);
      }
    }
  }

  void _drawShells(Canvas canvas) {
    for (final Shell shell in engine.shells) {
      if (shell.homing) {
        sprRocket.draw(canvas, shell.x - 1.5, shell.y - 2.5);
      } else {
        Px.rect(canvas, shell.x - 1, shell.y - 3, 2, 6, 10);
        Px.px(canvas, shell.x, shell.y - 4, 7);
      }
    }
  }

  // --- HUD -----------------------------------------------------------------

  void _drawHud(Canvas canvas) {
    if (engine.scene == GameScene.title) {
      return;
    }

    _text(canvas, 'ОЧКИ ${engine.score}', 4, 3, 7, 7);
    _text(canvas, 'ВОЛНА ${engine.wave}', kWorldW - 4, 3, 7, 7, align: TextAlign.right);

    if (engine.combo > 1.2) {
      _text(canvas, 'КОМБО x${engine.combo.toStringAsFixed(1)}', 4, 12, 6, 10);
    }

    // Патроны: пипсы магазина.
    double ammoX = 4;
    for (int i = 0; i < engine.magSize; i++) {
      final bool loaded = i < engine.ammo;
      Px.rect(canvas, ammoX, 21, 2, 5, loaded ? 10 : 1);
      Px.frame(canvas, ammoX - 1, 20, 4, 7, 0);
      ammoX += 4;
    }
    if (engine.reloadTimer > 0) {
      _text(canvas, 'ПЕРЕЗАРЯДКА', ammoX + 4, 21, 6, 9);
    }

    // Шкала EMP.
    final double empRatio = engine.empCharge / engine.empNeeded;
    _text(canvas, 'EMP', 4, 30, 6, engine.empReady ? 7 : 11);
    Px.frame(canvas, 24, 30, 42, 5, 0);
    Px.rect(canvas, 25, 31, 40 * empRatio, 3, engine.empReady ? 3 : 13);

    for (final FloatText text in engine.texts) {
      double alpha = text.life * 2.0;
      if (alpha > 1) {
        alpha = 1;
      }
      _text(canvas, text.text, text.x, text.y, 6, text.color, align: TextAlign.center, alpha: alpha);
    }

    if (engine.waveBanner > 0) {
      final double alpha = engine.waveBanner > 1.6 ? (2.2 - engine.waveBanner) / 0.6 : 1.0;
      final double y = engine.worldH * 0.32;
      _text(canvas, 'ВОЛНА ${engine.wave}', kWorldW / 2 + 1, y + 1, 14, 0, align: TextAlign.center, alpha: alpha);
      _text(canvas, 'ВОЛНА ${engine.wave}', kWorldW / 2, y, 14, 10, align: TextAlign.center, alpha: alpha);
    }

    if (engine.paused) {
      _text(canvas, 'ПАУЗА', kWorldW / 2, engine.worldH * 0.4, 12, 7, align: TextAlign.center);
    }
  }

  void _text(
    Canvas canvas,
    String text,
    double vx,
    double vy,
    double fontSize,
    int color, {
    TextAlign align = TextAlign.left,
    double alpha = 1.0,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: P.alpha(color, alpha),
          fontSize: fontSize * transform.scale,
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: 0.5 * transform.scale,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    double x = transform.offsetX + vx * transform.scale;
    final double y = transform.offsetY + vy * transform.scale;
    if (align == TextAlign.center) {
      x -= painter.width / 2;
    } else if (align == TextAlign.right) {
      x -= painter.width;
    }
    painter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant PixelPainter oldDelegate) {
    return oldDelegate.engine != engine || oldDelegate.transform.scale != transform.scale;
  }
}
