import 'package:drift/drift.dart';
import 'package:drift/native.dart';

QueryExecutor openTestConnection() {
  return NativeDatabase.memory();
}