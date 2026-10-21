import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../forms/entity_form.dart';
import '../forms/field_spec.dart';
import '../models/tag.dart';
import '../repositories/category_repository.dart';
import '../repositories/tag_repository.dart';
import '../state/tag_list_notifier.dart';
import '../validation/validators.dart';

/// Форма тега — один экран для создания и изменения.
class TagFormScreen extends StatefulWidget {
  final int? id;

  const TagFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  State<TagFormScreen> createState() => _TagFormScreenState();
}

class _TagFormScreenState extends State<TagFormScreen> {
  Tag? _tag;
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
    final tag = await context.read<TagRepository>().findById(widget.id!);
    if (!context.mounted) return;
    setState(() {
      _tag = tag;
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
          context.go('/tags');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Изменение тега' : 'Новый тег'),
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
    final repo = context.read<TagRepository>();
    final categoryRepo = context.read<CategoryRepository>();
    final notifier = context.read<TagListNotifier>();
    final t = _tag;

    return EntityForm(
      key: const ValueKey('tag_form'),
      onDirtyChange: () => setState(() => _dirty = true),
      submitLabel: widget.isEditing ? 'Сохранить изменения' : 'Создать',
      fieldsBuilder: (values) {
        final categories = categoryRepo.allActive();
        return [
          TextFieldSpec(
            'Название',
            initialValue: t?.name ?? '',
            maxLength: 30,
            validator: (v) {
              final err = requiredText(v, field: 'название');
              if (err != null) return err;
              return maxLength(v, 30, field: 'Название');
            },
          ),
          DropdownFieldSpec(
            'Цвет',
            initialValue: t?.color ?? tagColors.first,
            items: [
              for (final c in tagColors) DropdownOption(c, c),
            ],
          ),
          DropdownFieldSpec(
            'Категория',
            initialValue: t?.categoryId,
            items: [
              for (final c in categories)
                DropdownOption(c.id, c.name),
            ],
            helpText: 'Необязательно: тег может быть общим',
          ),
        ];
      },
      onSubmit: (values) async {
        final name = (values['Название'] as String).trim();
        final duplicate = await repo.findByName(name);
        if (duplicate != null && duplicate.id != widget.id) {
          return const FormResult(
            values: {},
            errorField: 'Название',
            errorMessage: 'Тег с таким названием уже есть',
          );
        }
        final saved = await notifier.save(Tag(
          id: widget.id ?? 0,
          name: name,
          color: values['Цвет'] as String? ?? tagColors.first,
          categoryId: values['Категория'] as int?,
        ));        if (!context.mounted) return const FormResult(values: {});
        context.go('/tags/${saved.id}');
        return const FormResult(values: {});
      },
    );
  }
}

