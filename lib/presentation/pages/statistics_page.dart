import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gercorridas/state/providers.dart';
import 'package:gercorridas/data/models/counter.dart' as model;
import 'package:gercorridas/domain/time_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gercorridas/core/text_sanitizer.dart';

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  late DateTime _startDate;
  late DateTime _endDate;
  int _selectedYear = DateTime.now().year;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, 1, 1);
    _endDate = DateTime(now.year, 12, 31, 23, 59, 59);
    _selectedYear = now.year;
  }

  List<model.Counter> _applyDateRangeFilter(List<model.Counter> list) {
    return list
        .where(
          (c) =>
              c.eventDate.isAfter(
                _startDate.subtract(const Duration(milliseconds: 1)),
              ) &&
              c.eventDate.isBefore(
                _endDate.add(const Duration(milliseconds: 1)),
              ),
        )
        .toList();
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

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL invalida')),
        );
      }
      return;
    }
    final openedExternal = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!openedExternal) {
      final openedInApp = await launchUrl(
        uri,
        mode: LaunchMode.inAppWebView,
        webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
      );
      if (!openedInApp && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel abrir o link')),
        );
      }
    }
  }

  void _shareRace(model.Counter race) {
    final effectiveDate = DateTime(
      race.eventDate.year,
      race.eventDate.month,
      race.eventDate.day,
      race.eventDate.hour,
      race.eventDate.minute,
      race.eventDate.second,
      race.eventDate.millisecond,
      race.eventDate.microsecond,
    );
    final isFuture = effectiveDate.isAfter(DateTime.now());
    final shareText = buildShareText(race, effectiveDate, isFuture);
    final sanitizedText = sanitizeForShare(shareText);
    final sanitizedSubject = sanitizeForShare('Corrida: ${race.name}');
    Share.share(sanitizedText, subject: sanitizedSubject);
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
          Row(
            children: [
              const Text('📊', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Estatísticas',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              countersAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (items) {
                  final years = {
                    for (final c in items) c.eventDate.year,
                  }.toList()
                    ..sort();
                  if (years.isEmpty) return const SizedBox.shrink();
                  if (!years.contains(_selectedYear)) {
                    Future.microtask(() {
                      if (!mounted) return;
                      setState(() {
                        _selectedYear = years.last;
                        _startDate = DateTime(_selectedYear, 1, 1);
                        _endDate = DateTime(_selectedYear, 12, 31, 23, 59, 59);
                      });
                    });
                  }
                  return SizedBox(
                    width: 84,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isDense: true,
                        value: years.contains(_selectedYear) ? _selectedYear : years.last,
                        items: [
                          for (final y in years) DropdownMenuItem(value: y, child: Text('$y')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _selectedYear = v;
                            _startDate = DateTime(v, 1, 1);
                            _endDate = DateTime(v, 12, 31, 23, 59, 59);
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: _showFilters ? 'Ocultar filtro' : 'Mostrar filtro',
                child: IconButton.filledTonal(
                  icon: Icon(_showFilters ? Icons.search_off : Icons.search),
                  onPressed: () => setState(() => _showFilters = !_showFilters),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_showFilters)
            countersAsync.when(
              loading: () => Card(
                color: cs.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cs.outline.withValues(alpha: 0.12)),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: LinearProgressIndicator(),
                ),
              ),
              error: (e, st) => Card(
                color: cs.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cs.outline.withValues(alpha: 0.12)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Erro ao carregar filtros'),
                ),
              ),
              data: (items) {
                final df = DateFormat('dd/MM/yyyy');
                return Card(
                  color: cs.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.outline.withValues(alpha: 0.12)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.filter_alt, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Filtrar por Período',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _startDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    final newStart = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                    );
                                    var newEnd = _endDate;
                                    final maxEnd = DateTime(
                                      newStart.year + 10,
                                      newStart.month,
                                      newStart.day,
                                      23,
                                      59,
                                      59,
                                    );
                                    if (newEnd.isBefore(newStart)) {
                                      newEnd = DateTime(
                                        newStart.year,
                                        newStart.month,
                                        newStart.day,
                                        23,
                                        59,
                                        59,
                                      );
                                    }
                                    if (newEnd.isAfter(maxEnd)) {
                                      newEnd = maxEnd;
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Intervalo máximo de 10 anos',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                    setState(() {
                                      _startDate = newStart;
                                      _endDate = newEnd;
                                      _selectedYear = newStart.year;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.date_range),
                                label: Text('Início: ${df.format(_startDate)}'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _endDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    var selectedEnd = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                      23,
                                      59,
                                      59,
                                    );
                                    final maxEnd = DateTime(
                                      _startDate.year + 10,
                                      _startDate.month,
                                      _startDate.day,
                                      23,
                                      59,
                                      59,
                                    );
                                    if (selectedEnd.isBefore(_startDate)) {
                                      selectedEnd = DateTime(
                                        _startDate.year,
                                        _startDate.month,
                                        _startDate.day,
                                        23,
                                        59,
                                        59,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Fim não pode ser antes do início',
                                            ),
                                          ),
                                        );
                                      }
                                    } else if (selectedEnd.isAfter(maxEnd)) {
                                      selectedEnd = maxEnd;
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Intervalo máximo de 10 anos',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                    setState(() => _endDate = selectedEnd);
                                  }
                                },
                                icon: const Icon(Icons.event),
                                label: Text('Fim: ${df.format(_endDate)}'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 16),

          countersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Erro ao carregar: $e')),
            data: (counters) {
              final filtered = _applyDateRangeFilter(counters);
              final concluded = filtered
                  .where((c) => c.status == 'concluida')
                  .toList();
              Duration? bestForKm(int km) {
                final list = concluded
                    .where((c) => c.distanceKm >= km && c.distanceKm < (km + 1))
                    .toList();
                Duration? best;
                for (final c in list) {
                  final d = _parseDuration(c.finishTime);
                  if (d == null) continue;
                  if (best == null || d < best) best = d;
                }
                return best;
              }

              model.Counter? bestRaceForKm(int km) {
                final list = concluded
                    .where(
                      (c) =>
                          c.distanceKm >= km &&
                          c.distanceKm < (km + 1) &&
                          _parseDuration(c.finishTime) != null,
                    )
                    .toList();
                list.sort(
                  (a, b) => _parseDuration(
                    a.finishTime,
                  )!.compareTo(_parseDuration(b.finishTime)!),
                );
                if (list.isEmpty) return null;
                return list.first;
              }

              String? bestRaceLabel(int km) {
                final list = concluded
                    .where(
                      (c) =>
                          c.distanceKm >= km &&
                          c.distanceKm < (km + 1) &&
                          _parseDuration(c.finishTime) != null,
                    )
                    .toList();
                list.sort(
                  (a, b) => _parseDuration(
                    a.finishTime,
                  )!.compareTo(_parseDuration(b.finishTime)!),
                );
                if (list.isEmpty) return null;
                final first = list.first;
                return first.name;
              }

              String? bestRacePace(int km) {
                final list = concluded
                    .where(
                      (c) =>
                          c.distanceKm >= km &&
                          c.distanceKm < (km + 1) &&
                          _parseDuration(c.finishTime) != null,
                    )
                    .toList();
                list.sort(
                  (a, b) => _parseDuration(
                    a.finishTime,
                  )!.compareTo(_parseDuration(b.finishTime)!),
                );
                if (list.isEmpty) return null;
                final first = list.first;
                final t = _parseDuration(first.finishTime);
                return computePace(t, first.distanceKm);
              }

              final totalCorridasConcluidas = filtered
                  .where((c) => c.status == 'concluida')
                  .length;
              final distanciaTotal = concluded.fold<double>(
                0.0,
                (sum, c) => sum + c.distanceKm,
              );
              int countStatus(String s) =>
                  filtered.where((c) => c.status == s).length;
              final inscricoes = countStatus('inscrito');
              final concluidas = countStatus('concluida');
              final pretendo = countStatus('pretendo_ir');
              final canceladas = countStatus('cancelada');
              final naDuvida = countStatus('na_duvida');
              final naoPude = countStatus('nao_pude_ir');
              final valorTotalGasto = filtered
                  .where(
                    (c) =>
                        c.status == 'inscrito' ||
                        c.status == 'concluida' ||
                        c.status == 'nao_pude_ir',
                  )
                  .fold<double>(0.0, (sum, c) => sum + (c.price ?? 0.0));
              final valorPerdido = filtered
                  .where((c) => c.status == 'nao_pude_ir')
                  .fold<double>(0.0, (sum, c) => sum + (c.price ?? 0.0));
              final currency = NumberFormat.currency(
                locale: 'pt_BR',
                symbol: 'R\$',
              );

              return Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 900;
                      final cross = isNarrow ? 2 : 4;
                      final extentRP = isNarrow ? 128.0 : 112.0;
                      final extentOther = isNarrow ? 92.0 : 84.0;
                      return Column(
                        children: [
                          GridView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cross,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: extentRP,
                                ),
                            children: [
                              _metricCard(
                                context,
                                emoji: '⏱️',
                                title: 'RP nos 5km',
                                value: _formatDuration(bestForKm(5)),
                                subtitle: bestRaceLabel(5),
                                footer: (() {
                                  final p = bestRacePace(5);
                                  return p;
                                })(),
                                onTap: () => _showRaceDialog(context, bestRaceForKm(5)),
                              ),
                              _metricCard(
                                context,
                                emoji: '⏱️',
                                title: 'RP nos 10km',
                                value: _formatDuration(bestForKm(10)),
                                subtitle: bestRaceLabel(10),
                                footer: (() {
                                  final p = bestRacePace(10);
                                  return p;
                                })(),
                                onTap: () => _showRaceDialog(context, bestRaceForKm(10)),
                              ),
                              _metricCard(
                                context,
                                emoji: '⏱️',
                                title: 'RP nos 21km',
                                value: _formatDuration(bestForKm(21)),
                                subtitle: bestRaceLabel(21),
                                footer: (() {
                                  final p = bestRacePace(21);
                                  return p;
                                })(),
                                onTap: () => _showRaceDialog(context, bestRaceForKm(21)),
                              ),
                              _metricCard(
                                context,
                                emoji: '⏱️',
                                title: 'RP nos 42km',
                                value: _formatDuration(bestForKm(42)),
                                subtitle: bestRaceLabel(42),
                                footer: (() {
                                  final p = bestRacePace(42);
                                  return p;
                                })(),
                                onTap: () => _showRaceDialog(context, bestRaceForKm(42)),
                              ),
                            ],
                          ),
                          GridView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cross,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: extentOther,
                                ),
                            children: [
                              _metricCard(
                                context,
                                emoji: '🏆',
                                title: 'Total de Corridas',
                                value: '$totalCorridasConcluidas',
                              ),
                              _metricCard(
                                context,
                                emoji: '📍',
                                title: 'Distância Total',
                                value:
                                    '${distanciaTotal.toStringAsFixed(1)} km',
                              ),
                              _metricCard(
                                context,
                                emoji: '🎯',
                                title: 'Inscrições',
                                value: '$inscricoes',
                              ),
                              _metricCard(
                                context,
                                emoji: '🏅',
                                title: 'Concluídas',
                                value: '$concluidas',
                              ),
                              _metricCard(
                                context,
                                emoji: '🗓️',
                                title: 'Pretendo Ir',
                                value: '$pretendo',
                              ),
                              _metricCard(
                                context,
                                emoji: '✖️',
                                title: 'Canceladas',
                                value: '$canceladas',
                              ),
                              _metricCard(
                                context,
                                emoji: '〰️',
                                title: 'Na Dúvida',
                                value: '$naDuvida',
                              ),
                              _metricCard(
                                context,
                                emoji: '⛔',
                                title: 'Não Pude Ir',
                                value: '$naoPude',
                              ),
                              _metricCard(
                                context,
                                emoji: '💲',
                                title: 'Valor Total Gasto',
                                value: currency.format(valorTotalGasto),
                              ),
                              _metricCard(
                                context,
                                emoji: '❌',
                                title: 'Valor Perdido',
                                value: currency.format(valorPerdido),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: cs.outline.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.calendar_month, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Resumo do Período',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isNarrow2 = constraints.maxWidth < 900;
                              final cross2 = isNarrow2 ? 1 : 3;
                              final extent2 = isNarrow2 ? 100.0 : 90.0;
                              return GridView(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: cross2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      mainAxisExtent: extent2,
                                    ),
                                children: [
                                  _summaryCard(
                                    context,
                                    emoji: '🏃',
                                    title: 'Corridas Registradas',
                                    value: '${filtered.length}',
                                  ),
                                  _summaryCard(
                                    context,
                                    emoji: '💰',
                                    title: 'Investimento Total',
                                    value: currency.format(valorTotalGasto),
                                  ),
                                  _summaryCard(
                                    context,
                                    emoji: '📍',
                                    title: 'Distância Total',
                                    value:
                                        '${distanciaTotal.toStringAsFixed(1)} km',
                                  ),
                                ],
                              );
                            },
                          ),
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

  Widget _metricCard(
    BuildContext context, {
    required String emoji,
    required String title,
    required String value,
    String? subtitle,
    String? footer,
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurface),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (value.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (footer != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        footer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRaceDialog(BuildContext context, model.Counter? race) {
    if (race == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma corrida encontrada para este RP')),
      );
      return;
    }

    final cs = Theme.of(context).colorScheme;
    final df = DateFormat('dd/MM/yyyy');
    final tf = DateFormat('HH:mm');
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final numfmt = NumberFormat.decimalPattern('pt_BR');
    final distHasDecimals = race.distanceKm % 1 != 0;
    final distLabel = distHasDecimals
        ? numfmt.format(race.distanceKm)
        : race.distanceKm.toStringAsFixed(0);
    final dur = _parseDuration(race.finishTime);
    final pace = computePace(dur, race.distanceKm);
    final hasLink = (race.registrationUrl ?? '').trim().isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primaryContainer.withValues(alpha: 0.35),
                cs.surfaceContainerHighest.withValues(alpha: 0.9),
              ],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          race.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Compartilhar',
                        onPressed: () => _shareRace(race),
                        icon: Icon(Icons.share, color: cs.onSurfaceVariant),
                      ),
                      IconButton(
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _infoColumn('Data', df.format(race.eventDate))),
                      const SizedBox(width: 16),
                      Expanded(child: _infoColumn('Horario', tf.format(race.eventDate))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _infoColumn('Distancia', '$distLabel km')),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _infoColumn(
                          'Preco',
                          race.price != null ? currency.format(race.price) : '-',
                        ),
                      ),
                    ],
                  ),
                  if ((race.finishTime ?? '').isNotEmpty || pace != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _infoColumn(
                            'Tempo',
                            (race.finishTime ?? '').isNotEmpty ? race.finishTime! : '-',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _infoColumn('Pace', pace ?? '-')),
                      ],
                    ),
                  ],
                  if ((race.category ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _infoColumn('Categoria', race.category!.trim()),
                  ],
                  if ((race.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(race.description!.trim()),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_iconForStatus(race.status), size: 16, color: cs.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text(_labelForStatus(race.status), style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (hasLink)
                        FilledButton.tonalIcon(
                          onPressed: () => _openUrl(context, race.registrationUrl!.trim()),
                          icon: const Icon(Icons.link, size: 16),
                          label: const Text('Link'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  String _labelForStatus(String s) {
    switch (s) {
      case 'pretendo_ir':
        return 'Pretendo ir';
      case 'inscrito':
        return 'Inscrito';
      case 'concluida':
        return 'Concluida';
      case 'cancelada':
        return 'Cancelada';
      case 'nao_pude_ir':
        return 'Nao pude ir';
      case 'na_duvida':
        return 'Na duvida';
      default:
        return s;
    }
  }

  IconData _iconForStatus(String s) {
    switch (s) {
      case 'pretendo_ir':
        return Icons.event;
      case 'inscrito':
        return Icons.assignment_turned_in;
      case 'concluida':
        return Icons.emoji_events_outlined;
      case 'cancelada':
        return Icons.cancel;
      case 'nao_pude_ir':
        return Icons.not_interested;
      case 'na_duvida':
        return Icons.help_outline;
      default:
        return Icons.info_outline;
    }
  }

  Widget _summaryCard(
    BuildContext context, {
    required String emoji,
    required String title,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
