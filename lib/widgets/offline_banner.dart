import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/connection_monitor.dart';

class OfflineBanner extends StatelessWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final monitor = context.watch<ConnectionMonitor>();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (monitor.offline)
          Material(
            color: scheme.error,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off, size: 18, color: scheme.onError),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        monitor.checking
                            ? 'Нет связи с сервером. Проверяем…'
                            : 'Нет связи с сервером. Показаны последние данные.',
                        maxLines: 2,
                        style: TextStyle(color: scheme.onError, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: monitor.checking ? null : monitor.probe,
                      child: Text(
                        'Повторить',
                        style: TextStyle(color: scheme.onError),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}
