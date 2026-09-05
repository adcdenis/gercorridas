import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:gercorridas/state/providers.dart';
import 'package:gercorridas/presentation/widgets/premium_paywall_widget.dart';
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
      // voltar leva à listagem de corridas; somente nela perguntar para sair.
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

        // Se puder dar pop na pilha interna do roteador (ex: voltando de tela de detalhe/edição)
        if (router.canPop()) {
          router.pop();
          return;
        }

        // Se estiver em outra página que não a raiz de corridas ou dashboard, retorna para /corridas
        if (location != '/corridas' && location != '/') {
          router.go('/corridas');
          return;
        }

        // Na tela principal, confirma saída
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
      },
      child: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final cs = Theme.of(context).colorScheme;
        final currentLocation = GoRouterState.of(context).uri.toString();
        final title = Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cs.onPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.directions_run, size: 20, color: isWide ? cs.onPrimary : null),
            ),
            const SizedBox(width: 10),
            const Text('PlanRace'),
          ],
        );

      if (isWide) {
        final selectedIndex = _selectedIndexForLocation(currentLocation);
        return Scaffold(
          appBar: AppBar(title: title, actions: const [
            _PremiumCrownButton(),
            _ThemeToggleButton(),
            Padding(
              padding: EdgeInsets.only(right: 12.0),
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
                minWidth: 72,
                minExtendedWidth: 200,
                elevation: 2,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                indicatorColor: Theme.of(context).colorScheme.primaryContainer,
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: const _VersionFooter(),
                    ),
                  ),
                ),
                destinations: [
                  NavigationRailDestination(icon: Icon(Icons.dashboard_outlined, color: cs.primary), selectedIcon: Icon(Icons.dashboard, color: cs.primary), label: const Text('Dashboard')),
                  NavigationRailDestination(icon: Icon(Icons.directions_run, color: cs.secondary), selectedIcon: Icon(Icons.directions_run, color: cs.secondary), label: const Text('Corridas')),
                  NavigationRailDestination(icon: Icon(Icons.insights_outlined, color: cs.error), selectedIcon: Icon(Icons.insights, color: cs.error), label: const Text('Estatísticas')),
                  NavigationRailDestination(icon: Icon(Icons.account_tree_outlined, color: cs.tertiary), selectedIcon: Icon(Icons.account_tree, color: cs.tertiary), label: const Text('Mapa Mental')),
                  NavigationRailDestination(icon: Icon(Icons.assignment_outlined, color: cs.primary), selectedIcon: Icon(Icons.assignment, color: cs.primary), label: const Text('Relatórios')),
                  NavigationRailDestination(icon: Icon(Icons.sync_alt, color: cs.secondary), selectedIcon: Icon(Icons.sync, color: cs.secondary), label: const Text('Backup')),
                  NavigationRailDestination(icon: Icon(Icons.payments, color: cs.primary), selectedIcon: Icon(Icons.payments, color: cs.primary), label: const Text('Finanças')),
                ],
              ),
              VerticalDivider(width: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
              Expanded(child: child),
            ],
          ),
        );
      }

      final bottomNavIndex = _bottomNavIndexForLocation(currentLocation);

      return Scaffold(
        appBar: AppBar(title: title, centerTitle: false, actions: const [
          _PremiumCrownButton(),
          _ThemeToggleButton(),
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: _ProfileAvatar(),
          ),
        ]),
        drawer: _AppDrawer(
          selectedIndex: _selectedIndexForLocation(currentLocation),
          onNavigateIndex: (index) => _goToIndex(context, index),
        ),
        body: child,
        bottomNavigationBar: bottomNavIndex != null
            ? NavigationBar(
                selectedIndex: bottomNavIndex,
                onDestinationSelected: (index) => _onBottomNavTapped(context, index),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: 'Dashboard',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.directions_run_outlined),
                    selectedIcon: Icon(Icons.directions_run),
                    label: 'Corridas',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.insights_outlined),
                    selectedIcon: Icon(Icons.insights),
                    label: 'Estatísticas',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.payments_outlined),
                    selectedIcon: Icon(Icons.payments),
                    label: 'Finanças',
                  ),
                ],
              )
            : null,
      );
    }),
    );
  }

  int? _bottomNavIndexForLocation(String location) {
    if (location == '/') return 0;
    if (location.startsWith('/corridas')) return 1;
    if (location.startsWith('/estatisticas')) return 2;
    if (location.startsWith('/financas')) return 3;
    return null;
  }

  void _onBottomNavTapped(BuildContext context, int index) {
    HapticFeedback.lightImpact();
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
        context.go('/financas');
        break;
    }
  }

  int _selectedIndexForLocation(String location) {
    if (location.startsWith('/corridas')) return 1;
    if (location.startsWith('/estatisticas')) return 2;
    if (location.startsWith('/mapa-mental')) return 3;
    if (location.startsWith('/reports')) return 4;
    if (location.startsWith('/backup')) return 5;
    if (location.startsWith('/cloud-backup')) return 5;
    if (location.startsWith('/financas')) return 6;
    return 0;
  }

  void _goToIndex(BuildContext context, int index) {
    HapticFeedback.lightImpact();
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
        context.go('/financas');
        break;
    }
  }
}

