// ignore_for_file: deprecated_member_use
import 'package:drift/drift.dart';
import 'package:drift/web.dart';

LazyDatabase openConnection() {
  // Força IndexedDB no Web para evitar fallback em sql.js
  return LazyDatabase(() async {
  final storage = await DriftWebStorage.indexedDbIfSupported('gercorridas');
    return WebDatabase.withStorage(storage);
  });
}