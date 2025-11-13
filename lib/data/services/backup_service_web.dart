import 'dart:convert';
import 'dart:async';
// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

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
    final json = jsonEncode(await BackupCodec.encode(db));

    final bytes = utf8.encode(json);
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final now = DateTime.now();
    final ts = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final filename = 'gercorridas_backup_$ts.json';
    html.AnchorElement(href: url)
      ..download = filename
      ..click();
    html.Url.revokeObjectUrl(url);
    return 'Download iniciado ($filename)';
  }

  @override
  Future<String> exportPath() async {
    // Não suportado no Web: não há caminho local de arquivo
    throw 'Exportação com caminho não suportada no Web';
  }

  @override
  Future<String> import() async {
    final input = html.FileUploadInputElement()..accept = '.json,application/json';
    final completer = Completer<String>();
    input.onChange.listen((event) {
      final file = input.files?.first;
      if (file == null) {
        completer.completeError('Nenhum arquivo selecionado');
        return;
      }
      final reader = html.FileReader();
      reader.onLoadEnd.listen((_) async {
        try {
          final content = reader.result as String;
          final data = jsonDecode(content) as Map<String, dynamic>;
          final errors = BackupCodec.validate(data);
          if (errors.isNotEmpty) {
            final report = StringBuffer('Validação falhou (${errors.length} problemas):\n');
            for (final e in errors) { report.writeln('- $e'); }
            completer.completeError(report.toString());
            return;
          }
          await BackupCodec.restore(db, data);
          completer.complete('Dados importados com sucesso');
        } catch (e) {
          completer.completeError(e);
        }
      });
      reader.readAsText(file);
    });
    input.click();
    return completer.future;
  }

  @override
  Future<List<String>> listBackups() async {
    // Não suportado no Web: não há diretório de documentos
    return [];
  }

  @override
  Future<String> importFromPath(String path) async {
    // Não suportado no Web
    throw 'Importação por caminho não suportada no Web';
  }
}