import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screenshots.dart';
import 'services/marks.dart';
import 'ui/kit.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Screenshots.seed();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..initialize(),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: 'Daily KJB',
            debugShowCheckedModeBanner: false,
            theme: Parchment.light.material,
            darkTheme: Parchment.lamplight.material,
            themeMode: provider.themeMode,
            home: const AppWrapper(),
          );
        },
      ),
    );
  }
}

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  @override
  void initState() {
    super.initState();
    Marks.i.load();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.parch;
    SystemChrome.setSystemUIOverlayStyle(
      p.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return Scaffold(
            backgroundColor: p.page,
            body: const Paper(child: SizedBox.expand()),
          );
        }
        final shot = Screenshots.scene;
        if (shot != null) return Screenshots.build(context, shot);
        if (provider.isFirstRun) return const OnboardingScreen();
        return const HomeScreen();
      },
    );
  }
}
