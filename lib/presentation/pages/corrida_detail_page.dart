 import 'package:flutter/material.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
 import 'package:go_router/go_router.dart';
import 'package:gercorridas/state/providers.dart';

class CorridaDetailPage extends ConsumerWidget {
  final int counterId;
  const CorridaDetailPage({super.key, required this.counterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(corridaRepositoryProvider);
    return FutureBuilder(
      future: repo.byId(counterId),
      builder: (context, snap) {
        final c = snap.data;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Detalhe da Corrida', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Builder(
                builder: (_) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const CircularProgressIndicator();
                  }
                  if (c == null) {
                    return const Text('Corrida não encontrada');
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ID: ${c.id}'),
                      const SizedBox(height: 8),
                      Text('Nome: ${c.name}'),
                      c.description != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text('Descrição: ${c.description}')
                              ],
                            )
                          : const SizedBox.shrink(),
                      const SizedBox(height: 8),
                      Text('Data: ${c.eventDate}'),
                      const SizedBox(height: 8),
                      Text('Categoria: ${c.category ?? '-'}'),
                      const SizedBox(height: 8),
                      Text('Distância: ${c.distanceKm.toStringAsFixed(0)} km'),
                      const SizedBox(height: 8),
                      Text('Status: ${_labelForStatus(c.status)}'),
                      c.price != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text('Preço: R\$ ${c.price!.toStringAsFixed(2)}'),
                              ],
                            )
                          : const SizedBox.shrink(),
                      Builder(
                        builder: (_) {
                          if (c.registrationUrl != null && c.registrationUrl!.isNotEmpty) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text('Inscrição: ${c.registrationUrl}'),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      Builder(
                        builder: (_) {
                          if (c.finishTime != null && c.finishTime!.isNotEmpty) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text('Tempo de conclusão: ${c.finishTime}'),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 8),
                      const SizedBox.shrink(),
                      const SizedBox(height: 24),
                      Row(children: [
                        FilledButton.icon(
                          onPressed: () => context.go('/corrida/${c.id}/edit'),
                          icon: const Text('📝', style: TextStyle(fontSize: 20)),
                          label: const Text('Editar'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Excluir corrida'),
                                content: const Text('Tem certeza que deseja excluir? Esta ação não pode ser desfeita.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
                                  TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Excluir')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await repo.delete(c.id!);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Corrida excluída')));
                                context.go('/');
                              }
                            }
                          },
                          icon: const Text('🗑️', style: TextStyle(fontSize: 20)),
                          label: const Text('Excluir'),
                        ),
                      ]),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

String _labelForStatus(String s) {
  switch (s) {
    case 'pretendo_ir':
      return 'Pretendo ir';
    case 'inscrito':
      return 'Inscrito';
    case 'concluida':
      return 'Concluída';
    case 'cancelada':
      return 'Cancelada';
    case 'nao_pude_ir':
      return 'Não pude ir';
    case 'na_duvida':
      return 'Na dúvida';
    default:
      return s;
  }
}
