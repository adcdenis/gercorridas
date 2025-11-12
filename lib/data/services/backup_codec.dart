import 'dart:convert';

import 'package:gercorridas/data/database/app_database.dart';

/// Utilitário para serializar e restaurar dados de backup sem depender de IO.
class BackupCodec {
  static DateTime _dateFromJson(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (v is String) return DateTime.parse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    throw ArgumentError('Unsupported date value: $v');
  }
  // Histórico removido do backup: não há cálculo de órfãos ou filtros
  /// Gera um Map pronto para JSON contendo todas as entidades.
  static Future<Map<String, dynamic>> encode(AppDatabase db) async {
    final counters = await db.getAllCounters();
    final categories = await db.getAllCategories();
    return {
      'version': 1,
      'counters': counters.map((c) => c.toJson()).toList(),
      'categories': categories.map((c) => c.toJson()).toList(),
    };
  }

  /// Valida a estrutura e tipos do JSON de backup.
  /// Retorna uma lista de mensagens de erro; vazia se válido.
  static List<String> validate(Map<String, dynamic> data) {
    final errors = <String>[];

    void requireKey<T>(String key, bool Function(dynamic) typeCheck, {String? ctx}) {
      if (!data.containsKey(key)) {
        errors.add('[${ctx ?? 'root'}] chave obrigatória ausente: $key');
        return;
      }
      final v = data[key];
      if (!typeCheck(v)) {
        errors.add('[${ctx ?? 'root'}] tipo inválido para $key: ${v.runtimeType}');
      }
    }

    requireKey<int>('version', (v) => v is int);
    requireKey<List>('counters', (v) => v is List);
    requireKey<List>('categories', (v) => v is List);
    // Histórico não é mais suportado

    // Counters
    final counters = (data['counters'] as List<dynamic>? ?? []);
    final counterIds = <int>{};
    for (var i = 0; i < counters.length; i++) {
      final m = counters[i];
      if (m is! Map<String, dynamic>) {
        errors.add('[counters[$i]] não é um objeto');
        continue;
      }
      if (m['id'] is! num) {
        errors.add('[counters[$i]] id obrigatorio (num)');
      } else {
        counterIds.add((m['id'] as num).toInt());
      }
      if (m['name'] is! String) errors.add('[counters[$i]] name obrigatorio (string)');
      if (m['description'] != null && m['description'] is! String) errors.add('[counters[$i]] description opcional (string)');
      if (m['eventDate'] == null) {
        errors.add('[counters[$i]] eventDate obrigatorio');
      } else {
        try { _dateFromJson(m['eventDate']); } catch (_) { errors.add('[counters[$i]] eventDate inválido'); }
      }
      if (m['category'] != null && m['category'] is! String) errors.add('[counters[$i]] category opcional (string)');
      // Campos de corridas (todos opcionais para manter retrocompatibilidade)
      if (m['status'] != null && m['status'] is! String) errors.add('[counters[$i]] status opcional (string)');
      if (m['distanceKm'] != null && m['distanceKm'] is! num) errors.add('[counters[$i]] distanceKm opcional (num)');
      if (m['price'] != null && m['price'] is! num) errors.add('[counters[$i]] price opcional (num)');
      if (m['registrationUrl'] != null && m['registrationUrl'] is! String) errors.add('[counters[$i]] registrationUrl opcional (string)');
      if (m['finishTime'] != null && m['finishTime'] is! String) errors.add('[counters[$i]] finishTime opcional (string HH:mm:ss)');
      if (m['createdAt'] == null) {
        errors.add('[counters[$i]] createdAt obrigatorio');
      } else {
        try { _dateFromJson(m['createdAt']); } catch (_) { errors.add('[counters[$i]] createdAt inválido'); }
      }
      if (m['updatedAt'] != null) {
        try { _dateFromJson(m['updatedAt']); } catch (_) { errors.add('[counters[$i]] updatedAt inválido'); }
      }
    }

    // Categories
    final categories = (data['categories'] as List<dynamic>? ?? []);
    for (var i = 0; i < categories.length; i++) {
      final m = categories[i];
      if (m is! Map<String, dynamic>) { errors.add('[categories[$i]] não é um objeto'); continue; }
      if (m['id'] is! num) errors.add('[categories[$i]] id obrigatorio (num)');
      if (m['name'] is! String) errors.add('[categories[$i]] name obrigatorio (string)');
      if (m['normalized'] is! String) errors.add('[categories[$i]] normalized obrigatorio (string)');
    }

    // Histórico removido: nenhuma validação de history

    return errors;
  }

  /// Restaura dados a partir de um Map JSON.
  static Future<void> restore(AppDatabase db, Map<String, dynamic> data) async {
    // Executa restauração de forma atômica para evitar estados intermediários
    await db.transaction(() async {
      // Restauração completa: limpamos os dados atuais antes de inserir
      await db.customStatement('DELETE FROM categories');
      await db.customStatement('DELETE FROM corridas');

      // Recria categorias
      final categories = (data['categories'] as List<dynamic>? ?? []);
      for (final cat in categories) {
        final m = cat as Map<String, dynamic>;
        await db.upsertCategoryRaw(
          id: (m['id'] as num).toInt(),
          name: m['name'] as String,
          normalized: m['normalized'] as String,
        );
      }

      // Recria contadores
      final counters = (data['counters'] as List<dynamic>? ?? []);
      for (final c in counters) {
        final m = c as Map<String, dynamic>;
        await db.upsertCounterRaw(
          id: (m['id'] as num).toInt(),
          name: m['name'] as String,
          description: m['description'] as String?,
          eventDate: _dateFromJson(m['eventDate']),
          category: m['category'] as String?,
          status: (m['status'] as String?) ?? 'pretendo_ir',
          distanceKm: (m['distanceKm'] as num?)?.toDouble() ?? 0.0,
          price: (m['price'] as num?)?.toDouble(),
          registrationUrl: m['registrationUrl'] as String?,
          finishTime: m['finishTime'] as String?,
          createdAt: _dateFromJson(m['createdAt']),
          updatedAt: m['updatedAt'] != null ? _dateFromJson(m['updatedAt']) : null,
        );
      }

      // Histórico removido: nada a restaurar
    });
  }

  /// Convenience para retornar uma String JSON a partir do banco.
  static Future<String> encodeToJsonString(AppDatabase db) async {
    final map = await encode(db);
    return jsonEncode(map);
  }

  /// Convenience para restaurar a partir de uma String JSON.
  static Future<void> restoreFromJsonString(AppDatabase db, String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    await restore(db, data);
  }
}