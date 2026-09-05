import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:gercorridas/domain/time_utils.dart';
import 'package:gercorridas/state/providers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gercorridas/data/models/counter.dart';
import 'package:gercorridas/core/text_sanitizer.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  static final _selectedYearProvider = StateProvider<int>((ref) => DateTime.now().year);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countersAsync = ref.watch(corridasProvider);
    final cs = Theme.of(context).colorScheme;

    void openFilteredList({String? status, required int year}) {
      final params = <String, String>{
        'year': '$year',
        'status': status ?? 'all',
      };
      context.go(Uri(path: '/corridas', queryParameters: params).toString());
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: countersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erro ao carregar: $e')),
        data: (counters) {
          final now = DateTime.now();
          DateTime effectiveDate(DateTime base) => base;

          final years = {
            for (final c in counters) c.eventDate.year
          }..add(DateTime.now().year);
          final sortedYears = years.toList()..sort();

          final selectedYear = ref.watch(_selectedYearProvider);
          final filteredByYear = counters.where((c) => c.eventDate.year == selectedYear).toList();
          int countStatus(String s) => filteredByYear.where((c) => c.status == s).length;
          final total = filteredByYear.length;
          final inscritas = countStatus('inscrito');
          final concluidas = countStatus('concluida');
          final pretendo = countStatus('pretendo_ir');
          final canceladas = countStatus('cancelada');
          final naoPude = countStatus('nao_pude_ir');
          final naDuvida = countStatus('na_duvida');

          final upcomingInscritas = filteredByYear
              .map((c) => (c, effectiveDate(c.eventDate)))
              .where((t) => t.$1.status == 'inscrito' && !isPast(t.$2, now: now))
              .toList()
            ..sort((a, b) => a.$2.compareTo(b.$2));

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.insights_rounded, size: 20, color: cs.primary),
                  ),
                  const SizedBox(width: 10),
                  const Text('Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
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
                        value: selectedYear,
                        icon: const Icon(Icons.arrow_drop_down, size: 20),
                        items: [
                          for (final y in sortedYears)
                            DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontWeight: FontWeight.w600))),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            ref.read(_selectedYearProvider.notifier).state = v;
                          }
                        },
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(
                  'Visão geral do seu histórico e metas',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 14),

                // Cards principais (grid: garante 2 colunas no mobile)
                LayoutBuilder(builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 900;
                  final cross = 2;
                  final extent = isNarrow ? 82.0 : 80.0;
                  return GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      mainAxisExtent: extent,
                    ),
                    children: [
                      _statCard(
                        context,
                        title: 'Total',
                        value: total,
                        color: cs.surface,
                        icon: Icons.trending_up_rounded,
                        iconColor: cs.primary,
                        width: double.infinity,
                        onTap: () => openFilteredList(year: selectedYear),
                      ),
                      _statCard(
                        context,
                        title: 'Inscritas',
                        value: inscritas,
                        color: cs.surface,
                        icon: Icons.assignment_turned_in_rounded,
                        iconColor: Colors.blueAccent,
                        width: double.infinity,
                        onTap: () => openFilteredList(status: 'inscrito', year: selectedYear),
                      ),
                      _statCard(
                        context,
                        title: 'Concluídas',
                        value: concluidas,
                        color: cs.surface,
                        icon: Icons.emoji_events_rounded,
                        iconColor: Colors.amber.shade700,
                        width: double.infinity,
                        onTap: () => openFilteredList(status: 'concluida', year: selectedYear),
                      ),
                      _statCard(
                        context,
                        title: 'Pretendo Ir',
                        value: pretendo,
                        color: cs.surface,
                        icon: Icons.flag_rounded,
                        iconColor: Colors.teal,
                        width: double.infinity,
                        onTap: () => openFilteredList(status: 'pretendo_ir', year: selectedYear),
                      ),
                      _statCard(
                        context,
                        title: 'Canceladas',
                        value: canceladas,
                        color: cs.surface,
                        icon: Icons.cancel_rounded,
                        iconColor: cs.error,
                        width: double.infinity,
                        onTap: () => openFilteredList(status: 'cancelada', year: selectedYear),
                      ),
                      _statCard(
                        context,
                        title: 'Não Pude Ir',
                        value: naoPude,
                        color: cs.surface,
                        icon: Icons.event_busy_rounded,
                        iconColor: Colors.deepOrange,
                        width: double.infinity,
                        onTap: () => openFilteredList(status: 'nao_pude_ir', year: selectedYear),
                      ),
                      _statCard(
                        context,
                        title: 'Na Dúvida',
                        value: naDuvida,
                        color: cs.surface,
                        icon: Icons.help_outline_rounded,
                        iconColor: Colors.purple,
                        width: double.infinity,
                        onTap: () => openFilteredList(status: 'na_duvida', year: selectedYear),
                      ),
                    ],
                  );
                }),

                const SizedBox(height: 16),

                _panelCard(
                  context,
                  title: 'Próximas Corridas Inscritas',
                  icon: Icons.timer_outlined,
                  iconColor: cs.primary,
                  child: StreamBuilder<DateTime>(
                    stream: Stream<DateTime>.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
                    initialData: DateTime.now(),
                    builder: (context, snap) {
                      final refNow = snap.data ?? now;
                      if (upcomingInscritas.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('Sem corridas inscritas futuras', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: upcomingInscritas.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final c = upcomingInscritas[i].$1;
                          final eff = upcomingInscritas[i].$2;
                          return _inscritaTile(context, c, eff, refNow);
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),
                _panelCard(
                  context,
                  title: 'Últimas Corridas Concluídas',
                  icon: Icons.sports_score_rounded,
                  iconColor: Colors.amber.shade700,
                  child: Builder(builder: (context) {
                    final concluidas = filteredByYear
                        .where((c) => c.status == 'concluida')
                        .toList()
                      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
                    final ultimas = concluidas.take(5).toList();
                    if (ultimas.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('Sem corridas concluídas', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: ultimas.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final c = ultimas[i];
                        return _concluidaTile(context, c.name, c.category, c.distanceKm, c.eventDate, c.finishTime, c.price);
                      },
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(
    BuildContext context, {
    required String title,
    required int value,
    required Color color,
    required IconData icon,
    Color? iconColor,
    required double width,
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? cs.primary;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: effectiveIconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: effectiveIconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$value',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panelCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    Color? iconColor,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? cs.primary;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: effectiveIconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: effectiveIconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
  
  Widget _inscritaTile(BuildContext context, Counter c, DateTime date, DateTime now) {
    final cs = Theme.of(context).colorScheme;
    final df = DateFormat('dd/MM/yyyy');
    final tf = DateFormat('HH:mm');
    final comps = calendarDiff(now, date);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(spacing: 16, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Row(children: [const Icon(Icons.calendar_month, size: 16), const SizedBox(width: 6), Text(df.format(date))]),
                  Row(children: [const Icon(Icons.access_time, size: 16), const SizedBox(width: 6), Text(tf.format(date))]),
                  Row(children: [const Icon(Icons.route, size: 16), const SizedBox(width: 6), Text('${c.distanceKm.toStringAsFixed(0)} km')]),
                ]),
              ]),
            ),
            IconButton(
              tooltip: 'Compartilhar',
              onPressed: () {
                final isFuture = date.isAfter(now);
                final text = buildShareText(c, date, isFuture);
                final sanitizedText = sanitizeForShare(text);
                final sanitizedSubject = sanitizeForShare('Corrida: ${c.name}');
                Share.share(sanitizedText, subject: sanitizedSubject);
              },
              icon: const Icon(Icons.share),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Faltam:', style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (comps.years > 0) _countBox('${comps.years}', comps.years == 1 ? 'ano' : 'anos', cs),
                      if (comps.months > 0) _countBox('${comps.months}', comps.months == 1 ? 'mês' : 'meses', cs),
                      if (comps.days > 0) _countBox('${comps.days}', comps.days == 1 ? 'dia' : 'dias', cs),
                      if (comps.hours > 0) _countBox('${comps.hours}', comps.hours == 1 ? 'hora' : 'horas', cs),
                      if (comps.minutes > 0) _countBox('${comps.minutes}', comps.minutes == 1 ? 'minuto' : 'minutos', cs),
                      if (comps.seconds > 0 || (comps.years + comps.months + comps.days + comps.hours + comps.minutes) == 0)
                        _countBox('${comps.seconds}', comps.seconds == 1 ? 'segundo' : 'segundos', cs),
                    ],
                  ),
                ]),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _countBox(String value, String label, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
        Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
      ]),
    );
  }

  Widget _concluidaTile(BuildContext context, String name, String? category, double distanceKm, DateTime date, String? finishTime, double? price) {
    final cs = Theme.of(context).colorScheme;
    final df = DateFormat('dd/MM/yyyy');
    final tf = DateFormat('HH:mm');
    final priceStr = (price == null || price == 0)
        ? 'Gratuita'
        : NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(price);
    String? pace() {
      if (finishTime == null || finishTime.trim().isEmpty) return null;
      final parts = finishTime.split(':');
      Duration? total;
      if (parts.length == 3) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final s = int.tryParse(parts[2]) ?? 0;
        total = Duration(hours: h, minutes: m, seconds: s);
      } else if (parts.length == 2) {
        final m = int.tryParse(parts[0]) ?? 0;
        final s = int.tryParse(parts[1]) ?? 0;
        total = Duration(minutes: m, seconds: s);
      }
      return computePace(total, distanceKm);
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(14)),
              child: Text(
                'Concluído',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.purple.shade700),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Icon(Icons.calendar_month, size: 16), const SizedBox(width: 6), Text(df.format(date))]),
                const SizedBox(height: 8),
                Row(children: [const Icon(Icons.adjust, size: 16), const SizedBox(width: 6), Text('${distanceKm.toStringAsFixed(0)} km')]),
                const SizedBox(height: 8),
                Row(children: [const Icon(Icons.emoji_events_outlined, size: 16), const SizedBox(width: 6), Text(priceStr)]),
              ]),
            ),
            SizedBox(
              width: 180,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Icon(Icons.access_time, size: 16), const SizedBox(width: 6), Text(tf.format(date))]),
                const SizedBox(height: 8),
                Row(children: [const Icon(Icons.timelapse, size: 16), const SizedBox(width: 6), Text(finishTime?.isNotEmpty == true ? finishTime! : '-')]),
                const SizedBox(height: 8),
                if (pace() != null)
                  Row(children: [const Icon(Icons.speed, size: 16), const SizedBox(width: 6), Text('${pace()}', style: const TextStyle(fontSize: 12))]),
              ]),
            ),
          ]),
        ],
      ),
    );
  }

  

  // Gera uma paleta distinta de cores para a quantidade solicitada,
  // distribuindo as cores pelo círculo de matiz (HSL) para evitar colisões.
  
}
