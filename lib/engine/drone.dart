import 'dart:math' as math;

import 'constants.dart';
import 'sprites.dart';

/// Типы противников (см. таблицу в README).
enum DroneKind { scout, interceptor, armored, swarmer, cloaker, mothership }

/// Характеристики типа дрона.
class DroneSpec {
  const DroneSpec({
    required this.w,
    required this.h,
    required this.hp,
    required this.speed,
    required this.points,
    required this.damage,
    required this.title,
    required this.sprite,
  });

  final int w;
  final int h;
  final int hp;
  final double speed;
  final int points;
  final int damage;
  final String title;
  final Sprite sprite;
}

/// Таблица типов. Скорости — в виртуальных пикселях в секунду.
final Map<DroneKind, DroneSpec> kDroneSpecs = <DroneKind, DroneSpec>{
  DroneKind.scout: DroneSpec(
    w: sprScout.w,
    h: sprScout.h,
    hp: 1,
    speed: 30,
    points: 10,
    damage: 6,
    title: 'Разведчик',
    sprite: sprScout,
  ),
  DroneKind.interceptor: DroneSpec(
    w: sprInterceptor.w,
    h: sprInterceptor.h,
    hp: 1,
    speed: 54,
    points: 20,
    damage: 8,
    title: 'Перехватчик',
    sprite: sprInterceptor,
  ),
  DroneKind.armored: DroneSpec(
    w: sprArmored.w,
    h: sprArmored.h,
    hp: 3,
    speed: 20,
    points: 30,
    damage: 14,
    title: 'Бронированный дрон',
    sprite: sprArmored,
  ),
  DroneKind.swarmer: DroneSpec(
    w: sprSwarmer.w,
    h: sprSwarmer.h,
    hp: 1,
    speed: 40,
    points: 15,
    damage: 4,
    title: 'Дрон-роевик',
    sprite: sprSwarmer,
  ),
  DroneKind.cloaker: DroneSpec(
    w: sprCloaker.w,
    h: sprCloaker.h,
    hp: 2,
    speed: 28,
    points: 25,
    damage: 10,
    title: 'Маскировщик',
    sprite: sprCloaker,
  ),
  DroneKind.mothership: DroneSpec(
    w: sprMothership.w,
    h: sprMothership.h,
    hp: 20,
    speed: 18,
    points: 250,
    damage: 40,
    title: 'Дрон-матка',
    sprite: sprMothership,
  ),
};

DroneSpec specOf(DroneKind kind) => kDroneSpecs[kind]!;

/// Прочность дрона с учётом номера волны (сложность растёт постепенно).
int droneHpFor(DroneKind kind, int wave) {
  final int base = specOf(kind).hp;
  if (kind == DroneKind.scout) {
    return base + wave ~/ 7;
  }
  if (kind == DroneKind.interceptor) {
    return base + wave ~/ 9;
  }
  if (kind == DroneKind.armored) {
    return base + wave ~/ 4;
  }
  if (kind == DroneKind.swarmer) {
    return base + wave ~/ 8;
  }
  if (kind == DroneKind.cloaker) {
    return base + wave ~/ 6;
  }
  return base + wave * 4;
}

/// Живой дрон на экране.
class Drone {
  Drone(this.kind, this.x, this.y, {required this.hp, this.vx = 0}) : maxHp = hp;

  final DroneKind kind;
  double x;
  double y;
  double vx;
  int hp;
  final int maxHp;
  double phase = 0;
  double stunTimer = 0;
  double slowTimer = 0;
  double hitTimer = 0;
  double cloak = 1.0;
  double spawnTimer = 2.4;
  bool alive = true;

  DroneSpec get spec => specOf(kind);

  bool get isBoss => kind == DroneKind.mothership;

  void update(double dt, double coreX) {
    if (!alive) {
      return;
    }
    if (hitTimer > 0) {
      hitTimer = math.max(0.0, hitTimer - dt);
    }
    if (stunTimer > 0) {
      stunTimer = math.max(0.0, stunTimer - dt);
      return;
    }
    phase += dt;

    double speed = spec.speed;
    if (slowTimer > 0) {
      slowTimer = math.max(0.0, slowTimer - dt);
      speed *= 0.45;
    }

    if (kind == DroneKind.scout) {
      x += math.sin(phase * 2.1) * 14 * dt;
      y += speed * dt;
    } else if (kind == DroneKind.interceptor) {
      x += math.sin(phase * 4.4) * 62 * dt;
      y += speed * dt;
    } else if (kind == DroneKind.armored) {
      y += speed * dt;
    } else if (kind == DroneKind.swarmer) {
      x += (coreX - x).sign * 10 * dt;
      y += speed * dt;
    } else if (kind == DroneKind.cloaker) {
      cloak = 0.2 + 0.8 * (0.5 + 0.5 * math.sin(phase * 1.5));
      x += math.sin(phase * 1.1) * 16 * dt;
      y += speed * dt;
    } else {
      // Дрон-матка: снижается, затем ходит над базой и медленно давит вниз.
      if (y < 62) {
        y += speed * dt;
      } else {
        if (vx == 0) {
          vx = 16;
        }
        x += vx * dt;
        if (x < 32) {
          x = 32;
          vx = vx.abs();
        }
        if (x > kWorldW - 32) {
          x = kWorldW - 32;
          vx = -vx.abs();
        }
        y += 2.5 * dt;
      }
    }

    if (x < 8) {
      x = 8;
    }
    if (x > kWorldW - 8) {
      x = kWorldW - 8;
    }
  }
}
