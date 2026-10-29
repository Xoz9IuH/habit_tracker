import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/auth_controller.dart';
import '../core/config.dart';
import '../core/supabase_config.dart';
import '../core/layout.dart';

class LoginScreen extends StatefulWidget {
  final String? from;
  final String? reason;

  const LoginScreen({super.key, this.from, this.reason});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _login = TextEditingController(
    text: SupabaseConfig.isConfigured ? 'admin@habit.local' : 'admin',
  );
  final _password = TextEditingController(text: 'admin123');

  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.reason == 'expired') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сессия завершена. Войдите снова.')),
        );
      });
    }
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  String get _target {
    final from = widget.from;
    if (from == null || from.isEmpty) return '/habits';
    if (from.startsWith('/login') || from.startsWith('/register')) {
      return '/habits';
    }
    return from;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await context.read<AuthController>().login(_login.text, _password.text);
      if (!mounted) return;
      context.go(_target);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = switch (e) {
          UnauthorizedException() => 'Неверный логин или пароль',
          ApiException() => errorText(e),
          _ => 'Не удалось войти. Попробуйте ещё раз.',
        };
      });
    }
  }

  void _useAccount(String login, String password) {
    setState(() {
      _login.text = login;
      _password.text = password;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = _target;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Layout.formMaxWidth),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Трекер привычек',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        SupabaseConfig.isConfigured
                            ? 'Вход через Supabase'
                            : 'Вход в учебное API',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      if (target != '/habits') ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'После входа откроется $target',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                      if (widget.reason == 'expired') ...[
                        const SizedBox(height: 12),
                        Text(
                          'Время сессии истекло — войдите снова.',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _login,
                        decoration: InputDecoration(
                          labelText: SupabaseConfig.isConfigured
                              ? 'Почта'
                              : 'Логин',
                          border: const OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Введите логин' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
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
                        obscureText: !_showPassword,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) =>
                            (v ?? '').isEmpty ? 'Введите пароль' : null,
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
                            : const Text('Войти'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => context.go('/register'),
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Зарегистрироваться'),
                      ),
                      const SizedBox(height: 16),
                      Text('Быстрый вход:', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => _useAccount('admin', 'admin123'),
                            child: const Text('администратор'),
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                _useAccount('librarian', 'librarian123'),
                            child: const Text('редактор'),
                          ),
                          OutlinedButton(
                            onPressed: () => _useAccount('reader', 'reader123'),
                            child: const Text('читатель'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        SupabaseConfig.isConfigured
                            ? 'Данные: Supabase'
                            : 'API: $resolvedApiBase',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
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
