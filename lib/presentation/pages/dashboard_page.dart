import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

          final upcomingInscritas = filteredByYear
              .map((c) => (c, effectiveDate(c.eventDate)))
              .where((t) => t.$1.status == 'inscrito' && !isPast(t.$2, now: now))
              .toList()
            ..sort((a, b) => a.$2.compareTo(b.$2));

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: const [
                  Text('📊', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text('Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 8),
                const Text('Visão geral do sistema de corridas'),
                const SizedBox(height: 16),

                Row(children: [
                  const Text('Ano:'),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: selectedYear,
                    items: [
                      for (final y in sortedYears)
                        DropdownMenuItem(value: y, child: Text('$y'))
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(_selectedYearProvider.notifier).state = v;
                      }
                    },
                  ),
                ]),
                const SizedBox(height: 16),

                // Cards principais (grid: garante 2 colunas no mobile)
                LayoutBuilder(builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 900;
                  final cross = 2;
                  final extent = isNarrow ? 120.0 : 120.0;
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
                      _statCard(context, title: 'Total', value: total, color: cs.surface, emoji: '📈', width: double.infinity),
                      _statCard(context, title: 'Inscritas', value: inscritas, color: cs.surface, emoji: '👥', width: double.infinity),
                      _statCard(context, title: 'Concluídas', value: concluidas, color: cs.surface, emoji: '🏆', width: double.infinity),
                      _statCard(context, title: 'Pretendo Ir', value: pretendo, color: cs.surface, emoji: '🎯', width: double.infinity),
                      _statCard(context, title: 'Canceladas', value: canceladas, color: cs.surface, emoji: '✖️', width: double.infinity),
                      _statCard(context, title: 'Não Pude Ir', value: naoPude, color: cs.surface, emoji: '⏱️', width: double.infinity),
                    ],
                  );
                }),

                const SizedBox(height: 16),

                _panelCard(
                  context,
                  title: 'Próximas Corridas Inscritas',
                  emoji: '⏲️',
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
                  emoji: '🏁',
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

  Widget _statCard(BuildContext context, {required String title, required int value, required Color color, required String emoji, required double width}) {
    final cs = Theme.of(context).colorScheme;
    // Choose an appropriate text color based on the container color for better contrast
    // Map text color according to background for good contrast.
    // Use theme on*Container for scheme containers, otherwise compute fallback based on brightness.
    final Color onColor;
    if (color == cs.primaryContainer) {
      onColor = cs.onPrimaryContainer;
    } else if (color == cs.secondaryContainer) {
      onColor = cs.onSecondaryContainer;
    } else if (color == cs.tertiaryContainer) {
      onColor = cs.onTertiaryContainer;
    } else if (color == cs.errorContainer) {
      onColor = cs.onErrorContainer;
    } else {
      final isLightBg = ThemeData.estimateBrightnessForColor(color) == Brightness.light;
      onColor = isLightBg ? Colors.black.withValues(alpha: 0.87) : Colors.white;
    }
    return Card(
      elevation: 0,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outline.withValues(alpha: 0.12))),
      child: SizedBox(
        width: width,
        height: 90,
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
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: onColor)),
                    const SizedBox(height: 4),
                    Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: onColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panelCard(BuildContext context, {required String title, required String emoji, required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outline.withValues(alpha: 0.12))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
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
                  Row(children: [
                    if (comps.years > 0) _countBox('${comps.years}', comps.years == 1 ? 'ano' : 'anos', cs),
                    const SizedBox(width: 6),
                    if (comps.months > 0) _countBox('${comps.months}', comps.months == 1 ? 'mês' : 'meses', cs),
                    const SizedBox(width: 6),
                    if (comps.days > 0) _countBox('${comps.days}', comps.days == 1 ? 'dia' : 'dias', cs),
                    const SizedBox(width: 6),
                    if (comps.hours > 0) _countBox('${comps.hours}', comps.hours == 1 ? 'hora' : 'horas', cs),
                    const SizedBox(width: 6),
                    if (comps.minutes > 0) _countBox('${comps.minutes}', comps.minutes == 1 ? 'minuto' : 'minutos', cs),
                    const SizedBox(width: 6),
                    if (comps.seconds > 0 || (comps.years + comps.months + comps.days + comps.hours + comps.minutes) == 0)
                      _countBox('${comps.seconds}', comps.seconds == 1 ? 'segundo' : 'segundos', cs),
                  ]),
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
