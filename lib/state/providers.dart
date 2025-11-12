import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:gercorridas/data/database/app_database.dart';
import 'package:gercorridas/data/models/counter.dart';
import 'package:gercorridas/data/models/category.dart' as model;
import 'package:gercorridas/data/repositories/corrida_repository.dart';
import 'package:gercorridas/data/repositories/category_repository.dart';
import 'package:gercorridas/data/services/backup_service.dart';
export 'cloud_providers.dart';

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
