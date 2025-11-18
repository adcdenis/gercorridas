import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gercorridas/data/models/counter.dart' as model;
import 'package:gercorridas/state/providers.dart';
import 'package:gercorridas/data/models/category.dart' as cat;
import 'package:gercorridas/domain/category_utils.dart';

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
  // Holds a reference to the Autocomplete text field controller to keep UI in sync
  TextEditingController? _categoryFieldCtrl;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  // Campos de corrida
  String _status = 'pretendo_ir';
  DateTime? _createdAt;

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
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _distanceCtrl.dispose();
    _priceCtrl.dispose();
    _urlCtrl.dispose();
    _finishCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.counterId != null;
    final categoriesAsync = ref.watch(categoriesProvider);
    final countersAsync = ref.watch(corridasProvider);
    final categoryRepo = ref.read(categoryRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            Text(
              isEdit ? 'Editar Corrida' : 'Nova Corrida',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome da Corrida',
                border: OutlineInputBorder(),
              ),
              maxLength: 200,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe um nome' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Observações',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              maxLength: 500,
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Categoria da Corrida',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                // Autocomplete para listar e buscar categorias existentes
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
                        // Guarda referência para sincronizar quando chips/botões atualizam a categoria
                        _categoryFieldCtrl = textController;
                        return TextFormField(
                          controller: textController,
                          focusNode: focusNode,
                          maxLength: 100,
                          onChanged: (v) {
                            // Mantém _categoryCtrl como fonte de verdade para outros widgets
                            _categoryCtrl
                              ..text = v
                              ..selection = textController.selection;
                            setState(() {});
                          },
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            hintText: 'Selecione ou digite uma categoria',
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_categoryCtrl.text.isNotEmpty)
                                  IconButton(
                                    tooltip: 'Limpar',
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _categoryCtrl.clear();
                                      _categoryFieldCtrl?.clear();
                                      setState(() {});
                                    },
                                  ),
                                // Lista rápida de categorias já existentes
                                Builder(
                                  builder: (ctx) {
                                    final cats = categoriesAsync.maybeWhen(
                                      data: (list) => list,
                                      orElse: () => const <cat.Category>[],
                                    );
                                    if (cats.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return PopupMenuButton<String>(
                                      tooltip: 'Selecionar categoria existente',
                                      icon: const Icon(Icons.list),
                                      itemBuilder: (ctx) => cats
                                          .map(
                                            (c) => PopupMenuItem<String>(
                                              value: c.name,
                                              child: Text(c.name),
                                            ),
                                          )
                                          .toList(),
                                      onSelected: (value) {
                                        _categoryCtrl.text = value;
                                        _categoryFieldCtrl?.text = value;
                                        _categoryFieldCtrl?.selection =
                                            TextSelection.collapsed(
                                              offset: value.length,
                                            );
                                        setState(() {});
                                      },
                                    );
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Criar nova categoria',
                                  icon: const Icon(Icons.add),
                                  onPressed: () async {
                                    final name =
                                        (_categoryFieldCtrl?.text ??
                                                _categoryCtrl.text)
                                            .trim();
                                    if (name.isEmpty) return;
                                    final normalized = normalizeCategory(name);
                                    // Evita duplicação no client-side
                                    final exists = categoriesAsync.maybeWhen(
                                      data: (cats) => cats.any(
                                        (c) => c.normalized == normalized,
                                      ),
                                      orElse: () => false,
                                    );
                                    if (exists) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Categoria "$name" já existe',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    await categoryRepo.create(
                                      cat.Category(
                                        name: name,
                                        normalized: normalized,
                                      ),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Categoria "$name" criada',
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
                // Chips das categorias existentes para seleção rápida
                categoriesAsync.when(
                  data: (cats) {
                    if (cats.isEmpty) {
                      return const SizedBox.shrink();
                    }
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
                            child: InputChip(
                              label: Text(c.name),
                              selected: selected,
                              onPressed: () {
                                _categoryCtrl.text = c.name;
                                _categoryFieldCtrl?.text = c.name;
                                _categoryFieldCtrl?.selection =
                                    TextSelection.collapsed(
                                      offset: c.name.length,
                                    );
                                setState(() {});
                              },
                              onDeleted: isUsed
                                  ? null
                                  : () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text(
                                            'Excluir categoria',
                                          ),
                                          content: Text(
                                            'Excluir "${c.name}"? Esta ação não pode ser desfeita.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(false),
                                              child: const Text('Cancelar'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(true),
                                              child: const Text('Excluir'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm != true) return;
                                      final ok = await categoryRepo
                                          .deleteIfUnused(c);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
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
                                  ? const Icon(Icons.block)
                                  : const Icon(Icons.delete),
                              tooltip: isUsed ? 'Em uso' : 'Excluir',
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 4),
                // Botão de criação rápida quando texto não pertence a nenhuma categoria
                Builder(
                  builder: (context) {
                    final input = _categoryCtrl.text.trim();
                    final exists = categoriesAsync.maybeWhen(
                      data: (cats) => cats.any(
                        (c) => c.name.toLowerCase() == input.toLowerCase(),
                      ),
                      orElse: () => false,
                    );
                    if (input.isNotEmpty && !exists) {
                      return TextButton.icon(
                        onPressed: () async {
                          final normalized = normalizeCategory(input);
                          final exists = categoriesAsync.maybeWhen(
                            data: (cats) =>
                                cats.any((c) => c.normalized == normalized),
                            orElse: () => false,
                          );
                          if (exists) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Categoria "$input" já existe'),
                              ),
                            );
                            return;
                          }
                          await categoryRepo.create(
                            cat.Category(name: input, normalized: normalized),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Categoria "$input" criada'),
                            ),
                          );
                        },
                        icon: const Text('➕', style: TextStyle(fontSize: 20)),
                        label: Text('Criar "$input"'),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Campos específicos de corrida: distância, preço, URL e status
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _distanceCtrl,
                    decoration: InputDecoration(
                      labelText: 'Distância (km) *',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Informe a distância';
                      final d = double.tryParse(v.replaceAll(',', '.'));
                      if (d == null || d <= 0) return 'Distância inválida';
                      if (d > 999) return 'Distância máxima é 999';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    decoration: InputDecoration(
                      labelText: 'Preço (R\$)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final p = double.tryParse(v.replaceAll(',', '.'));
                      if (p == null || p < 0) return 'Preço inválido';
                      if (p > 99999999) return 'Preço máximo é 99.999.999';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'URL de Inscrição',
                      border: OutlineInputBorder(),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      counterText: '',
                    ),
                    keyboardType: TextInputType.url,
                    maxLength: 200,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _finishCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Tempo de Conclusão',
                      border: const OutlineInputBorder(),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      suffixIcon: IconButton(
                        tooltip: 'Selecionar horário',
                        icon: const Icon(Icons.access_time),
                        onPressed: () async {
                          await _pickFinishTimeWithSeconds();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(
                      value: 'pretendo_ir',
                      child: Text('Pretendo ir'),
                    ),
                    DropdownMenuItem(
                      value: 'inscrito',
                      child: Text('Inscrito'),
                    ),
                    DropdownMenuItem(
                      value: 'concluida',
                      child: Text('Concluída'),
                    ),
                    DropdownMenuItem(
                      value: 'cancelada',
                      child: Text('Cancelada'),
                    ),
                    DropdownMenuItem(
                      value: 'nao_pude_ir',
                      child: Text('Não pude ir'),
                    ),
                    DropdownMenuItem(
                      value: 'na_duvida',
                      child: Text('Na dúvida'),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _status = v ?? 'pretendo_ir'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
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
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      'Data: ${_date.day}/${_date.month}/${_date.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _time,
                      );
                      if (picked != null) {
                        setState(() => _time = picked);
                      }
                    },
                    icon: const Icon(Icons.access_time),
                    label: Text('Hora: ${_time.format(context)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('btn_submit_corrida'),
                    onPressed: _onSubmit,
                    icon: const Text('💾', style: TextStyle(fontSize: 20)),
                    label: Text(isEdit ? 'Atualizar Corrida' : 'Criar Corrida'),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => context.go('/corridas'),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(corridaRepositoryProvider);
    final categoryRepo = ref.read(categoryRepositoryProvider);
    final dt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );

    // Garante que a categoria digitada exista na tabela de categorias
    final catName = _categoryCtrl.text.trim();
    if (catName.isNotEmpty) {
      final normalized = normalizeCategory(catName);
      await categoryRepo.create(
        cat.Category(name: catName, normalized: normalized),
      );
    }

    final distance =
        double.tryParse(_distanceCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final price = _priceCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_priceCtrl.text.replaceAll(',', '.'));
    final finish = _finishCtrl.text.trim().isEmpty
        ? null
        : _finishCtrl.text.trim();

    if (widget.counterId == null) {
      final now = DateTime.now();
      final c = model.Counter(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        eventDate: dt,
        category: _categoryCtrl.text.trim().isEmpty
            ? null
            : _categoryCtrl.text.trim(),
        status: _status,
        distanceKm: distance,
        price: price,
        registrationUrl: _urlCtrl.text.trim().isEmpty
            ? null
            : _urlCtrl.text.trim(),
        finishTime: finish,
        createdAt: now,
        updatedAt: now,
      );
      await repo.create(c);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Corrida criada com sucesso')),
      );
      context.go('/corridas');
    } else {
      final now = DateTime.now();
      final c = model.Counter(
        id: widget.counterId,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        eventDate: dt,
        category: _categoryCtrl.text.trim().isEmpty
            ? null
            : _categoryCtrl.text.trim(),
        status: _status,
        distanceKm: distance,
        price: price,
        registrationUrl: _urlCtrl.text.trim().isEmpty
            ? null
            : _urlCtrl.text.trim(),
        finishTime: finish,
        createdAt: _createdAt ?? now,
        updatedAt: now,
      );
      final ok = await repo.update(c);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Corrida atualizada' : 'Falha ao atualizar'),
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
        title: const Text('Tempo de conclusão'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: hc,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Horas',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: mc,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Minutos',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: sc,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Segundos',
                  border: OutlineInputBorder(),
                ),
              ),
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
            child: const Text('OK'),
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
}
