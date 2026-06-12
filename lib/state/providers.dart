import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:gercorridas/data/database/app_database.dart';
import 'package:gercorridas/data/models/counter.dart';
import 'package:gercorridas/data/models/category.dart' as model;
import 'package:gercorridas/data/repositories/corrida_repository.dart';
import 'package:gercorridas/data/repositories/category_repository.dart';
import 'package:gercorridas/data/services/backup_service.dart';
export 'cloud_providers.dart';
export 'premium_provider.dart';

// Database
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

// Repositories
final corridaRepositoryProvider = Provider<CorridaRepository>((ref) => CorridaRepository(ref.read(databaseProvider)));
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) => CategoryRepository(ref.read(databaseProvider)));
final backupServiceProvider = Provider<BackupService>((ref) => BackupServiceImpl(ref.read(databaseProvider)));

// Streams of data
final corridasProvider = StreamProvider<List<Counter>>((ref) => ref.watch(corridaRepositoryProvider).watchAll());
final categoriesProvider = StreamProvider<List<model.Category>>((ref) => ref.watch(categoryRepositoryProvider).watchAll());

// Versão do aplicativo para exibir no rodapé do menu lateral
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return 'v${info.version} (build ${info.buildNumber})';
});

// Theme Mode Provider com persistência
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  static const _key = 'theme_mode';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt(_key);
      if (index != null && index < ThemeMode.values.length) {
        state = ThemeMode.values[index];
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, mode.index);
    } catch (_) {}
  }

  void toggleTheme() {
    if (state == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }
}
