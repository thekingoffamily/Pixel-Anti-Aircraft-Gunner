import 'dart:math' as math;

import '../services/sfx.dart';
import 'constants.dart';
import 'drone.dart';
import 'effects.dart';
import 'signal.dart';
import 'upgrades.dart';

/// Игровые сцены (как SCENE_TITLE / SCENE_PLAY / SCENE_GAMEOVER в примере
/// Pyxel Shooter).
enum GameScene { title, playing, upgrade, gameOver }

/// Звезда на ночном небе.
class Star {
  Star(this.x, this.y, this.speed, this.color);

  double x;
  double y;
  final double speed;
  final int color;
}

/// Пиксельное облако.
class Cloud {
  Cloud(this.x, this.y, this.w, this.h, this.speed);

  double x;
  double y;
  final int w;
  final int h;
  final double speed;
}

/// Движок игры: состояние, логика волн, стрельба и урон.
///
/// Разделение сигналов:
///  * сам движок ([emit]) уведомляет каждый кадр — на нём висит перерисовка;
///  * [ui] уведомляет редко (смена сцены, рекорд) — на нём висят экраны меню.
class GameEngine extends Signal {
  GameEngine({this.bestScore = 0}) {
    _initBackground();
  }

  /// Вызывается, когда рекорд побит — виджет сохраняет его в память устройства.
  void Function(int score)? onBestChanged;

  final Signal ui = Signal();
  final math.Random _rnd = math.Random();

  /// Высота мира в виртуальных пикселях (задаётся из виджета по размеру экрана).
  double worldH = kWorldH;

  double time = 0;
  GameScene scene = GameScene.title;
  bool paused = false;
  int bestScore;

  /// Побит ли рекорд в текущей партии (для надписи «НОВЫЙ РЕКОРД!»).
  bool newRecord = false;

  int score = 0;
  int wave = 1;
  int kills = 0;
  double combo = 1.0;
  double comboTimer = 0;

  int baseMaxHp = 100;
  double baseHp = 100;

  int ammo = 6;
  double reloadTimer = 0;
  double fireTimer = 0;
  double empCharge = 0;

  double angle = -math.pi / 2;
  double aimX = kWorldW / 2;
  double aimY = 140;
  bool aiming = false;
  double muzzle = 0;
  double shake = 0;
  double waveBanner = 0;

  int _spawnLeft = 0;
  double _spawnTimer = 0;
  double _rocketTimer = 0;
  double _droneTimer = 0;
  bool _empReadyNotified = false;

  /// Уровни улучшений по идентификаторам из [kUpgrades].
  Map<String, int> levels = <String, int>{};

  /// Предложенные улучшения на экране выбора.
  List<Upgrade> choices = <Upgrade>[];

  final List<Drone> drones = <Drone>[];
  final List<Shell> shells = <Shell>[];
  final List<Blast> blasts = <Blast>[];
  final List<Particle> particles = <Particle>[];
  final List<FloatText> texts = <FloatText>[];
  final List<Star> stars = <Star>[];
  final List<Cloud> clouds = <Cloud>[];

  // --- Геометрия -----------------------------------------------------------

  double get groundY => worldH - 34;
  double get coreX => kWorldW / 2;
  double get coreY => groundY - 6;
  double get turretX => kWorldW / 2;
  double get turretY => groundY - 16;

  // --- Характеристики (зависят от выбранных улучшений) ---------------------

  int lvl(String id) => levels[id] ?? 0;

  double get shellDamage => 1.0 + lvl('damage') * 1.0;
  double get fireCooldown => math.max(0.14, 0.42 - lvl('firerate') * 0.05);
  double get turnSpeed => (200.0 + lvl('turn') * 70.0) * math.pi / 180.0;
  int get magSize => 6 + lvl('mag') * 2;
  double get reloadTime => math.max(0.5, 1.3 - lvl('reload') * 0.15);
  double get critChance => math.min(0.6, 0.05 + lvl('crit') * 0.07);
  double get splashRadius => lvl('splash') == 0 ? 0.0 : 2.5 + lvl('splash') * 1.2;
  bool get freezeShells => lvl('freeze') > 0;
  double get rocketInterval => lvl('rockets') == 0 ? 0.0 : math.max(3.5, 9.0 - lvl('rockets') * 1.5);
  double get droneInterval => lvl('drone') == 0 ? 0.0 : math.max(1.2, 3.5 - lvl('drone') * 0.6);
  double get empNeeded => math.max(12.0, 25.0 - lvl('empcore') * 3.0);

