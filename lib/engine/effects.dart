import 'dart:math' as math;

import 'constants.dart';
import 'drone.dart';

/// Снаряд (обычный, криоснаряд, ракета с самонаведением).
class Shell {
  Shell({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.damage,
    this.splash = 0,
    this.freeze = false,
    this.crit = false,
    this.homing = false,
    this.color = 10,
    this.radius = 2.0,
  });

  double x;
  double y;
  double vx;
  double vy;
  double damage;
  double splash;
  bool freeze;
  bool crit;
  bool homing;
  int color;
  double radius;
  double life = 2.6;
  bool alive = true;

  void update(double dt, List<Drone> targets) {
    if (!alive) {
      return;
    }
    life -= dt;
    if (life <= 0) {
      alive = false;
      return;
    }

    if (homing) {
      Drone? target;
      double bestDistance = 1e9;
      for (final Drone drone in targets) {
        if (!drone.alive) {
          continue;
        }
        final double dx = drone.x - x;
        final double dy = drone.y - y;
        final double distance = math.sqrt(dx * dx + dy * dy);
        if (distance < bestDistance) {
          bestDistance = distance;
          target = drone;
        }
      }
      if (target != null) {
        final double dx = target.x - x;
        final double dy = target.y - y;
        final double distance = math.max(1.0, math.sqrt(dx * dx + dy * dy));
        final double speed = math.max(1.0, math.sqrt(vx * vx + vy * vy));
        final double desiredX = dx / distance * speed;
        final double desiredY = dy / distance * speed;
        final double k = math.min(1.0, dt * 7.0);
        vx += (desiredX - vx) * k;
        vy += (desiredY - vy) * k;
      }
    }

    x += vx * dt;
    y += vy * dt;

    if (x < -8 || x > kWorldW + 8 || y < -10 || y > kMaxWorldH + 20) {
      alive = false;
    }
  }
}

/// Взрыв: расширяющееся кольцо (как pyxel.circ/circb в примере shooter).
class Blast {
  Blast(this.x, this.y, this.maxRadius, {this.color = 10, this.ring = false, this.thickness = 2.0});

  double x;
  double y;
  double radius = 1.0;
  final double maxRadius;
  final int color;
  final bool ring;
  final double thickness;
  bool alive = true;

  void update(double dt) {
    radius += dt * (maxRadius * 4.0 + 8.0);
    if (radius >= maxRadius) {
      alive = false;
    }
  }
}

/// Осколок / искра.
class Particle {
  Particle(this.x, this.y, this.vx, this.vy, this.color, this.life);

  double x;
  double y;
  double vx;
  double vy;
  double life;
  final int color;
  bool alive = true;

  void update(double dt) {
    life -= dt;
    if (life <= 0) {
      alive = false;
      return;
    }
    x += vx * dt;
    y += vy * dt;
    vy += 70 * dt;
  }
}

/// Всплывающий текст (очки за попадание, подсказки).
class FloatText {
  FloatText(this.x, this.y, this.text, this.color);

  final double x;
  double y;
  final String text;
  final int color;
  double life = 0.9;
  bool alive = true;

  void update(double dt) {
    life -= dt;
    if (life <= 0) {
      alive = false;
      return;
    }
    y -= 16 * dt;
  }
}
