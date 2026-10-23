import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';

import '../models/check_in.dart';
import '../repositories/check_in_repository.dart';
import '../repositories/habit_repository.dart';
import '../repositories/profile_repository.dart';
import '../state/check_in_list_notifier.dart';

class CheckInDetailScreen extends StatefulWidget {
  final int id;

  const CheckInDetailScreen({super.key, required this.id});

  @override
  State<CheckInDetailScreen> createState() => _CheckInDetailScreenState();
}

class _CheckInDetailScreenState extends State<CheckInDetailScreen> {
  CheckIn? _checkIn;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final checkIn = await context.read<CheckInRepository>().findById(
        widget.id,
      );
      if (!mounted) return;
      setState(() {
        _checkIn = checkIn;
        _loading = false;
        if (checkIn == null) _error = 'Отметка не найдена';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _checkIn == null
              ? 'Загрузка отметки…'
              : 'Отметка: ${_checkIn!.date.day}.${_checkIn!.date.month}',
        ),
        actions: [
          if (_checkIn != null)
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/check-ins/${_checkIn!.id}/edit'),
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
                    onPressed: () => context.go('/check-ins'),
                    child: const Text('К списку отметок'),
                  ),
                ],
              ),
            )
          : _card(context, _checkIn!),
    );
  }

  Widget _card(BuildContext context, CheckIn checkIn) {
    final notifier = context.read<CheckInListNotifier>();
    final habitRepo = context.read<HabitRepository>();
    final profileRepo = context.read<ProfileRepository>();

    String nameOfHabit(int id) {
      for (final h in habitRepo.allActive()) {
        if (h.id == id) return h.name;
      }
      return '—';
    }

    String nameOfProfile(int id) {
      for (final p in profileRepo.allActive()) {
        if (p.id == id) return p.name;
      }
      return '—';
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row('Привычка', nameOfHabit(checkIn.habitId)),
              _row('Профиль', nameOfProfile(checkIn.profileId)),
              _row(
                'Дата',
                '${checkIn.date.day}.${checkIn.date.month}.${checkIn.date.year}',
              ),
              _row('Минут', '${checkIn.minutes}'),
              _row('Статус', checkIn.completed ? 'выполнено' : 'не выполнено'),
              _row('Заметка', checkIn.note.isEmpty ? '—' : checkIn.note),
              _row('Запись', checkIn.isDeleted ? 'удалена' : 'активна'),
              const SizedBox(height: 20),
              if (!checkIn.isDeleted)
                FilledButton.icon(
                  onPressed: () async {
                    await notifier.softDeleteOne(checkIn.id);
                    if (context.mounted) context.go('/check-ins');
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Удалить (в корзину)'),
                )
              else
                FilledButton.icon(
                  onPressed: () async {
                    await notifier.restoreOne(checkIn.id);
                    if (context.mounted) context.go('/check-ins');
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
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