  bool get empReady => empCharge >= empNeeded;

  // --- Управление игрой ----------------------------------------------------

  /// Подогнать высоту мира под экран (вызывается из виджета).
  ///
  /// Высота обновляется всегда, чтобы мир не «съезжал» относительно рамки,
  /// а фон пересобирается только при заметном изменении пропорций.
  void resizeWorld(double height) {
    if (height <= 0 || height == worldH) {
      return;
    }
    final bool rebuildBackground = (height - worldH).abs() > 4.0;
    worldH = height;
    if (rebuildBackground) {
      _initBackground();
    }
  }

  void newGame() {
    score = 0;
    kills = 0;
    combo = 1.0;
    comboTimer = 0;
    newRecord = false;
    baseHp = baseMaxHp.toDouble();
    levels = <String, int>{};
    choices = <Upgrade>[];
    empCharge = 0;
    paused = false;
    shake = 0;
    muzzle = 0;
    waveBanner = 0;
    blasts.clear();
    particles.clear();
    texts.clear();
    scene = GameScene.playing;
    _startWave(1);
    ui.emit();
    emit();
  }

  void toTitle() {
    scene = GameScene.title;
    paused = false;
    shake = 0;
    muzzle = 0;
    waveBanner = 0;
    drones.clear();
    shells.clear();
    blasts.clear();
    particles.clear();
    texts.clear();
    ui.emit();
    emit();
  }

  void togglePause() {
    if (scene != GameScene.playing) {
      return;
    }
    paused = !paused;
    ui.emit();
  }

  /// Навести установку на точку (без выстрела).
  void setAim(double x, double y) {
    aimX = math.max(8.0, math.min(kWorldW - 8.0, x));
    final double maxY = turretY - 10.0;
    aimY = math.max(14.0, math.min(maxY, y));
    aiming = true;
  }

  /// Выстрел по точке касания.
  void tapAt(double x, double y) {
    if (scene != GameScene.playing || paused) {
      return;
    }
    setAim(x, y);
    fire();
  }

  void fire() {
    if (scene != GameScene.playing || paused) {
      return;
    }
    if (reloadTimer > 0 || fireTimer > 0) {
      return;
    }
    if (ammo <= 0) {
      reloadTimer = reloadTime;
      return;
    }
    ammo--;
    fireTimer = fireCooldown;

    final double a = math.atan2(aimY - turretY, aimX - turretX);
    final double startX = turretX + math.cos(a) * 13;
    final double startY = turretY + math.sin(a) * 13;
    final double dx = aimX - startX;
    final double dy = aimY - startY;
    final double length = math.max(1.0, math.sqrt(dx * dx + dy * dy));
    const double speed = 520.0;
    final bool crit = _rnd.nextDouble() < critChance;

    shells.add(Shell(
      x: startX,
      y: startY,
      vx: dx / length * speed,
      vy: dy / length * speed,
      damage: shellDamage * (crit ? 2.0 : 1.0),
      splash: splashRadius,
      freeze: freezeShells,
      crit: crit,
    ));

    muzzle = 0.07;
    Sfx.shoot();
  }

  void reloadNow() {
    if (scene != GameScene.playing || paused) {
      return;
    }
    if (reloadTimer > 0 || ammo >= magSize) {
      return;
    }
    reloadTimer = reloadTime;
    Sfx.ui();
  }

  /// Применить EMP-импульс (когда шкала заполнена).
  void useEmp() {
    if (scene != GameScene.playing || paused || !empReady) {
      return;
    }
    empCharge = 0;
    shake = 0.7;
    blasts.add(Blast(coreX, groundY - 70, 110, color: 3));
    blasts.add(Blast(coreX, groundY - 70, 80, color: 7, ring: true));
    for (final Drone drone in drones) {
      if (!drone.alive) {
        continue;
      }
      drone.stunTimer = 3.0;
      _damage(drone, 3.0, false);
    }
    Sfx.emp();
    ui.emit();
  }

