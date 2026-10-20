import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/seed.dart';
import '../models/habit.dart';
import '../repositories/habit_repository.dart';
import '../state/habit_list_notifier.dart';

class HabitDetailScreen extends StatefulWidget {
  final int id;

  const HabitDetailScreen({super.key, required this.id});

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  Habit? _habit;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final habit =
          await context.read<HabitRepository>().findById(widget.id);
      if (!mounted) return;
      setState(() {
        _habit = habit;
        _loading = false;
        if (habit == null) _error = 'Привычка не найдена';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить привычку: $e';
      });
    }
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
        title: Text(_habit?.name ?? 'Загрузка привычки…'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/habits'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null ? _errorView() : _card(context, _habit!),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 8),
          Text(_error!),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.go('/habits'),
            child: const Text('К списку привычек'),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Habit habit) {
    final notifier = context.read<HabitListNotifier>();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row('Название', habit.name),
              _row('Цель', habit.goal),
              _row('Категория', categoryName(habit.categoryId)),
              _row('Периодичность', periodicityName(habit.periodicityId)),
              _row('Минут в день', '${habit.minutesPerDay}'),
              _row('Серия подряд', '${habit.streak} дн.'),
              _row('Статус',
                  habit.isDeleted ? 'Удалёна (в корзине)' : 'Активна'),
              const SizedBox(height: 20),
              if (!habit.isDeleted)
                FilledButton.icon(
                  onPressed: () async {
                    if (!await _confirm('Удалить привычку?',
                        'Привычка уйдёт в корзину, её можно будет вернуть.')) {
                      return;
                    }
                    await notifier.softDeleteOne(habit.id);
                    if (context.mounted) context.go('/habits');
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Удалить (в корзину)'),
                )
              else ...[
                FilledButton.icon(
                  onPressed: () async {
                    await notifier.restoreOne(habit.id);
                    if (context.mounted) context.go('/habits');
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('Вернуть из корзины'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    if (!await _confirm('Удалить навсегда?',
                        'Привычка будет стёрта из хранилища безвозвратно.')) {
                      return;
                    }
                    await notifier.hardDeleteOne(habit.id);
                    if (context.mounted) context.go('/habits');
                  },
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Удалить навсегда'),
                ),
              ],
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
            width: 140,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
