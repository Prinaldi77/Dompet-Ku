import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ledger/ledger_service.dart';
import '../../core/ledger/ledger_types.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/dialogs.dart';

class DebtFormPage extends ConsumerStatefulWidget {
  const DebtFormPage({super.key, this.initialType});

  final String? initialType;

  @override
  ConsumerState<DebtFormPage> createState() => _DebtFormPageState();
}

class _DebtFormPageState extends ConsumerState<DebtFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  late String _type = widget.initialType == DebtType.receivable
      ? DebtType.receivable
      : DebtType.payable;
  bool _receivedInWallet = true;
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 30)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 20)),
      helpText: 'Pilih Jatuh Tempo',
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ledger = ref.read(ledgerServiceProvider);

    setState(() => _saving = true);
    try {
      await ledger.createDebt(
        personName: _nameController.text,
        type: _type,
        totalAmount: parseAmount(_amountController.text),
        dueDate: _dueDate,
        description: _descriptionController.text,
        receivedInWallet: _receivedInWallet,
      );
      if (mounted) Navigator.of(context).pop();
    } on InsufficientBalanceException catch (error) {
      if (!mounted) return;
      final proceed = await showConfirmDialog(
        context,
        title: 'Saldo tidak mencukupi',
        message:
            'Saldo utama Anda ${formatRupiah(error.available)}. '
            'Piutang ini akan membuat saldo minus. Lanjutkan?',
        confirmLabel: 'Tetap Simpan',
      );
      if (proceed) {
        try {
          await ledger.createDebt(
            personName: _nameController.text,
            type: _type,
            totalAmount: parseAmount(_amountController.text),
            dueDate: _dueDate,
            description: _descriptionController.text,
            receivedInWallet: _receivedInWallet,
            force: true,
          );
          if (mounted) Navigator.of(context).pop();
        } on LedgerException catch (error) {
          _showMessage(error.message);
        }
      }
    } on LedgerException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isPayable = _type == DebtType.payable;

    return Scaffold(
      appBar: AppBar(
        title: Text(isPayable ? 'Catat Hutang' : 'Catat Piutang'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: DebtType.payable,
                  label: Text('Hutang Saya'),
                  icon: Icon(Icons.call_made_rounded, size: 16),
                ),
                ButtonSegment(
                  value: DebtType.receivable,
                  label: Text('Piutang Saya'),
                  icon: Icon(Icons.call_received_rounded, size: 16),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
            ),
            const SizedBox(height: 16),
            _InfoBox(text: _effectDescription),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama orang',
                hintText: 'Contoh: Budi',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama orang wajib diisi.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsInputFormatter()],
              style: const TextStyle(
                fontSize: 24,
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
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration:
                    const InputDecoration(labelText: 'Jatuh tempo (opsional)'),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_rounded,
                      size: 18,
                      color: p.emerald,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _dueDate == null
                          ? 'Tidak ada tenggat'
                          : formatDate(_dueDate!),
                      style: TextStyle(
                        fontSize: 14,
                        color: _dueDate == null ? p.muted : p.slate,
                      ),
                    ),
                    const Spacer(),
                    if (_dueDate != null)
                      InkWell(
                        onTap: () => setState(() => _dueDate = null),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: p.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                alignLabelWithHint: true,
              ),
            ),
            if (isPayable) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _receivedInWallet,
                activeTrackColor: p.emerald,
                title: const Text(
                  'Uang pinjaman diterima di dompet',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Jika aktif, Saldo Utama bertambah sebesar nominal pinjaman.',
                  style: TextStyle(fontSize: 11.5, color: p.muted),
                ),
                onChanged: (value) =>
                    setState(() => _receivedInWallet = value),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: p.onAccent,
                      ),
                    )
                  : Text(isPayable ? 'Simpan Hutang' : 'Simpan Piutang'),
            ),
          ],
        ),
      ),
    );
  }

  String get _effectDescription {
    if (_type == DebtType.receivable) {
      return 'Piutang baru akan otomatis memotong Saldo Utama sebesar '
          'nominal yang Anda pinjamkan.';
    }
    if (_receivedInWallet) {
      return 'Saldo Utama akan bertambah sebesar nominal pinjaman karena '
          'uangnya masuk ke dompet Anda.';
    }
    return 'Tidak ada perubahan Saldo Utama. Gunakan opsi ini untuk hutang '
        'lama yang dananya sudah terpakai sebelum dicatat.';
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.emeraldSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: p.emerald),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: p.emerald,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
