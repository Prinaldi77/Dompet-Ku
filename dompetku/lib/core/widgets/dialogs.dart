import 'package:flutter/material.dart';

import '../ledger/ledger_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Lanjutkan',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final p = context.palette;
      return AlertDialog(
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: Text(
          message,
          style: TextStyle(fontSize: 13.5, height: 1.5, color: p.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: destructive ? p.expense : p.emerald,
              foregroundColor:
                  destructive ? Colors.white : p.onAccent,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

class AmountDialog extends StatefulWidget {
  const AmountDialog({
    super.key,
    required this.title,
    required this.onSubmit,
    this.description,
    this.initialAmount = 0,
    this.confirmLabel = 'Simpan',
  });

  final String title;
  final String? description;
  final int initialAmount;
  final String confirmLabel;
  final Future<void> Function(int amount) onSubmit;

  @override
  State<AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<AmountDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialAmount > 0 ? formatDigits(widget.initialAmount) : '',
  );
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = parseAmount(_controller.text);
    if (amount <= 0) {
      setState(() => _error = 'Nominal harus lebih dari nol.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.onSubmit(amount);
      if (mounted) Navigator.of(context).pop(true);
    } on LedgerException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Terjadi kesalahan tak terduga.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.description != null) ...[
            Text(
              widget.description!,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: p.muted,
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsInputFormatter()],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            decoration: const InputDecoration(
              labelText: 'Nominal',
              prefixText: 'Rp ',
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 12, color: p.expense),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: p.onAccent,
                  ),
                )
              : Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
