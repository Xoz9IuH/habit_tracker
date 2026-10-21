import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/seed.dart';
import '../forms/entity_form.dart';
import '../forms/field_spec.dart';
import '../models/habit.dart';
import '../repositories/category_repository.dart';
import '../repositories/habit_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/tag_repository.dart';
import '../state/habit_list_notifier.dart';
import '../validation/validators.dart';

class HabitFormScreen extends StatefulWidget {
  final int? id;

  const HabitFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  State<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends State<HabitFormScreen> {
  Habit? _habit;
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.id == null) {
      setState(() => _loading = false);
      return;
    }
    final habit = await context.read<HabitRepository>().findById(widget.id!);
    if (!context.mounted) return;
    setState(() {
      _habit = habit;
      _loading = false;
    });
  }

  Future<bool> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти без сохранения?'),
        content: const Text(
            'Изменения не были сохранены. Если уйти, они потеряются.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          context.go('/habits');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Изменение привычки' : 'Новая привычка'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _form(context),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final habitRepo = context.read<HabitRepository>();
    final categoryRepo = context.read<CategoryRepository>();
    final tagRepo = context.read<TagRepository>();
    final profileRepo = context.read<ProfileRepository>();
    final notifier = context.read<HabitListNotifier>();

    final h = _habit;

    return EntityForm(
      key: const ValueKey('habit_form'),
      onDirtyChange: () => setState(() => _dirty = true),
      submitLabel: widget.isEditing ? 'Сохранить изменения' : 'Создать',
      fieldsBuilder: (values) {
        final categories = categoryRepo.allActive();
        final profiles = profileRepo.allActive();
        final allTags = tagRepo.allActive();

        final selectedCategory = values['Категория'] as int?;
        final visibleTags = allTags
            .where((t) =>
                t.categoryId == null ||
                selectedCategory == null ||
                t.categoryId == selectedCategory)
            .toList();

        return <FieldSpec>[
          TextFieldSpec(
            'Название',
            initialValue: h?.name ?? '',
            maxLength: 60,
            validator: (v) {
              final err = requiredText(v, field: 'название');
              if (err != null) return err;
              return maxLength(v, 60, field: 'Название');
            },
          ),
          TextFieldSpec(
            'Цель',
            initialValue: h?.goal ?? '',
            maxLength: 120,
            validator: (v) => requiredText(v, field: 'цель'),
          ),
          DropdownFieldSpec(
            'Категория',
            initialValue: h?.categoryId,
            items: [
              for (final c in categories) DropdownOption(c.id, c.name),
            ],
            validator: (v) => v == null ? 'Выберите категорию' : null,
            helpText: 'Связь «многие к одному»',
          ),
          DropdownFieldSpec(
            'Профиль',
            initialValue: h?.profileId,
            items: [
              for (final p in profiles) DropdownOption(p.id, p.name),
            ],
            validator: (v) => v == null ? 'Выберите профиль' : null,
            helpText: 'Связь «многие к одному»',
          ),
          DropdownFieldSpec(
            'Периодичность',
            initialValue: h?.periodicityId,
            items: [
              for (final p in periodicities) DropdownOption(p.id, p.name),
            ],
            validator: (v) => v == null ? 'Выберите периодичность' : null,
          ),
          MultiSelectFieldSpec(
            'Теги',
            initialValue: h?.tagIds ?? const [],
            items: [
              for (final t in visibleTags) DropdownOption(t.id, t.name),
            ],
            validator: (v) =>
                v.isEmpty ? 'Выберите хотя бы один тег' : null,
            helpText: 'Связь «многие ко многим»',
          ),
          NumberFieldSpec(
            'Минут в день',
            initialValue: h == null ? '' : '${h.minutesPerDay}',
            validator: (v) => intRange(v, min: 0, max: 600, field: 'Минуты'),
          ),
          NumberFieldSpec(
            'Серия дней',
            initialValue: h == null ? '' : '${h.streak}',
            validator: (v) => intRange(v, min: 0, max: 3650, field: 'Серия'),
          ),
        ];
      },
      onSubmit: (values) async {
        final name = (values['Название'] as String).trim();
        final duplicate = await habitRepo.findByName(name);
        if (duplicate != null && duplicate.id != widget.id) {
          return const FormResult(
            values: {},
            errorField: 'Название',
            errorMessage: 'Привычка с таким названием уже есть',
          );
        }
        final minutes = int.tryParse((values['Минут в день'] as String).trim());
        final streak = int.tryParse((values['Серия дней'] as String).trim());
        final saved = await notifier.save(Habit(
          id: widget.id ?? 0,
          name: name,
          goal: (values['Цель'] as String).trim(),
          categoryId: values['Категория'] as int,
          periodicityId: values['Периодичность'] as int,
          minutesPerDay: minutes ?? 0,
          streak: streak ?? 0,
          profileId: values['Профиль'] as int,
          tagIds: List<int>.from(values['Теги'] as List<int>),
        ));
        if (!context.mounted) return const FormResult(values: {});
        context.go('/habits/${saved.id}');
        return const FormResult(values: {});
      },
    );
  }
}
