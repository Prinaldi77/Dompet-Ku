import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/ledger/ledger_service.dart';
import '../../core/ledger/ledger_types.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/category_avatar.dart';

class TransactionFormPage extends ConsumerStatefulWidget {
  const TransactionFormPage({
    super.key,
    this.transactionId,
    this.initialType,
  });

  final int? transactionId;
  final String? initialType;

  @override
  ConsumerState<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  String _type = TxType.expense;
  int? _categoryId;
  DateTime _date = DateTime.now();
  bool _loading = false;
  bool _saving = false;

  bool get _isEdit => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
    final initialType = widget.initialType;
    if (initialType == TxType.income || initialType == TxType.expense) {
      _type = initialType!;
    }
    if (_isEdit) _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entry = await ref
        .read(databaseProvider)
        .getTransactionById(widget.transactionId!);
    if (!mounted) return;

    if (entry == null) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _type = entry.txn.type;
      _amountController.text = formatDigits(entry.txn.amount);
      _titleController.text = entry.txn.title;
      _categoryId = entry.txn.categoryId;
      _date = DateTime.fromMillisecondsSinceEpoch(entry.txn.transactionDate);
      _noteController.text = entry.txn.note ?? '';
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      helpText: 'Pilih Tanggal',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final categories = ref.read(categoriesProvider).valueOrNull ?? const [];
    final selected = _categoryId;
    if (selected == null || !categories.any((c) => c.id == selected)) {
      _showMessage('Pilih kategori terlebih dahulu.');
      return;
    }

    setState(() => _saving = true);
    try {
      final ledger = ref.read(ledgerServiceProvider);
      final amount = parseAmount(_amountController.text);

      if (_isEdit) {
        await ledger.updateManualTransaction(
          id: widget.transactionId!,
          title: _titleController.text,
          amount: amount,
          type: _type,
          categoryId: selected,
          date: _date,
          note: _noteController.text,
        );
      } else {
        await ledger.addManualTransaction(
          title: _titleController.text,
          amount: amount,
          type: _type,
          categoryId: selected,
          date: _date,
          note: _noteController.text,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } on LedgerException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Ubah Transaksi' : 'Tambah Transaksi'),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: p.emerald),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: TxType.income,
                        label: Text('Pemasukan'),
                        icon: Icon(Icons.south_west_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: TxType.expense,
                        label: Text('Pengeluaran'),
                        icon: Icon(Icons.north_east_rounded, size: 16),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _type = selection.first;
                        _categoryId = null;
                      });
                    },
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: _amountController,
                    autofocus: !_isEdit,
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandsInputFormatter()],
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Nominal',
                      prefixText: 'Rp ',
                    ),
                    validator: (value) {
                      if (parseAmount(value ?? '') <= 0) {
                        return 'Masukkan nominal yang valid.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Judul',
                      hintText: 'Contoh: Makan siang',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Judul wajib diisi.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildCategoryField(categories),
                  const SizedBox(height: 16),
                  _DateField(date: _date, onTap: _pickDate),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 26),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: p.onAccent,
                            ),
                          )
                        : Text(_isEdit ? 'Simpan Perubahan' : 'Simpan Transaksi'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCategoryField(List<TxCategory> categories) {
    final p = context.palette;
    final filtered = categories
        .where((c) =>
            !c.isSystem &&
            c.isActive &&
            (c.tipe == _type || c.tipe == 'BOTH'))
        .toList();
    final value =
        filtered.any((c) => c.id == _categoryId) ? _categoryId : null;

    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Kategori'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: value,
          hint: Text(
            'Pilih kategori',
            style: TextStyle(fontSize: 14, color: p.muted),
          ),
          items: filtered
              .map(
                (category) => DropdownMenuItem<int>(
                  value: category.id,
                  child: Row(
                    children: [
                      Icon(
                        iconForCategory(category.icon),
                        size: 18,
                        color: p.emerald,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _categoryId = value),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Tanggal'),
        child: Row(
          children: [
            Icon(Icons.event_rounded, size: 18, color: p.emerald),
            const SizedBox(width: 8),
            Text(
              formatDate(date),
              style: const TextStyle(fontSize: 14),
            ),
            const Spacer(),
            Icon(Icons.expand_more_rounded, color: p.muted),
          ],
        ),
      ),
    );
  }
}
