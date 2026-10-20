import 'dart:async';

import 'package:flutter/material.dart';

// Поле поиска с задержкой: выборка запускается не на каждое нажатие,
// а спустя 350 мс после окончания ввода.
class DebouncedSearchField extends StatefulWidget {
  final String initialValue;
  final String hint;
  final ValueChanged<String> onChanged;

  const DebouncedSearchField({
    super.key,
    this.initialValue = '',
    this.hint = 'Поиск…',
    required this.onChanged,
  });

  @override
  State<DebouncedSearchField> createState() => _DebouncedSearchFieldState();
}

class _DebouncedSearchFieldState extends State<DebouncedSearchField> {
  late final TextEditingController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(DebouncedSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Внешний сброс (кнопка «Сбросить») подтягиваем в поле.
    if (widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onText(String value) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () {
      widget.onChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _timer?.cancel();
                  _controller.clear();
                  widget.onChanged('');
                },
              ),
      ),
      onChanged: _onText,
    );
  }
}
