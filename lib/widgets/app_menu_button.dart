import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_controller.dart';
import '../core/role.dart';

class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final role = auth.user?.role ?? Role.reader.code;
    final location = GoRouterState.of(context).matchedLocation;
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      tooltip: 'Разделы',
      icon: const Icon(Icons.menu),
      onSelected: (route) => context.go(route),
      itemBuilder: (context) => [
        for (final section in menuSections)
          if (Role.atLeast(role, section.minimumRole))
            PopupMenuItem<String>(
              value: section.route,
              child: Row(
                children: [
                  Icon(
                    section.icon,
                    size: 20,
                    color: location.startsWith(section.route)
                        ? scheme.primary
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    section.label,
                    style: location.startsWith(section.route)
                        ? TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          )
                        : null,
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class MenuSection {
  final IconData icon;
  final String label;
  final String route;
  final Role minimumRole;

  const MenuSection({
    required this.icon,
    required this.label,
    required this.route,
    this.minimumRole = Role.reader,
  });
}

const menuSections = <MenuSection>[
  MenuSection(icon: Icons.checklist, label: 'Привычки', route: '/habits'),
  MenuSection(
    icon: Icons.event_available,
    label: 'Отметки',
    route: '/check-ins',
  ),
  MenuSection(
    icon: Icons.category_outlined,
    label: 'Категории',
    route: '/categories',
  ),
  MenuSection(icon: Icons.sell_outlined, label: 'Теги', route: '/tags'),
  MenuSection(icon: Icons.person_outline, label: 'Профили', route: '/profiles'),
  MenuSection(icon: Icons.card_giftcard, label: 'Купоны', route: '/coupons'),
  MenuSection(
    icon: Icons.group_outlined,
    label: 'Пользователи',
    route: '/users',
  ),
  MenuSection(
    icon: Icons.insights_outlined,
    label: 'Статистика',
    route: '/system',
  ),
];