  /// Выбрать улучшение на экране между волнами.
  void chooseUpgrade(int index) {
    if (scene != GameScene.upgrade || index < 0 || index >= choices.length) {
      return;
    }
    final Upgrade upgrade = choices[index];
    levels[upgrade.id] = lvl(upgrade.id) + 1;
    if (upgrade.id == 'bonus') {
      score += 500;
    }
    if (upgrade.id == 'repair') {
      baseHp = math.min(baseMaxHp.toDouble(), baseHp + 25);
    }
    choices = <Upgrade>[];
    scene = GameScene.playing;
    _startWave(wave);
    Sfx.ui();
    ui.emit();
    emit();
  }

  /// Список из трёх улучшений для выбора.
  List<Upgrade> rollUpgrades() {
    final List<Upgrade> pool = <Upgrade>[];
    for (final Upgrade upgrade in kUpgrades) {
      if (upgrade.id == 'repair' && baseHp >= baseMaxHp) {
        continue;
      }
      if (upgrade.id == 'bonus') {
        continue;
      }
      if (lvl(upgrade.id) >= upgrade.maxLevel) {
        continue;
      }
      pool.add(upgrade);
    }
    pool.shuffle(_rnd);
    final List<Upgrade> result = <Upgrade>[];
    for (final Upgrade upgrade in pool) {
      if (result.length >= 3) {
        break;
      }
      result.add(upgrade);
    }
    while (result.length < 3) {
      result.add(kBonusUpgrade);
    }
    return result;
  }

  // --- Основной цикл -------------------------------------------------------

  void update(double dt) {
    if (dt <= 0) {
      return;
    }
    time += dt;
    _updateBackground(dt);

    if (shake > 0) {
      shake = math.max(0.0, shake - dt * 2.5);
    }
    if (muzzle > 0) {
      muzzle = math.max(0.0, muzzle - dt);
    }

    for (int i = texts.length - 1; i >= 0; i--) {
      texts[i].update(dt);
      if (!texts[i].alive) {
        texts.removeAt(i);
      }
    }
    for (int i = particles.length - 1; i >= 0; i--) {
      particles[i].update(dt);
      if (!particles[i].alive) {
        particles.removeAt(i);
      }
    }
    for (int i = blasts.length - 1; i >= 0; i--) {
      blasts[i].update(dt);
      if (!blasts[i].alive) {
        blasts.removeAt(i);
      }
    }

    if (scene != GameScene.playing || paused) {
      emit();
      return;
    }

    if (waveBanner > 0) {
      waveBanner = math.max(0.0, waveBanner - dt);
    }
    if (comboTimer > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) {
        combo = 1.0;
      }
    }

    _updateTurret(dt);
    _updateAmmo(dt);
    _updateAbilities(dt);
    _updateSpawner(dt);
    _updateDrones(dt);
    // База могла быть уничтожена прямо в _updateDrones: тогда кадр боя
    // заканчивается, чтобы никто не «отбил волну» после проигрыша.
    if (scene != GameScene.playing) {
      emit();
      return;
    }
    _updateShells(dt);
    _checkWaveEnd();
    _syncEmpUi();

