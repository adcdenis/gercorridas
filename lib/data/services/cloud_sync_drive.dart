import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import 'package:gercorridas/data/database/app_database.dart';
import 'package:gercorridas/data/services/backup_codec.dart';
import 'package:gercorridas/data/services/cloud_sync_service.dart';
import 'package:gercorridas/core/cloud/cloud_config.dart';

/// HTTP client que injeta os headers de autenticação do Google
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

/// Implementação de CloudSyncService usando Google Drive (sem Firebase)
class GoogleDriveCloudSyncService implements CloudSyncService {
  final AppDatabase db;
  late final StreamController<CloudUser?> _authCtrl;
  late final StreamController<bool> _autoSyncCtrl;
  late final StreamController<DateTime> _restoreCtrl;
  late final StreamController<DateTime> _backupCtrl;
  DateTime? _lastRestoreEvent;
  bool _auto = false;
  DateTime? _suppressAutoBackupUntil; // janela de supressão de backup após restauração
  Timer? _suppressionTimer; // dispara um backup logo após fim da supressão se houve mudanças
  bool _suppressedChange = false; // houve mudança local durante supressão

  final GoogleSignIn _signIn = GoogleSignIn(
    serverClientId: '888851963736-tm49m91ku2kvuliqe9fa2402i7ao8630.apps.googleusercontent.com',
    scopes: useDriveAppDataSpace
        ? const [
            'email',
            'https://www.googleapis.com/auth/drive.appdata',
          ]
        : const [
            'email',
            'https://www.googleapis.com/auth/drive.file',
          ],
  );

  StreamSubscription? _countersSub;
  Timer? _debounce;
  String? _backupFolderId; // cache do id da subpasta de backups
  static const String _prefsKeyAutoSync = 'cloud_auto_sync_enabled';
  static const String _prefsKeyLastUpdate = 'cloud_last_update_timestamp';
  static const String _prefsKeyLastBackupTs = 'cloud_last_backup_timestamp';
  static const String _prefsKeyLastBackupFile = 'cloud_last_backup_file';
  static const String _prefsKeyLastRestoreTs = 'cloud_last_restore_timestamp';
  static const String _prefsKeyLastRestoreFile = 'cloud_last_restore_file';

