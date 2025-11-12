import 'package:drift/drift.dart';
import 'connection/open_connection.dart';
import 'connection/open_test_connection.dart';

part 'app_database.g.dart';

@DataClassName('CounterRow')
class Counters extends Table {
  @override
  String get tableName => 'corridas';
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get eventDate => dateTime()();
  TextColumn get category => text().nullable()();
  // Campos específicos de corridas
  // Status da corrida (ex.: pretendo_ir, inscrito, concluida, cancelada, nao_pude_ir, na_duvida)
  TextColumn get status => text()();
  // Distância da corrida em quilômetros
  RealColumn get distanceKm => real()();
  // Preço pago ou previsto (R$)
  RealColumn get price => real().nullable()();
  // URL de inscrição (opcional)
  TextColumn get registrationUrl => text().nullable()();
  // Tempo de conclusão no formato HH:mm:ss (opcional)
  TextColumn get finishTime => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

@DataClassName('CategoryRow')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get normalized => text()();
}

LazyDatabase _openConnection() => openConnection();

@DriftDatabase(tables: [Counters, Categories])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.test() : super(openTestConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // Garante que chaves estrangeiras estejam ativadas (necessário para CASCADE funcionar)
          await customStatement('PRAGMA foreign_keys = ON');
        },
        onCreate: (m) async {
          // Projeto novo: cria todas as tabelas definidas sem afetar sistemas existentes
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // Não alterar esquemas de sistemas anteriores. Apenas garante que
          // as novas tabelas existam, caso o banco tenha sido criado sem elas.
          final hasCorridas = await customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='corridas'",
          ).get();
          if (hasCorridas.isEmpty) {
            await m.createTable(counters);
          }

          // Migração para v4: remover coluna 'recurrence' da tabela corridas
          if (from < 4) {
            // Verifica se a coluna existe no banco atual
            final cols = await customSelect("PRAGMA table_info('corridas')").get();
            final hasRecurrenceColumn = cols.any((row) {
              final data = row.data;
              final name = data['name'] as String?;
              return name == 'recurrence';
            });
            if (hasRecurrenceColumn) {
              // Renomeia a tabela antiga, recria a nova sem 'recurrence' e copia os dados
              await customStatement('ALTER TABLE corridas RENAME TO corridas_old');
              await m.createTable(counters);
              await customStatement(
                'INSERT INTO corridas (id, name, description, event_date, category, status, distance_km, price, registration_url, finish_time, created_at, updated_at) '
                'SELECT id, name, description, event_date, category, status, distance_km, price, registration_url, finish_time, created_at, updated_at FROM corridas_old',
              );
              await customStatement('DROP TABLE corridas_old');
            }
          }
          // Migração para v5: remover tabela 'counter_history'
          if (from < 5) {
            // Se existir, dropar a tabela de histórico
            final hasHistory = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='counter_history'",
            ).get();
            if (hasHistory.isNotEmpty) {
              await customStatement('DROP TABLE counter_history');
            }
          }

          final hasCategories = await customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='categories'",
          ).get();
          if (hasCategories.isEmpty) {
            await m.createTable(categories);
          }
        },
      );

  // CRUD básico para Counters
  Future<int> insertCounter(CountersCompanion entry) => into(counters).insert(entry);
  Future<List<CounterRow>> getAllCounters() => select(counters).get();
  Future<CounterRow?> getCounterById(int id) => (select(counters)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<bool> updateCounter(CountersCompanion entry) => update(counters).replace(entry);
  Future<int> deleteCounter(int id) => (delete(counters)..where((t) => t.id.equals(id))).go();
  Future<int> countCountersByCategoryName(String name) async {
    final rows = await (select(counters)..where((t) => t.category.equals(name))).get();
    return rows.length;
  }
  Stream<List<CounterRow>> watchAllCounters() => select(counters).watch();
  Future<void> upsertCounterRaw({
    required int id,
    required String name,
    String? description,
    required DateTime eventDate,
    String? category,
    required String status,
    required double distanceKm,
    double? price,
    String? registrationUrl,
    String? finishTime,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) async {
    await into(counters).insertOnConflictUpdate(CountersCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      eventDate: Value(eventDate),
      category: Value(category),
      status: Value(status),
      distanceKm: Value(distanceKm),
      price: Value(price),
      registrationUrl: Value(registrationUrl),
      finishTime: Value(finishTime),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    ));
  }

  // CRUD básico para Categories
  Future<int> insertCategory(CategoriesCompanion entry) => into(categories).insert(entry);
  Future<List<CategoryRow>> getAllCategories() => select(categories).get();
  Future<CategoryRow?> getCategoryById(int id) => (select(categories)..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<CategoryRow?> getCategoryByNormalized(String normalized) =>
      (select(categories)..where((t) => t.normalized.equals(normalized))).getSingleOrNull();
  Future<bool> updateCategory(CategoriesCompanion entry) => update(categories).replace(entry);
  Future<int> deleteCategory(int id) => (delete(categories)..where((t) => t.id.equals(id))).go();
  Stream<List<CategoryRow>> watchAllCategories() => select(categories).watch();
  Future<void> upsertCategoryRaw({
    required int id,
    required String name,
    required String normalized,
  }) async {
    await into(categories).insertOnConflictUpdate(CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      normalized: Value(normalized),
    ));
  }
}