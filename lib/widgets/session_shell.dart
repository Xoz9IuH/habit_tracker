import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_controller.dart';
import '../core/config.dart';

class SessionShell extends StatefulWidget {
  final GoRouter router;
  final Widget child;

  const SessionShell({super.key, required this.router, required this.child});

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
    _auth?.removeListener(_changed);
    _auth = auth..addListener(_changed);
    _changed();
  }

  @override
  void dispose() {
    _auth?.removeListener(_changed);
    _stop();
    super.dispose();
  }

  void _changed() {
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
    if (!mounted) return;
    widget.router.go('/login?reason=$reason');
    _signingOut = false;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (_) => _activity(),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _activity(),
        onPointerMove: (_) => _activity(),
        onPointerSignal: (_) => _activity(),
        child: widget.child,
      ),
    );
  }
}

void debugSessionExpired() {
  if (kDebugMode) debugPrint('Сессия завершена');
}
