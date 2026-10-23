import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../forms/entity_form.dart';
import '../forms/field_spec.dart';
import '../models/coupon.dart';
import '../models/profile.dart';
import '../repositories/coupon_repository.dart';
import '../repositories/profile_repository.dart';
import '../state/profile_list_notifier.dart';
import '../core/form_api_errors.dart';
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
    final profile = await context.read<ProfileRepository>().findById(
      widget.id!,
    );
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
          'Изменения не были сохранены. Если уйти, они потеряются.',
        ),
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
    final couponRepo = context.read<CouponRepository>();
    final notifier = context.read<ProfileListNotifier>();
    final p = _profile;
    final coupon = p?.couponId == null ? null : couponRepo.findByProfile(p!.id);

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
                initialValue: p == null ? '' : '${p.dailyGoalMinutes}',
                validator: (v) => positiveInt(v, field: 'Цель'),
              ),
              SwitchFieldSpec(
                'Напоминания включены',
                initialValue: p?.remindersEnabled ?? false,
              ),
            ],
          ),

          FieldGroupSpec(
            'Скидочный купон',
            helpText: 'Связь «один к одному»: у профиля один купон',
            children: [
              TextFieldSpec(
                'Промокод',
                initialValue: coupon?.code ?? '',
                maxLength: 20,
                validator: (v) {
                  final text = (v ?? '').trim();
                  if (text.isEmpty) return null;
                  if (!RegExp(r'^[A-Za-z0-9-]{4,20}$').hasMatch(text)) {
                    return 'Промокод: 4–20 латинских букв, цифр и дефисов';
                  }
                  return null;
                },
                helpText: 'Оставьте пустым, если купона нет',
              ),
              NumberFieldSpec(
                'Скидка, %',
                initialValue: coupon == null ? '' : '${coupon.discountPercent}',
                validator: (v) {
                  final text = (v ?? '').trim();
                  if (text.isEmpty) return null;
                  return intRange(text, min: 1, max: 100, field: 'Скидка');
                },
              ),
              DateFieldSpec(
                'Действует до',
                initialValue:
                    coupon?.expiresAt ??
                    DateTime.now().add(const Duration(days: 30)),
                validator: (v) {
                  final date = v;
                  if (date == null) return null;
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  if (date.isBefore(today)) {
                    return 'Срок действия не может быть в прошлом';
                  }
                  return null;
                },
              ),
            ],
          ),
        ];
      },
      onSubmit: (values) async {
        try {
          final goal = int.tryParse(
            (values['Цель в минутах в день'] as String).trim(),
          );
          final code = (values['Промокод'] as String).trim();

          final saved = await notifier.save(
            Profile(
              id: widget.id ?? 0,
              name: (values['Имя'] as String).trim(),
              email: (values['Почта'] as String).trim(),
              city: (values['Город'] as String).trim(),
              dailyGoalMinutes: goal ?? 0,
              remindersEnabled:
                  values['Напоминания включены'] as bool? ?? false,
              couponId: coupon?.id,
            ),
          );

          if (code.isNotEmpty) {
            final discount =
                int.tryParse((values['Скидка, %'] as String).trim()) ?? 0;
            final expires =
                values['Действует до'] as DateTime? ??
                DateTime.now().add(const Duration(days: 30));
            await couponRepo.saveCoupon(
              Coupon(
                id: coupon?.id ?? 0,
                profileId: saved.id,
                code: code,
                discountPercent: discount,
                expiresAt: expires,
              ),
            );
          } else if (coupon != null) {
            await couponRepo.softDelete(coupon.id, DateTime.now());
          }

          if (!context.mounted) return const FormResult(values: {});
          context.go('/profiles/${saved.id}');
          return const FormResult(values: {});
        } catch (e) {
          return apiFormResult(e, const {
            'name': 'Имя',
            'email': 'Почта',
            'city': 'Город',
            'dailyGoalMinutes': 'Цель в минутах в день',
            'code': 'Промокод',
            'discountPercent': 'Скидка, %',
            'expiresAt': 'Действует до',
            'profileId': 'Промокод',
          });
        }
      },
    );
  }
}
