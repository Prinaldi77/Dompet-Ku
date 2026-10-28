import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ledger/ledger_service.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

class SavingsGoalFormPage extends ConsumerStatefulWidget {
  const SavingsGoalFormPage({super.key});

  @override
  ConsumerState<SavingsGoalFormPage> createState() =>
      _SavingsGoalFormPageState();
}

class _SavingsGoalFormPageState extends ConsumerState<SavingsGoalFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  DateTime? _targetDate;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 20)),
      helpText: 'Pilih Tenggat Target',
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(ledgerServiceProvider).createSavingsGoal(
            name: _nameController.text,
            targetAmount: parseAmount(_targetController.text),
            targetDate: _targetDate,
          );
      if (mounted) Navigator.of(context).pop();
    } on LedgerException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Target Baru')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nama target',
                hintText: 'Contoh: Dana Darurat',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama target wajib diisi.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsInputFormatter()],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              decoration: const InputDecoration(
                labelText: 'Nominal target',
                prefixText: 'Rp ',
              ),
              validator: (value) {
                if (parseAmount(value ?? '') <= 0) {
                  return 'Masukkan nominal target yang valid.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _TargetDateField(
              date: _targetDate,
              onTap: _pickDate,
              onClear: () => setState(() => _targetDate = null),
            ),
            const SizedBox(height: 12),
            Text(
              'Tenggat waktu bersifat opsional. Setoran ke target ini akan '
              'otomatis memotong Saldo Utama.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: p.muted,
              ),
            ),
            const SizedBox(height: 26),
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
                  : const Text('Simpan Target'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetDateField extends StatelessWidget {
  const _TargetDateField({
    required this.date,
    required this.onTap,
    required this.onClear,
  });

  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Tenggat (opsional)'),
        child: Row(
          children: [
            Icon(Icons.event_rounded, size: 18, color: p.emerald),
            const SizedBox(width: 8),
            Text(
              date == null ? 'Tidak ada tenggat' : formatDate(date!),
              style: TextStyle(
                fontSize: 14,
                color: date == null ? p.muted : p.slate,
              ),
            ),
            const Spacer(),
            if (date != null)
              InkWell(
                onTap: onClear,
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: p.muted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
