import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../pages/dashboard_page.dart';
import '../pages/corrida_detail_page.dart';
import '../pages/corrida_form_page.dart';
import '../pages/corrida_list_page.dart';
import '../pages/reports_page.dart';
import '../pages/statistics_page.dart';
import '../pages/backup_page.dart';
import '../pages/cloud_backup_page.dart';
import '../widgets/app_shell.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/corridas',
    routes: <RouteBase>[
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'dashboard',
            pageBuilder: (context, state) => const MaterialPage(child: DashboardPage()),
          ),
          GoRoute(
            path: '/corridas',
            name: 'corridas',
            pageBuilder: (context, state) => const MaterialPage(child: CorridaListPage()),
          ),
          GoRoute(
            path: '/estatisticas',
            name: 'estatisticas',
            pageBuilder: (context, state) => const MaterialPage(child: StatisticsPage()),
          ),
          GoRoute(
            path: '/corrida/new',
            name: 'corrida_new',
            pageBuilder: (context, state) => const MaterialPage(child: CorridaFormPage()),
          ),
          GoRoute(
            path: '/corrida/:id',
            name: 'corrida_detail',
            pageBuilder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return MaterialPage(child: CorridaDetailPage(counterId: id));
            },
          ),
          GoRoute(
            path: '/corrida/:id/edit',
            name: 'corrida_edit',
            pageBuilder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return MaterialPage(child: CorridaFormPage(counterId: id));
            },
          ),
          GoRoute(
            path: '/reports',
            name: 'reports',
            pageBuilder: (context, state) => const MaterialPage(child: ReportsPage()),
          ),
          GoRoute(
            path: '/backup',
            name: 'backup',
            pageBuilder: (context, state) => const MaterialPage(child: BackupPage()),
          ),
          GoRoute(
            path: '/cloud-backup',
            name: 'cloud_backup',
            pageBuilder: (context, state) => const MaterialPage(child: CloudBackupPage()),
          ),
        ],
      ),
    ],
  );
}
