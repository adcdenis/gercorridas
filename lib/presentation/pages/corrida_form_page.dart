import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gercorridas/data/models/counter.dart' as model;
import 'package:gercorridas/state/providers.dart';
import 'package:gercorridas/data/models/category.dart' as cat;
import 'package:gercorridas/domain/category_utils.dart';
import 'package:gercorridas/domain/time_utils.dart';
import 'package:gercorridas/presentation/widgets/premium_paywall_widget.dart';

class CorridaFormPage extends ConsumerStatefulWidget {
  final int? counterId;
  const CorridaFormPage({super.key, this.counterId});

  @override
  ConsumerState<CorridaFormPage> createState() => _CorridaFormPageState();
}

class _CorridaFormPageState extends ConsumerState<CorridaFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _finishCtrl = TextEditingController();

  TextEditingController? _categoryFieldCtrl;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  String _status = 'pretendo_ir';
  DateTime? _createdAt;

  static const _quickDistances = [5.0, 10.0, 15.0, 21.1, 42.2];

  static const _statusOptions = [
    (
      key: 'pretendo_ir',
      label: 'Pretendo ir',
      icon: Icons.flag_outlined,
      color: Color(0xFF2563EB),
    ),
    (
      key: 'inscrito',
      label: 'Inscrito',
      icon: Icons.confirmation_number_outlined,
      color: Color(0xFF0284C7),
    ),
    (
      key: 'concluida',
      label: 'Concluída',
      icon: Icons.emoji_events_outlined,
      color: Color(0xFF16A34A),
    ),
    (
      key: 'na_duvida',
      label: 'Na dúvida',
      icon: Icons.help_outline_rounded,
      color: Color(0xFFD97706),
    ),
    (
      key: 'cancelada',
      label: 'Cancelada',
      icon: Icons.cancel_outlined,
      color: Color(0xFFDC2626),
    ),
    (
      key: 'nao_pude_ir',
      label: 'Não pude ir',
      icon: Icons.event_busy_outlined,
      color: Color(0xFF64748B),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadForEditIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final t = _categoryCtrl.text.trim();
      if (t.isNotEmpty) {
        _categoryFieldCtrl?.text = t;
        _categoryFieldCtrl?.selection = TextSelection.collapsed(
          offset: t.length,
        );
        setState(() {});
      }
    });

    _distanceCtrl.addListener(_onMetricChanged);
    _finishCtrl.addListener(_onMetricChanged);
  }

  void _onMetricChanged() {
    setState(() {});
  }

  Future<void> _loadForEditIfNeeded() async {
    final id = widget.counterId;
    if (id != null) {
      final repo = ref.read(corridaRepositoryProvider);
      final c = await repo.byId(id);
      if (c != null) {
        final base = c.eventDate;
        setState(() {
          _nameCtrl.text = c.name;
          _descCtrl.text = c.description ?? '';
          _categoryCtrl.text = c.category ?? '';
          final catText = c.category ?? '';
          _categoryFieldCtrl?.text = catText;
          _categoryFieldCtrl?.selection = TextSelection.collapsed(
            offset: catText.length,
          );
          final dist = c.distanceKm;
          final distStr = (dist % 1 == 0)
              ? dist.toStringAsFixed(0)
              : NumberFormat.decimalPattern('pt_BR').format(dist);
          _distanceCtrl.text = distStr;
          _priceCtrl.text = c.price == null ? '' : c.price!.toStringAsFixed(2);
          _urlCtrl.text = c.registrationUrl ?? '';
          _finishCtrl.text = c.finishTime ?? '';
          _date = base;
          _time = TimeOfDay(hour: base.hour, minute: base.minute);
          _status = c.status;
          _createdAt = c.createdAt;
        });
      }
    }
  }

  @override
  void dispose() {
    _distanceCtrl.removeListener(_onMetricChanged);
    _finishCtrl.removeListener(_onMetricChanged);
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _distanceCtrl.dispose();
    _priceCtrl.dispose();
    _urlCtrl.dispose();
    _finishCtrl.dispose();
    super.dispose();
  }

  Duration? _parseFinishDuration() {
    final t = _finishCtrl.text.trim();
    if (t.isEmpty) return null;
    final parts = t.split(':');
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      if (h == 0 && m == 0 && s == 0) return null;
      return Duration(hours: h, minutes: m, seconds: s);
    } else if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      if (m == 0 && s == 0) return null;
      return Duration(minutes: m, seconds: s);
    }
    return null;
  }

  double? _parseDistance() {
    final raw = _distanceCtrl.text.trim().replaceAll(',', '.');
    final val = double.tryParse(raw);
    if (val != null && val > 0) return val;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.counterId != null;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoriesAsync = ref.watch(categoriesProvider);
    final countersAsync = ref.watch(corridasProvider);
    final categoryRepo = ref.read(categoryRepositoryProvider);

    final dur = _parseFinishDuration();
    final dist = _parseDistance();
    final pace = (dur != null && dist != null) ? computePace(dur, dist) : null;
    final speedKmh = (dur != null && dist != null && dur.inSeconds > 0)
        ? (dist / (dur.inSeconds / 3600))
        : null;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Cabeçalho da página
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isEdit ? Icons.edit_note_rounded : Icons.add_task_rounded,
                  color: colorScheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? 'Editar Corrida' : 'Nova Corrida',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isEdit
                          ? 'Atualize os dados e resultados desta prova'
                          : 'Planeje sua próxima meta esportiva',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Seção 1: Dados da Prova
          _buildCard(
            context,
            title: 'Dados da Prova',
            icon: Icons.sports_score_rounded,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome da Corrida *',
                  hintText: 'Ex: Maratona do Rio, Circuito das Estações',
                  prefixIcon: Icon(Icons.directions_run_rounded),
                ),
                maxLength: 200,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome da corrida' : null,
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Categoria',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue tv) {
                      final q = tv.text.trim().toLowerCase();
                      return categoriesAsync.maybeWhen(
                        data: (cats) {
                          if (q.isEmpty) return cats.map((c) => c.name);
                          final nq = normalizeCategory(q);
                          return cats
                              .where(
                                (c) =>
                                    c.name.toLowerCase().contains(q) ||
                                    c.normalized.contains(nq),
                              )
                              .map((c) => c.name);
                        },
                        orElse: () => const [],
                      );
                    },
                    fieldViewBuilder:
                        (context, textController, focusNode, onFieldSubmitted) {
                      _categoryFieldCtrl = textController;
                      return TextFormField(
                        controller: textController,
                        focusNode: focusNode,
                        maxLength: 100,
                        onChanged: (v) {
                          _categoryCtrl
                            ..text = v
                            ..selection = textController.selection;
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          hintText: 'Selecione ou digite uma categoria',
                          prefixIcon: const Icon(Icons.category_outlined),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_categoryCtrl.text.isNotEmpty)
                                IconButton(
                                  tooltip: 'Limpar categoria',
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _categoryCtrl.clear();
                                    _categoryFieldCtrl?.clear();
                                    setState(() {});
                                  },
                                ),
                              IconButton(
                                tooltip: 'Salvar como nova categoria',
                                icon: const Icon(Icons.add_circle_outline, size: 22),
                                onPressed: () async {
                                  final name = (_categoryFieldCtrl?.text ?? _categoryCtrl.text).trim();
                                  if (name.isEmpty) return;
                                  final normalized = normalizeCategory(name);
                                  final exists = categoriesAsync.maybeWhen(
                                    data: (cats) => cats.any((c) => c.normalized == normalized),
                                    orElse: () => false,
                                  );
                                  if (exists) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Categoria "$name" já existe')),
                                    );
                                    return;
                                  }
                                  await categoryRepo.create(
                                    cat.Category(name: name, normalized: normalized),
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Categoria "$name" adicionada')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    onSelected: (value) {
                      _categoryCtrl.text = value;
                      _categoryFieldCtrl?.text = value;
                      _categoryFieldCtrl?.selection = TextSelection.collapsed(
                        offset: value.length,
                      );
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),

                  // Chips rápidos de categorias existentes
                  categoriesAsync.when(
                    data: (cats) {
                      if (cats.isEmpty) return const SizedBox.shrink();
                      final usedNames = countersAsync.maybeWhen(
                        data: (ctrs) => ctrs
                            .map((c) => c.category?.trim())
                            .whereType<String>()
                            .map((name) => normalizeCategory(name))
                            .toSet(),
                        orElse: () => <String>{},
                      );
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: cats.map((c) {
                            final selected = _categoryCtrl.text.trim() == c.name;
                            final isUsed = usedNames.contains(c.normalized);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                label: Text(c.name),
                                selected: selected,
                                showCheckmark: true,
                                onSelected: (sel) {
                                  HapticFeedback.selectionClick();
                                  final newName = sel ? c.name : '';
                                  _categoryCtrl.text = newName;
                                  _categoryFieldCtrl?.text = newName;
                                  _categoryFieldCtrl?.selection = TextSelection.collapsed(
                                    offset: newName.length,
                                  );
                                  setState(() {});
                                },
                                onDeleted: isUsed
                                    ? null
                                    : () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Excluir categoria'),
                                            content: Text(
                                              'Excluir "${c.name}"? Esta ação não pode ser desfeita.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(ctx).pop(false),
                                                child: const Text('Cancelar'),
                                              ),
                                              FilledButton(
                                                onPressed: () => Navigator.of(ctx).pop(true),
                                                child: const Text('Excluir'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm != true) return;
                                        final ok = await categoryRepo.deleteIfUnused(c);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              ok
                                                  ? 'Categoria "${c.name}" excluída'
                                                  : 'Não é possível excluir: em uso',
                                            ),
                                          ),
                                        );
                                      },
                                deleteIcon: isUsed
                                    ? null
                                    : const Icon(Icons.close_rounded, size: 16),
                                deleteButtonTooltipMessage: isUsed ? 'Em uso' : 'Excluir categoria',
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                    loading: () => const LinearProgressIndicator(minHeight: 2),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Local ou Observações',
                  hintText: 'Ex: Aterro do Flamengo, largada no portão B',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                maxLines: 2,
                maxLength: 500,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Seção 2: Data e Horário
          _buildCard(
            context,
            title: 'Data & Horário',
            icon: Icons.calendar_month_outlined,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(
                            () => _date = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              _date.hour,
                              _date.minute,
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, color: colorScheme.primary, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Data da Prova',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('dd/MM/yyyy').format(_date),
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _time,
                        );
                        if (picked != null) {
                          setState(() => _time = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.alarm_rounded, color: colorScheme.primary, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Largada',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _time.format(context),
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
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
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Seção 3: Performance & Métricas
          _buildCard(
            context,
            title: 'Performance & Métricas',
            icon: Icons.speed_rounded,
            children: [
              TextFormField(
                controller: _distanceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Distância (km) *',
                  hintText: 'Ex: 10 ou 21.1',
                  prefixIcon: Icon(Icons.straighten_rounded),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Informe a distância da prova';
                  }
                  final d = double.tryParse(v.replaceAll(',', '.'));
                  if (d == null || d <= 0) return 'Distância inválida';
                  if (d > 999) return 'Distância máxima é 999 km';
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Atalhos de distâncias populares
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickDistances.map((d) {
                    final isSelected = (_parseDistance() == d);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        avatar: isSelected
                            ? const Icon(Icons.check, size: 16)
                            : null,
                        label: Text('${d % 1 == 0 ? d.toInt() : d} km'),
                        backgroundColor: isSelected
                            ? colorScheme.primaryContainer
                            : null,
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          final str = d % 1 == 0 ? d.toStringAsFixed(0) : d.toString();
                          _distanceCtrl.text = str;
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  HapticFeedback.lightImpact();
                  await _pickFinishTimeWithSeconds();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, color: colorScheme.primary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tempo de Conclusão / Oficial',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _finishCtrl.text.trim().isEmpty
                                  ? 'Toque para registrar o tempo (hh:mm:ss)'
                                  : _finishCtrl.text.trim(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _finishCtrl.text.trim().isEmpty
                                    ? colorScheme.onSurfaceVariant
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_finishCtrl.text.trim().isNotEmpty)
                        IconButton(
                          tooltip: 'Limpar tempo',
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _finishCtrl.clear();
                            setState(() {});
                          },
                        )
                      else
                        const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),

              // Banner de cálculo em tempo real do Pace e Velocidade
              if (pace != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer.withValues(alpha: 0.7),
                        colorScheme.secondaryContainer.withValues(alpha: 0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.speed_rounded, size: 18, color: colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                'Pace Médio',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pace,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 36,
                        width: 1,
                        color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                      Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.trending_up_rounded, size: 18, color: colorScheme.secondary),
                              const SizedBox(width: 6),
                              Text(
                                'Velocidade',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            speedKmh != null ? '${speedKmh.toStringAsFixed(1)} km/h' : '-',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Seção 4: Status & Inscrição
          _buildCard(
            context,
            title: 'Status & Inscrição',
            icon: Icons.flag_outlined,
            children: [
              Text(
                'Status da Corrida',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),

              // Seletor visual de Status (Grid responsiva de Chips esportivos)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statusOptions.map((opt) {
                  final isSelected = (_status == opt.key);
                  return ChoiceChip(
                    avatar: Icon(
                      opt.icon,
                      size: 18,
                      color: isSelected ? Colors.white : opt.color,
                    ),
                    label: Text(opt.label),
                    selected: isSelected,
                    selectedColor: opt.color,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                    ),
                    onSelected: (sel) {
                      if (sel) {
                        HapticFeedback.selectionClick();
                        setState(() => _status = opt.key);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Preço da Inscrição (R\$)',
                  hintText: 'Ex: 89.90',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final p = double.tryParse(v.replaceAll(',', '.'));
                  if (p == null || p < 0) return 'Preço inválido';
                  if (p > 99999999) return 'Preço máximo é 99.999.999';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Link de Inscrição / Regulamento',
                  hintText: 'https://exemplo.com/evento',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
                keyboardType: TextInputType.url,
                maxLength: 200,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Botões de Ação
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    key: const ValueKey('btn_submit_corrida'),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _onSubmit();
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
                    label: Text(
                      isEdit ? 'Atualizar Corrida' : 'Salvar Corrida',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.go('/corridas');
                  },
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final isPro = ref.read(premiumProvider);
    if (!isPro && widget.counterId == null) {
      final corridasAsync = ref.read(corridasProvider);
      final count = corridasAsync.maybeWhen(
        data: (list) => list.length,
        orElse: () => 0,
      );
      if (count >= 15) {
        _showPremiumLimitDialog(context);
        return;
      }
    }

    final repo = ref.read(corridaRepositoryProvider);
    final categoryRepo = ref.read(categoryRepositoryProvider);
    final dt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );

    final catName = _categoryCtrl.text.trim();
    if (catName.isNotEmpty) {
      final normalized = normalizeCategory(catName);
      await categoryRepo.create(
        cat.Category(name: catName, normalized: normalized),
      );
    }

    final distance = double.tryParse(_distanceCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final price = _priceCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_priceCtrl.text.replaceAll(',', '.'));
    final finish = _finishCtrl.text.trim().isEmpty ? null : _finishCtrl.text.trim();

    if (widget.counterId == null) {
      final now = DateTime.now();
      final c = model.Counter(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        eventDate: dt,
        category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
        status: _status,
        distanceKm: distance,
        price: price,
        registrationUrl: _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
        finishTime: finish,
        createdAt: now,
        updatedAt: now,
      );
      await repo.create(c);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Corrida cadastrada com sucesso!')),
      );
      context.go('/corridas');
    } else {
      final now = DateTime.now();
      final c = model.Counter(
        id: widget.counterId,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        eventDate: dt,
        category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
        status: _status,
        distanceKm: distance,
        price: price,
        registrationUrl: _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
        finishTime: finish,
        createdAt: _createdAt ?? now,
        updatedAt: now,
      );
      final ok = await repo.update(c);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Corrida atualizada com sucesso!' : 'Falha ao atualizar'),
        ),
      );
      context.go('/corridas');
    }
  }

  Future<void> _pickFinishTimeWithSeconds() async {
    int h = 0, m = 0, s = 0;
    final current = _finishCtrl.text.trim();
    if (current.isNotEmpty) {
      final parts = current.split(':');
      if (parts.length == 3) {
        h = int.tryParse(parts[0]) ?? 0;
        m = int.tryParse(parts[1]) ?? 0;
        s = int.tryParse(parts[2]) ?? 0;
      } else if (parts.length == 2) {
        h = int.tryParse(parts[0]) ?? 0;
        m = int.tryParse(parts[1]) ?? 0;
      }
    }

    final hc = TextEditingController(text: h.toString().padLeft(2, '0'));
    final mc = TextEditingController(text: m.toString().padLeft(2, '0'));
    final sc = TextEditingController(text: s.toString().padLeft(2, '0'));

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.timer_outlined, color: Color(0xFF0062E3)),
            SizedBox(width: 8),
            Text('Tempo de Conclusão'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Insira as horas, minutos e segundos oficiais da sua prova:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: hc,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Horas',
                      hintText: '00',
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: TextField(
                    controller: mc,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Minutos',
                      hintText: '00',
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: TextField(
                    controller: sc,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Segundos',
                      hintText: '00',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (result == true) {
      int hh = int.tryParse(hc.text) ?? 0;
      int mm = int.tryParse(mc.text) ?? 0;
      int ss = int.tryParse(sc.text) ?? 0;
      hh = hh.clamp(0, 99);
      mm = mm.clamp(0, 59);
      ss = ss.clamp(0, 59);
      _finishCtrl.text =
          '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  void _showPremiumLimitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.workspace_premium, color: Colors.amber),
            SizedBox(width: 8),
            Text('Limite Atingido'),
          ],
        ),
        content: const SizedBox(
          width: 400,
          child: PremiumPaywallWidget(
            customMessage:
                'Você atingiu o limite da versão gratuita (máximo de 15 corridas). Adquira a versão Pro para cadastrar corridas ilimitadas!',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
