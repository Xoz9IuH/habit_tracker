import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/coupon.dart';
import '../repositories/coupon_repository.dart';
import '../repositories/profile_repository.dart';
import '../state/coupon_list_notifier.dart';

class CouponDetailScreen extends StatefulWidget {
  final int id;

  const CouponDetailScreen({super.key, required this.id});

  @override
  State<CouponDetailScreen> createState() => _CouponDetailScreenState();
}

class _CouponDetailScreenState extends State<CouponDetailScreen> {
  Coupon? _coupon;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final coupon =
        await context.read<CouponRepository>().findById(widget.id);
    if (!context.mounted) return;
    setState(() {
      _coupon = coupon;
      _loading = false;
      if (coupon == null) _error = 'Купон не найден';
    });
  }

  Future<bool> _confirm(String title, String text) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_coupon?.code ?? 'Загрузка купона…'),
        actions: [
          if (_coupon != null)
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/coupons/${_coupon!.id}/edit'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => context.go('/coupons'),
                        child: const Text('К списку купонов'),
                      ),
                    ],
                  ),
                )
              : _card(context, _coupon!),
    );
  }

  Widget _card(BuildContext context, Coupon coupon) {
    final notifier = context.read<CouponListNotifier>();
    final profiles = context.read<ProfileRepository>().allActive();
    String profileName = '—';
    for (final p in profiles) {
      if (p.id == coupon.profileId) profileName = p.name;
    }
    final active = coupon.isActiveAt(DateTime.now());

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row('Промокод', coupon.code),
              _row('Профиль', profileName),
              _row('Скидка', '${coupon.discountPercent}%'),
              _row('Действует до',
                  '${coupon.expiresAt.day}.${coupon.expiresAt.month}.${coupon.expiresAt.year}'),
              _row('Состояние', active ? 'активен' : 'истёк или удалён'),
              const SizedBox(height: 20),
              if (!coupon.isDeleted)
                FilledButton.icon(
                  onPressed: () async {
                    if (!await _confirm('Удалить купон?',
                        'Купон уйдёт в корзину, его можно будет вернуть.')) {
                      return;
                    }
                    await notifier.softDeleteOne(coupon.id);
                    if (context.mounted) context.go('/coupons');
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Удалить (в корзину)'),
                )
              else
                FilledButton.icon(
                  onPressed: () async {
                    await notifier.restoreOne(coupon.id);
                    if (context.mounted) context.go('/coupons');
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('Вернуть из корзины'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
