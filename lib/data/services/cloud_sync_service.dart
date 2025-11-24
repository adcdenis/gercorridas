import 'dart:async';

import 'package:gercorridas/data/database/app_database.dart';
import 'package:gercorridas/data/services/backup_codec.dart';
import 'package:gercorridas/core/cloud/cloud_config.dart';
import 'package:gercorridas/data/services/cloud_sync_drive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Representa o usuário autenticado para sincronização na nuvem
class CloudUser {
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  CloudUser({required this.uid, this.displayName, this.email, this.photoUrl});
}

/// Interface do serviço de sincronização em nuvem
abstract class CloudSyncService {
  Stream<CloudUser?> authStateChanges();
  Future<void> signInWithGoogle();
  Future<void> signOut();

  /// Liga/desliga sincronização automática
  Future<void> setAutoSyncEnabled(bool enabled);
  Stream<bool> autoSyncEnabled();

  /// Backup imediato dos dados locais para a nuvem
  Future<void> backupNow();

  /// Eventos de backup concluído, emitindo a data/hora local do backup criado.
  Stream<DateTime> backupEvents();

  /// Restaura os dados da nuvem para o dispositivo local
  Future<void> restoreNow();

  /// Eventos de restauração concluída, emitindo a data/hora do backup restaurado.
  /// A data representa o timestamp do arquivo de backup remoto (UTC convertido para local).
  Stream<DateTime> restoreEvents();

  /// Inicia observação contínua para sincronização bidirecional
  Future<void> startRealtimeSync();
  Future<void> stopRealtimeSync();
}

/// Implementação padrão (Noop) que não depende de Firebase.
/// Exibe mensagens educativas e permite fluxo local sem quebras de build.
class NoopCloudSyncService implements CloudSyncService {
  final AppDatabase db;
  late final StreamController<CloudUser?> _authCtrl;
  late final StreamController<bool> _autoSyncCtrl;
  late final StreamController<DateTime> _restoreCtrl;
  late final StreamController<DateTime> _backupCtrl;
  bool _auto = false;
  StreamSubscription? _countersSub;
  Timer? _debounce;
  static const String _prefsKeyAutoSync = 'cloud_auto_sync_enabled';

  NoopCloudSyncService(this.db) {
    _authCtrl = StreamController<CloudUser?>.broadcast(
      onListen: () {
        // Noop: não há usuário autenticado; emite estado inicial imediatamente
        // para evitar travar a UI em loading.
        _authCtrl.add(null);
      },
    );
    _autoSyncCtrl = StreamController<bool>.broadcast(
      onListen: () {
        // Garante que o assinante receba o estado atual imediatamente.
        _autoSyncCtrl.add(_auto);
      },
    );
    _restoreCtrl = StreamController<DateTime>.broadcast();
    _backupCtrl = StreamController<DateTime>.broadcast();
    // Bootstrap: carregar preferências de auto-sync
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _auto = prefs.getBool(_prefsKeyAutoSync) ?? false;
      _autoSyncCtrl.add(_auto);
      if (_auto) {
        await startRealtimeSync();
      }
    } catch (_) {
      // Ignorar falhas de prefs
    }
  }

  @override
  Stream<CloudUser?> authStateChanges() => _authCtrl.stream;

  @override
  Future<void> signInWithGoogle() async {
    // Orienta sobre configuração necessária
    throw 'Login Google indisponível. Configure Google Sign-In (veja README).';
  }

  @override
  Future<void> signOut() async {
    _authCtrl.add(null);
  }

  @override
  Future<void> setAutoSyncEnabled(bool enabled) async {
    _auto = enabled;
    _autoSyncCtrl.add(_auto);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyAutoSync, _auto);
    } catch (_) {}
    if (_auto) {
      await startRealtimeSync();
    } else {
      await stopRealtimeSync();
    }
  }

  @override
  Stream<bool> autoSyncEnabled() => _autoSyncCtrl.stream;

  @override
  Future<void> backupNow() async {
    // Usa o mesmo codec dos backups locais para garantir compatibilidade
    final json = await BackupCodec.encodeToJsonString(db);
    // Aqui enviaríamos para a nuvem (Firestore/Storage). No Noop, apenas valida.
    if (json.isEmpty) {
      throw 'Falha ao preparar backup';
    }
    // Noop: emite evento para que UI possa se atualizar em ambientes sem Drive
    _backupCtrl.add(DateTime.now());
  }

  @override
  Future<void> restoreNow() async {
    // No Noop, apenas demonstra fluxo: requer dados da nuvem
    throw 'Restauração indisponível sem provedor de nuvem configurado.';
  }

  @override
  Stream<DateTime> restoreEvents() => _restoreCtrl.stream;

  @override
  Stream<DateTime> backupEvents() => _backupCtrl.stream;

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
    () async {
      try {
        await backupNow();
      } catch (_) {}
    }();
  }
}

// Fábrica que decide implementação com base na configuração
CloudSyncService createCloudSyncService(AppDatabase db) {
  if (useGoogleDriveCloudSync) {
    return GoogleDriveCloudSyncService(db);
  }
  return NoopCloudSyncService(db);
}
