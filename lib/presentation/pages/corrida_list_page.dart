import 'package:flutter/material.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
 import 'package:shared_preferences/shared_preferences.dart';
 import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gercorridas/state/providers.dart';
import 'package:gercorridas/domain/time_utils.dart';
import 'package:gercorridas/data/models/counter.dart';
import 'package:gercorridas/core/text_sanitizer.dart';

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
  
  TimeDiffComponents _calendarComponents(DateTime a, DateTime b) {
    // Usa diferença de calendário normalizada em horário local
    return calendarDiff(a, b);
  }
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  Set<String> _selectedCategories = {};
  bool _showSearch = false;
  int _selectedYear = DateTime.now().year;

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
      if (mounted) {
        setState(() {
          _search = savedSearch;
          final set = <String>{...?(savedCategories)};
          if ((legacySingle?.isNotEmpty ?? false)) set.add(legacySingle!);
          _selectedCategories = set;
          _showSearch = savedSearch.isNotEmpty;
          _selectedYear = savedYear ?? DateTime.now().year;
        });
        _searchCtrl.text = savedSearch;
      }
    } catch (_) {
      // Ignora erros de persistência
    }
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
                const SizedBox(width: 12),
                countersAsync.when(
                  data: (items) {
                    final years = {for (final c in items) c.eventDate.year}
                      ..add(DateTime.now().year)
                      ..add(_selectedYear);
                    final sortedYears = years.toList()..sort();
                    return SizedBox(
                      width: 120,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
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
                    onPressed: () => setState(() => _showSearch = !_showSearch),
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
                    });
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove(_prefsKeyFilterSearch);
                      await prefs.remove(_prefsKeyFilterCategory); // legado
                      await prefs.remove(_prefsKeyFilterCategories);
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
            // Linha de etiquetas (chips) selecionáveis de categorias
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
                      return matchesSearch && matchesCat;
                    }).toList();

                filtered.sort((a, b) => b.eventDate.compareTo(a.eventDate));

                if (filtered.isEmpty) {
                  return const Expanded(child: Center(child: Text('Nenhuma corrida encontrada.')));
                }

                // Rebuild a cada segundo para contagem dinâmica
                return Expanded(
                  child: StreamBuilder<DateTime>(
                    stream: Stream<DateTime>.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
                    initialData: DateTime.now(),
                    builder: (context, snap) {
                      final now = snap.data ?? DateTime.now();

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final crossAxisCount = width >= 1400 ? 3 : (width >= 900 ? 2 : 1);

                          Widget buildCard(int index) {
                            final c = filtered[index];
                            final baseLocal = DateTime(
                              c.eventDate.year,
                              c.eventDate.month,
                              c.eventDate.day,
                              c.eventDate.hour,
                              c.eventDate.minute,
                              c.eventDate.second,
                              c.eventDate.millisecond,
                              c.eventDate.microsecond,
                            );
                            final effectiveDate = baseLocal;
                            final isFuture = effectiveDate.isAfter(now);
                            final hasDecimals = c.distanceKm % 1 != 0;
                            final distLabel = hasDecimals
                                ? NumberFormat.decimalPattern('pt_BR').format(c.distanceKm)
                                : c.distanceKm.toStringAsFixed(0);

                            return Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => context.go('/corrida/${c.id}/edit'),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: isFuture
                                          ? [scheme.primaryContainer.withValues(alpha: 0.6), scheme.primaryContainer.withValues(alpha: 0.3)]
                                          : [scheme.errorContainer.withValues(alpha: 0.6), scheme.errorContainer.withValues(alpha: 0.3)],
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
                                          Container(
                                            decoration: BoxDecoration(
                                              color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Tooltip(
                                                  message: 'Compartilhar',
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      borderRadius: BorderRadius.circular(6),
                                                      onTap: () => _shareCounter(context, c, effectiveDate, isFuture),
                                                      child: const Padding(
                                                        padding: EdgeInsets.all(8),
                                                        child: Icon(
                                                          Icons.share,
                                                          size: 16.8,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const VerticalDivider(width: 1),
                                                Tooltip(
                                                  message: 'Excluir',
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      borderRadius: BorderRadius.circular(6),
                                                      onTap: () async {
                                                        final confirm = await showDialog<bool>(
                                                          context: context,
                                                          builder: (ctx) => AlertDialog(
                                                            title: const Text('Excluir corrida'),
                                                            content: const Text('Tem certeza que deseja excluir? Esta ação não pode ser desfeita.'),
                                                            actions: [
                                                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
                                                              TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Excluir')),
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
                                                      child: const Padding(
                                                        padding: EdgeInsets.all(8),
                                                        child: Icon(
                                                          Icons.delete_outline,
                                                          size: 16.8,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
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
                                                Text('Data:', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                                const SizedBox(height: 4),
                                                Text(DateFormat('dd/MM/yyyy').format(effectiveDate), style: const TextStyle(fontSize: 14)),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Horário:', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                                const SizedBox(height: 4),
                                                Text(DateFormat('HH:mm').format(effectiveDate), style: const TextStyle(fontSize: 14)),
                                              ],
                                            ),
                                          ]),
                                          TableRow(children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Distância:', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                                const SizedBox(height: 4),
                                                Text('$distLabel km', style: const TextStyle(fontSize: 14)),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Preço:', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
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
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(_iconForStatus(c.status), size: 14, color: scheme.onPrimaryContainer),
                                                const SizedBox(width: 6),
                                                Text(
                                                  _labelForStatus(c.status),
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onPrimaryContainer),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if ((c.registrationUrl?.isNotEmpty ?? false)) ...[
                                            const SizedBox(width: 8),
                                            InkWell(
                                              borderRadius: BorderRadius.circular(12),
                                              onTap: () => _openUrl(context, c.registrationUrl!),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.link, size: 14, color: scheme.onPrimaryContainer),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Link',
                                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onPrimaryContainer),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
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
