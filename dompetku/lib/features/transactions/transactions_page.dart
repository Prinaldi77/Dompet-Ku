import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/ledger/ledger_types.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/category_avatar.dart';
import '../../core/widgets/month_selector.dart';
import '../../core/widgets/transaction_tile.dart';

typedef _FilterResult = ({String? type, String? source, int? categoryId});

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  String? _type;
  String? _source;
  int? _categoryId;

  bool get _hasAdvancedFilters => _source != null || _categoryId != null;

  int get _advancedFilterCount =>
      (_source == null ? 0 : 1) + (_categoryId == null ? 0 : 1);

  Future<void> _openFilterSheet(List<TxCategory> categories) async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(
        type: _type,
        source: _source,
        categoryId: _categoryId,
        categories: categories,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _type = result.type;
      _source = result.source;
      _categoryId = result.categoryId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <TxCategory>[];
    final filter = (
      month: month,
      type: _type,
      source: _source,
      categoryId: _categoryId,
    );
    final async = ref.watch(transactionsProvider(filter));
    final p = context.palette;

    String? activeCategoryName;
    for (final category in categories) {
      if (category.id == _categoryId) {
        activeCategoryName = category.name;
        break;
      }
    }

    final isFiltered = _type != null || _hasAdvancedFilters;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arus Kas'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/transactions/new'),
        backgroundColor: p.emerald,
        foregroundColor: p.onAccent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Catat'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: MonthSelector(
              month: month,
              onChanged: (value) =>
                  ref.read(selectedMonthProvider.notifier).state = value,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Semua',
                  selected: _type == null,
                  onTap: () => setState(() => _type = null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Masuk',
                  selected: _type == TxType.income,
                  onTap: () => setState(() => _type = TxType.income),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Keluar',
                  selected: _type == TxType.expense,
                  onTap: () => setState(() => _type = TxType.expense),
                ),
                const Spacer(),
                _FilterButton(
                  activeCount: _advancedFilterCount,
                  onTap: () => _openFilterSheet(categories),
                ),
              ],
            ),
          ),
          if (_hasAdvancedFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (_source != null)
                          _ActiveFilterChip(
                            label: _sourceLabel(_source!),
                            onDeleted: () => setState(() => _source = null),
                          ),
                        if (activeCategoryName != null)
                          _ActiveFilterChip(
                            label: activeCategoryName,
                            onDeleted: () =>
                                setState(() => _categoryId = null),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _source = null;
                      _categoryId = null;
                    }),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 14),
          Expanded(
            child: async.when(
              data: (items) {
                if (items.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    children: [
                      EmptyTransactions(
                        message: isFiltered
                            ? 'Tidak ada transaksi yang cocok dengan filter ini.'
                            : null,
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = items[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: p.line),
                      ),
                      child: TransactionTile(
                        entry: entry,
                        onTap: () => openTransactionEntry(context, entry),
                      ),
                    );
                  },
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(color: p.emerald),
              ),
              error: (error, _) => Center(
                child: Text('Gagal memuat transaksi: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _sourceLabel(String source) {
  return switch (source) {
    TxSource.manual => 'Manual',
    TxSource.saving => 'Tabungan',
    TxSource.debt => 'Utang',
    _ => source,
  };
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.activeCount, required this.onTap});

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final active = activeCount > 0;
    return InkWell(
      key: const ValueKey('filter-button'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? p.emeraldSoft : p.card,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: active ? p.emerald : p.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 15,
              color: active ? p.emerald : p.muted,
            ),
            const SizedBox(width: 6),
            Text(
              active ? 'Filter ($activeCount)' : 'Filter',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? p.emerald : p.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 3),
      decoration: BoxDecoration(
        color: p.emeraldSoft,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: p.emerald,
            ),
          ),
          InkWell(
            onTap: onDeleted,
            borderRadius: BorderRadius.circular(100),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 13, color: p.emerald),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.type,
    required this.source,
    required this.categoryId,
    required this.categories,
  });

  final String? type;
  final String? source;
  final int? categoryId;
  final List<TxCategory> categories;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _type;
  String? _source;
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    _type = widget.type;
    _source = widget.source;
    _categoryId = widget.categoryId;
  }

  void _clear() {
    setState(() {
      _type = null;
      _source = null;
      _categoryId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final categoryValue =
        widget.categories.any((c) => c.id == _categoryId) ? _categoryId : null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filter Transaksi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('filter-reset'),
                    onPressed: _clear,
                    child: const Text('Hapus semua'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const _SectionLabel('Tipe'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    key: const ValueKey('filter-type-all'),
                    label: 'Semua',
                    selected: _type == null,
                    onTap: () => setState(() => _type = null),
                  ),
                  _FilterChip(
                    key: const ValueKey('filter-type-income'),
                    label: 'Masuk',
                    selected: _type == TxType.income,
                    onTap: () => setState(() => _type = TxType.income),
                  ),
                  _FilterChip(
                    key: const ValueKey('filter-type-expense'),
                    label: 'Keluar',
                    selected: _type == TxType.expense,
                    onTap: () => setState(() => _type = TxType.expense),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _SectionLabel('Sumber'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    key: const ValueKey('filter-source-all'),
                    label: 'Semua',
                    selected: _source == null,
                    onTap: () => setState(() => _source = null),
                  ),
                  _FilterChip(
                    key: const ValueKey('filter-source-manual'),
                    label: 'Manual',
                    selected: _source == TxSource.manual,
                    onTap: () => setState(() => _source = TxSource.manual),
                  ),
                  _FilterChip(
                    key: const ValueKey('filter-source-saving'),
                    label: 'Tabungan',
                    selected: _source == TxSource.saving,
                    onTap: () => setState(() => _source = TxSource.saving),
                  ),
                  _FilterChip(
                    key: const ValueKey('filter-source-debt'),
                    label: 'Utang',
                    selected: _source == TxSource.debt,
                    onTap: () => setState(() => _source = TxSource.debt),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _SectionLabel('Kategori'),
              const SizedBox(height: 8),
              InputDecorator(
                decoration: const InputDecoration(),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    key: const ValueKey('filter-category'),
                    isExpanded: true,
                    value: categoryValue,
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'Semua kategori',
                          style: TextStyle(fontSize: 14, color: p.muted),
                        ),
                      ),
                      ...widget.categories.map(
                        (category) => DropdownMenuItem<int?>(
                          value: category.id,
                          child: Row(
                            children: [
                              Icon(
                                iconForCategory(category.icon),
                                size: 18,
                                color: p.emerald,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  category.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _categoryId = value),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey('filter-apply'),
                onPressed: () => Navigator.of(context).pop((
                  type: _type,
                  source: _source,
                  categoryId: _categoryId,
                )),
                child: const Text('Terapkan Filter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: context.palette.muted,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? p.emerald : p.card,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? p.emerald : p.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? p.onAccent : p.muted,
          ),
        ),
      ),
    );
  }
}
