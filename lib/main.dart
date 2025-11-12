import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'presentation/navigation/app_router.dart';
import 'presentation/widgets/app_lifecycle_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: GerCorridasApp()));
}

class GerCorridasApp extends StatelessWidget {
  const GerCorridasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLifecycleSync(
      child: MaterialApp.router(
        title: 'GerCorridas',
        theme: AppTheme.light(),
        // darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: AppRouter.router,
      ),
    );
  }
}
