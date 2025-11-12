 import 'package:gercorridas/data/database/app_database.dart';
 import 'package:gercorridas/data/models/counter.dart';
import 'package:drift/drift.dart';

class CorridaRepository {
  final AppDatabase db;
  CorridaRepository(this.db);

  Counter _mapRow(CounterRow r) => Counter(
        id: r.id,
        name: r.name,
        description: r.description,
        // Converte para local primeiro (se vier em UTC do banco) e então
        // reconstrói como horário local "ingênuo" a partir dos componentes.
        eventDate: (() {
          final ev = r.eventDate.isUtc ? r.eventDate.toLocal() : r.eventDate;
          return DateTime(
            ev.year,
            ev.month,
            ev.day,
            ev.hour,
            ev.minute,
            ev.second,
            ev.millisecond,
            ev.microsecond,
          );
        })(),
        category: r.category,
        status: r.status,
        distanceKm: r.distanceKm,
        price: r.price,
        registrationUrl: r.registrationUrl,
        finishTime: r.finishTime,
        createdAt: (() {
          final ca = r.createdAt.isUtc ? r.createdAt.toLocal() : r.createdAt;
          return DateTime(
            ca.year,
            ca.month,
            ca.day,
            ca.hour,
            ca.minute,
            ca.second,
            ca.millisecond,
            ca.microsecond,
          );
        })(),
        updatedAt: r.updatedAt == null
            ? null
            : (() {
                final up = r.updatedAt!.isUtc ? r.updatedAt!.toLocal() : r.updatedAt!;
                return DateTime(
                  up.year,
                  up.month,
                  up.day,
                  up.hour,
                  up.minute,
                  up.second,
                  up.millisecond,
                  up.microsecond,
                );
              })(),
      );

  CountersCompanion _toCompanion(Counter c) => CountersCompanion(
        id: c.id != null ? Value(c.id!) : const Value.absent(),
        name: Value(c.name),
        description: Value(c.description),
        // Persiste como hora local (parede) para manter semântica do usuário
        eventDate: Value(c.eventDate),
        category: Value(c.category),
        status: Value(c.status),
        distanceKm: Value(c.distanceKm),
        price: Value(c.price),
        registrationUrl: Value(c.registrationUrl),
        finishTime: Value(c.finishTime),
        createdAt: Value(c.createdAt),
        updatedAt: Value(c.updatedAt),
      );

  Future<int> create(Counter c) => db.insertCounter(_toCompanion(c));
  Future<List<Counter>> all() async => (await db.getAllCounters()).map(_mapRow).toList();
  Future<Counter?> byId(int id) async {
    final r = await db.getCounterById(id);
    return r == null ? null : _mapRow(r);
  }

  Future<bool> update(Counter c) => db.updateCounter(_toCompanion(c));
  Future<int> delete(int id) => db.deleteCounter(id);

  Stream<List<Counter>> watchAll() => db.watchAllCounters().map((rows) => rows.map(_mapRow).toList());

  // Removido suporte a histórico: operações usam apenas create/update diretos
}