class _AppDrawer extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavigateIndex;
  const _AppDrawer({required this.selectedIndex, required this.onNavigateIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(premiumProvider);
    final cs = Theme.of(context).colorScheme;

    Widget tile({required int index, required String label, required Widget leading, String? subtitle}) {
      final selected = selectedIndex == index;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Material(
          color: selected ? cs.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Scaffold.maybeOf(context)?.closeDrawer();
              onNavigateIndex(index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: selected
                    ? Border.all(color: cs.primary.withValues(alpha: 0.2))
                    : null,
              ),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 15,
                            color: selected ? cs.onPrimaryContainer : cs.onSurface,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(Icons.chevron_right, size: 18, color: cs.primary),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header do Drawer com gradiente
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primaryContainer, cs.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.onPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.directions_run, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('PlanRace', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isPro ? Colors.amber : Colors.white24,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isPro ? 'PRO' : 'FREE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: isPro ? Colors.black : Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('Organize suas corridas', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text(
                      'PRINCIPAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  tile(index: 0, label: 'Dashboard', subtitle: 'Visão geral', leading: Icon(Icons.dashboard_outlined, color: cs.primary)),
                  tile(index: 1, label: 'Corridas', subtitle: 'Seus eventos', leading: Icon(Icons.directions_run, color: cs.secondary)),
                  tile(index: 2, label: 'Estatísticas', subtitle: 'Análise detalhada', leading: Icon(Icons.insights_outlined, color: cs.error)),
                  tile(index: 6, label: 'Finanças', subtitle: 'Controle financeiro', leading: Icon(Icons.payments, color: cs.primary)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(height: 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text(
                      'FERRAMENTAS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  tile(index: 3, label: 'Mapa Mental', subtitle: 'Planejamento visual', leading: Icon(Icons.account_tree_outlined, color: cs.tertiary)),
                  tile(index: 4, label: 'Relatórios', subtitle: 'Exportar dados', leading: Icon(Icons.assignment_outlined, color: cs.primary)),
                  tile(index: 5, label: 'Backup & Nuvem', subtitle: 'Local e Google Drive', leading: Icon(Icons.sync_alt, color: cs.secondary)),
                ],
              ),
            ),
            Divider(color: cs.outlineVariant.withValues(alpha: 0.3)),
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
          Icon(Icons.info_outline, size: 14, color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Text(v, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant.withValues(alpha: 0.6))),
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
    Widget defaultAvatar() => Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: cs.onPrimary.withValues(alpha: 0.3), width: 1.5),
          ),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: cs.onPrimary.withValues(alpha: 0.1),
            child: Icon(Icons.person_outline, size: 18, color: cs.onPrimary.withValues(alpha: 0.7)),
          ),
        );

    return userAsync.maybeWhen(
      data: (user) {
        if (user == null || user.photoUrl == null) {
          return defaultAvatar();
        }
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: cs.onPrimary.withValues(alpha: 0.3), width: 1.5),
          ),
          child: CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage(user.photoUrl!),
            backgroundColor: cs.surface,
          ),
        );
      },
      orElse: () => defaultAvatar(),
    );
  }
}

// Botão da coroa Pro com efeito shimmer animado
class _PremiumCrownButton extends ConsumerWidget {
  const _PremiumCrownButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(premiumProvider);
    // Em produção, só exibimos o ícone de coroa no cabeçalho se o usuário for Pro
    if (!useSimulatedBilling && !isPro) {
      return const SizedBox.shrink();
    }
    return Tooltip(
      message: isPro ? 'Você é Pro! Obrigado pelo apoio.' : 'Seja Pro! Clique para saber mais',
      child: isPro
          ? _ShimmerIcon(
              onPressed: useSimulatedBilling ? () => _showPremiumDialog(context, ref) : null,
              child: Icon(
                Icons.workspace_premium,
                color: Colors.amber.shade600,
              ),
            )
          : IconButton(
              icon: const Icon(Icons.workspace_premium_outlined),
              onPressed: useSimulatedBilling ? () => _showPremiumDialog(context, ref) : null,
            ),
    );
  }

  void _showPremiumDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.workspace_premium, color: Colors.amber),
            SizedBox(width: 8),
            Text('PlanRace Pro'),
          ],
        ),
        content: const SizedBox(
          width: 400,
          child: PremiumPaywallWidget(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

// Widget de ícone com shimmer para a coroa Pro
class _ShimmerIcon extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  const _ShimmerIcon({required this.child, this.onPressed});

  @override
  State<_ShimmerIcon> createState() => _ShimmerIconState();
}

class _ShimmerIconState extends State<_ShimmerIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-1.0 + 2.0 * _controller.value + 1.0, 0),
              colors: const [
                Colors.amber,
                Colors.white,
                Colors.amber,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: child,
        );
      },
      child: IconButton(
        icon: widget.child,
        onPressed: widget.onPressed,
      ),
    );
  }
}

// Botão para alternar entre tema claro e escuro
class _ThemeToggleButton extends ConsumerWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
                  (themeMode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Tooltip(
      message: isDark ? 'Mudar para tema claro' : 'Mudar para tema escuro',
      child: IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => RotationTransition(
            turns: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Icon(
            isDark ? Icons.light_mode : Icons.dark_mode,
            key: ValueKey(isDark),
          ),
        ),
        onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
      ),
    );
  }
}
