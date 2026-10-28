import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/ledger/ledger_service.dart';
import '../../core/ledger/ledger_types.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/category_avatar.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Kategori')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        backgroundColor: p.emerald,
        foregroundColor: p.onAccent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Kategori'),
      ),
      body: categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final category = categories[index];
                return Container(
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: p.line),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        CategoryAvatar(
                          icon: category.icon,
                          tipe: category.tipe,
                          size: 38,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.name,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _typeLabel(category.tipe) +
                                    (category.isSystem ? ' · Sistem' : ''),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: p.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: category.isActive,
                          activeTrackColor: p.emerald,
                          onChanged: (value) => _setActive(
                            context,
                            ref,
                            category,
                            value,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _typeLabel(String tipe) => switch (tipe) {
        TxType.income => 'Pemasukan',
        TxType.expense => 'Pengeluaran',
        _ => 'Keduanya',
      };

  Future<void> _setActive(
    BuildContext context,
    WidgetRef ref,
    TxCategory category,
    bool value,
  ) async {
    try {
      await ref
          .read(categoryServiceProvider)
          .setActive(category.id, value);
    } on LedgerException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _CategoryDialog(),
    );
  }
}

class _CategoryDialog extends ConsumerStatefulWidget {
  const _CategoryDialog();

  @override
  ConsumerState<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<_CategoryDialog> {
  final _controller = TextEditingController();
  String _tipe = TxType.expense;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(categoryServiceProvider)
          .add(name: _controller.text, tipe: _tipe);
      if (mounted) Navigator.of(context).pop();
    } on LedgerException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AlertDialog(
      title: const Text(
        'Kategori Baru',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama kategori'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: TxType.income, label: Text('Pemasukan')),
              ButtonSegment(value: TxType.expense, label: Text('Pengeluaran')),
            ],
            selected: {_tipe},
            onSelectionChanged: (selection) =>
                setState(() => _tipe = selection.first),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 12, color: p.expense),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _busy ? null : _submit,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
