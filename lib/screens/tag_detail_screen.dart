import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/seed.dart';
import '../models/tag.dart';
import '../repositories/habit_repository.dart';
import '../repositories/tag_repository.dart';
import '../state/tag_list_notifier.dart';

/// Карточка тега. Показывает, сколько привычек ссылается на тег.
class TagDetailScreen extends StatefulWidget {
  final int id;

  const TagDetailScreen({super.key, required this.id});

  @override
  State<TagDetailScreen> createState() => _TagDetailScreenState();
}

class _TagDetailScreenState extends State<TagDetailScreen> {
  Tag? _tag;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tag = await context.read<TagRepository>().findById(widget.id);
    if (!mounted) return;
    setState(() {
      _tag = tag;
      _loading = false;
      if (tag == null) _error = 'Тег не найден';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tag?.name ?? 'Загрузка тега…'),
        actions: [
          if (_tag != null)
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/tags/${_tag!.id}/edit'),
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
                        onPressed: () => context.go('/tags'),
                        child: const Text('К списку тегов'),
                      ),
                    ],
                  ),
                )
              : _card(context, _tag!),
    );
  }

  Widget _card(BuildContext context, Tag tag) {
    final notifier = context.read<TagListNotifier>();
    final linked = context.read<HabitRepository>().countByTag(tag.id);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row('Название', tag.name),
              _row('Цвет', tag.color),
              _row('Категория',
                  tag.categoryId == null ? 'общий' : categoryName(tag.categoryId!)),
              _row('Привычек с тегом', '$linked шт.'),
              _row('Статус', tag.isDeleted ? 'Удалён (в корзине)' : 'Активен'),
              const SizedBox(height: 20),
              if (!tag.isDeleted)
                FilledButton.icon(
                  onPressed: linked > 0
                      ? () => showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Удаление невозможно'),
                              content: Text('На тег «${tag.name}» '
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
                          await notifier.softDeleteOne(tag.id);
                          if (context.mounted) context.go('/tags');
                        },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Удалить (в корзину)'),
                )
              else
                FilledButton.icon(
                  onPressed: () async {
                    await notifier.restoreOne(tag.id);
                    if (context.mounted) context.go('/tags');
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

