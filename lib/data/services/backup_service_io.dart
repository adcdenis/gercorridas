import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gercorridas/data/database/app_database.dart';
import 'package:gercorridas/data/services/backup_codec.dart';

abstract class BackupService {
  Future<String> export();
  Future<String> import();
  Future<List<String>> listBackups();
  Future<String> importFromPath(String path);
  Future<String> exportPath();
}

class BackupServiceImpl implements BackupService {
  final AppDatabase db;
  BackupServiceImpl(this.db);

  @override
  Future<String> export() async {
    // Gera arquivo e retorna mensagem amigável
    final path = await exportPath();
    return 'Backup salvo em $path';
  }

  @override
  Future<String> exportPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final ts = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final filename = 'gercorridas_backup_$ts.json';
    final file = File('${dir.path}${Platform.pathSeparator}$filename');

    final json = jsonEncode(await BackupCodec.encode(db));

    await file.writeAsString(json);
    return file.path;
  }

  @override
  Future<String> import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      throw 'Nenhum arquivo selecionado';
    }
    final path = result.files.single.path;
    if (path == null) {
      throw 'Caminho do arquivo não disponível';
    }
    return importFromPath(path);
  }

  @override
  Future<String> importFromPath(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw 'Arquivo não existe: $path';
    }
    final content = await file.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;
    final errors = BackupCodec.validate(data);
    if (errors.isNotEmpty) {
      final report = StringBuffer('Validação falhou (${errors.length} problemas):\n');
      for (final e in errors) {
        report.writeln('- $e');
      }
      throw report.toString();
    }
    await BackupCodec.restore(db, data);
    return 'Dados importados com sucesso de ${file.path}';
  }

  @override
  Future<List<String>> listBackups() async {
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory(dir.path);
    if (!await d.exists()) return [];
    final files = await d
        .list()
        .where((e) => e is File && e.path.endsWith('.json') && RegExp(r'gercorridas_backup_\d{8}_\d{6}\.json').hasMatch(e.path.split(Platform.pathSeparator).last))
        .cast<File>()
        .toList();
    files.sort((a, b) {
      final am = a.statSync().modified;
      final bm = b.statSync().modified;
      return bm.compareTo(am);
    });
    return files.map((f) => f.path).toList();
  }
}