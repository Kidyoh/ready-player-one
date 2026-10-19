import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'app_state.dart';
import 'screens/home_shell.dart';
import 'screens/title_screen.dart';
import 'theme.dart';
import 'widgets/desert.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(Api())..boot(),
      child: const LifeRpgApp(),
    ),
  );
}

class LifeRpgApp extends StatelessWidget {
  const LifeRpgApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'Life RPG',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: state.booting
          ? const DesertBackground(child: Center(child: CircularProgressIndicator(color: Colors.white)))
          : state.signedIn
              ? const HomeShell()
              : const TitleScreen(),
    );
  }
}
