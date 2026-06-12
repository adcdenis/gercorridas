import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gercorridas/state/providers.dart';
import 'package:gercorridas/core/cloud/cloud_config.dart';
import 'package:gercorridas/presentation/widgets/premium_paywall_widget.dart';

class CloudBackupPage extends ConsumerWidget {
  const CloudBackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(premiumProvider);
    if (!isPro) {
      return const PremiumPaywallWidget(
        customMessage: 'Sincronize e faça backup automático de suas corridas diretamente no seu Google Drive. Recurso exclusivo do PlanRace Pro.',
      );
    }

    final cloudSvc = ref.watch(cloudSyncServiceProvider);
    final cloudUserAsync = ref.watch(cloudUserProvider);
    final autoSyncAsync = ref.watch(cloudAutoSyncProvider);
    final autoSyncInitialAsync = ref.watch(cloudAutoSyncInitialProvider);
    final lastBackupAsync = ref.watch(cloudLastBackupInfoProvider);
    final lastRestoreAsync = ref.watch(cloudLastRestoreInfoProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.primary.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.cloud_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Backup na Nuvem',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                    Text(
                      'Sincronize com o Google Drive',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Aviso quando Google Drive não está habilitado
          if (!useGoogleDriveCloudSync)
            Card(
              elevation: 0,
              color: Colors.orange.withValues(alpha: isDark ? 0.2 : 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Para habilitar login Google e backup no Google Drive, ative o provedor Drive nas configurações do código.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!useGoogleDriveCloudSync) const SizedBox(height: 16),

          // Card de Conta Google
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_circle_outlined, size: 20, color: cs.primary),
                      const SizedBox(width: 8),
                      const Text('Conta Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  cloudUserAsync.when(
                    data: (user) {
                      if (user == null) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.person_off_outlined, size: 28, color: cs.onSurfaceVariant),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Não autenticado', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                                      Text('Faça login para sincronizar', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () async {
                                  try {
                                    await cloudSvc.signInWithGoogle();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Login Google concluído')),
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Backup inicial criado no Drive')),
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
                                icon: const Icon(Icons.login_rounded),
                                label: const Text('Entrar com Google'),
                              ),
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: cs.primaryContainer,
                            backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                            child: user.photoUrl == null ? Icon(Icons.person, color: cs.onPrimaryContainer) : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName ?? 'Usuário',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  user.email ?? user.uid,
                                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await cloudSvc.signOut();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Logout concluído')),
                                );
                              }
                            },
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: const Text('Sair'),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(child: LinearProgressIndicator()),
                    error: (e, _) => Text('Erro auth: $e', style: TextStyle(color: cs.error)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cards de info: último backup e última restauração
          Row(
            children: [
              Expanded(
                child: _InfoCard(
                  icon: Icons.cloud_upload_rounded,
                  title: 'Último Backup',
                  cs: cs,
                  child: lastBackupAsync.when(
                    data: (info) {
                      final dt = info.when;
                      final name = info.fileName;
                      if (dt != null && name != null && name.isNotEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('dd/MM/yyyy').format(dt), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            Text(DateFormat('HH:mm:ss').format(dt), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          ],
                        );
                      }
                      return Text('—', style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant));
                    },
                    loading: () => const SizedBox(height: 20, child: LinearProgressIndicator()),
                    error: (e, _) => Text('Erro', style: TextStyle(fontSize: 12, color: cs.error)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoCard(
                  icon: Icons.cloud_download_rounded,
                  title: 'Última Restauração',
                  cs: cs,
                  child: lastRestoreAsync.when(
                    data: (info) {
                      final dt = info.when;
                      final name = info.fileName;
                      if (dt != null && name != null && name.isNotEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('dd/MM/yyyy').format(dt), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            Text(DateFormat('HH:mm:ss').format(dt), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          ],
                        );
                      }
                      return Text('—', style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant));
                    },
                    loading: () => const SizedBox(height: 20, child: LinearProgressIndicator()),
                    error: (e, _) => Text('Erro', style: TextStyle(fontSize: 12, color: cs.error)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Card de Sincronização automática
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.sync_rounded, size: 22, color: cs.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sincronização automática', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text('Sincroniza alterações em tempo real', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cartões de ação: Backup e Restaurar
          Row(
            children: [
              Expanded(
                child: _CloudActionCard(
                  icon: Icons.cloud_upload_rounded,
                  label: 'Backup Agora',
                  description: 'Enviar para o Drive',
                  color: cs.primary,
                  onPressed: () async {
                    try {
                      await cloudSvc.backupNow();
                      ref.invalidate(cloudLastBackupInfoProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Backup enviado para nuvem')),
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
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CloudActionCard(
                  icon: Icons.cloud_download_rounded,
                  label: 'Restaurar',
                  description: 'Baixar do Drive',
                  color: cs.secondary,
                  onPressed: () async {
                    try {
                      await cloudSvc.restoreNow();
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// Card de informação (último backup / última restauração)
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final ColorScheme cs;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.child,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

// Card de ação de nuvem (Backup / Restaurar)
class _CloudActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onPressed;

  const _CloudActionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              Text(description, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
