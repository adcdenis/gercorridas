// ignore_for_file: deprecated_member_use
import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor openTestConnection() {
  // Usar IndexedDB diretamente nos testes web para estabilidade
  return LazyDatabase(() async =>
      WebDatabase.withStorage(await DriftWebStorage.indexedDbIfSupported(
  'gercorridas_test',
      )));
}