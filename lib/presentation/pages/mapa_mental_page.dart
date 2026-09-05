import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gercorridas/state/providers.dart';
import 'package:gercorridas/data/models/counter.dart' as model;
import 'package:url_launcher/url_launcher.dart';
import 'package:gercorridas/domain/time_utils.dart';

class MapaMentalPage extends ConsumerStatefulWidget {
  const MapaMentalPage({super.key});

  @override
  ConsumerState<MapaMentalPage> createState() => _MapaMentalPageState();
}

class _MapaMentalPageState extends ConsumerState<MapaMentalPage> {
  int _selectedYear = DateTime.now().year;
  final Map<int, bool> _monthExpanded = {for (var m = 1; m <= 12; m++) m: false};

  List<model.Counter> _filterByYear(List<model.Counter> list) {
    return list.where((c) => c.eventDate.year == _selectedYear).toList();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL inválida')));
      }
      return;
    }
    final openedExternal = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!openedExternal) {
      final openedInApp = await launchUrl(
        uri,
        mode: LaunchMode.inAppWebView,
        webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
      );
      if (!openedInApp && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o link')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final countersAsync = ref.watch(corridasProvider);

    const monthNames = [
      'Janeiro','Fevereiro','Março','Abril','Maio','Junho','Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 420;
            final yearSelector = countersAsync.when(
              data: (items) {
                final years = {for (final c in items) c.eventDate.year}..add(DateTime.now().year)..add(_selectedYear);
                final sortedYears = years.toList()..sort();
                return SizedBox(
                  width: 84,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isDense: true,
                      value: _selectedYear,
                      items: [for (final y in sortedYears) DropdownMenuItem(value: y, child: Text('$y'))],
                      onChanged: (v) => setState(() => _selectedYear = v ?? _selectedYear),
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            );

            if (isNarrow) {
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.account_tree_rounded, size: 20, color: cs.primary),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Mapa Mental', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 8),
                  yearSelector,
                ],
              );
            }

            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.account_tree_rounded, size: 20, color: cs.primary),
                ),
                const SizedBox(width: 10),
                const Expanded(child: Text('Mapa Mental', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700))),
                const SizedBox(width: 12),
                yearSelector,
              ],
            );
          }),
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
                child: Text('Erro ao carregar dados: $e'),
              ),
            ),
            data: (items) {
              final filtered = _filterByYear(items);
              final byMonth = <int, List<model.Counter>>{for (var m = 1; m <= 12; m++) m: []};
              for (final c in filtered) {
                byMonth[c.eventDate.month]!.add(c);
              }
              for (final m in byMonth.keys) {
                byMonth[m]!.sort((a, b) => a.eventDate.compareTo(b.eventDate));
              }
              final total = filtered.length;
              return Card(
                color: cs.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outline.withValues(alpha: 0.12))),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_month, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text('$_selectedYear', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                                child: Text('$total', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.center,
                        child: Container(width: 2, height: 16, color: cs.outline),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columnWidth = constraints.maxWidth;
                          final cardWidth = constraints.maxWidth < 600 ? constraints.maxWidth * 0.85 : 320.0;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int m = 1; m <= 12; m++) ...[
                                _monthBlock(
                                  context,
                                  month: m,
                                  title: monthNames[m - 1],
                                  items: byMonth[m]!,
                                  width: columnWidth,
                                  cardWidth: cardWidth,
                                  spacingRight: 0,
                                ),
                                if (m < 12) const SizedBox(height: 12),
                              ],
                            ],
                          );
                        },
                      ),
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

  Widget _monthBlock(BuildContext context, {required int month, required String title, required List<model.Counter> items, required double width, required double cardWidth, required double spacingRight}) {
    final cs = Theme.of(context).colorScheme;
    final df = DateFormat('dd/MM/yyyy');
    final tf = DateFormat('HH:mm');
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final numfmt = NumberFormat.decimalPattern('pt_BR');

    final expanded = _monthExpanded[month] ?? false;
    return Container(
      width: width,
      margin: EdgeInsets.only(right: spacingRight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                  child: Text('${items.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _monthExpanded[month] = !expanded),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                    child: Text(expanded ? '−' : '+', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text('Sem corridas', style: TextStyle(color: cs.onSurfaceVariant))
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      SizedBox(
                        width: cardWidth,
                        child: _raceCard(context, items[i], df, tf, currency, numfmt, cs),
                      ),
                      if (i < items.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _raceCard(BuildContext context, model.Counter c, DateFormat df, DateFormat tf, NumberFormat currency, NumberFormat numfmt, ColorScheme cs) {
    final distHasDecimals = c.distanceKm % 1 != 0;
    final distLabel = distHasDecimals ? numfmt.format(c.distanceKm) : c.distanceKm.toStringAsFixed(0);
    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: cs.outline.withValues(alpha: 0.12))),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LayoutBuilder(builder: (context, constraints) {
          final tileWidth = (constraints.maxWidth - 8) / 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    c.status == 'concluida' ? 'Concluído' : c.status == 'inscrito' ? 'Inscrito' : '—',
                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 2,
                children: [
                  _infoTile(tileWidth, Icons.event, Text(df.format(c.eventDate), softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                  _infoTile(tileWidth, Icons.access_time, Text(tf.format(c.eventDate), softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                  _infoTile(tileWidth, Icons.place, Text('$distLabel km', softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                  _infoTile(tileWidth, Icons.attach_money, Text(c.price != null ? currency.format(c.price) : '—', softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                  if (c.status == 'concluida' && (c.finishTime ?? '').isNotEmpty) ...[
                    _infoTile(tileWidth, Icons.timer, Text(c.finishTime!, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                    Builder(builder: (_) {
                      final parts = c.finishTime!.split(':');
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
                      final pace = computePace(total, c.distanceKm);
                      return pace != null
                          ? _infoTile(
                              tileWidth,
                              Icons.speed,
                              Text(pace, softWrap: false, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                            )
                          : const SizedBox.shrink();
                    }),
                  ],
                  if ((c.registrationUrl ?? '').isNotEmpty)
                    SizedBox(
                      width: tileWidth,
                      child: Row(children: [
                        const Icon(Icons.link, size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                          onPressed: () => _openUrl(c.registrationUrl!),
                          child: const Text('link'),
                        ),
                      ]),
                    ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _infoTile(double w, IconData icon, Widget content) {
    return SizedBox(
      width: w,
      child: Row(children: [
        Icon(icon, size: 13, color: Colors.grey),
        const SizedBox(width: 4),
        Expanded(child: content),
      ]),
    );
  }

}
