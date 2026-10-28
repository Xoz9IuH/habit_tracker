import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_controller.dart';
import '../core/connection_observer.dart';
import '../core/config.dart';

class SessionShell extends StatefulWidget {
  final Widget child;

  const SessionShell({super.key, required this.child});

  @override
  State<SessionShell> createState() => _SessionShellState();
}

class _SessionShellState extends State<SessionShell> {
  AuthController? _auth;
  Timer? _ticker;
  Timer? _warning;
  Timer? _expiry;
  DateTime _lastAction = DateTime.now();
  bool _signingOut = false;
  bool _sessionChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthController>();
    if (identical(auth, _auth)) return;
    _auth?.removeListener(_authChanged);
    _auth = auth..addListener(_authChanged);
    _authChanged();
  }

  @override
  void dispose() {
    _auth?.removeListener(_authChanged);
    _stop();
    super.dispose();
  }

  void _authChanged() {
    if (_auth?.isAuthenticated == true) {
      _arm();
    } else {
      _stop();
    }
  }

  void _arm() {
    _warning?.cancel();
    _expiry?.cancel();
    _warning = Timer(sessionTimeout - sessionWarning, _showWarning);
    _expiry = Timer(sessionTimeout, () => _expire('idle'));
    _ticker ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkServer(),
    );
  }

  void _stop() {
    _warning?.cancel();
    _expiry?.cancel();
    _ticker?.cancel();
    _ticker = null;
    _sessionChecked = false;
  }

  void _activity() {
    _lastAction = DateTime.now();
    final auth = _auth;
    if (auth == null || !auth.isAuthenticated) return;
    _warning?.cancel();
    _expiry?.cancel();
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    _arm();
  }

  void _showWarning() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          'Сессия завершится через ${sessionWarning.inSeconds} с. '
          'Двиньте мышью, чтобы продолжить.',
        ),
        duration: sessionWarning,
      ),
    );
  }

  Future<void> _checkServer() async {
    final auth = _auth;
    if (auth == null || !auth.isAuthenticated || _signingOut) return;
    if (DateTime.now().difference(_lastAction) < sessionCheckDelay) return;
    if (_sessionChecked) return;
    _sessionChecked = true;
    final ok = await auth.checkSession();
    if (!mounted) return;
    if (!ok) await _expire('session');
  }

  Future<void> _expire(String reason) async {
    final auth = _auth;
    if (auth == null || _signingOut) return;
    _signingOut = true;
    _stop();
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    await auth.logout();
    _signingOut = false;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return ValueListenableBuilder<ConnectionStatus>(
      valueListenable: ConnectionObserver.instance,
      builder: (context, connection, child) {
        final offline = connection == ConnectionStatus.offline;
        return Column(
          children: [
            if (offline && auth.isAuthenticated)
              Material(
                color: Theme.of(context).colorScheme.error,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_off,
                          size: 18,
                          color: Theme.of(context).colorScheme.onError,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Нет связи с сервером. Показаны последние данные.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onError,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final ok = await auth.checkSession();
                            if (!ok) {
                              ConnectionObserver.instance.markOffline();
                            }
                          },
                          child: Text(
                            'Повторить',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onError,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => _activity(),
                onPointerMove: (_) => _activity(),
                onPointerSignal: (_) => _activity(),
                child: child!,
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}
