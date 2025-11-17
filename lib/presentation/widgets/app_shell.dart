import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:gercorridas/state/providers.dart';
import 'package:intl/intl.dart';

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ouve eventos de restauração e mostra uma mensagem com data/hora exata
    ref.listen(cloudRestoreEventProvider, (prev, next) {
      next.whenData((dt) {
        final formatted = DateFormat('dd/MM/yyyy HH:mm:ss').format(dt);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dados atualizados. Restauração de $formatted.')),
        );
      });
    });
    return PopScope(
      // Intercepta sempre o botão voltar para aplicar regra:
      // voltar leva à listagem de contadores; somente nela perguntar para sair.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        // Se o Drawer estiver aberto, feche-o e não trate como "voltar" da página
        final scaffoldState = Scaffold.maybeOf(context);
        if (scaffoldState?.isDrawerOpen == true) {
          scaffoldState!.closeDrawer();
          return;
        }
        final router = GoRouter.of(context);
        final location = GoRouterState.of(context).uri.toString();
        if (location == '/corridas') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Sair do aplicativo'),
              content: const Text('Deseja realmente fechar o app?'),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
                FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sair')),
              ],
            ),
          );
          if (confirm == true) {
            SystemNavigator.pop();
          }
        } else {
          router.go('/corridas');
        }
      },
      child: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final selectedIndex = _selectedIndexForLocation(GoRouterState.of(context).uri.toString());
        final title = Row(
          children: const [
            Icon(Icons.directions_run),
            SizedBox(width: 8),
            Text('PlanRace'),
          ],
        );

      if (isWide) {
        return Scaffold(
          appBar: AppBar(title: title, actions: const [
            Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: _ProfileAvatar(),
            ),
          ]),
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) => _goToIndex(context, index),
                extended: constraints.maxWidth >= 1200,
                // Quando extended=true, labelType deve ser null/none.
                labelType: (constraints.maxWidth >= 1200)
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                useIndicator: true,
                elevation: 2,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                indicatorColor: Theme.of(context).colorScheme.primaryContainer,
                leading: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.directions_run),
                      SizedBox(width: 8),
                      Text('PlanRace', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                trailing: const Padding(
                  padding: EdgeInsets.all(12),
                  child: _VersionFooter(),
                ),
                destinations: const [
                  NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
                  NavigationRailDestination(icon: Icon(Icons.directions_run), selectedIcon: Icon(Icons.directions_run), label: Text('Corridas')),
                  NavigationRailDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: Text('Estatísticas')),
                  NavigationRailDestination(icon: Icon(Icons.account_tree_outlined), selectedIcon: Icon(Icons.account_tree), label: Text('Mapa Mental')),
                  NavigationRailDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: Text('Relatórios')),
                  NavigationRailDestination(icon: Icon(Icons.sync_alt), selectedIcon: Icon(Icons.sync), label: Text('Backup')),
                  NavigationRailDestination(icon: Icon(Icons.cloud_outlined), selectedIcon: Icon(Icons.cloud), label: Text('Backup na Nuvem')),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: child),
            ],
          ),
        );
      }

      return Scaffold(
        appBar: AppBar(title: title, centerTitle: false, actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: _ProfileAvatar(),
          ),
        ]),
        drawer: _AppDrawer(selectedIndex: selectedIndex, onNavigateIndex: (index) => _goToIndex(context, index)),
        body: child,
      );
    }),
    );
  }

  int _selectedIndexForLocation(String location) {
    if (location.startsWith('/corridas')) return 1;
    if (location.startsWith('/estatisticas')) return 2;
    if (location.startsWith('/mapa-mental')) return 3;
    if (location.startsWith('/reports')) return 4;
    if (location.startsWith('/backup')) return 5;
    if (location.startsWith('/cloud-backup')) return 6;
    return 0; // dashboard default
  }

  void _goToIndex(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/corridas');
        break;
      case 2:
        context.go('/estatisticas');
        break;
      case 3:
        context.go('/mapa-mental');
        break;
      case 4:
        context.go('/reports');
        break;
      case 5:
        context.go('/backup');
        break;
      case 6:
        context.go('/cloud-backup');
        break;
    }
  }
}

class _AppDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavigateIndex;
  const _AppDrawer({required this.selectedIndex, required this.onNavigateIndex});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: [cs.primaryContainer, cs.secondaryContainer]),
              ),
              child: Row(children: const [
                Icon(Icons.directions_run, size: 28),
                SizedBox(width: 10),
                Text('PlanRace', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ]),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              selected: selectedIndex == 0,
              selectedTileColor: cs.secondaryContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Scaffold.maybeOf(context)?.closeDrawer();
                onNavigateIndex(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_run),
              title: const Text('Corridas'),
              selected: selectedIndex == 1,
              selectedTileColor: cs.secondaryContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Scaffold.maybeOf(context)?.closeDrawer();
                onNavigateIndex(1);
              },
            ),
          ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: const Text('Estatísticas'),
            selected: selectedIndex == 2,
            selectedTileColor: cs.secondaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () {
              Scaffold.maybeOf(context)?.closeDrawer();
              onNavigateIndex(2);
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: const Text('Mapa Mental'),
            selected: selectedIndex == 3,
            selectedTileColor: cs.secondaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () {
              Scaffold.maybeOf(context)?.closeDrawer();
              onNavigateIndex(3);
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment_outlined),
            title: const Text('Relatórios'),
            selected: selectedIndex == 4,
            selectedTileColor: cs.secondaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () {
              Scaffold.maybeOf(context)?.closeDrawer();
              onNavigateIndex(4);
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync_alt),
            title: const Text('Backup'),
            selected: selectedIndex == 5,
            selectedTileColor: cs.secondaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () {
              Scaffold.maybeOf(context)?.closeDrawer();
              onNavigateIndex(5);
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Backup na Nuvem'),
            selected: selectedIndex == 6,
            selectedTileColor: cs.secondaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () {
              Scaffold.maybeOf(context)?.closeDrawer();
              onNavigateIndex(6);
            },
          ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _VersionFooter(),
            ),
          ],
        ),
      ),
    );
  }
}

// Rodapé com a versão do aplicativo
class _VersionFooter extends ConsumerWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionProvider);
    final scheme = Theme.of(context).colorScheme;
    return versionAsync.when(
      loading: () => Text('Versão...', style: TextStyle(color: scheme.onSurfaceVariant)),
      error: (err, _) => Text('Versão indisponível', style: TextStyle(color: scheme.onSurfaceVariant)),
      data: (v) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(v, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// Avatar do usuário (topo direito): mostra foto do Google quando logado,
// e avatar padrão quando deslogado.
class _ProfileAvatar extends ConsumerWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(cloudUserProvider);
    final cs = Theme.of(context).colorScheme;
    Widget defaultAvatar() => CircleAvatar(
          radius: 16,
          backgroundColor: cs.surface,
          child: Icon(Icons.account_circle, size: 20, color: cs.onSurfaceVariant),
        );

    return userAsync.maybeWhen(
      data: (user) {
        if (user == null || user.photoUrl == null) {
          return defaultAvatar();
        }
        return CircleAvatar(
          radius: 16,
          backgroundImage: NetworkImage(user.photoUrl!),
          backgroundColor: cs.surface,
        );
      },
      orElse: () => defaultAvatar(),
    );
  }
}
