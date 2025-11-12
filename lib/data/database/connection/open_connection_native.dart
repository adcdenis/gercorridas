import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final newPath = p.join(dir.path, 'gercorridas.db');
    final dbFile = File(newPath);
    return NativeDatabase(dbFile);
  });
}