import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gercorridas/state/providers.dart';
import 'package:gercorridas/data/models/counter.dart';
import 'package:gercorridas/core/text_sanitizer.dart';
import 'package:gercorridas/domain/time_utils.dart';

class CorridaListPage extends ConsumerStatefulWidget {
  const CorridaListPage({super.key});

  @override
  ConsumerState<CorridaListPage> createState() => _CorridaListPageState();
}

class _CorridaListPageState extends ConsumerState<CorridaListPage> {
  static const _prefsKeyFilterSearch = 'counter_list_filter_search';
  static const _prefsKeyFilterCategory = 'counter_list_filter_category';
  static const _prefsKeyFilterCategories = 'counter_list_filter_categories';
  static const _prefsKeyFilterYear = 'counter_list_filter_year';
  static const _prefsKeyFilterStatus = 'counter_list_filter_status';

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

  IconData _iconForStatus(String s) {
    switch (s) {
      case 'pretendo_ir':
        return Icons.flag_rounded;
      case 'inscrito':
        return Icons.assignment_turned_in_rounded;
      case 'concluida':
        return Icons.emoji_events_rounded;
      case 'cancelada':
        return Icons.cancel_rounded;
      case 'nao_pude_ir':
        return Icons.event_busy_rounded;
      case 'na_duvida':
        return Icons.help_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _colorForStatus(String s, ColorScheme cs) {
    switch (s) {
      case 'concluida':
        return Colors.amber.shade700;
      case 'inscrito':
        return cs.primary;
      case 'pretendo_ir':
        return Colors.teal;
      case 'na_duvida':
        return Colors.purple;
      case 'cancelada':
        return cs.error;
      case 'nao_pude_ir':
        return Colors.deepOrange;
      default:
        return cs.outline;
    }
  }

  void _shareCounter(BuildContext context, Counter counter, DateTime effectiveDate, bool isFuture) {
    final shareText = buildShareText(counter, effectiveDate, isFuture);
    final sanitizedText = sanitizeForShare(shareText);
    final sanitizedSubject = sanitizeForShare('Corrida: ${counter.name}');
    Share.share(sanitizedText, subject: sanitizedSubject);
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri == null) {
      if (context.mounted) {
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
      if (!openedInApp && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o link')));
      }
    }
  }
  
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  Set<String> _selectedCategories = {};
  String? _statusFilter;
  bool _showSearch = false;
  int _selectedYear = DateTime.now().year;
  bool _appliedRouteFilters = false;

  @override
  void initState() {
    super.initState();
    _loadSavedFilters();
  }

  Future<void> _loadSavedFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSearch = prefs.getString(_prefsKeyFilterSearch) ?? '';
      final savedCategories = prefs.getStringList(_prefsKeyFilterCategories);
      final legacySingle = prefs.getString(_prefsKeyFilterCategory);
      final savedYear = prefs.getInt(_prefsKeyFilterYear);
      final savedStatus = prefs.getString(_prefsKeyFilterStatus);
      if (mounted) {
        setState(() {
          _search = savedSearch;
          final set = <String>{...?(savedCategories)};
          if ((legacySingle?.isNotEmpty ?? false)) set.add(legacySingle!);
          _selectedCategories = set;
          _showSearch = savedSearch.isNotEmpty;
          _selectedYear = savedYear ?? DateTime.now().year;
          _statusFilter = (savedStatus?.isNotEmpty ?? false) ? savedStatus : null;
        });
        _searchCtrl.text = savedSearch;
      }
    } catch (_) {
      // Ignora erros de persistência
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyRouteFiltersIfNeeded();
  }

  void _applyRouteFiltersIfNeeded() {
    if (_appliedRouteFilters) return;
    _appliedRouteFilters = true;
    final state = GoRouterState.of(context);
    final params = state.uri.queryParameters;
    if (params.isEmpty) return;

    final statusParam = params['status'];
    final yearParam = params['year'];
    if (statusParam == null && yearParam == null) return;

    final parsedYear = yearParam != null ? int.tryParse(yearParam) : null;
    final normalizedStatus = (statusParam == null || statusParam.isEmpty || statusParam == 'all')
        ? null
        : statusParam;

    Future.microtask(() async {
      if (!mounted) return;
      setState(() {
        if (parsedYear != null) _selectedYear = parsedYear;
        _statusFilter = normalizedStatus;
        _showSearch = true;
        _search = '';
        _searchCtrl.text = '';
        _selectedCategories.clear();
      });
      try {
        final prefs = await SharedPreferences.getInstance();
        if (parsedYear != null) {
          await prefs.setInt(_prefsKeyFilterYear, parsedYear);
        }
        if (normalizedStatus != null) {
          await prefs.setString(_prefsKeyFilterStatus, normalizedStatus);
        } else {
          await prefs.remove(_prefsKeyFilterStatus);
        }
        await prefs.remove(_prefsKeyFilterSearch);
        await prefs.remove(_prefsKeyFilterCategory); // legado
        await prefs.remove(_prefsKeyFilterCategories);
      } catch (_) {
        // Ignora erros de persistência
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final countersAsync = ref.watch(corridasProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final repo = ref.watch(corridaRepositoryProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/corrida/new'),
        child: const Text('➕', style: TextStyle(fontSize: 24)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Corridas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                const Spacer(),
                countersAsync.when(
                  data: (items) {
                    final years = {for (final c in items) c.eventDate.year}
                      ..add(DateTime.now().year)
                      ..add(_selectedYear);
                    final sortedYears = years.toList()..sort();
                    return SizedBox(
                      width: 84,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isDense: true,
                          value: _selectedYear,
                          items: [for (final y in sortedYears) DropdownMenuItem(value: y, child: Text('$y'))],
                          onChanged: (v) async {
                            final nv = v ?? DateTime.now().year;
                            setState(() => _selectedYear = nv);
                            try {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setInt(_prefsKeyFilterYear, nv);
                            } catch (_) {}
                          },
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => const SizedBox.shrink(),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: _showSearch ? 'Ocultar filtro' : 'Mostrar filtro',
                  child: IconButton.filledTonal(
                    icon: Icon(_showSearch ? Icons.search_off : Icons.search),
                    onPressed: () async {
                      if (_showSearch) {
                        setState(() {
                          _showSearch = false;
                          _statusFilter = null;
                        });
                        try {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove(_prefsKeyFilterStatus);
                        } catch (_) {
                          // Ignora erros de persistência
                        }
                      } else {
                        setState(() => _showSearch = true);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_showSearch) Row(children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                    child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 20),
                      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      hintText: 'Buscar por descrição ou nome...',
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      isDense: true,
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? Tooltip(
                              message: 'Limpar busca',
                              child: IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () async {
                                  setState(() {
                                    _searchCtrl.clear();
                                    _search = '';
                                  });
                                  try {
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.remove(_prefsKeyFilterSearch);
                                  } catch (_) {
                                    // Ignora erros de persistência
                                  }
                                },
                              ),
                            )
                          : null,
                    ),
                    onChanged: (v) async {
                      final nv = v.trim();
                      setState(() => _search = nv);
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString(_prefsKeyFilterSearch, nv);
                      } catch (_) {
                        // Ignora erros de persistência
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 16)),
                  onPressed: () async {
                    setState(() {
                      _search = '';
                      _searchCtrl.clear();
                      _selectedCategories.clear();
                      _statusFilter = null;
                    });
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove(_prefsKeyFilterSearch);
                      await prefs.remove(_prefsKeyFilterCategory); // legado
                      await prefs.remove(_prefsKeyFilterCategories);
                      await prefs.remove(_prefsKeyFilterStatus);
                    } catch (_) {
                      // Ignora erros de persistência
                    }
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_alt_off),
                      SizedBox(width: 8),
                      Text('Limpar filtros'),
                    ],
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            if (_showSearch)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: SizedBox(
                  height: 48,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_statusFilter ?? 'all'),
                    initialValue: _statusFilter ?? 'all',
                    decoration: InputDecoration(
                      labelText: 'Status',
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Todos')),
                      DropdownMenuItem(value: 'pretendo_ir', child: Text('Pretendo ir')),
                      DropdownMenuItem(value: 'inscrito', child: Text('Inscrito')),
                      DropdownMenuItem(value: 'concluida', child: Text('Concluída')),
                      DropdownMenuItem(value: 'cancelada', child: Text('Cancelada')),
                      DropdownMenuItem(value: 'nao_pude_ir', child: Text('Não pude ir')),
                      DropdownMenuItem(value: 'na_duvida', child: Text('Na dúvida')),
                    ],
                    onChanged: (value) async {
                      final normalized = (value == null || value == 'all') ? null : value;
                      setState(() => _statusFilter = normalized);
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        if (normalized == null) {
                          await prefs.remove(_prefsKeyFilterStatus);
                        } else {
                          await prefs.setString(_prefsKeyFilterStatus, normalized);
                        }
                      } catch (_) {
                        // Ignora erros de persistência
                      }
                    },
                  ),
                ),
              ),
            // Linha de etiquetas (chips) selecionáveis de categorias
            if (_showSearch)
              countersAsync.when(
                loading: () => const SizedBox(height: 32, child: Align(alignment: Alignment.centerLeft, child: CircularProgressIndicator())),
                error: (e, _) => const SizedBox.shrink(),
                data: (items) {
                  final presentCats = <String>{
                    for (final c in items)
                      if ((c.category ?? '').trim().isNotEmpty) (c.category!)
                  };

                  final catsData = categoriesAsync.asData?.value ?? const [];
                  final nameByNormalized = {for (final cat in catsData) cat.normalized: cat.name};

                  final present = <String>{...presentCats, ..._selectedCategories};

                  final chips = present.map((norm) {
                    final selected = _selectedCategories.contains(norm);
                    final scheme = Theme.of(context).colorScheme;
                    final labelStyle = TextStyle(
                      color: selected ? scheme.onPrimaryContainer : scheme.onSecondaryContainer,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 12,
                    );
                    return FilterChip(
                      selected: selected,
                      showCheckmark: true,
                      checkmarkColor: scheme.onPrimaryContainer,
                      avatar: Icon(
                        Icons.local_offer,
                        size: 14,
                        color: selected ? scheme.onPrimaryContainer : scheme.onSecondaryContainer,
                      ),
                      label: Text(nameByNormalized[norm] ?? norm, style: labelStyle),
                      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                      backgroundColor: selected ? scheme.primaryContainer : scheme.secondaryContainer,
                      selectedColor: scheme.primaryContainer,
                      side: BorderSide(
                        color: selected ? scheme.primary : scheme.outlineVariant,
                        width: selected ? 2 : 1,
                      ),
                      elevation: selected ? 1 : 0,
                      onSelected: (v) async {
                        setState(() {
                          if (v) {
                            _selectedCategories.add(norm);
                          } else {
                            _selectedCategories.remove(norm);
                          }
                        });
                        try {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setStringList(_prefsKeyFilterCategories, _selectedCategories.toList());
                        } catch (_) {
                          // Ignora erros de persistência
                        }
                      },
                    );
                  }).toList();

                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: chips,
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            countersAsync.when(
              loading: () => const Expanded(child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Expanded(child: Text('Erro ao carregar: $e')),
              data: (items) {
                var filtered = items
                    .where((c) => c.eventDate.year == _selectedYear)
                    .where((c) {
                      final q = _search.toLowerCase();
                      final matchesSearch = _search.isEmpty ||
                          c.name.toLowerCase().contains(q) ||
                          (c.description?.toLowerCase().contains(q) ?? false);
                      final cat = (c.category ?? '').trim();
                      final matchesCat = _selectedCategories.isEmpty || (cat.isNotEmpty && _selectedCategories.contains(cat));
                      final matchesStatus = _statusFilter == null || c.status == _statusFilter;
                      return matchesSearch && matchesCat && matchesStatus;
                    }).toList();
                filtered.sort((a, b) => a.eventDate.compareTo(b.eventDate));

                if (filtered.isEmpty) {
                  return Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.directions_run_rounded, size: 52, color: scheme.primary),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Nenhuma corrida encontrada',
                              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _search.isNotEmpty || _statusFilter != null || _selectedCategories.isNotEmpty
                                  ? 'Tente remover os filtros ou alterar a busca.'
                                  : 'Você ainda não possui corridas cadastradas para o ano de $_selectedYear.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 22),
                            if (_search.isNotEmpty || _statusFilter != null || _selectedCategories.isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _search = '';
                                    _searchCtrl.clear();
                                    _statusFilter = null;
                                    _selectedCategories.clear();
                                  });
                                },
                                icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                                label: const Text('Limpar Filtros'),
                              )
                            else
                              FilledButton.icon(
                                onPressed: () => context.go('/corrida/new'),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Cadastrar Nova Corrida'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Periodicidade de 30s para contagem suave com alta performance
                return Expanded(
                  child: StreamBuilder<DateTime>(
                    stream: Stream<DateTime>.periodic(const Duration(seconds: 30), (_) => DateTime.now()),
                    initialData: DateTime.now(),
                    builder: (context, snap) {
                      final now = snap.data ?? DateTime.now();

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final crossAxisCount = width >= 1400 ? 3 : (width >= 900 ? 2 : 1);

                          Widget buildCard(int index) {
                            final c = filtered[index];
                            final effectiveDate = DateTime(
                              c.eventDate.year,
                              c.eventDate.month,
                              c.eventDate.day,
                              c.eventDate.hour,
                              c.eventDate.minute,
                              c.eventDate.second,
                            );
                            final isFuture = effectiveDate.isAfter(now);
                            final hasDecimals = c.distanceKm % 1 != 0;
                            final distLabel = hasDecimals
                                ? NumberFormat.decimalPattern('pt_BR').format(c.distanceKm)
                                : c.distanceKm.toStringAsFixed(0);
                            final isConcluded = c.status == 'concluida' && (c.finishTime?.isNotEmpty ?? false);

                            Duration? finishDur;
                            if (isConcluded) {
                              final parts = c.finishTime!.split(':');
                              if (parts.length == 3) {
                                final h = int.tryParse(parts[0]) ?? 0;
                                final m = int.tryParse(parts[1]) ?? 0;
                                final s = int.tryParse(parts[2]) ?? 0;
                                finishDur = Duration(hours: h, minutes: m, seconds: s);
                              } else if (parts.length == 2) {
                                final m = int.tryParse(parts[0]) ?? 0;
                                final s = int.tryParse(parts[1]) ?? 0;
                                finishDur = Duration(minutes: m, seconds: s);
                              }
                            }
                            final paceStr = isConcluded ? computePace(finishDur, c.distanceKm) : null;
                            final statusColor = _colorForStatus(c.status, scheme);
                            final statusIcon = _iconForStatus(c.status);
                            final statusLabel = _labelForStatus(c.status);

                            // Badge de contagem regressiva
                            String? countdownBadge;
                            if (isFuture && c.status == 'inscrito') {
                              final diff = effectiveDate.difference(now);
                              if (diff.inDays > 1) {
                                countdownBadge = 'Em ${diff.inDays} dias';
                              } else if (diff.inDays == 1) {
                                countdownBadge = 'Amanhã!';
                              } else if (diff.inHours > 0) {
                                countdownBadge = 'Em ${diff.inHours}h';
                              } else {
                                countdownBadge = 'Hoje!';
                              }
                            }

                            Widget metricPill({
                              required IconData icon,
                              required String text,
                              Color? iconColor,
                              bool isPrimary = false,
                            }) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isPrimary
                                      ? scheme.primaryContainer.withValues(alpha: 0.6)
                                      : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isPrimary
                                        ? scheme.primary.withValues(alpha: 0.3)
                                        : scheme.outlineVariant.withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      icon,
                                      size: 14,
                                      color: iconColor ?? (isPrimary ? scheme.primary : scheme.onSurfaceVariant),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      text,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w600,
                                        color: isPrimary ? scheme.onPrimaryContainer : scheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isConcluded
                                      ? Colors.amber.withValues(alpha: 0.4)
                                      : (c.status == 'inscrito'
                                          ? scheme.primary.withValues(alpha: 0.35)
                                          : scheme.outlineVariant.withValues(alpha: 0.35)),
                                  width: isConcluded || c.status == 'inscrito' ? 1.4 : 1,
                                ),
                              ),
                              elevation: 0,
                              color: scheme.surfaceContainerLow,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => context.go('/corrida/${c.id}/edit'),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Linha Superior: Badges de Status + Categoria + Ações
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(statusIcon, size: 13, color: statusColor),
                                                const SizedBox(width: 5),
                                                Text(
                                                  statusLabel,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: statusColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if ((c.category?.trim().isNotEmpty ?? false)) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                c.category!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: scheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (countdownBadge != null) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: scheme.primary.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                countdownBadge,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: scheme.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                          const Spacer(),
                                          // Ações Rápidas (Compartilhar e Excluir)
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(8),
                                              onTap: () => _shareCounter(context, c, effectiveDate, isFuture),
                                              child: Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Icon(Icons.share_rounded, size: 18, color: scheme.onSurfaceVariant),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(8),
                                              onTap: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text('Excluir corrida'),
                                                    content: const Text('Tem certeza que deseja excluir esta corrida?'),
                                                    actions: [
                                                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
                                                      FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Excluir')),
                                                    ],
                                                  ),
                                                );
                                                if (confirm == true) {
                                                  await repo.delete(c.id!);
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Corrida excluída')));
                                                  }
                                                }
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Icon(Icons.delete_outline_rounded, size: 18, color: scheme.error.withValues(alpha: 0.8)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // Nome da corrida
                                      Text(
                                        c.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          height: 1.22,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),

                                      if ((c.description?.trim().isNotEmpty ?? false)) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          c.description!,
                                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 12),

                                      // Métricas em Chips elegantes
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          metricPill(
                                            icon: Icons.calendar_today_rounded,
                                            text: '${DateFormat('dd/MM/yyyy').format(effectiveDate)} às ${DateFormat('HH:mm').format(effectiveDate)}',
                                          ),
                                          metricPill(
                                            icon: Icons.straighten_rounded,
                                            text: '$distLabel km',
                                            isPrimary: true,
                                          ),
                                          if (isConcluded) ...[
                                            metricPill(
                                              icon: Icons.timer_outlined,
                                              text: c.finishTime ?? '—',
                                              iconColor: Colors.amber.shade800,
                                            ),
                                            if (paceStr != null)
                                              metricPill(
                                                icon: Icons.speed_rounded,
                                                text: '$paceStr/km',
                                                iconColor: Colors.amber.shade800,
                                              ),
                                          ],
                                          if (c.price != null)
                                            metricPill(
                                              icon: Icons.payments_outlined,
                                              text: NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(c.price),
                                            ),
                                          if ((c.registrationUrl?.trim().isNotEmpty ?? false))
                                            InkWell(
                                              borderRadius: BorderRadius.circular(8),
                                              onTap: () => _openUrl(context, c.registrationUrl!),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: scheme.primary.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.open_in_new_rounded, size: 13, color: scheme.primary),
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      'Regulamento/Link',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w700,
                                                        color: scheme.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          if (crossAxisCount == 1) {
                            return ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (context, index) => buildCard(index),
                            );
                          } else {
                            final aspectRatio = crossAxisCount == 2 ? 1.8 : 2.1;
                            return GridView.builder(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: aspectRatio,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) => buildCard(index),
                            );
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}
