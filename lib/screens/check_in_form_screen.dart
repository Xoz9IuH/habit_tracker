import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../forms/entity_form.dart';
import '../forms/field_spec.dart';
import '../models/check_in.dart';
import '../repositories/check_in_repository.dart';
import '../repositories/habit_repository.dart';
import '../repositories/profile_repository.dart';
import '../state/check_in_list_notifier.dart';
import '../validation/validators.dart';

class CheckInFormScreen extends StatefulWidget {
  final int? id;

  const CheckInFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  State<CheckInFormScreen> createState() => _CheckInFormScreenState();
}

class _CheckInFormScreenState extends State<CheckInFormScreen> {
  CheckIn? _checkIn;
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
    final checkIn =
        await context.read<CheckInRepository>().findById(widget.id!);
    if (!context.mounted) return;
    setState(() {
      _checkIn = checkIn;
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
          context.go('/check-ins');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Изменение отметки' : 'Новая отметка'),
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
    final profileRepo = context.read<ProfileRepository>();
    final notifier = context.read<CheckInListNotifier>();
    final c = _checkIn;

    return EntityForm(
      key: const ValueKey('check_in_form'),
      onDirtyChange: () => setState(() => _dirty = true),
      submitLabel: widget.isEditing ? 'Сохранить изменения' : 'Создать',
      fieldsBuilder: (values) {
        final habits = habitRepo.allActive();
        final profiles = profileRepo.allActive();
        return [
          DropdownFieldSpec(
            'Привычка',
            initialValue: c?.habitId,
            items: [
              for (final h in habits) DropdownOption(h.id, h.name),
            ],
            validator: (v) => v == null ? 'Выберите привычку' : null,
            helpText: 'Связь «многие к одному»',
          ),
          DropdownFieldSpec(
            'Профиль',
            initialValue: c?.profileId,
            items: [
              for (final p in profiles) DropdownOption(p.id, p.name),
            ],
            validator: (v) => v == null ? 'Выберите профиль' : null,
            helpText: 'Связь «многие к одному»',
          ),
          DateFieldSpec(
            'Дата',
            initialValue: c?.date ?? DateTime.now(),
            validator: (v) => notInFuture(v, field: 'Дата'),
          ),
          NumberFieldSpec(
            'Минут',
            initialValue: c == null ? '' : '${c.minutes}',
            validator: (v) => intRange(v, min: 0, max: 1440, field: 'Минуты'),
          ),
          SwitchFieldSpec(
            'Выполнено',
            initialValue: c?.completed ?? true,
          ),
          TextFieldSpec(
            'Заметка',
            initialValue: c?.note ?? '',
            maxLength: 200,
            maxLines: 2,
            validator: (v) => maxLength(v, 200, field: 'Заметка'),
          ),
        ];
      },
      onSubmit: (values) async {
        final minutes = int.tryParse((values['Минут'] as String).trim());
        final saved = await notifier.save(CheckIn(
          id: widget.id ?? 0,
          habitId: values['Привычка'] as int,
          profileId: values['Профиль'] as int,
          date: values['Дата'] as DateTime,
          minutes: minutes ?? 0,
          completed: values['Выполнено'] as bool? ?? false,
          note: (values['Заметка'] as String).trim(),
        ));
        if (!context.mounted) return const FormResult(values: {});
        context.go('/check-ins/${saved.id}');
        return const FormResult(values: {});
      },
    );
  }
}
