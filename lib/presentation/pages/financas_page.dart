import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gercorridas/state/providers.dart';
import 'package:gercorridas/data/models/counter.dart' as model;

class FinancasPage extends ConsumerStatefulWidget {
  const FinancasPage({super.key});

  @override
  ConsumerState<FinancasPage> createState() => _FinancasPageState();
}

class _FinancasPageState extends ConsumerState<FinancasPage> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  List<double> _monthlyTotals(List<model.Counter> counters) {
    final statuses = {'inscrito', 'concluida', 'nao_pude_ir'};
    final totals = List<double>.filled(12, 0);
    for (final c in counters) {
      if (c.price == null) continue;
      if (!statuses.contains(c.status)) continue;
      final d = c.eventDate;
      if (d.year != _year) continue;
      totals[d.month - 1] += c.price!;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final countersAsync = ref.watch(corridasProvider);
    final cs = Theme.of(context).colorScheme;
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    final monthLabels = const ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
    final monthColors = const [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.cyan,
      Colors.lime,
      Colors.pink,
      Colors.amber,
      Colors.brown,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.payments),
            const SizedBox(width: 8),
            const Text('Finanças', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<int>(
                value: countersAsync.maybeWhen(
                  data: (list) {
                    final years = list.map((c) => c.eventDate.year).toSet().toList()..sort((a,b) => b.compareTo(a));
                    final selected = years.contains(_year) ? _year : (years.isNotEmpty ? years.first : _year);
                    return selected;
                  },
                  orElse: () => _year,
                ),
                items: countersAsync.maybeWhen(
                  data: (list) {
                    final years = list.map((c) => c.eventDate.year).toSet().toList()..sort((a,b) => b.compareTo(a));
                    return years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList();
                  },
                  orElse: () => [DropdownMenuItem(value: _year, child: Text(_year.toString()))],
                ),
                onChanged: (y) => setState(() => _year = y ?? _year),
                decoration: const InputDecoration(labelText: 'Ano'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          const Text('Gasto total mês a mês. Filtre por ano.'),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          countersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Erro ao carregar: $e')),
            data: (counters) {
              final totals = _monthlyTotals(counters);
              final maxVal = totals.fold<double>(0, (p, v) => v > p ? v : p);
              final annual = totals.fold<double>(0, (p, v) => p + v);
              

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text('Gastos por mês'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(builder: (context, constraints) {
                        final labelWidth = 50.0;
                        final spacing = 8.0;
                        final maxBarWidth = constraints.maxWidth - labelWidth - spacing;
                        const barHeight = 24.0;
                        return Column(
                          children: [
                            for (int i = 0; i < 12; i++) ...[
                              Row(
                                children: [
                                  SizedBox(
                                    width: labelWidth,
                                    child: Text(monthLabels[i], style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: maxVal > 0 ? (totals[i] / maxVal) * maxBarWidth : 2,
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: monthColors[i],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        );
                      }),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (int i = 0; i < 12; i++)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(color: monthColors[i], borderRadius: BorderRadius.circular(2)),
                                ),
                                const SizedBox(width: 6),
                                Text(currency.format(totals[i]), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Total anual: ${currency.format(annual)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}