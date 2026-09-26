/// Улучшение, которое игрок выбирает между волнами.
class Upgrade {
  const Upgrade({
    required this.id,
    required this.title,
    required this.desc,
    required this.maxLevel,
  });

  final String id;
  final String title;
  final String desc;
  final int maxLevel;
}

/// Повторяемое улучшение-«затычка»: гарантирует, что выбор всегда есть.
const Upgrade kBonusUpgrade = Upgrade(
  id: 'bonus',
  title: 'Премия штаба',
  desc: '+500 очков сразу',
  maxLevel: 99,
);

/// Полный список улучшений (бесплатная версия — всё доступно без покупок).
const List<Upgrade> kUpgrades = <Upgrade>[
  Upgrade(id: 'damage', title: 'Усиленный заряд', desc: '+1 урон основного орудия', maxLevel: 6),
  Upgrade(id: 'firerate', title: 'Скорострельность', desc: 'Меньше пауза между выстрелами', maxLevel: 6),
  Upgrade(id: 'turn', title: 'Привод наведения', desc: 'Турель поворачивается быстрее', maxLevel: 5),
  Upgrade(id: 'crit', title: 'Критический узел', desc: '+7% шанса крита, крит — двойной урон', maxLevel: 7),
  Upgrade(id: 'splash', title: 'Осколочный снаряд', desc: 'Взрыв задевает соседние дроны', maxLevel: 5),
  Upgrade(id: 'mag', title: 'Ёмкость магазина', desc: '+2 снаряда в обойме', maxLevel: 5),
  Upgrade(id: 'reload', title: 'Быстрая перезарядка', desc: 'Обойма заполняется быстрее', maxLevel: 5),
  Upgrade(id: 'freeze', title: 'Криоснаряды', desc: 'Попадания замедляют дроны', maxLevel: 2),
  Upgrade(id: 'rockets', title: 'Ракетный залп', desc: 'Периодический залп самонаводящихся ракет', maxLevel: 4),
  Upgrade(id: 'drone', title: 'Дрон-перехватчик', desc: 'Автоматически бьёт по ближайшей цели', maxLevel: 4),
  Upgrade(id: 'empcore', title: 'Форсаж EMP', desc: 'EMP-импульс заряжается быстрее', maxLevel: 4),
  Upgrade(id: 'repair', title: 'Ремонт ядра', desc: '+25 прочности базы', maxLevel: 9),
  kBonusUpgrade,
];
