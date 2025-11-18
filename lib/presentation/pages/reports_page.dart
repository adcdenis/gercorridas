import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:gercorridas/data/models/counter.dart' as model;
import 'package:gercorridas/domain/time_utils.dart';
import 'package:gercorridas/state/providers.dart';
import 'package:gercorridas/domain/report_export.dart';
import 'package:gercorridas/data/models/category.dart' as cat;

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _type = 'Todos'; // Todos | Passado | Futuro
  String _category = 'Todas';
  final _descCtrl = TextEditingController();
  DateTime _now = DateTime.now();

  String _labelForStatus(String s) {
    switch (s) {
      case 'pretendo_ir':
        return 'Pretendo ir';
      case 'inscrito':
        return 'Inscrito';
      case 'concluida':
        return 'Concluída';
      case 'cancelada':
        return 'Cancelada';
      case 'nao_pude_ir':
        return 'Não pude ir';
      case 'na_duvida':
        return 'Na dúvida';
      default:
        return s;
    }
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, 1, 1);
    _endDate = DateTime(now.year, 12, 31, 23, 59, 59);
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

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate(BuildContext context) async {
    final base = _startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate(BuildContext context) async {
    final base = _endDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _type = 'Todos';
      _category = 'Todas';
      _descCtrl.clear();
    });
  }

  DateTime _effectiveDate(DateTime base) {
    return base;
  }


  String _formatDiff(DateTime target) {
    final diff = calendarDiff(_now, target);
    final parts = <String>[];
    if (diff.years > 0) parts.add('${diff.years} ano${diff.years == 1 ? '' : 's'}');
    if (diff.months > 0) parts.add('${diff.months} ${diff.months == 1 ? 'mês' : 'meses'}');
    if (diff.days > 0) parts.add('${diff.days} dia${diff.days == 1 ? '' : 's'}');
    if (diff.hours > 0) parts.add('${diff.hours} hora${diff.hours == 1 ? '' : 's'}');
    if (diff.minutes > 0) parts.add('${diff.minutes} minuto${diff.minutes == 1 ? '' : 's'}');
    if (parts.isEmpty) parts.add('${diff.seconds} segundo${diff.seconds == 1 ? '' : 's'}');
    return parts.join(', ');
  }

  List<model.Counter> _applyFilters(List<model.Counter> list, List<String> categories) {
    List<model.Counter> out = List.of(list);
    // Date range filters (inclusive day)
    if (_startDate != null) {
      out = out.where((c) => c.eventDate.isAfter(DateTime(_startDate!.year, _startDate!.month, _startDate!.day).subtract(const Duration(seconds: 1)))).toList();
    }
    if (_endDate != null) {
      out = out.where((c) => c.eventDate.isBefore(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59))).toList();
    }
    if (_type != 'Todos') {
      out = out.where((c) {
        final eff = _effectiveDate(c.eventDate);
        final past = isPast(eff, now: _now);
        return _type == 'Passado' ? past : !past; // Futuro
      }).toList();
    }
    if (_category != 'Todas') {
      out = out.where((c) => (c.category ?? '') == _category).toList();
    }
    if (_descCtrl.text.trim().isNotEmpty) {
      final q = _descCtrl.text.trim().toLowerCase();
      out = out.where((c) => (c.description ?? '').toLowerCase().contains(q)).toList();
    }
    return out;
  }

  List<ReportRow> _toReportRows(List<model.Counter> counters) {
    return counters.map((c) {
      final eff = _effectiveDate(c.eventDate);
      final past = isPast(eff, now: _now);
      final diffLabel = _formatDiff(eff);
      final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
      final numfmt = NumberFormat.decimalPattern('pt_BR');
      return ReportRow(
        nome: c.name,
        descricao: c.description ?? '',
        dataHora: c.eventDate,
        categoria: c.category ?? '-',
        tempoFormatado: past ? diffLabel : diffLabel,
        preco: c.price != null ? currency.format(c.price) : '-',
        distancia: '${numfmt.format(c.distanceKm)} km',
        tempoConclusao: (c.finishTime ?? '').isNotEmpty ? c.finishTime! : '-',
      );
    }).toList();
  }

  Future<void> _generateAndShareXlsx(List<ReportRow> rows) async {
    final file = await generateXlsxReport(rows);
    await shareFile(file, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  }

  Future<void> _generateAndSharePdf(List<ReportRow> rows) async {
    final file = await generatePdfReport(rows);
    await shareFile(file, mimeType: 'application/pdf');
  }

  Future<void> _recalcAndShareXlsx() async {
    setState(() => _now = DateTime.now());
    final counters = ref.read(corridasProvider).asData?.value ?? const <model.Counter>[];
    final catsData = ref.read(categoriesProvider).asData?.value ?? const <cat.Category>[];
    final cats = catsData.map((c) => c.name).toList();
    final filtered = _applyFilters(counters, cats);
    final rows = _toReportRows(filtered);
    if (rows.isEmpty) return;
    await _generateAndShareXlsx(rows);
  }

  Future<void> _recalcAndSharePdf() async {
    setState(() => _now = DateTime.now());
    final counters = ref.read(corridasProvider).asData?.value ?? const <model.Counter>[];
    final catsData = ref.read(categoriesProvider).asData?.value ?? const <cat.Category>[];
    final cats = catsData.map((c) => c.name).toList();
    final filtered = _applyFilters(counters, cats);
    final rows = _toReportRows(filtered);
    if (rows.isEmpty) return;
    await _generateAndSharePdf(rows);
  }

  @override
  Widget build(BuildContext context) {
    final countersAsync = ref.watch(corridasProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final cs = Theme.of(context).colorScheme;
    final df = DateFormat('dd/MM/yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Text('📈', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text('Relatórios', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          const Text('Gere relatórios detalhados das suas corridas.'),
          const SizedBox(height: 16),

          // Filtros
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filtros', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 150,
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Data início',
                            hintText: 'dd/mm/aaaa',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () => _pickStartDate(context),
                            ),
                          ),
                          controller: TextEditingController(text: _startDate == null ? '' : df.format(_startDate!)),
                          onTap: () => _pickStartDate(context),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Data fim',
                            hintText: 'dd/mm/aaaa',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () => _pickEndDate(context),
                            ),
                          ),
                          controller: TextEditingController(text: _endDate == null ? '' : df.format(_endDate!)),
                          onTap: () => _pickEndDate(context),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<String>(
                          value: _type,
                          items: const [
                            DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                            DropdownMenuItem(value: 'Passado', child: Text('Passado')),
                            DropdownMenuItem(value: 'Futuro', child: Text('Futuro')),
                          ],
                          onChanged: (v) => setState(() => _type = v ?? 'Todos'),
                          decoration: const InputDecoration(labelText: 'Tipo'),
                        ),
                      ),
                      categoriesAsync.when(
                        loading: () => const SizedBox(width: 150, child: LinearProgressIndicator()),
                        error: (e, st) => SizedBox(width: 150, child: Text('Erro categorias')), 
                        data: (cats) {
                          final items = ['Todas', ...cats.map((c) => c.name)];
                          if (!items.contains(_category)) _category = 'Todas';
                          return SizedBox(
                            width: 150,
                            child: DropdownButtonFormField<String>(
                              value: _category,
                              items: items
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) => setState(() => _category = v ?? 'Todas'),
                              decoration: const InputDecoration(labelText: 'Categoria'),
                            ),
                          );
                        },
                      ),
                      SizedBox(
                        width: 150,
                        child: TextField(
                          controller: _descCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Descrição',
                            hintText: 'Filtrar por texto na descrição',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.filter_alt_off),
                        label: const Text('Limpar filtros'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      countersAsync.when(
                        loading: () => const SizedBox(),
                        error: (e, st) => const SizedBox(),
                        data: (counters) {
                          final cats = categoriesAsync.maybeWhen(data: (v) => v.map((c) => c.name).toList(), orElse: () => <String>[]);
                          final filtered = _applyFilters(counters, cats);
                          return Wrap(spacing: 8, children: [
                            FilledButton.icon(
                              onPressed: filtered.isEmpty ? null : _recalcAndShareXlsx,
                              icon: const Icon(Icons.grid_on),
                              label: const Text('Gerar Excel'),
                            ),
                            FilledButton.icon(
                              onPressed: filtered.isEmpty ? null : _recalcAndSharePdf,
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text('Gerar PDF'),
                            ),
                            Text('Atualizado às ${DateFormat('HH:mm').format(_now)}',
                                style: TextStyle(color: cs.onSurfaceVariant)),
                          ]);
                        },
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          // Prévia dos dados
          countersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Erro ao carregar: $e')),
            data: (counters) {
              final cats = categoriesAsync.maybeWhen(data: (v) => v.map((c) => c.name).toList(), orElse: () => <String>[]);
              final filtered = _applyFilters(counters, cats);

              return Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${filtered.length} corrida(s) encontrada(s)',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final c = filtered[i];
                          final eff = _effectiveDate(c.eventDate);
                          final isFuture = eff.isAfter(_now);
                          final hasDecimals = c.distanceKm % 1 != 0;
                          final distLabel = hasDecimals
                              ? NumberFormat.decimalPattern('pt_BR').format(c.distanceKm)
                              : c.distanceKm.toStringAsFixed(0);

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cs.outlineVariant),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isFuture
                                      ? [cs.primaryContainer.withValues(alpha: 0.6), cs.primaryContainer.withValues(alpha: 0.3)]
                                      : [cs.errorContainer.withValues(alpha: 0.6), cs.errorContainer.withValues(alpha: 0.3)],
                                ),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          c.name,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            height: 1.2,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Table(
                                    columnWidths: const {
                                      0: FlexColumnWidth(),
                                      1: FlexColumnWidth(),
                                    },
                                    defaultVerticalAlignment: TableCellVerticalAlignment.top,
                                    children: [
                                      TableRow(children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Data:', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                            const SizedBox(height: 4),
                                            Text(DateFormat('dd/MM/yyyy').format(eff), style: const TextStyle(fontSize: 14)),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Horário:', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                            const SizedBox(height: 4),
                                            Text(DateFormat('HH:mm').format(eff), style: const TextStyle(fontSize: 14)),
                                          ],
                                        ),
                                      ]),
                                      TableRow(children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Distância:', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                            const SizedBox(height: 4),
                                            Text('$distLabel km', style: const TextStyle(fontSize: 14)),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Preço:', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                            const SizedBox(height: 4),
                                            Text(
                                              c.price != null
                                                  ? NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(c.price)
                                                  : '—',
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ]),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_iconForStatus(c.status), size: 14, color: cs.onPrimaryContainer),
                                        const SizedBox(width: 6),
                                        Text(
                                          _labelForStatus(c.status),
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
}
