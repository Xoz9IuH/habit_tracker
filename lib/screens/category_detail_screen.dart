import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../repositories/category_repository.dart';
import '../repositories/habit_repository.dart';
import '../models/habit_query.dart';
import '../state/category_list_notifier.dart';

class CategoryDetailScreen extends StatefulWidget {
  final int id;

  const CategoryDetailScreen({super.key, required this.id});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  Category? _category;
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
      final category =
          await context.read<CategoryRepository>().findById(widget.id);
      if (!mounted) return;
      setState(() {
        _category = category;
        _loading = false;
        if (category == null) _error = 'Категория не найдена';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить категорию: $e';
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

  /// Сколько активных привычек ссылаетются на эту категорию.
  Future<int> _habitCount(int categoryId) async {
    final page = await context
        .read<HabitRepository>()
        .find(HabitQuery(categoryId: categoryId, size: 1));
    return page.total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_category?.name ?? 'Загрузка категории…'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/categories'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null ? _errorView() : _card(context, _category!),
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
            onPressed: () => context.go('/categories'),
            child: const Text('К списку категорий'),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, Category category) {
    final notifier = context.read<CategoryListNotifier>();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row('Название', category.name),
              _row('Описание', category.description),
              FutureBuilder<int>(
                future: _habitCount(category.id),
                builder: (context, snapshot) => _row('Привычек в категории',
                    snapshot.hasData ? '${snapshot.data}' : '…'),
              ),
              _row('Статус',
                  category.isDeleted ? 'Удалёна (в корзине)' : 'Активна'),
              const SizedBox(height: 20),
              if (!category.isDeleted)
                FilledButton.icon(
                  onPressed: () async {
                    if (!await _confirm('Удалить категорию?',
                        'Категория уйдёт в корзину, её можно будет вернуть.')) {
                      return;
                    }
                    await notifier.softDeleteOne(category.id);
                    if (context.mounted) context.go('/categories');
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Удалить (в корзину)'),
                )
              else ...[
                FilledButton.icon(
                  onPressed: () async {
                    await notifier.restoreOne(category.id);
                    if (context.mounted) context.go('/categories');
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('Вернуть из корзины'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    if (!await _confirm('Удалить навсегда?',
                        'Категория будет стёрта из хранилища безвозвратно.')) {
                      return;
                    }
                    await notifier.hardDeleteOne(category.id);
                    if (context.mounted) context.go('/categories');
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
            width: 170,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
