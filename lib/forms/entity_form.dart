import 'package:flutter/material.dart';

import 'field_spec.dart';

/// Результат отправки формы: значения полей и сообщение об ошибке,
/// привязанное к конкретному полю (например, «почта уже занята»).
class FormResult {
  final Map<String, dynamic> values;
  final String? errorField;
  final String? errorMessage;

  const FormResult({
    required this.values,
    this.errorField,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null;
}

/// Универсальная форма: список описаний полей + общая разметка и общая
/// обработка отправки. Экраны создания и изменения используют один и тот же
/// виджет — различается только начальное заполнение.
///
/// fieldsBuilder позволяет пересобирать поля по текущим значениям: так
/// работает каскад — выбор одного поля сужает список значений другого.
class EntityForm extends StatefulWidget {
  final List<FieldSpec> Function(Map<String, dynamic> values) fieldsBuilder;
  final String submitLabel;
  final Future<FormResult> Function(Map<String, dynamic> values) onSubmit;
  final VoidCallback? onDirtyChange;

  const EntityForm({
    super.key,
    required this.fieldsBuilder,
    required this.onSubmit,
    this.submitLabel = 'Сохранить',
    this.onDirtyChange,
  });

  @override
  State<EntityForm> createState() => EntityFormState();
}

class EntityFormState extends State<EntityForm> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _values = <String, dynamic>{};
  bool _saving = false;
  String? _errorField;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    for (final spec in _flatten(widget.fieldsBuilder(const {}))) {
      _initField(spec);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Разворачивает вложенные группы в плоский список — так удобнее
  /// инициализировать значения и собирать их при отправке.
  List<FieldSpec> _flatten(List<FieldSpec> fields) {
    final result = <FieldSpec>[];
    for (final spec in fields) {
      result.add(spec);
      if (spec is FieldGroupSpec) {
        result.addAll(_flatten(spec.children));
      }
    }
    return result;
  }

  void _initField(FieldSpec spec) {
    switch (spec) {
      case TextFieldSpec(:final initialValue):
        _controllers[spec.label] = TextEditingController(text: initialValue);
        _values[spec.label] = initialValue;
      case NumberFieldSpec(:final initialValue):
        _controllers[spec.label] = TextEditingController(text: initialValue);
        _values[spec.label] = initialValue;
      case DropdownFieldSpec(:final initialValue):
        _values[spec.label] = initialValue;
      case MultiSelectFieldSpec(:final initialValue):
        _values[spec.label] = List<int>.from(initialValue);
      case DateFieldSpec(:final initialValue):
        _values[spec.label] = initialValue;
      case SwitchFieldSpec(:final initialValue):
        _values[spec.label] = initialValue;
      case FieldGroupSpec():
        break; // значения детей инициализируются рекурсивно
    }
  }

  /// Значения полей — используются для вычисления каскадных списков.
  Map<String, dynamic> get values => Map.unmodifiable(_values);

  void _changed() {
    widget.onDirtyChange?.call();
    // Пересобираем поля: каскадные списки зависят от текущих значений.
    setState(() {});
  }

  Future<void> _submit() async {
    setState(() {
      _errorField = null;
      _errorMessage = null;
    });
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _saving = true);
    final result = await widget.onSubmit(_collect());
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (result.hasError) {
        _errorField = result.errorField;
        _errorMessage = result.errorMessage;
      }
    });
  }

  Map<String, dynamic> _collect() {
    final collected = <String, dynamic>{};
    for (final spec in _flatten(widget.fieldsBuilder(_values))) {
      collected[spec.label] = _values[spec.label];
    }
    return collected;
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.fieldsBuilder(_values);
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final spec in fields) ...[
            _buildField(spec),
            const SizedBox(height: 16),
          ],
          if (_errorMessage != null && _errorField == null) ...[
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildField(FieldSpec spec) {
    switch (spec) {
      case FieldGroupSpec():
        // Вложенная группа — визуально отдельный блок внутри формы.
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  spec.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (spec.helpText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    spec.helpText!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                for (final child in spec.children) ...[
                  _buildField(child),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        );

      case TextFieldSpec():
        return TextFormField(
          controller: _controllerFor(spec.label, spec.initialValue),
          maxLength: spec.maxLength,
          maxLines: spec.maxLines,
          keyboardType: spec.keyboardType,
          decoration: InputDecoration(
            labelText: spec.label,
            hintText: spec.hint,
            border: const OutlineInputBorder(),
            errorText: _errorField == spec.label ? _errorMessage : null,
          ),
          validator: spec.validator,
          onChanged: (v) {
            _values[spec.label] = v;
            _changed();
          },
        );

      case NumberFieldSpec():
        return TextFormField(
          controller: _controllerFor(spec.label, spec.initialValue),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: spec.label,
            border: const OutlineInputBorder(),
            errorText: _errorField == spec.label ? _errorMessage : null,
          ),
          validator: spec.validator,
          onChanged: (v) {
            _values[spec.label] = v;
            _changed();
          },
        );

      case DropdownFieldSpec():
        return _dropdown(
          label: spec.label,
          initialValue: spec.initialValue,
          items: spec.items,
          validator: spec.validator,
          errorField: spec.label,
        );

      case MultiSelectFieldSpec():
        return FormField<List<int>>(
          initialValue: List<int>.from(_values[spec.label] as List<int>),
          validator: (value) => spec.validator == null
              ? null
              : spec.validator!(value ?? const <int>[]),
          builder: (field) {
            final selected = field.value ?? const <int>[];
            return InputDecorator(
              decoration: InputDecoration(
                labelText: spec.label,
                border: const OutlineInputBorder(),
                errorText: field.errorText ??
                    (_errorField == spec.label ? _errorMessage : null),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in spec.items)
                    FilterChip(
                      label: Text(item.text),
                      selected: selected.contains(item.value as int),
                      onSelected: (_) {
                        final id = item.value as int;
                        final next = [...selected];
                        if (next.contains(id)) {
                          next.remove(id);
                        } else {
                          next.add(id);
                        }
                        field.didChange(next);
                        setState(() => _values[spec.label] = next);
                        _changed();
                      },
                    ),
                ],
              ),
            );
          },
        );

      case DateFieldSpec():
        return FormField<DateTime>(
          initialValue: _values[spec.label] as DateTime?,
          validator: spec.validator,
          builder: (field) {
            return InkWell(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: field.value ?? now,
                  firstDate: DateTime(now.year - 5),
                  lastDate: DateTime(now.year + 1),
                );
                if (picked != null) {
                  field.didChange(picked);
                  setState(() => _values[spec.label] = picked);
                  _changed();
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: spec.label,
                  border: const OutlineInputBorder(),
                  errorText: field.errorText ??
                      (_errorField == spec.label ? _errorMessage : null),
                ),
                child: Text(
                  field.value == null
                      ? 'Выберите дату'
                      : '${field.value!.day}.${field.value!.month}.${field.value!.year}',
                ),
              ),
            );
          },
        );

      case SwitchFieldSpec():
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(spec.label),
          value: _values[spec.label] as bool? ?? false,
          onChanged: (v) {
            setState(() => _values[spec.label] = v);
            _changed();
          },
        );
    }
  }

  /// Выпадающий список: значение берётся из состояния формы, а не из
  /// initialValue виджета — так список корректно обновляется при каскаде.
  Widget _dropdown({
    required String label,
    required Object? initialValue,
    required List<DropdownOption> items,
    required String? Function(Object?)? validator,
    required String errorField,
  }) {
    final current = _values[errorField];
    return FormField<Object?>(
      initialValue: current ?? initialValue,
      validator: (value) => validator == null ? null : validator(value),
      builder: (field) {
        return InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            errorText: field.errorText ??
                (_errorField == errorField ? _errorMessage : null),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Object?>(
              value: field.value,
              isExpanded: true,
              hint: const Text('Выберите значение'),
              items: [
                for (final item in items)
                  DropdownMenuItem<Object?>(
                      value: item.value, child: Text(item.text)),
              ],
              onChanged: (v) {
                field.didChange(v);
                setState(() => _values[errorField] = v);
                _changed();
              },
            ),
          ),
        );
      },
    );
  }

  /// Контроллер создаётся один раз на поле: пересборка полей при каскаде
  /// не должна затирать уже введённый текст.
  TextEditingController _controllerFor(String label, String initialValue) {
    return _controllers.putIfAbsent(
      label,
      () => TextEditingController(text: initialValue),
    );
  }
}

