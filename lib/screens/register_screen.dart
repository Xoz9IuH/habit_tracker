import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/auth_controller.dart';
import '../core/config.dart';

class PasswordPolicy {
  PasswordPolicy._();

  static bool longEnough(String value) => value.length >= 8;

  static bool hasDigit(String value) => RegExp(r'[0-9]').hasMatch(value);

  static bool hasSpecial(String value) =>
      RegExp(r'[^A-Za-z0-9]').hasMatch(value);

  static bool hasLetter(String value) =>
      RegExp(r'[A-Za-zА-Яа-яЁё]').hasMatch(value);

  static bool isStrong(String value) =>
      longEnough(value) &&
      hasDigit(value) &&
      hasSpecial(value) &&
      hasLetter(value);

  static String? error(String value) {
    if (value.isEmpty) return 'Введите пароль';
    if (!longEnough(value)) return 'Пароль: не короче 8 символов';
    if (!hasLetter(value)) return 'Пароль: нужна хотя бы одна буква';
    if (!hasDigit(value)) return 'Пароль: нужна хотя бы одна цифра';
    if (!hasSpecial(value)) {
      return 'Пароль: нужен специальный символ (! @ # \$ %)';
    }
    return null;
  }

  static List<PasswordRule> rules(String value) => [
    PasswordRule('Не короче 8 символов', longEnough(value)),
    PasswordRule('Есть буква', hasLetter(value)),
    PasswordRule('Есть цифра', hasDigit(value)),
    PasswordRule('Есть специальный символ', hasSpecial(value)),
  ];
}

class PasswordRule {
  final String label;
  final bool done;

  const PasswordRule(this.label, this.done);
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _fullName = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();

  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _fullName.dispose();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthController>().register(
        username: _username.text,
        password: _password.text,
        fullName: _fullName.text,
      );
      if (!mounted) return;
      context.go('/habits');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = switch (error) {
          ValidationException() => error.message,
          ApiException() => error.message,
          _ => 'Не удалось зарегистрироваться',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rules = PasswordPolicy.rules(_password.text);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Регистрация', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(
                        'Новый пользователь получает роль «читатель». '
                        'API: $apiBaseUrl',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _username,
                        decoration: const InputDecoration(
                          labelText: 'Логин',
                          helperText: '3–20 символов: латиница, цифры, . _ -',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final v = (value ?? '').trim();
                          if (v.isEmpty) return 'Введите логин';
                          if (!RegExp(r'^[a-zA-Z0-9._-]{3,20}$').hasMatch(v)) {
                            return 'Логин: 3–20 символов, латиница, цифры, . _ -';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _fullName,
                        decoration: const InputDecoration(
                          labelText: 'Имя и фамилия',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) => (value ?? '').trim().length < 3
                            ? 'Укажите имя (не короче 3 символов)'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: !_showPassword,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _showPassword
                                ? 'Скрыть пароль'
                                : 'Показать пароль',
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        validator: (value) => PasswordPolicy.error(value ?? ''),
                      ),
                      const SizedBox(height: 8),
                      for (final rule in rules)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(
                                rule.done
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 16,
                                color: rule.done
                                    ? Colors.green.shade700
                                    : theme.colorScheme.outline,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                rule.label,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: rule.done
                                      ? Colors.green.shade800
                                      : theme.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _repeat,
                        obscureText: !_showPassword,
                        decoration: const InputDecoration(
                          labelText: 'Повторите пароль',
                          border: OutlineInputBorder(),
                        ),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) => value != _password.text
                            ? 'Пароли не совпадают'
                            : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Зарегистрироваться'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading ? null : () => context.go('/login'),
                        child: const Text('У меня уже есть аккаунт'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
