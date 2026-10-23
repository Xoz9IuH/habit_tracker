import 'package:flutter/material.dart';

import '../core/api_log.dart';

class ApiLogScreen extends StatelessWidget {
  const ApiLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: ApiLog.instance,
      builder: (context, _) {
        final entries = ApiLog.instance.entries;
        final failed = entries.where((e) => !e.isOk).length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Журнал API'),
            actions: [
              IconButton(
                tooltip: 'Очистить',
                onPressed: entries.isEmpty ? null : ApiLog.instance.clear,
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: theme.colorScheme.surfaceContainerHighest,
                child: Text(
                  'Запросов: ${entries.length} · с ошибкой: $failed',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? const Center(child: Text('Запросов пока не было'))
                    : ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return ListTile(
                            dense: true,
                            leading: _MethodBadge(method: entry.method),
                            title: Text(
                              entry.path,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${_time(entry.at)} · ${entry.durationMs} мс'
                              '${entry.error == null ? '' : ' · ${entry.error}'}',
                            ),
                            trailing: _StatusBadge(
                              status: entry.status,
                              isOk: entry.isOk,
                              isClientError: entry.isClientError,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}:'
      '${value.second.toString().padLeft(2, '0')}';
}

class _MethodBadge extends StatelessWidget {
  const _MethodBadge({required this.method});

  final String method;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: Text(
        method,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
    required this.isOk,
    required this.isClientError,
  });

  final int? status;
  final bool isOk;
  final bool isClientError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = status == null
        ? scheme.error
        : isOk
        ? Colors.green.shade700
        : isClientError
        ? Colors.orange.shade800
        : scheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status?.toString() ?? 'сбой',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
