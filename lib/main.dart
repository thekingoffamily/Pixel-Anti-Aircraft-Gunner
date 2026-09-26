import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/sfx.dart';
import 'ui/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Прогреваем пул звуковых эффектов заранее, чтобы выстрелы не запаздывали.
  Sfx.init();

  // Игра задумана вертикальной и занимает весь экран.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const PixelZenitchikApp());
}

/// «Пиксельный Зенитчик» — пиксельная аркада для Android.
class PixelZenitchikApp extends StatelessWidget {
  const PixelZenitchikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Пиксельный Зенитчик',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF19959C),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF000000),
      ),
      home: const GameScreen(),
    );
  }
}
