import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:presensia/theme/app_theme.dart';
import 'package:presensia/view/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static _MyAppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ThemeScope>();
    assert(scope != null, 'No _ThemeScope found in context');
    return scope!.state;
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const String _darkModeKey = 'is_dark_mode';
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool(_darkModeKey) ?? false;
    if (!mounted) return;
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> toggleThemeMode() async {
    final nextMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    setState(() {
      _themeMode = nextMode;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, nextMode == ThemeMode.dark);
  }

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return _ThemeScope(
      state: this,
      child: MaterialApp(
        title: 'Presensia',
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7BEF),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: AppPalette.light().background,
          cardColor: AppPalette.light().surface,
          dividerColor: AppPalette.light().border,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            foregroundColor: Color(0xFF20232B),
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7BEF),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: AppPalette.dark().background,
          cardColor: AppPalette.dark().surface,
          dividerColor: AppPalette.dark().border,
          canvasColor: AppPalette.dark().background,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            foregroundColor: Color(0xFFF4F8FF),
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

class _ThemeScope extends InheritedWidget {
  const _ThemeScope({required this.state, required super.child});

  final _MyAppState state;

  @override
  bool updateShouldNotify(_ThemeScope oldWidget) {
    return oldWidget.state._themeMode != state._themeMode;
  }
}

