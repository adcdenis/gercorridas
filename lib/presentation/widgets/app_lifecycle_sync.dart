import 'package:flutter/widgets.dart';

/// Wrapper simples que atualmente não dispara backups por ciclo de vida.
/// Mantido para futura extensão, mas sem efeitos colaterais.
class AppLifecycleSync extends StatelessWidget {
  final Widget child;
  const AppLifecycleSync({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}