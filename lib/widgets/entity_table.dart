import 'package:flutter/material.dart';

class TableColumnSpec<T> {
  final String label;
  final String? sortField;
  final bool numeric;
  final Widget Function(T item) build;

  const TableColumnSpec({
    required this.label,
    required this.build,
    this.sortField,
    this.numeric = false,
  });
}

class EntityTable<T> extends StatelessWidget {
  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final int Function(T item) idOf;
  final Set<int> selected;
  final ValueChanged<int>? onToggleSelect;
  final ValueChanged<List<int>>? onToggleSelectAll;
  final String? sortField;
  final bool sortAscending;
  final void Function(String field)? onSort;
  final List<Widget> Function(T item)? actions;

  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    required this.idOf,
    this.selected = const {},
    this.onToggleSelect,
    this.onToggleSelectAll,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final sortIndex = _sortColumnIndex();

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(

        scrollDirection: Axis.horizontal,
        child: DataTable(
          sortColumnIndex: sortIndex,
          sortAscending: sortAscending,
          columns: [

            for (final c in columns)
              DataColumn(
                label: Text(c.label),
                numeric: c.numeric,
                onSort: c.sortField == null || onSort == null
                    ? null
                    : (_, _) => onSort!(c.sortField!),
              ),
            if (actions != null) const DataColumn(label: Text('Действия')),
          ],
          rows: [
            for (final item in items)
              DataRow(
                key: ValueKey(idOf(item)),
                selected: selected.contains(idOf(item)),
                onSelectChanged: onToggleSelect == null
                    ? null
                    : (_) => onToggleSelect!(idOf(item)),
                cells: [
                  for (final c in columns) DataCell(c.build(item)),
                  if (actions != null)
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions!(item),
                    )),
                ],
              ),
          ],
        ),
      ),
    );
  }

  int? _sortColumnIndex() {
    if (sortField == null || onSort == null) return null;

    var index = 0;
    for (final c in columns) {
      if (c.sortField == sortField) return index;
      index++;
    }
    return null;
  }
}
