import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gercorridas/domain/time_utils.dart';
import 'package:gercorridas/state/providers.dart';
import 'package:share_plus/share_plus.dart';

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
                          return _inscritaTile(context, c.name, c.category, c.distanceKm, eff, refNow);
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
  
  Widget _inscritaTile(BuildContext context, String name, String? category, double distanceKm, DateTime date, DateTime now) {
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
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(spacing: 16, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Row(children: [const Icon(Icons.calendar_month, size: 16), const SizedBox(width: 6), Text(df.format(date))]),
                  Row(children: [const Icon(Icons.access_time, size: 16), const SizedBox(width: 6), Text(tf.format(date))]),
                  Row(children: [const Icon(Icons.route, size: 16), const SizedBox(width: 6), Text('${distanceKm.toStringAsFixed(0)} km')]),
                ]),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Spacer(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Faltam:', style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    _countBox('${comps.days}', 'dias', cs),
                    _countBox('${comps.hours}', 'hrs', cs),
                    _countBox('${comps.minutes}', 'min', cs),
                    _countBox('${comps.seconds}', 'seg', cs),
                  ]),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Compartilhar',
              onPressed: () {
                final text = '${name}\n${df.format(date)} ${tf.format(date)}\n${category ?? ''}\n${distanceKm.toStringAsFixed(0)} km';
                Share.share(text, subject: 'Corrida: $name');
              },
              icon: const Icon(Icons.share),
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

  Widget _categoryBar(BuildContext context, {required String label, required int value, required int max, required Color color}) {
    final cs = Theme.of(context).colorScheme;
    final pct = max == 0 ? 0.0 : value / max;
    final barColor = color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.circle, size: 10, color: barColor),
                const SizedBox(width: 6),
                Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Text('$value'),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 8,
                  child: Stack(children: [
                    Container(color: cs.surfaceContainerHighest),
                    FractionallySizedBox(widthFactor: pct, child: Container(color: barColor)),
                  ]),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // Gera uma paleta distinta de cores para a quantidade solicitada,
  // distribuindo as cores pelo círculo de matiz (HSL) para evitar colisões.
  List<Color> _distinctPalette(BuildContext context, int count) {
    final brightness = Theme.of(context).brightness;
    final double s = brightness == Brightness.dark ? 0.65 : 0.60;
    final double l = brightness == Brightness.dark ? 0.55 : 0.50;
    if (count <= 0) return const [];
    return List<Color>.generate(count, (i) {
      final hue = (360.0 * i / count) % 360.0;
      return HSLColor.fromAHSL(1.0, hue, s, l).toColor();
    });
  }
}

class _DonutChart extends StatelessWidget {
  final Map<String, int> data;
  final int total;
  final Map<String, Color> colorsByCategory;
  const _DonutChart({required this.data, required this.total, required this.colorsByCategory});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DonutPainter(data: data, total: total, colorsByCategory: colorsByCategory),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Total'),
            Text('$total', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final Map<String, int> data;
  final int total;
  final Map<String, Color> colorsByCategory;
  _DonutPainter({required this.data, required this.total, required this.colorsByCategory});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..color = Colors.grey.withValues(alpha: 0.15);
    canvas.drawArc(rect, 0, 2 * 3.1415926, false, bg);

    if (total <= 0 || data.isEmpty) return;

    double start = -3.1415926 / 2; // topo
    for (final e in data.entries) {
      final sweep = (e.value / total) * 2 * 3.1415926;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.butt
        // Usa mapeamento de cor único por categoria
        ..color = colorsByCategory[e.key] ?? Colors.grey;
      canvas.drawArc(rect, start, sweep, false, p);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.total != total;
  }
}
