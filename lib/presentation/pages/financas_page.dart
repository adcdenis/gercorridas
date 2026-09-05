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
    final monthLabels = const ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.payments_rounded, size: 20, color: cs.primary),
              ),
              const SizedBox(width: 10),
              const Text('Finanças', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isDense: true,
                    value: countersAsync.maybeWhen(
                      data: (list) {
                        final years = list.map((c) => c.eventDate.year).toSet().toList()..sort((a, b) => b.compareTo(a));
                        final selected = years.contains(_year) ? _year : (years.isNotEmpty ? years.first : _year);
                        return selected;
                      },
                      orElse: () => _year,
                    ),
                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                    items: countersAsync.maybeWhen(
                      data: (list) {
                        final years = list.map((c) => c.eventDate.year).toSet().toList()..sort((a, b) => b.compareTo(a));
                        return years.map((y) => DropdownMenuItem(value: y, child: Text(y.toString(), style: const TextStyle(fontWeight: FontWeight.w600)))).toList();
                      },
                      orElse: () => [DropdownMenuItem(value: _year, child: Text(_year.toString(), style: const TextStyle(fontWeight: FontWeight.w600)))],
                    ),
                    onChanged: (y) => setState(() => _year = y ?? _year),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Controle de investimento em inscrições mês a mês',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          countersAsync.when(
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            )),
            error: (e, st) => Center(child: Text('Erro ao carregar: $e')),
            data: (counters) {
              final totals = _monthlyTotals(counters);
              final maxVal = totals.fold<double>(0, (p, v) => v > p ? v : p);
              final annual = totals.fold<double>(0, (p, v) => p + v);
              final activeMonths = totals.where((v) => v > 0).length;
              final monthlyAvg = activeMonths > 0 ? annual / activeMonths : 0.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card de Resumo Anual
                  Card(
                    color: cs.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'INVESTIMENTO TOTAL EM $_year',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  currency.format(annual),
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: cs.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 44,
                            width: 1,
                            color: cs.outlineVariant.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MÉDIA / MÊS ATIVO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currency.format(monthlyAvg),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gráfico de Barras Mensal com visual refinado
                  Card(
                    color: cs.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.bar_chart_rounded, size: 18, color: cs.primary),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Evolução Mensal',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(builder: (context, constraints) {
                            const labelWidth = 36.0;
                            const valueWidth = 84.0;
                            const spacing = 10.0;
                            final maxBarWidth = constraints.maxWidth - labelWidth - valueWidth - (spacing * 2);
                            const barHeight = 18.0;

                            return Column(
                              children: [
                                for (int i = 0; i < 12; i++) ...[
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: labelWidth,
                                        child: Text(
                                          monthLabels[i],
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: totals[i] > 0 ? FontWeight.w700 : FontWeight.w500,
                                            color: totals[i] > 0 ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: spacing),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            width: maxVal > 0 && totals[i] > 0
                                                ? ((totals[i] / maxVal) * maxBarWidth).clamp(6.0, maxBarWidth)
                                                : 2,
                                            height: barHeight,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(6),
                                              gradient: totals[i] > 0
                                                  ? LinearGradient(
                                                      colors: [
                                                        cs.primary,
                                                        cs.primary.withValues(alpha: 0.7),
                                                      ],
                                                    )
                                                  : null,
                                              color: totals[i] == 0
                                                  ? cs.outlineVariant.withValues(alpha: 0.25)
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: spacing),
                                      SizedBox(
                                        width: valueWidth,
                                        child: Text(
                                          totals[i] > 0 ? currency.format(totals[i]) : '—',
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: totals[i] > 0 ? FontWeight.w700 : FontWeight.w400,
                                            color: totals[i] > 0 ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.4),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (i < 11) const SizedBox(height: 10),
                                ],
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}