import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../forms/entity_form.dart';
import '../forms/field_spec.dart';
import '../models/profile.dart';
import '../repositories/profile_repository.dart';
import '../state/profile_list_notifier.dart';
import '../validation/validators.dart';

class ProfileFormScreen extends StatefulWidget {
  final int? id;

  const ProfileFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  Profile? _profile;
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
    final profile =
        await context.read<ProfileRepository>().findById(widget.id!);
    if (!context.mounted) return;
    setState(() {
      _profile = profile;
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
          context.go('/profiles');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Изменение профиля' : 'Новый профиль'),
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
    final repo = context.read<ProfileRepository>();
    final notifier = context.read<ProfileListNotifier>();
    final p = _profile;

    return EntityForm(
      key: const ValueKey('profile_form'),
      onDirtyChange: () => setState(() => _dirty = true),
      submitLabel: widget.isEditing ? 'Сохранить изменения' : 'Создать',
      fieldsBuilder: (values) {
        return <FieldSpec>[
          TextFieldSpec(
            'Имя',
            initialValue: p?.name ?? '',
            maxLength: 60,
            validator: (v) {
              final err = requiredText(v, field: 'имя');
              if (err != null) return err;
              return maxLength(v, 60, field: 'Имя');
            },
          ),
          TextFieldSpec(
            'Почта',
            initialValue: p?.email ?? '',
            keyboardType: TextInputType.emailAddress,
            maxLength: 80,
            validator: (v) => email(v),
            helpText: 'Почта должна быть уникальной',
          ),
          TextFieldSpec(
            'Город',
            initialValue: p?.city ?? '',
            maxLength: 60,
            validator: (v) => requiredText(v, field: 'город'),
          ),

          FieldGroupSpec(
            'Настройки',
            helpText: 'Связь «один к одному» — отдельного экрана нет',
            children: [
              NumberFieldSpec(
                'Цель в минутах в день',
                initialValue:
                    p == null ? '' : '${p.dailyGoalMinutes}',
                validator: (v) => positiveInt(v, field: 'Цель'),
              ),
              SwitchFieldSpec(
                'Напоминания включены',
                initialValue: p?.remindersEnabled ?? false,
              ),
            ],
          ),
        ];
      },
      onSubmit: (values) async {
        final mail = (values['Почта'] as String).trim();
        final duplicate = await repo.findByEmail(mail, excludeId: widget.id);
        if (duplicate != null) {
          return const FormResult(
            values: {},
            errorField: 'Почта',
            errorMessage: 'Почта уже занята другим профилем',
          );
        }
        final goal =
            int.tryParse((values['Цель в минутах в день'] as String).trim());
        final saved = await notifier.save(Profile(
          id: widget.id ?? 0,
          name: (values['Имя'] as String).trim(),
          email: mail,
          city: (values['Город'] as String).trim(),
          dailyGoalMinutes: goal ?? 0,
          remindersEnabled: values['Напоминания включены'] as bool? ?? false,
        ));
        if (!context.mounted) return const FormResult(values: {});
        context.go('/profiles/${saved.id}');
        return const FormResult(values: {});
      },
    );
  }
}
