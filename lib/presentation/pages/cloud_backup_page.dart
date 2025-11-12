import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gercorridas/state/providers.dart';
import 'package:gercorridas/core/cloud/cloud_config.dart';

class CloudBackupPage extends ConsumerWidget {
  const CloudBackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloudSvc = ref.watch(cloudSyncServiceProvider);
    final cloudUserAsync = ref.watch(cloudUserProvider);
    final autoSyncAsync = ref.watch(cloudAutoSyncProvider);
    final autoSyncInitialAsync = ref.watch(cloudAutoSyncInitialProvider);
    final lastBackupAsync = ref.watch(cloudLastBackupInfoProvider);
    final lastRestoreAsync = ref.watch(cloudLastRestoreInfoProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Backup na Nuvem',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('Sincronize seus dados com a nuvem (Google).'),
          const SizedBox(height: 16),
          if (!useGoogleDriveCloudSync)
            const Text(
              'Para habilitar login Google e backup no Google Drive, ative o provedor Drive nas configurações do código.',
              style: TextStyle(color: Colors.orange),
            ),
          const SizedBox(height: 12),
          // Informações de último backup e última restauração
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              lastBackupAsync.when(
                data: (info) {
                  final dt = info.when;
                  final name = info.fileName;
                  final text = (dt != null && name != null && name.isNotEmpty)
                      ? 'Último backup: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(dt)} • arquivo: $name'
                      : 'Último backup: —';
                  return Text(text, maxLines: 2);
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Erro ao carregar último backup: $e'),
              ),
              const SizedBox(height: 6),
              lastRestoreAsync.when(
                data: (info) {
                  final dt = info.when;
                  final name = info.fileName;
                  final text = (dt != null && name != null && name.isNotEmpty)
                      ? 'Última restauração: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(dt)} • arquivo: $name'
                      : 'Última restauração: —';
                  return Text(text, maxLines: 2);
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) =>
                    Text('Erro ao carregar última restauração: $e'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Status de autenticação na primeira linha; botões na linha abaixo
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cloudUserAsync.when(
                data: (user) {
                  final status = user == null
                      ? 'Não autenticado'
                      : 'Autenticado: ${user.email ?? user.displayName ?? user.uid}';
                  return Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(
                  'Erro auth: $e',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              cloudUserAsync.when(
                data: (user) {
                  final children = <Widget>[];
                  if (user == null) {
                    children.add(
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await cloudSvc.signInWithGoogle();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Login Google concluído'),
                                ),
                              );
                              // Indica visualmente o backup inicial criado após o login
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Backup inicial criado no Drive'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Falha no login: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.login),
                        label: const Text('Entrar com Google'),
                      ),
                    );
                  } else {
                    children.add(
                      OutlinedButton.icon(
                        onPressed: () async {
                          await cloudSvc.signOut();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Logout concluído')),
                            );
                          }
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Sair'),
                      ),
                    );
                  }
                  return Wrap(spacing: 8, runSpacing: 8, children: children);
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [Text('Erro auth: $e')],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Switch(
                value: autoSyncAsync.maybeWhen(
                  data: (v) => v,
                  orElse: () => autoSyncInitialAsync.asData?.value ?? false,
                ),
                onChanged: (v) async {
                  await cloudSvc.setAutoSyncEnabled(v);
                  if (v) {
                    await cloudSvc.startRealtimeSync();
                  } else {
                    await cloudSvc.stopRealtimeSync();
                  }
                },
              ),
              const SizedBox(width: 8),
              Row(children: [const Text('Sincronização automática')]),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () async {
                  try {
                    await cloudSvc.backupNow();
                    // Atualiza campos de último backup na UI
                    ref.invalidate(cloudLastBackupInfoProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Backup enviado para nuvem'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Falha ao enviar: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Backup na nuvem'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await cloudSvc.restoreNow();
                    // Atualiza campos de última restauração na UI
                    ref.invalidate(cloudLastRestoreInfoProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Restauração concluída')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Falha ao restaurar: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.cloud_download),
                label: const Text('Restaurar da nuvem'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
