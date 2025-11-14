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
        final title = Row(
          children: const [
            Icon(Icons.directions_run),
            SizedBox(width: 8),
            Text('GerCorridas'),
          ],
        );

      if (isWide) {
        final selectedIndex = _selectedIndexForLocation(GoRouterState.of(context).uri.toString());
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
                trailing: const Padding(
                  padding: EdgeInsets.all(12),
                  child: _VersionFooter(),
                ),
                destinations: const [
                  NavigationRailDestination(icon: Text('📋', style: TextStyle(fontSize: 20)), selectedIcon: Text('📋', style: TextStyle(fontSize: 20)), label: Text('Dashboard')),
                  NavigationRailDestination(icon: Text('🏃', style: TextStyle(fontSize: 20)), selectedIcon: Text('🏃', style: TextStyle(fontSize: 20)), label: Text('Corridas')),
                  NavigationRailDestination(icon: Text('📊', style: TextStyle(fontSize: 20)), selectedIcon: Text('📊', style: TextStyle(fontSize: 20)), label: Text('Estatísticas')),
                  NavigationRailDestination(icon: Text('📈', style: TextStyle(fontSize: 20)), selectedIcon: Text('📈', style: TextStyle(fontSize: 20)), label: Text('Relatórios')),
                  NavigationRailDestination(icon: Text('🔄', style: TextStyle(fontSize: 20)), selectedIcon: Text('🔄', style: TextStyle(fontSize: 20)), label: Text('Backup')),
                  NavigationRailDestination(icon: Text('☁️', style: TextStyle(fontSize: 20)), selectedIcon: Text('☁️', style: TextStyle(fontSize: 20)), label: Text('Backup na Nuvem')),
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
        drawer: _AppDrawer(onNavigateIndex: (index) => _goToIndex(context, index)),
        body: child,
      );
    }),
    );
  }

  int _selectedIndexForLocation(String location) {
    if (location.startsWith('/corridas')) return 1;
    if (location.startsWith('/estatisticas')) return 2;
    if (location.startsWith('/reports')) return 3;
    if (location.startsWith('/backup')) return 4;
    if (location.startsWith('/cloud-backup')) return 5;
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
        context.go('/reports');
        break;
      case 4:
        context.go('/backup');
        break;
      case 5:
        context.go('/cloud-backup');
        break;
    }
  }
}

class _AppDrawer extends StatelessWidget {
  final ValueChanged<int> onNavigateIndex;
  const _AppDrawer({required this.onNavigateIndex});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(Icons.directions_run, size: 24),
                    SizedBox(width: 8),
                    Text('GerCorridas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Text('📋', style: TextStyle(fontSize: 20)),
              title: const Text('Dashboard'),
              onTap: () {
                Scaffold.maybeOf(context)?.closeDrawer();
                onNavigateIndex(0);
              },
            ),
            ListTile(
              leading: const Text('🏃', style: TextStyle(fontSize: 20)),
              title: const Text('Corridas'),
              onTap: () {
                Scaffold.maybeOf(context)?.closeDrawer();
                onNavigateIndex(1);
              },
            ),
            ListTile(
              leading: const Text('📊', style: TextStyle(fontSize: 20)),
              title: const Text('Estatísticas'),
              onTap: () {
                Scaffold.maybeOf(context)?.closeDrawer();
                onNavigateIndex(2);
              },
            ),
            ListTile(
              leading: const Text('📈', style: TextStyle(fontSize: 20)),
              title: const Text('Relatórios'),
              onTap: () {
                Scaffold.maybeOf(context)?.closeDrawer();
                onNavigateIndex(3);
              },
            ),
            ListTile(
              leading: const Text('🔄', style: TextStyle(fontSize: 20)),
              title: const Text('Backup'),
              onTap: () {
                Scaffold.maybeOf(context)?.closeDrawer();
                onNavigateIndex(4);
              },
            ),
            ListTile(
              leading: const Text('☁️', style: TextStyle(fontSize: 20)),
              title: const Text('Backup na Nuvem'),
              onTap: () {
                Scaffold.maybeOf(context)?.closeDrawer();
                onNavigateIndex(5);
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
