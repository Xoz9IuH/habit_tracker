import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../repositories/category_repository.dart';
import '../repositories/habit_repository.dart';
import '../state/category_list_notifier.dart';

/// Карточка категории. Удаление запрещено, если на категорию ссылаются
/// привычки — показывается число связанных записей.
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
    final category =
        await context.read<CategoryRepository>().findById(widget.id);
    if (!mounted) return;
    setState(() {
      _category = category;
      _loading = false;
      if (category == null) _error = 'Категория не найдена';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_category?.name ?? 'Загрузка категории…'),
        actions: [
          if (_category != null)
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/categories/${_category!.id}/edit'),
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
                        onPressed: () => context.go('/categories'),
                        child: const Text('К списку категорий'),
                      ),
                    ],
                  ),
                )
              : _card(context, _category!),
    );
  }

  Widget _card(BuildContext context, Category category) {
    final notifier = context.read<CategoryListNotifier>();
    final habitRepo = context.read<HabitRepository>();
    final linked = habitRepo.countByCategory(category.id);

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
              _row('Привычек в категории', '$linked шт.'),
              _row('Статус',
                  category.isDeleted ? 'Удалена (в корзине)' : 'Активна'),
              const SizedBox(height: 20),
              if (!category.isDeleted)
                FilledButton.icon(
                  onPressed: linked > 0
                      ? () => showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Удаление невозможно'),
                              content: Text('На категорию «${category.name}» '
                                  'ссылаются привычки: $linked шт.'),
                              actions: [
                                FilledButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Понятно'),
                                ),
                              ],
                            ),
                          )
                      : () async {
                          await notifier.softDeleteOne(category.id);
                          if (context.mounted) context.go('/categories');
                        },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Удалить (в корзину)'),
                )
              else
                FilledButton.icon(
                  onPressed: () async {
                    await notifier.restoreOne(category.id);
                    if (context.mounted) context.go('/categories');
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

