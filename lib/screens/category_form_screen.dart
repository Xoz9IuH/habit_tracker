import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../forms/entity_form.dart';
import '../forms/field_spec.dart';
import '../models/category.dart';
import '../repositories/category_repository.dart';
import '../state/category_list_notifier.dart';
import '../validation/validators.dart';

class CategoryFormScreen extends StatefulWidget {
  final int? id;

  const CategoryFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  Category? _category;
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
    final category =
        await context.read<CategoryRepository>().findById(widget.id!);
    if (!context.mounted) return;
    setState(() {
      _category = category;
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
          context.go('/categories');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Изменение категории' : 'Новая категория'),
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
    final repo = context.read<CategoryRepository>();
    final notifier = context.read<CategoryListNotifier>();
    final c = _category;

    return EntityForm(
      key: const ValueKey('category_form'),
      onDirtyChange: () => setState(() => _dirty = true),
      submitLabel: widget.isEditing ? 'Сохранить изменения' : 'Создать',
      fieldsBuilder: (values) => [
        TextFieldSpec(
          'Название',
          initialValue: c?.name ?? '',
          maxLength: 40,
          validator: (v) {
            final err = requiredText(v, field: 'название');
            if (err != null) return err;
            return maxLength(v, 40, field: 'Название');
          },
        ),
        TextFieldSpec(
          'Описание',
          initialValue: c?.description ?? '',
          maxLength: 200,
          maxLines: 3,
          validator: (v) => requiredText(v, field: 'описание'),
        ),
      ],
      onSubmit: (values) async {
        final name = (values['Название'] as String).trim();
        final duplicate = await repo.findByName(name);
        if (duplicate != null && duplicate.id != widget.id) {
          return const FormResult(
            values: {},
            errorField: 'Название',
            errorMessage: 'Категория с таким названием уже есть',
          );
        }
        final saved = await notifier.save(Category(
          id: widget.id ?? 0,
          name: name,
          description: (values['Описание'] as String).trim(),
        ));
        if (!context.mounted) return const FormResult(values: {});
        context.go('/categories/${saved.id}');
        return const FormResult(values: {});
      },
    );
  }
}
