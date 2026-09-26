import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_zenitchik/engine/drone.dart';
import 'package:pixel_zenitchik/engine/game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('новая игра запускает первую волну', () {
    final GameEngine engine = GameEngine();
    engine.newGame();
    expect(engine.scene, GameScene.playing);
    expect(engine.wave, 1);
    expect(engine.baseHp, 100);
    expect(engine.ammo, engine.magSize);
  });

  test('улучшение увеличивает урон', () {
    final GameEngine engine = GameEngine();
    engine.newGame();
    final double before = engine.shellDamage;
    engine.levels['damage'] = 2;
    expect(engine.shellDamage, greaterThan(before));
  });

  test('выстрел создаёт снаряд', () {
    final GameEngine engine = GameEngine();
    engine.newGame();
    engine.tapAt(90, 40);
    expect(engine.shells.isNotEmpty, isTrue);
    expect(engine.ammo, engine.magSize - 1);
  });

  test('долгий прогон не ломает состояние и спавнит дронов', () {
    final GameEngine engine = GameEngine();
    engine.newGame();
    for (int i = 0; i < 600; i++) {
      engine.update(1 / 60);
    }
    expect(engine.drones.isNotEmpty, isTrue);
    expect(engine.baseHp, lessThanOrEqualTo(100));
  });

  test('промахи не уменьшают прочность базы', () {
    final GameEngine engine = GameEngine();
    engine.newGame();
    for (int i = 0; i < 60; i++) {
      engine.tapAt(12, 20);
      engine.update(1 / 60);
    }
    expect(engine.baseHp, 100);
  });

  test('EMP доступен только при заполненной шкале', () {
    final GameEngine engine = GameEngine();
    engine.newGame();
    expect(engine.empReady, isFalse);
    engine.useEmp();
    expect(engine.empCharge, 0);
    engine.empCharge = engine.empNeeded;
    expect(engine.empReady, isTrue);
    engine.useEmp();
    expect(engine.empCharge, 0);
  });

  test('выбор улучшения возвращает игру в бой на новой волне', () {
    final GameEngine engine = GameEngine();
    engine.newGame();
    // Так выглядит состояние после успешно отбитой волны: номер уже увеличен,
    // ждём выбор улучшения.
    engine.wave = 2;
    engine.scene = GameScene.upgrade;
    engine.choices = engine.rollUpgrades();
    expect(engine.choices.length, 3);
    engine.chooseUpgrade(0);
    expect(engine.scene, GameScene.playing);
    expect(engine.wave, 2);
    expect(engine.ammo, engine.magSize);
  });

  test('специфика типов дронов растёт со временем', () {
    final int early = droneHpFor(DroneKind.armored, 1);
    final int late = droneHpFor(DroneKind.armored, 20);
    expect(late, greaterThan(early));
  });
}
