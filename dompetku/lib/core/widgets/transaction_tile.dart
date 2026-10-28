import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/ledger/ledger_types.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import 'category_avatar.dart';

/// Membuka detail sesuai sumber transaksi:
/// manual → form edit, otomatis → bottom sheet read-only.
Future<void> openTransactionEntry(BuildContext context, TxEntry entry) async {
  if (!entry.isAutomatic) {
    await context.push('/transactions/${entry.txn.id}/edit');
    return;
  }

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final p = context.palette;
      final txn = entry.txn;
      final date = DateTime.fromMillisecondsSinceEpoch(txn.transactionDate);
      final isSaving = txn.referenceType == RefType.saving;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detail Transaksi Otomatis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _DetailRow(label: 'Judul', value: txn.title),
            _DetailRow(label: 'Kategori', value: entry.category.name),
            _DetailRow(label: 'Tanggal', value: formatDate(date)),
            _DetailRow(
              label: 'Nominal',
              value: formatSignedRupiah(
                txn.amount,
                isIncome: txn.type == TxType.income,
              ),
            ),
            if (txn.note != null)
              _DetailRow(label: 'Catatan', value: txn.note!),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.emeraldSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isSaving
                        ? Icons.savings_rounded
                        : Icons.handshake_rounded,
                    size: 18,
                    color: p.emerald,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isSaving
                          ? 'Transaksi ini dibuat otomatis dari modul Tabungan. Ubah atau hapus lewat riwayat target tabungan.'
                          : 'Transaksi ini dibuat otomatis dari modul Hutang & Piutang. Ubah atau hapus lewat riwayat cicilan.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: p.emerald,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: p.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.entry,
    this.onTap,
  });

  final TxEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final txn = entry.txn;
    final isIncome = txn.type == TxType.income;
    final date = DateTime.fromMillisecondsSinceEpoch(txn.transactionDate);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CategoryAvatar(icon: entry.category.icon, tipe: txn.type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        formatDate(date),
                        style: TextStyle(
                          color: p.muted,
                          fontSize: 11.5,
                        ),
                      ),
                      if (entry.isAutomatic) ...[
                        const SizedBox(width: 6),
                        _AutoBadge(referenceType: txn.referenceType),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatSignedRupiah(txn.amount, isIncome: isIncome),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isIncome ? p.income : p.expense,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoBadge extends StatelessWidget {
  const _AutoBadge({required this.referenceType});

  final String? referenceType;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isSaving = referenceType == RefType.saving;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: p.emeraldSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSaving ? Icons.savings_rounded : Icons.handshake_rounded,
            size: 10,
            color: p.emerald,
          ),
          const SizedBox(width: 3),
          Text(
            isSaving ? 'Tabungan' : 'Hutang',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: p.emerald,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyTransactions extends StatelessWidget {
  const EmptyTransactions({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 36, color: p.muted),
          const SizedBox(height: 10),
          Text(
            message ?? 'Belum ada transaksi pada periode ini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