    emit();
  }

  /// Сообщить интерфейсу о готовности EMP (иначе кнопка не обновится,
  /// пока экран не перестроится по другой причине).
  void _syncEmpUi() {
    final bool ready = empReady;
    if (ready == _empReadyNotified) {
      return;
    }
    _empReadyNotified = ready;
    ui.emit();
  }

  void _updateBackground(double dt) {
    for (final Star star in stars) {
      star.y += star.speed * dt;
      if (star.y > groundY - 10) {
        star.y = -2;
        star.x = _rnd.nextDouble() * kWorldW;
      }
    }
    for (final Cloud cloud in clouds) {
      cloud.x -= cloud.speed * dt;
      if (cloud.x + cloud.w < -4) {
        cloud.x = kWorldW + 4;
        cloud.y = 12 + _rnd.nextDouble() * math.max(24.0, groundY - 90);
      }
    }
  }

  void _updateTurret(double dt) {
    if (fireTimer > 0) {
      fireTimer = math.max(0.0, fireTimer - dt);
    }
    if (!aiming) {
      return;
    }
    final double target = math.atan2(aimY - turretY, aimX - turretX);
    double diff = target - angle;
    while (diff > math.pi) {
      diff -= math.pi * 2;
    }
    while (diff < -math.pi) {
      diff += math.pi * 2;
    }
    final double maxStep = turnSpeed * dt;
    if (diff.abs() <= maxStep) {
      angle = target;
    } else {
      angle += maxStep * diff.sign;
    }
  }

  void _updateAmmo(double dt) {
    if (ammo <= 0 && reloadTimer <= 0) {
      reloadTimer = reloadTime;
    }
    if (reloadTimer > 0) {
      reloadTimer -= dt;
      if (reloadTimer <= 0) {
        reloadTimer = 0;
        ammo = magSize;
        Sfx.reload();
      }
    }
  }

  void _updateAbilities(double dt) {
    final double rockets = rocketInterval;
    if (rockets > 0) {
      _rocketTimer -= dt;
      if (_rocketTimer <= 0) {
        _rocketTimer = rockets;
        _fireRockets();
      }
    }
    final double interceptor = droneInterval;
    if (interceptor > 0) {
      _droneTimer -= dt;
      if (_droneTimer <= 0) {
        _droneTimer = interceptor;
        _fireInterceptor();
      }
    }
  }

  void _updateSpawner(double dt) {
    if (_spawnLeft <= 0) {
      return;
    }
    _spawnTimer -= dt;
    if (_spawnTimer > 0) {
      return;
    }
    _spawnTimer = math.max(0.34, 1.15 - wave * 0.05);
    _spawnLeft--;

    final List<DroneKind> kinds = _kindsFor(wave);
    final DroneKind kind = kinds[_rnd.nextInt(kinds.length)];
    if (kind == DroneKind.swarmer) {
      final int group = 2 + _rnd.nextInt(3);
      for (int i = 0; i < group; i++) {
        _spawnDrone(kind, x: 22 + _rnd.nextDouble() * (kWorldW - 44));
      }
    } else {
      _spawnDrone(kind);
    }
  }

  List<DroneKind> _kindsFor(int waveNumber) {
    final List<DroneKind> kinds = <DroneKind>[DroneKind.scout];
    if (waveNumber >= 2) {
      kinds.add(DroneKind.interceptor);
    }
    if (waveNumber >= 3) {
      kinds.add(DroneKind.swarmer);
    }
    if (waveNumber >= 4) {
      kinds.add(DroneKind.armored);
    }
    if (waveNumber >= 6) {
      kinds.add(DroneKind.cloaker);
    }
    return kinds;
  }

  void _updateDrones(double dt) {
    for (int i = drones.length - 1; i >= 0; i--) {
      final Drone drone = drones[i];
      drone.update(dt, coreX);
      if (!drone.alive) {
        drones.removeAt(i);
        continue;
      }

      if (drone.isBoss) {
        drone.spawnTimer -= dt;
        if (drone.spawnTimer <= 0) {
          drone.spawnTimer = 2.6;
          _spawnDrone(DroneKind.swarmer, x: drone.x, y: drone.y + 8);
        }
      }

      final bool hitBase = drone.y >= groundY - 6;
      final bool hitCore = (drone.x - coreX).abs() < 10 && drone.y >= coreY - 14;
      if (hitBase || hitCore) {
        drone.alive = false;
        drones.removeAt(i);
        _damageBase(drone);
        if (scene != GameScene.playing) {
          return;
        }
      }
    }
  }

  void _updateShells(double dt) {
    for (final Shell shell in shells) {
      if (!shell.alive) {
        continue;
      }
      final double previousX = shell.x;
      final double previousY = shell.y;
      shell.update(dt, drones);
      if (!shell.alive) {
        continue;
      }

      final double dx = shell.x - previousX;
      final double dy = shell.y - previousY;
      final double distance = math.sqrt(dx * dx + dy * dy);
      int steps = (distance / 2.0).ceil();
      if (steps < 1) {
        steps = 1;
      }

      bool hit = false;
      for (int step = 1; step <= steps && !hit; step++) {
        final double sampleX = previousX + dx * step / steps;
        final double sampleY = previousY + dy * step / steps;
        for (final Drone drone in drones) {
          if (!drone.alive) {
            continue;
          }
          final double halfW = drone.spec.w / 2 + 1.5;
          final double halfH = drone.spec.h / 2 + 1.5;
          if ((sampleX - drone.x).abs() <= halfW && (sampleY - drone.y).abs() <= halfH) {
            _hitDrone(shell, drone, sampleX, sampleY);
            hit = true;
            break;
          }
        }
      }
    }
    for (int i = shells.length - 1; i >= 0; i--) {
      if (!shells[i].alive) {
        shells.removeAt(i);
      }
    }
  }

  void _hitDrone(Shell shell, Drone drone, double x, double y) {
    shell.alive = false;
    if (shell.freeze) {
      drone.slowTimer = 1.8;
    }
    _damage(drone, shell.damage, shell.crit);

    if (shell.splash > 0) {
      blasts.add(Blast(x, y, 4 + shell.splash * 1.6, color: 9));
      for (final Drone other in drones) {
        if (!other.alive || other == drone) {
          continue;
        }
        final double ddx = other.x - x;
        final double ddy = other.y - y;
        if (ddx * ddx + ddy * ddy <= shell.splash * shell.splash) {
          _damage(other, shell.damage * 0.6, false);
        }
      }
    } else {
      blasts.add(Blast(x, y, 4, color: 10));
    }

    for (int i = 0; i < 4; i++) {
      final double a = _rnd.nextDouble() * math.pi * 2;
      final double sp = 20 + _rnd.nextDouble() * 30;
      particles.add(Particle(x, y, math.cos(a) * sp, math.sin(a) * sp, 10, 0.2));
    }
    Sfx.hit();
  }

  void _damage(Drone drone, double damage, bool crit) {
    if (!drone.alive) {
      return;
    }
    drone.hp -= damage.round();
    drone.hitTimer = 0.09;
    if (drone.hp <= 0) {
      _killDrone(drone, crit);
    }
  }

  void _killDrone(Drone drone, bool crit) {
    drone.alive = false;
    kills++;
    empCharge = math.min(empNeeded, empCharge + 1);
    _addScore(drone.spec.points, drone.x, drone.y, crit);
    _explode(drone.x, drone.y, drone.spec.w * 0.9);
    if (drone.isBoss) {
      shake = 0.8;
      _explode(drone.x, drone.y, 18);
      Sfx.baseHit();
    } else {
      Sfx.explode();
    }
  }

  void _addScore(int points, double x, double y, bool crit) {
    combo = math.min(5.0, combo + 0.25);
    comboTimer = 2.4;
    final int gained = (points * combo * (crit ? 2 : 1)).round();
    score += gained;
    texts.add(FloatText(x, y - 6, '+$gained', crit ? 10 : 7));
  }

  void _explode(double x, double y, double radius) {
    final double outer = math.max(5.0, radius);
    blasts.add(Blast(x, y, outer, color: 10));
    blasts.add(Blast(x, y, outer * 0.7, color: 9, ring: true));
    for (int i = 0; i < 8; i++) {
      final double a = _rnd.nextDouble() * math.pi * 2;
      final double speed = 18 + _rnd.nextDouble() * 45;
      particles.add(Particle(
        x,
        y,
        math.cos(a) * speed,
        math.sin(a) * speed,
        i % 2 == 0 ? 10 : 9,
        0.25 + _rnd.nextDouble() * 0.35,
      ));
    }
  }

  void _damageBase(Drone drone) {
    baseHp -= drone.spec.damage;
    shake = 0.6;
    _explode(drone.x, math.min(drone.y, groundY), 10);
    Sfx.baseHit();
    if (baseHp <= 0) {
      baseHp = 0;
      _gameOver();
    } else {
      texts.add(FloatText(coreX, groundY - 30, '-${drone.spec.damage}', 8));
    }
  }

  void _gameOver() {
    if (scene != GameScene.playing) {
      return;
    }
    scene = GameScene.gameOver;
    paused = false;
    newRecord = score > bestScore;
    if (newRecord) {
      bestScore = score;
      final void Function(int score)? callback = onBestChanged;
      if (callback != null) {
        callback(score);
      }
    }
    _explode(coreX, coreY, 24);
    Sfx.gameOver();
    ui.emit();
  }

  // --- Волны ---------------------------------------------------------------

  void _startWave(int waveNumber) {
    wave = waveNumber;
    waveBanner = 2.2;
    _spawnLeft = math.min(40, 5 + waveNumber * 2);
    _spawnTimer = 1.0;
    _rocketTimer = rocketInterval;
    _droneTimer = droneInterval;
    drones.clear();
    shells.clear();
    particles.clear();
    ammo = magSize;
    reloadTimer = 0;
    fireTimer = 0;
    baseHp = math.min(baseMaxHp.toDouble(), baseHp + 5);
    if (waveNumber % 5 == 0) {
      _spawnDrone(DroneKind.mothership);
    }
  }

  void _checkWaveEnd() {
    // Волна не может завершиться, если бой уже проигран.
    if (scene != GameScene.playing) {
      return;
    }
    if (_spawnLeft > 0 || drones.isNotEmpty) {
      return;
    }
    _completeWave();
  }

  void _completeWave() {
    if (scene != GameScene.playing) {
      return;
    }
    wave++;
    scene = GameScene.upgrade;
    choices = rollUpgrades();
    Sfx.wave();
    ui.emit();
  }

  void _spawnDrone(DroneKind kind, {double? x, double? y}) {
    final double spawnX = x ?? (14 + _rnd.nextDouble() * (kWorldW - 28));
    final double spawnY = y ?? -12;
    drones.add(Drone(
      kind,
      spawnX,
      spawnY,
      hp: droneHpFor(kind, wave),
      vx: kind == DroneKind.mothership ? 16 : 0,
    ));
  }

  void _fireRockets() {
    final List<Drone> targets = _nearestDrones(3);
    if (targets.isEmpty) {
      return;
    }
    for (final Drone target in targets) {
      final double a = math.atan2(target.y - turretY, target.x - turretX);
      shells.add(Shell(
        x: turretX + math.cos(a) * 10,
        y: turretY + math.sin(a) * 10,
        vx: math.cos(a) * 110,
        vy: math.sin(a) * 110,
        damage: 2.0,
        homing: true,
        color: 9,
        radius: 3.0,
      ));
    }
  }

  void _fireInterceptor() {
    final List<Drone> targets = _nearestDrones(1);
    if (targets.isEmpty) {
      return;
    }
    final Drone target = targets.first;
    final double a = math.atan2(target.y - turretY, target.x - turretX);
    shells.add(Shell(
      x: turretX + math.cos(a) * 8,
      y: turretY + math.sin(a) * 8,
      vx: math.cos(a) * 150,
      vy: math.sin(a) * 150,
      damage: 1.5,
      homing: true,
      color: 6,
      radius: 2.0,
    ));
  }

  List<Drone> _nearestDrones(int count) {
    final List<Drone> alive = <Drone>[for (final Drone drone in drones) if (drone.alive) drone];
    alive.sort((Drone a, Drone b) {
      final double da = (a.x - turretX) * (a.x - turretX) + (a.y - turretY) * (a.y - turretY);
      final double db = (b.x - turretX) * (b.x - turretX) + (b.y - turretY) * (b.y - turretY);
      return da.compareTo(db);
    });
    if (alive.length > count) {
      return alive.sublist(0, count);
    }
    return alive;
  }

  // --- Фон -----------------------------------------------------------------

  void _initBackground() {
    stars.clear();
    clouds.clear();
    final int starCount = 70;
    for (int i = 0; i < starCount; i++) {
      stars.add(Star(
        _rnd.nextDouble() * kWorldW,
        _rnd.nextDouble() * math.max(20.0, groundY - 40),
        2 + _rnd.nextDouble() * 6,
        _rnd.nextDouble() > 0.8 ? 7 : 6,
      ));
    }
    for (int i = 0; i < 5; i++) {
      clouds.add(Cloud(
        _rnd.nextDouble() * kWorldW,
        16 + _rnd.nextDouble() * math.max(24.0, groundY - 100),
        14 + _rnd.nextInt(12),
        5 + _rnd.nextInt(5),
        3 + _rnd.nextDouble() * 4,
      ));
    }
  }
}
