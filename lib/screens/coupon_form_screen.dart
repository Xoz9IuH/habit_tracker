import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../forms/entity_form.dart';
import '../forms/field_spec.dart';
import '../models/coupon.dart';
import '../repositories/coupon_repository.dart';
import '../repositories/profile_repository.dart';
import '../state/coupon_list_notifier.dart';
import '../core/form_api_errors.dart';
import '../validation/validators.dart';

class CouponFormScreen extends StatefulWidget {
  final int? id;

  const CouponFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  State<CouponFormScreen> createState() => _CouponFormScreenState();
}

class _CouponFormScreenState extends State<CouponFormScreen> {
  Coupon? _coupon;
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
    final coupon = await context.read<CouponRepository>().findById(widget.id!);
    if (!context.mounted) return;
    setState(() {
      _coupon = coupon;
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
          context.go('/coupons');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Изменение купона' : 'Новый купон'),
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
    final profileRepo = context.read<ProfileRepository>();
    final notifier = context.read<CouponListNotifier>();
    final c = _coupon;
    final profiles = profileRepo.allActive();

    return EntityForm(
      key: const ValueKey('coupon_form'),
      onDirtyChange: () => setState(() => _dirty = true),
      submitLabel: widget.isEditing ? 'Сохранить изменения' : 'Создать',
      fieldsBuilder: (values) {
        return <FieldSpec>[
          TextFieldSpec(
            'Промокод',
            initialValue: c?.code ?? '',
            maxLength: 20,
            validator: (v) {
              final text = (v ?? '').trim();
              if (text.isEmpty) return 'Заполните промокод';
              if (!RegExp(r'^[A-Za-z0-9-]{4,20}$').hasMatch(text)) {
                return 'Промокод: 4–20 латинских букв, цифр и дефисов';
              }
              return null;
            },
            helpText: 'Промокод должен быть уникальным',
          ),
          DropdownFieldSpec(
            'Профиль',
            initialValue: c?.profileId,
            items: [for (final p in profiles) DropdownOption(p.id, p.name)],
            validator: (v) => v == null ? 'Выберите профиль' : null,
            helpText: 'Связь «один к одному»: у профиля один купон',
          ),
          NumberFieldSpec(
            'Скидка, %',
            initialValue: c == null ? '' : '${c.discountPercent}',
            validator: (v) => intRange(v, min: 1, max: 100, field: 'Скидка'),
          ),
          DateFieldSpec(
            'Действует до',
            initialValue:
                c?.expiresAt ?? DateTime.now().add(const Duration(days: 30)),
            validator: (v) {
              final date = v;
              if (date == null) return 'Выберите срок действия';
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              if (date.isBefore(today)) {
                return 'Срок действия не может быть в прошлом';
              }
              return null;
            },
          ),
        ];
      },
      onSubmit: (values) async {
        try {
          final saved = await notifier.save(
            Coupon(
              id: widget.id ?? 0,
              profileId: values['Профиль'] as int,
              code: (values['Промокод'] as String).trim(),
              discountPercent:
                  int.tryParse((values['Скидка, %'] as String).trim()) ?? 0,
              expiresAt:
                  values['Действует до'] as DateTime? ??
                  DateTime.now().add(const Duration(days: 30)),
            ),
          );
          if (!context.mounted) return const FormResult(values: {});
          context.go('/coupons/${saved.id}');
          return const FormResult(values: {});
        } catch (e) {
          return apiFormResult(e, const {
            'code': 'Промокод',
            'profileId': 'Профиль',
            'discountPercent': 'Скидка, %',
            'expiresAt': 'Действует до',
          });
        }
      },
    );
  }
}
