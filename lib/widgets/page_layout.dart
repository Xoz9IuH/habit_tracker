import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_controller.dart';

import '../core/layout.dart';
import '../core/role.dart';
import 'app_menu_button.dart';
import 'user_menu.dart';

class ListPageLayout extends StatelessWidget {
  final String title;
  final Widget filters;
  final Widget content;
  final Widget pagination;
  final List<Widget> actions;
  final Widget? selection;

  const ListPageLayout({
    super.key,
    required this.title,
    required this.filters,
    required this.content,
    required this.pagination,
    this.actions = const [],
    this.selection,
  });

  @override
  Widget build(BuildContext context) {
    final compact = Layout.isCompact(context);
    final wide = Layout.isWide(context);

    final column = Column(
      children: [
        filters,
        ?selection,
        Expanded(child: content),
        pagination,
        SizedBox(height: compact ? 4 : 8),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          ...(compact ? const <Widget>[] : actions),
          if (!wide) const AppMenuButton(),
          const UserMenu(),
        ],
      ),
      body: column,
    );
  }
}

class PageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;

  const PageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final wide = Layout.isWide(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          ...actions,
          if (!wide) const AppMenuButton(),
          const UserMenu(),
        ],
      ),
      body: wide
          ? Row(
              children: [
                const SectionNav(),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
    );
  }
}

class SectionScope extends StatelessWidget {
  final Widget child;

  const SectionScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    final location = router?.state.matchedLocation ?? '';
    final public =
        location.startsWith('/login') ||
        location.startsWith('/register') ||
        location.startsWith('/forbidden') ||
        location.startsWith('/api-log');

    if (public) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > Layout.mediumMax;
        return Row(
          children: [
            if (wide) ...[const SectionNav(), const VerticalDivider(width: 1)],
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

class SectionNav extends StatelessWidget {
  const SectionNav({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final role = auth.user?.role ?? Role.reader.code;
    final location = GoRouter.maybeOf(context)?.state.matchedLocation ?? '';
    final sections = menuSections
        .where((section) => Role.atLeast(role, section.minimumRole))
        .toList();
    final index = sections.indexWhere(
      (section) =>
          location == section.route || location.startsWith('${section.route}/'),
    );

    return SizedBox(
      width: 132,
      child: NavigationRail(
        labelType: NavigationRailLabelType.all,
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(sections[i].route),
        destinations: [
          for (final section in sections)
            NavigationRailDestination(
              icon: Icon(section.icon),
              label: Text(section.label),
            ),
        ],
      ),
    );
  }
}

class MobileNav extends StatelessWidget {
  const MobileNav({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final role = auth.user?.role ?? Role.reader.code;
    final location = GoRouter.maybeOf(context)?.state.matchedLocation ?? '';
    final sections = menuSections
        .where((section) => Role.atLeast(role, section.minimumRole))
        .take(4)
        .toList();
    if (sections.isEmpty) return const SizedBox.shrink();
    final index = sections.indexWhere(
      (section) =>
          location == section.route || location.startsWith('${section.route}/'),
    );

    return NavigationBar(
      selectedIndex: index < 0 ? 0 : index,
      onDestinationSelected: (i) => context.go(sections[i].route),
      destinations: [
        for (final section in sections)
          NavigationDestination(icon: Icon(section.icon), label: section.label),
      ],
    );
  }
}
