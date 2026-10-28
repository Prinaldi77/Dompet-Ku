import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Titik indikator panjang PIN.
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.filled,
    this.total = 6,
    this.error = false,
  });

  final int filled;
  final int total;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = error ? p.expense : p.emerald;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(total, (i) {
        final active = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? color : Colors.transparent,
            border: Border.all(
              color: active ? color : p.line,
              width: 1.8,
            ),
          ),
        );
      }),
    );
  }
}

/// Keypad angka untuk memasukkan PIN.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
    this.submitLabel = 'Buka',
    this.submitEnabled = true,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final String submitLabel;
  final bool submitEnabled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: [
        for (final row in const [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final digit in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _PinKey(
                        digit: digit,
                        onTap: () => onDigit(digit),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _PinIconKey(
                  icon: Icons.backspace_outlined,
                  onTap: onBackspace,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _PinKey(digit: 0, onTap: () => onDigit(0)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(
                  height: 62,
                  decoration: BoxDecoration(
                    color: submitEnabled ? p.emerald : p.line,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TextButton(
                    onPressed: submitEnabled ? onSubmit : null,
                    child: Text(
                      submitLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: submitEnabled ? p.onAccent : p.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({required this.digit, required this.onTap});

  final int digit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.line),
        ),
        child: Text(
          '$digit',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: p.slate,
          ),
        ),
      ),
    );
  }
}

class _PinIconKey extends StatelessWidget {
  const _PinIconKey({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.line),
        ),
        child: Icon(icon, size: 22, color: p.muted),
      ),
    );
  }
}
