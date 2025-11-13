import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gercorridas/state/providers.dart';
import 'package:gercorridas/data/models/counter.dart' as model;

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  int _selectedYear = DateTime.now().year;
  int? _selectedMonth;

  List<model.Counter> _applyYearMonthFilter(List<model.Counter> list) {
    var out = list.where((c) => c.eventDate.year == _selectedYear).toList();
    if (_selectedMonth != null) {
      out = out.where((c) => c.eventDate.month == _selectedMonth).toList();
    }
    return out;
  }

  Duration? _parseDuration(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final parts = s.split(':');
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final sec = int.tryParse(parts[2]) ?? 0;
      return Duration(hours: h, minutes: m, seconds: sec);
    } else if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final sec = int.tryParse(parts[1]) ?? 0;
      return Duration(minutes: m, seconds: sec);
    }
    return null;
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return [h, m, s].map((v) => v.toString().padLeft(2, '0')).join(':');
  }

  @override
  Widget build(BuildContext context) {
    final countersAsync = ref.watch(corridasProvider);
    final cs = Theme.of(context).colorScheme;
    // final df = DateFormat('dd/MM/yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Text('📊', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text('Estatísticas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),

          countersAsync.when(
            loading: () => Card(
              color: cs.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outline.withValues(alpha: 0.12))),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: LinearProgressIndicator(),
              ),
            ),
            error: (e, st) => Card(
              color: cs.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outline.withValues(alpha: 0.12))),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Erro ao carregar filtros'),
              ),
            ),
            data: (counters) {
              final years = {
                for (final c in counters) c.eventDate.year
              }..add(DateTime.now().year);
              final sortedYears = years.toList()..sort();
              final monthNames = const [
                'Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'
              ];

              return Card(
                color: cs.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outline.withValues(alpha: 0.12))),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: const [
                      Icon(Icons.filter_alt, size: 18),
                      SizedBox(width: 8),
                      Text('Filtrar por Período', style: TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selectedYear,
                          items: [
                            for (final y in sortedYears) DropdownMenuItem(value: y, child: Text('$y')),
                          ],
                          onChanged: (v) => setState(() => _selectedYear = v ?? _selectedYear),
                          decoration: const InputDecoration(labelText: 'Ano'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: _selectedMonth,
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('Todos')),
                            for (int m = 1; m <= 12; m++) DropdownMenuItem<int?>(value: m, child: Text(monthNames[m-1])),
                          ],
                          onChanged: (v) => setState(() => _selectedMonth = v),
                          decoration: const InputDecoration(labelText: 'Mês (opcional)'),
                        ),
                      ),
                    ]),
                  ]),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          countersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Erro ao carregar: $e')),
            data: (counters) {
              final filtered = _applyYearMonthFilter(counters);
              final concluded = filtered.where((c) => c.status == 'concluida').toList();
              Duration? bestForKm(int km) {
                final list = concluded.where((c) => c.distanceKm.round() == km).toList();
                Duration? best;
                for (final c in list) {
                  final d = _parseDuration(c.finishTime);
                  if (d == null) continue;
                  if (best == null || d < best) best = d;
                }
                return best;
              }
              String? bestRaceLabel(int km) {
                final list = concluded.where((c) => c.distanceKm.round() == km && _parseDuration(c.finishTime) != null).toList();
                list.sort((a, b) => _parseDuration(a.finishTime)!.compareTo(_parseDuration(b.finishTime)!));
                if (list.isEmpty) return null;
                final first = list.first;
                final t = _parseDuration(first.finishTime);
                final ts = _formatDuration(t);
                return ts.isEmpty ? first.name : '${first.name} • $ts';
              }

              final totalCorridasConcluidas = filtered.where((c) => c.status == 'concluida').length;
              final distanciaTotal = concluded.fold<double>(0.0, (sum, c) => sum + c.distanceKm);
              int countStatus(String s) => filtered.where((c) => c.status == s).length;
              final inscricoes = countStatus('inscrito');
              final concluidas = countStatus('concluida');
              final pretendo = countStatus('pretendo_ir');
              final canceladas = countStatus('cancelada');
              final naDuvida = countStatus('na_duvida');
              final naoPude = countStatus('nao_pude_ir');
              final valorTotalGasto = filtered
                  .where((c) => c.status == 'inscrito' || c.status == 'concluida' || c.status == 'nao_pude_ir')
                  .fold<double>(0.0, (sum, c) => sum + (c.price ?? 0.0));
              final valorPerdido = filtered
                  .where((c) => c.status == 'nao_pude_ir')
                  .fold<double>(0.0, (sum, c) => sum + (c.price ?? 0.0));
              final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

              return Column(
                children: [
                  LayoutBuilder(builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 900;
                    final cross = isNarrow ? 2 : 4;
                    final extent = isNarrow ? 130.0 : 110.0;
                    return GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: extent,
                      ),
                      children: [
                        _metricCard(context, emoji: '🕒', title: 'RP nos 5km', value: _formatDuration(bestForKm(5)), subtitle: bestRaceLabel(5)),
                        _metricCard(context, emoji: '🕒', title: 'RP nos 10km', value: _formatDuration(bestForKm(10)), subtitle: bestRaceLabel(10)),
                        _metricCard(context, emoji: '🕒', title: 'RP nos 21km', value: _formatDuration(bestForKm(21)), subtitle: bestRaceLabel(21)),
                        _metricCard(context, emoji: '🕒', title: 'RP nos 42km', value: _formatDuration(bestForKm(42)), subtitle: bestRaceLabel(42)),
                        _metricCard(context, emoji: '🏆', title: 'Total de Corridas', value: '$totalCorridasConcluidas'),
                        _metricCard(context, emoji: '📍', title: 'Distância Total', value: '${distanciaTotal.toStringAsFixed(1)} km'),
                        _metricCard(context, emoji: '🎯', title: 'Inscrições', value: '$inscricoes'),
                        _metricCard(context, emoji: '🏅', title: 'Concluídas', value: '$concluidas'),
                        _metricCard(context, emoji: '🗓️', title: 'Pretendo Ir', value: '$pretendo'),
                        _metricCard(context, emoji: '✖️', title: 'Canceladas', value: '$canceladas'),
                        _metricCard(context, emoji: '〰️', title: 'Na Dúvida', value: '$naDuvida'),
                        _metricCard(context, emoji: '⛔', title: 'Não Pude Ir', value: '$naoPude'),
                        _metricCard(context, emoji: '💲', title: 'Valor Total Gasto', value: currency.format(valorTotalGasto)),
                        _metricCard(context, emoji: '❌', title: 'Valor Perdido', value: currency.format(valorPerdido)),
                      ],
                    );
                  }),

                  const SizedBox(height: 16),

                  Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outline.withValues(alpha: 0.12))),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.calendar_month, size: 18),
                          const SizedBox(width: 8),
                          Text('Resumo do Período (Ano: $_selectedYear, Mês: ${_selectedMonth ?? 'Todos'})',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 12),
                        LayoutBuilder(builder: (context, constraints) {
                          final isNarrow2 = constraints.maxWidth < 900;
                          final cross2 = isNarrow2 ? 1 : 3;
                          final extent2 = isNarrow2 ? 100.0 : 90.0;
                          return GridView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cross2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              mainAxisExtent: extent2,
                            ),
                            children: [
                              _summaryCard(context, emoji: '🏃', title: 'Corridas Registradas', value: '${filtered.length}'),
                              _summaryCard(context, emoji: '💰', title: 'Investimento Total', value: currency.format(valorTotalGasto)),
                              _summaryCard(context, emoji: '📍', title: 'Distância Total', value: '${distanciaTotal.toStringAsFixed(1)} km'),
                            ],
                          );
                        }),
                      ]),
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

  Widget _metricCard(BuildContext context, {required String emoji, required String title, required String value, String? subtitle}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outline.withValues(alpha: 0.12))),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurface)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
                if (value.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context, {required String emoji, required String title, required String value}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outline.withValues(alpha: 0.12))),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    );
  }
}