  GoogleDriveCloudSyncService(this.db) {
    _authCtrl = StreamController<CloudUser?>.broadcast(
      onListen: () {
        // Emite estado de autenticação atual assim que houver assinante.
        final acct = _signIn.currentUser;
        if (acct != null) {
          _authCtrl.add(CloudUser(
            uid: acct.id,
            displayName: acct.displayName,
            email: acct.email,
            photoUrl: acct.photoUrl,
          ));
        } else {
          _authCtrl.add(null);
        }
      },
    );
    _autoSyncCtrl = StreamController<bool>.broadcast(
      onListen: () {
        // Emite estado atual do auto-sync imediatamente ao inscrever.
        _autoSyncCtrl.add(_auto);
      },
    );
    _restoreCtrl = StreamController<DateTime>.broadcast(
      onListen: () {
        // Emite o último evento conhecido para novos assinantes (evita perda se o evento
        // ocorreu antes da UI estar inscrita).
        if (_lastRestoreEvent != null) {
          _restoreCtrl.add(_lastRestoreEvent!);
        }
      },
    );
    _backupCtrl = StreamController<DateTime>.broadcast();
    // Emite usuário atual ao iniciar
    _signIn.onCurrentUserChanged.listen((account) {
      if (account == null) {
        _authCtrl.add(null);
      } else {
        _authCtrl.add(CloudUser(
          uid: account.id,
          displayName: account.displayName,
          email: account.email,
          photoUrl: account.photoUrl,
        ));
      }
    });

    // Bootstrap: carrega preferências e tenta login silencioso
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _auto = prefs.getBool(_prefsKeyAutoSync) ?? false;
      // Notificar assinantes do estado carregado
      _autoSyncCtrl.add(_auto);
    } catch (_) {
      // Ignora falhas de prefs; mantém padrão falso
    }
    try {
      final acct = await _signIn.signInSilently();
      if (acct != null) {
        _authCtrl.add(CloudUser(
          uid: acct.id,
          displayName: acct.displayName,
          email: acct.email,
          photoUrl: acct.photoUrl,
        ));
        // Se auto-sync habilitado, primeiro tenta sincronizar/restaurar do remoto
        // e só então inicia a observação contínua para evitar que mudanças
        // locais geradas na inicialização disparem um backup automático.
        if (_auto) {
          // Executa sincronização automática de restauração ao iniciar, se necessário
          await _runStartupAutoSync();
          await startRealtimeSync();
        }
      } else {
        _authCtrl.add(null);
      }
    } catch (_) {
      // Silencioso; usuário permanece não autenticado até login explícito
    }
  }

  /// Executa, de forma silenciosa, a verificação de backup remoto mais recente e restaura se necessário.
  /// Condições: usuário autenticado e auto-sync habilitado.
  Future<void> _runStartupAutoSync() async {
    try {
      if (!_auto) return; // precisa estar habilitado
      final acct = _signIn.currentUser ?? await _signIn.signInSilently();
      if (acct == null) return; // requer usuário autenticado
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getString(_prefsKeyLastUpdate) ?? '';

      final headers = await acct.authHeaders;
      final client = GoogleAuthClient(headers);
      final api = drive.DriveApi(client);

      String spaces = useDriveAppDataSpace ? 'appDataFolder' : 'drive';
      String q = "mimeType = 'application/json' and name contains 'gercorridas_backup_' and trashed = false";
      if (!useDriveAppDataSpace) {
        final folderId = await _ensureBackupFolderId(api);
        q = "$q and '$folderId' in parents";
      }

      // Lista arquivos de backup, sem limitar a 1, para também realizar limpeza
      final res = await api.files.list(
        q: q,
        orderBy: 'name desc', // ordena por nome para aproveitar o timestamp lexicográfico
        pageSize: 100,
        spaces: spaces,
        $fields: 'files(id,name,modifiedTime,size)',
      );
      final files = res.files ?? [];
      if (files.isEmpty) return; // nada a fazer

      String? latestTs;
      drive.File? latestFile;
      final regexp = RegExp(r"^gercorridas_backup_(\d{8}_\d{6})\.json");
      for (final f in files) {
        final name = f.name ?? '';
        final m = regexp.firstMatch(name);
        if (m != null) {
          final ts = m.group(1)!; // YYYYMMDD_HHMMSS
          if (latestTs == null || ts.compareTo(latestTs) > 0) {
            latestTs = ts;
            latestFile = f;
          }
        }
      }
      if (latestTs == null || latestFile == null) return; // nenhum arquivo compatível

      // Compara com timestamp salvo
      if (last.isEmpty || latestTs.compareTo(last) > 0) {
        // remoto é mais recente → baixa e restaura
        try {
          // Suprimir backups automáticos por um período após restauração
          _suppressAutoBackupUntil = DateTime.now().add(const Duration(seconds: 30));
          _suppressedChange = false;
          _suppressionTimer?.cancel();
          final delay = _suppressAutoBackupUntil!.difference(DateTime.now());
          _suppressionTimer = Timer(delay + const Duration(seconds: 1), () async {
            // Se houve mudanças durante supressão, realiza um backup logo após terminar
            if (_auto && _suppressedChange) {
              try { await backupNow(); } catch (_) {}
            }
            _suppressedChange = false;
          });
          final url = Uri.parse('https://www.googleapis.com/drive/v3/files/${latestFile.id}?alt=media');
          final response = await client.get(url);
          if (response.statusCode == 200) {
            final jsonStr = response.body;
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;
            final errors = BackupCodec.validate(data);
            if (errors.isEmpty) {
              debugPrint('[CloudDrive] Iniciando restauração automática de $latestTs');
              await BackupCodec.restore(db, data);
              // Persiste metadados de restauração (para UI/providers)
              try {
                debugPrint('[CloudDrive] Gravando metadados da restauração automática...');
                await prefs.setString(_prefsKeyLastUpdate, latestTs);
                // Também salvar explicitamente como última restauração
                await prefs.setString(_prefsKeyLastRestoreTs, latestTs);
                final name = latestFile.name ?? '';
                if (name.isNotEmpty) await prefs.setString(_prefsKeyLastRestoreFile, name);
                debugPrint('[CloudDrive] Metadados gravados: timestamp=$latestTs, arquivo=$name');
              } catch (e) {
                debugPrint('[CloudDrive] Erro ao gravar metadados: $e');
              }
              // Emite evento de restauração com o timestamp do backup restaurado
              final restoredAt = _parseTimestampToLocal(latestTs);
              if (restoredAt != null) {
                _lastRestoreEvent = restoredAt;
                _restoreCtrl.add(restoredAt);
              }
            }
          }
        } catch (_) {
          // silencioso: não interrompe inicialização
        }
      }

      // Limpeza automática: mantém no máximo 10 backups mais recentes
      await _cleanupOldBackups(api);
    } catch (_) {
      // Ignora erros gerais para permanecer silencioso
    }
  }

  DateTime? _parseTimestampToLocal(String ts) {
    // Formato: YYYYMMDD_HHMMSS (gerado em UTC pelo app)
    try {
      final year = int.parse(ts.substring(0, 4));
      final month = int.parse(ts.substring(4, 6));
      final day = int.parse(ts.substring(6, 8));
      final hour = int.parse(ts.substring(9, 11));
      final minute = int.parse(ts.substring(11, 13));
      final second = int.parse(ts.substring(13, 15));
      final dtUtc = DateTime.utc(year, month, day, hour, minute, second);
      return dtUtc.toLocal();
    } catch (_) {
      return null;
    }
  }

  Future<String> _ensureBackupFolderId(drive.DriveApi api) async {
    if (useDriveAppDataSpace) {
      // No appDataSpace, não há pasta arbitrária; retornamos marcador especial
      return 'appDataFolder';
    }
    // Se temos cache, verifica se ainda existe e não está na lixeira
    if (_backupFolderId != null) {
      try {
        final f = await api.files.get(_backupFolderId!, $fields: 'id,name,trashed');
        final file = f as drive.File;
        final trashed = file.trashed ?? false;
        final name = file.name ?? '';
        // Reutiliza apenas se não estiver na lixeira e o nome coincidir com o nome canônico configurado
        if (!trashed && name == cloudDriveFolderName) {
          return _backupFolderId!;
        } else {
          _backupFolderId = null; // pasta renomeada ou na lixeira → força recriação/localização por nome
        }
      } catch (_) {
        // id pode ter sido removido; limpa cache e prossegue para localizar/criar
        _backupFolderId = null;
      }
    }
    // Procurar pasta existente com nome configurado
    final res = await api.files.list(
      q: "mimeType = 'application/vnd.google-apps.folder' and name = '${cloudDriveFolderName.replaceAll("'", "\\'")}' and trashed = false",
      pageSize: 1,
      spaces: 'drive',
      $fields: 'files(id,name)'
    );
    final files = res.files ?? [];
    if (files.isNotEmpty) {
      _backupFolderId = files.first.id;
      return _backupFolderId!;
    }
    // Criar pasta
    final folderMeta = drive.File()
      ..name = cloudDriveFolderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folderMeta);
    _backupFolderId = created.id;
    return _backupFolderId!;
  }

  @override
  Stream<CloudUser?> authStateChanges() => _authCtrl.stream;

  @override
  Future<void> signInWithGoogle() async {
    final account = await _signIn.signIn();
    if (account == null) throw 'Login cancelado';
    _authCtrl.add(CloudUser(uid: account.id, displayName: account.displayName, email: account.email, photoUrl: account.photoUrl));

    // Ativar auto-sync por padrão ao autenticar e persistir preferência
    _auto = true;
    _autoSyncCtrl.add(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyAutoSync, true);
    } catch (_) {}
    // Executa sincronização de inicialização (restaura se necessário) antes de iniciar observação contínua
    try {
      await _runStartupAutoSync();
    } catch (_) {
      // silencioso: não interromper fluxo de login
    }
    await startRealtimeSync();
  }

  @override
  Future<void> signOut() async {
    await _signIn.disconnect();
    await _signIn.signOut();
    _authCtrl.add(null);
  }

  @override
  Future<void> setAutoSyncEnabled(bool enabled) async {
    _auto = enabled;
    _autoSyncCtrl.add(_auto);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyAutoSync, _auto);
    } catch (_) {
      // Ignora erros de persistência
    }
    // Ajusta observação contínua conforme estado
    if (_auto) {
      await startRealtimeSync();
    } else {
      await stopRealtimeSync();
    }
  }

  @override
  Stream<bool> autoSyncEnabled() => _autoSyncCtrl.stream;

  Future<drive.DriveApi> _driveApi() async {
    final acct = _signIn.currentUser ?? await _signIn.signInSilently();
    if (acct == null) throw 'Usuário não autenticado';
    final headers = await acct.authHeaders;
    final client = GoogleAuthClient(headers);
    return drive.DriveApi(client);
  }

  String _timestampName() {
    final now = DateTime.now().toUtc();
    final ts = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    return 'gercorridas_backup_$ts.json';
  }

  @override
  Future<void> backupNow() async {
    final api = await _driveApi();
    final jsonStr = await BackupCodec.encodeToJsonString(db);
    final bytes = utf8.encode(jsonStr);
    final media = drive.Media(Stream.value(Uint8List.fromList(bytes)), bytes.length);

    final fileMeta = drive.File()
      ..name = _timestampName()
      ..mimeType = 'application/json';
    if (useDriveAppDataSpace) {
      fileMeta.parents = ['appDataFolder'];
      final created = await api.files.create(fileMeta, uploadMedia: media);
      try {
        final prefs = await SharedPreferences.getInstance();
        final name = created.name ?? fileMeta.name ?? '';
        final m = RegExp(r"^gercorridas_backup_(\d{8}_\d{6})\.json").firstMatch(name);
        final ts = m?.group(1);
        if (ts != null) {
          await prefs.setString(_prefsKeyLastBackupTs, ts);
          await prefs.setString(_prefsKeyLastUpdate, ts);
          final when = _parseTimestampToLocal(ts) ?? DateTime.now();
          _backupCtrl.add(when);
        }
        await prefs.setString(_prefsKeyLastBackupFile, name);
      } catch (_) {}
      // Após gravação, limpar excedentes mantendo somente 10 mais recentes
      await _cleanupOldBackups(api);
      return;
    }
    final folderId = await _ensureBackupFolderId(api);
    fileMeta.parents = [folderId];
    final created = await api.files.create(fileMeta, uploadMedia: media);
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = created.name ?? fileMeta.name ?? '';
      final m = RegExp(r"^gercorridas_backup_(\d{8}_\d{6})\.json").firstMatch(name);
      final ts = m?.group(1);
      if (ts != null) {
        await prefs.setString(_prefsKeyLastBackupTs, ts);
        await prefs.setString(_prefsKeyLastUpdate, ts);
        final when = _parseTimestampToLocal(ts) ?? DateTime.now();
        _backupCtrl.add(when);
      }
      await prefs.setString(_prefsKeyLastBackupFile, name);
    } catch (_) {}
    // Após gravação, limpar excedentes mantendo somente 10 mais recentes
    await _cleanupOldBackups(api);
  }

  @override
  Future<void> restoreNow() async {
    final acct = _signIn.currentUser ?? await _signIn.signInSilently();
    if (acct == null) throw 'Usuário não autenticado';
    final headers = await acct.authHeaders;
    final client = GoogleAuthClient(headers);

    // Busca o arquivo mais recente com padrão de nome do app
    final api = drive.DriveApi(client);
    String spaces = 'drive';
    String q = "mimeType = 'application/json' and name contains 'gercorridas_backup_'";
    if (useDriveAppDataSpace) {
      spaces = 'appDataFolder';
    } else {
      final folderId = await _ensureBackupFolderId(api);
      q = "$q and '$folderId' in parents";
    }
    final res = await api.files.list(
      q: q,
      orderBy: 'modifiedTime desc',
      pageSize: 1,
      spaces: spaces,
      $fields: 'files(id,name,modifiedTime,size)',
    );
    final files = res.files ?? [];
    if (files.isEmpty) {
      throw 'Nenhum backup encontrado no Google Drive';
    }
    final f = files.first;
    final url = Uri.parse('https://www.googleapis.com/drive/v3/files/${f.id}?alt=media');
    final response = await client.get(url);
    if (response.statusCode != 200) {
      throw 'Falha ao baixar backup do Drive (HTTP ${response.statusCode})';
    }
    final jsonStr = response.body;
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final errors = BackupCodec.validate(data);
    if (errors.isNotEmpty) {
      final report = StringBuffer('Validação falhou (${errors.length} problemas):\n');
      for (final e in errors) { report.writeln('- $e'); }
      throw report.toString();
    }
    // Suprimir backups automáticos por um período após restauração manual
    _suppressAutoBackupUntil = DateTime.now().add(const Duration(seconds: 30));
    _suppressedChange = false;
    _suppressionTimer?.cancel();
    final delay = _suppressAutoBackupUntil!.difference(DateTime.now());
    _suppressionTimer = Timer(delay + const Duration(seconds: 1), () async {
      if (_auto && _suppressedChange) {
        try { await backupNow(); } catch (_) {}
      }
      _suppressedChange = false;
    });
    await BackupCodec.restore(db, data);
    // Limpeza após restauração: manter apenas os 10 mais recentes
    await _cleanupOldBackups(api);
    // Emite evento com a data definida pelo nome do arquivo
    final name = f.name ?? '';
    final m = RegExp(r"^gercorridas_backup_(\d{8}_\d{6})\.json").firstMatch(name);
    if (m != null) {
      final ts = m.group(1)!;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKeyLastRestoreTs, ts);
        await prefs.setString(_prefsKeyLastRestoreFile, name);
        await prefs.setString(_prefsKeyLastUpdate, ts);
      } catch (_) {}
      final restoredAt = _parseTimestampToLocal(ts);
      if (restoredAt != null) {
        _lastRestoreEvent = restoredAt;
        _restoreCtrl.add(restoredAt);
      }
    }
  }

  @override
  Future<void> startRealtimeSync() async {
    if (!_auto) return;
    _countersSub ??= db.watchAllCounters().skip(1).listen((_) => _onLocalChange());
    // Política: não sincronizar por mudanças de categorias
  }

  @override
  Future<void> stopRealtimeSync() async {
    await _countersSub?.cancel();
    _countersSub = null;
    _debounce?.cancel();
    _debounce = null;
  }

  void _onLocalChange() {
    if (!_auto) return;
    // Evita criar um backup imediatamente após uma restauração
    if (_suppressAutoBackupUntil != null && DateTime.now().isBefore(_suppressAutoBackupUntil!)) {
      // marca que houve alterações durante supressão
      _suppressedChange = true;
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 20), () async {
      try {
        await backupNow();
      } catch (_) {
        // ignora erros em auto-sync
      }
    });
  }


  /// Remove backups excedentes, mantendo apenas os 10 mais recentes.
  Future<void> _cleanupOldBackups(drive.DriveApi api) async {
    try {
      String spaces = useDriveAppDataSpace ? 'appDataFolder' : 'drive';
      String q = "mimeType = 'application/json' and name contains 'gercorridas_backup_' and trashed = false";
      if (!useDriveAppDataSpace) {
        final folderId = await _ensureBackupFolderId(api);
        q = "$q and '$folderId' in parents";
      }
      final res = await api.files.list(
        q: q,
        orderBy: 'name desc',
        pageSize: 100,
        spaces: spaces,
        $fields: 'files(id,name)'
      );
      final files = res.files ?? [];
      if (files.length <= 10) return;
      final regexp = RegExp(r"^gercorridas_backup_(\d{8}_\d{6})\.json");
      final entries = <MapEntry<String, drive.File>>[];
      for (final f in files) {
        final name = f.name ?? '';
        final m = regexp.firstMatch(name);
        if (m != null) entries.add(MapEntry(m.group(1)!, f));
      }
      entries.sort((a, b) => b.key.compareTo(a.key)); // mais recentes primeiro
      for (var i = 10; i < entries.length; i++) {
        final id = entries[i].value.id;
        if (id != null) {
          try {
            await api.files.delete(id);
            // Log discreto para depuração de limpeza de backups
            final deletedName = entries[i].value.name ?? id;
            debugPrint('[DriveCleanup] Excluído backup antigo: $deletedName');
          } catch (_) {
            // Ignora falhas pontuais
          }
        }
      }
    } catch (_) {
      // Silencioso: não falha fluxo de backup
    }
  }

  @override
  Stream<DateTime> restoreEvents() => _restoreCtrl.stream;

  @override
  Stream<DateTime> backupEvents() => _backupCtrl.stream;
}