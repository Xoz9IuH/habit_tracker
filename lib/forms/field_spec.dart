import 'package:flutter/material.dart';

/// Описание одного поля формы. Форма собирается из списка описаний,
/// поэтому один и тот же виджет обслуживает все сущности.
sealed class FieldSpec {
  final String label;
  final String? helpText;

  const FieldSpec(this.label, {this.helpText});
}

/// Вариант выпадающего списка: значение хранится отдельно от подписи.
/// Значение — Object, потому что списки бывают и с числами (id), и со
/// строками (например, цвет тега).
class DropdownOption {
  final Object? value;
  final String text;

  const DropdownOption(this.value, this.text);
}

/// Текстовое поле.
class TextFieldSpec extends FieldSpec {
  final String initialValue;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final int maxLength;
  final int maxLines;
  final String? hint;

  const TextFieldSpec(
    super.label, {
    this.initialValue = '',
    this.validator,
    this.keyboardType = TextInputType.text,
    this.maxLength = 200,
    this.maxLines = 1,
    this.hint,
    super.helpText,
  });
}

/// Числовое поле.
class NumberFieldSpec extends FieldSpec {
  final String initialValue;
  final String? Function(String?)? validator;

  const NumberFieldSpec(
    super.label, {
    this.initialValue = '',
    this.validator,
    super.helpText,
  });
}

/// Выпадающий список (связь «многие к одному»).
class DropdownFieldSpec extends FieldSpec {
  final Object? initialValue;
  final List<DropdownOption> items;
  final String? Function(Object?)? validator;

  const DropdownFieldSpec(
    super.label, {
    this.initialValue,
    required this.items,
    this.validator,
    super.helpText,
  });
}

/// Множественный выбор (связь «многие ко многим»).
class MultiSelectFieldSpec extends FieldSpec {
  final List<int> initialValue;
  final List<DropdownOption> items;
  final String? Function(List<int>)? validator;

  const MultiSelectFieldSpec(
    super.label, {
    this.initialValue = const [],
    required this.items,
    this.validator,
    super.helpText,
  });
}

/// Поле даты.
class DateFieldSpec extends FieldSpec {
  final DateTime? initialValue;
  final String? Function(DateTime?)? validator;

  const DateFieldSpec(
    super.label, {
    this.initialValue,
    this.validator,
    super.helpText,
  });
}

/// Флажок.
class SwitchFieldSpec extends FieldSpec {
  final bool initialValue;

  const SwitchFieldSpec(
    super.label, {
    this.initialValue = false,
    super.helpText,
  });
}

/// Вложенная группа полей — используется для связи «один к одному»:
/// настройки профиля редактируются прямо в его форме.
class FieldGroupSpec extends FieldSpec {
  final List<FieldSpec> children;

  const FieldGroupSpec(
    super.label, {
    required this.children,
    super.helpText,
  });
}
