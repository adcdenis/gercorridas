import 'package:gercorridas/data/database/app_database.dart';
import 'package:gercorridas/data/models/category.dart';
import 'package:drift/drift.dart';

class CategoryRepository {
  final AppDatabase db;
  CategoryRepository(this.db);

  Category _mapRow(CategoryRow r) => Category(id: r.id, name: r.name, normalized: r.normalized);

  CategoriesCompanion _toCompanion(Category c) => CategoriesCompanion(
        id: c.id != null ? Value(c.id!) : const Value.absent(),
        name: Value(c.name),
        normalized: Value(c.normalized),
      );

  Future<int> create(Category c) async {
    // Evita duplicação: se já existir por normalized, retorna o id existente
    final existing = await db.getCategoryByNormalized(c.normalized);
    if (existing != null) return existing.id;
    return db.insertCategory(_toCompanion(c));
  }
  Future<List<Category>> all() async => (await db.getAllCategories()).map(_mapRow).toList();
  Future<Category?> byId(int id) async {
    final r = await db.getCategoryById(id);
    return r == null ? null : _mapRow(r);
  }
  Future<Category?> byNormalized(String normalized) async {
    final r = await db.getCategoryByNormalized(normalized);
    return r == null ? null : _mapRow(r);
  }
  Future<bool> isUsed(Category c) async {
    final count = await db.countCountersByCategoryName(c.name);
    return count > 0;
  }
  Future<bool> deleteIfUnused(Category c) async {
    if (c.id == null) return false;
    if (await isUsed(c)) return false;
    await db.deleteCategory(c.id!);
    return true;
  }
  Future<bool> update(Category c) => db.updateCategory(_toCompanion(c));
  Future<int> delete(int id) => db.deleteCategory(id);

  Stream<List<Category>> watchAll() => db.watchAllCategories().map((rows) => rows.map(_mapRow).toList());
}