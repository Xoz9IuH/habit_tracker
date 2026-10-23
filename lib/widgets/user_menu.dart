import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_debug.dart';
import '../core/auth_controller.dart';

class UserMenu extends StatelessWidget {
  const UserMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final initials = (user?.fullName.isNotEmpty ?? false)
        ? user!.fullName.substring(0, 1).toUpperCase()
        : '?';

    return AnimatedBuilder(
      animation: ApiDebug.instance,
      builder: (context, _) {
        return PopupMenuButton<String>(
          tooltip: 'Пользователь и режим API',
          icon: CircleAvatar(
            radius: 15,
            child: Text(initials, style: const TextStyle(fontSize: 13)),
          ),
          onSelected: (value) async {
            switch (value) {
              case 'api-log':
                context.push('/api-log');
              case 'normal':
                ApiDebug.instance.normal();
              case 'slow':
                ApiDebug.instance.slow();
              case 'fail':
                ApiDebug.instance.fail();
              case 'logout':
                await auth.logout();
                if (context.mounted) context.go('/login');
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(user?.fullName ?? 'Гость'),
                subtitle: Text(user?.roleName ?? 'нет сессии'),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'api-log',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.receipt_long_outlined),
                title: Text('Журнал API'),
              ),
            ),
            PopupMenuItem<String>(
              value: 'normal',
              child: _modeTile('Обычный режим', ApiDebug.instance.isNormal),
            ),
            PopupMenuItem<String>(
              value: 'slow',
              child: _modeTile(
                'Задержка 1,5 с (?__delay)',
                ApiDebug.instance.delayMs > 0,
              ),
            ),
            PopupMenuItem<String>(
              value: 'fail',
              child: _modeTile(
                'Ошибка 500 (?__fail)',
                ApiDebug.instance.failCode != null,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'logout',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout),
                title: Text('Выйти'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _modeTile(String text, bool selected) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(selected ? Icons.check_circle : Icons.circle_outlined),
      title: Text(text),
    );
  }
}
