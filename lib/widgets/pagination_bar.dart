import 'package:flutter/material.dart';

// Панель пагинации: первая / предыдущая / следующая / последняя,
// номер текущей страницы, общее число записей, размер страницы.
class PaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final int total;
  final int size;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onSize;

  const PaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.size,
    required this.onPage,
    required this.onSize,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        IconButton(
          tooltip: 'Первая страница',
          icon: const Icon(Icons.first_page),
          onPressed: page > 1 ? () => onPage(1) : null,
        ),
        IconButton(
          tooltip: 'Предыдущая страница',
          icon: const Icon(Icons.chevron_left),
          onPressed: page > 1 ? () => onPage(page - 1) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('Стр. $page из $totalPages • Всего: $total'),
        ),
        IconButton(
          tooltip: 'Следующая страница',
          icon: const Icon(Icons.chevron_right),
          onPressed: page < totalPages ? () => onPage(page + 1) : null,
        ),
        IconButton(
          tooltip: 'Последняя страница',
          icon: const Icon(Icons.last_page),
          onPressed: page < totalPages ? () => onPage(totalPages) : null,
        ),
        const SizedBox(width: 12),
        const Text('По:'),
        DropdownButton<int>(
          value: size,
          items: const [10, 25, 50]
              .map((s) => DropdownMenuItem(value: s, child: Text('$s')))
              .toList(),
          onChanged: (s) {
            if (s != null) onSize(s);
          },
        ),
      ],
    );
  }
}
