import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'backup_page.dart';
import 'cloud_backup_page.dart';

class BackupTabsPage extends ConsumerStatefulWidget {
  final int initialIndex; // 0: Nuvem, 1: Arquivo
  const BackupTabsPage({super.key, this.initialIndex = 0});

  @override
  ConsumerState<BackupTabsPage> createState() => _BackupTabsPageState();
}

class _BackupTabsPageState extends ConsumerState<BackupTabsPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialIndex.clamp(0, 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          TabBar(
            isScrollable: false,
            tabs: [
              Tab(text: 'Backup na Nuvem', icon: Icon(Icons.cloud_outlined)),
              Tab(text: 'Backup Arquivo', icon: Icon(Icons.sync_alt)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                CloudBackupPage(),
                BackupPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}