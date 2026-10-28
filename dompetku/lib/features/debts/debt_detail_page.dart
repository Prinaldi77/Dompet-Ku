import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/ledger/ledger_service.dart';
import '../../core/ledger/ledger_types.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/transaction_tile.dart';
import 'debt_actions.dart';

class DebtDetailPage extends ConsumerWidget {
  const DebtDetailPage({super.key, required this.debtId});

  final int debtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final debt = ref.watch(debtProvider(debtId)).valueOrNull;
    final payments =
        ref.watch(debtPaymentsProvider(debtId)).valueOrNull ??
            const <DebtPayment>[];

    if (debt == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Data hutang tidak ditemukan.')),
      );
    }

    final isPayable = debt.type == DebtType.payable;

    return Scaffold(
      appBar: AppBar(
        title: Text(debt.personName, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenu(context, ref, debt, value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'archive', child: Text('Arsipkan')),
              PopupMenuItem(
                value: 'delete',
                child: Text('Hapus & sesuaikan saldo'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          _DebtDetailCard(debt: debt),
          if (debt.initialTransactionId == null && isPayable) ...[
            const SizedBox(height: 12),
            const _Note(
              text: 'Hutang ini dicatat tanpa transaksi saldo awal. '
                  'Saldo Utama tidak bertambah saat pencatatan.',
            ),
          ],
          const SizedBox(height: 16),
          if (!debt.isSettled)
            FilledButton(
              onPressed: () => showDebtPaymentDialog(context, ref, debt),
              child: Text(
                isPayable ? 'Bayar / Cicil Hutang' : 'Terima Cicilan Piutang',
              ),
            ),
          const SizedBox(height: 26),
          const Text(
            'Riwayat Cicilan',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (payments.isEmpty)
            const EmptyTransactions(
              message: 'Belum ada cicilan. Catat pembayaran pertama Anda.',
            )
          else
            Container(
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.line),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < payments.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    _PaymentTile(
                      payment: payments[i],
                      isPayable: isPayable,
                      onDelete: () => _deletePayment(
                        context,
                        ref,
                        payments[i],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _deletePayment(
    BuildContext context,
    WidgetRef ref,
    DebtPayment payment,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus cicilan?',
      message:
          'Cicilan ${formatRupiah(payment.amountPaid)} akan dihapus dan '
          'Saldo Utama disesuaikan kembali.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await ref.read(ledgerServiceProvider).deleteDebtPayment(payment.id);
    } on LedgerException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _handleMenu(
    BuildContext context,
    WidgetRef ref,
    Debt debt,
    String action,
  ) async {
    final ledger = ref.read(ledgerServiceProvider);

    if (action == 'archive') {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Arsipkan data?',
        message:
            'Data tidak tampil di daftar, tetapi riwayat dan saldo tetap tercatat.',
        confirmLabel: 'Arsipkan',
      );
      if (!confirmed) return;
      await ledger.deleteDebt(debt.id, withHistory: false);
      if (context.mounted) Navigator.of(context).pop();
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus data?',
      message:
          'Seluruh cicilan dan transaksi saldo yang terkait akan dihapus, '
          'sehingga Saldo Utama kembali ke kondisi sebelum data ini dibuat.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!confirmed) return;
    await ledger.deleteDebt(debt.id);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _DebtDetailCard extends StatelessWidget {
  const _DebtDetailCard({required this.debt});

  final Debt debt;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final remaining = debt.totalAmount - debt.paidAmount;
    final ratio = debt.totalAmount == 0
        ? 0.0
        : (debt.paidAmount / debt.totalAmount).clamp(0.0, 1.0);
    final due = debt.dueDate == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(debt.dueDate!);
    final isPayable = debt.type == DebtType.payable;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.heroSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: p.onHero.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  isPayable ? 'Hutang Saya' : 'Piutang Saya',
                  style: TextStyle(
                    color: p.onHero,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (debt.isSettled)
                Text(
                  isPayable ? 'LUNAS' : 'TERTAGIH',
                  style: const TextStyle(
                    color: Color(0xFF6EE7B7),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isPayable ? 'Sisa hutang' : 'Sisa piutang',
            style: TextStyle(color: p.heroMuted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatRupiah(remaining),
              style: TextStyle(
                color: p.onHero,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: p.onHero.withValues(alpha: 0.14),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF6EE7B7)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Terbayar ${formatRupiah(debt.paidAmount)} dari ${formatRupiah(debt.totalAmount)}',
                style: TextStyle(color: p.heroMuted, fontSize: 11),
              ),
              const Spacer(),
              if (due != null)
                Text(
                  formatDate(due),
                  style: TextStyle(
                    color: p.heroMuted,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          if (debt.description != null) ...[
            const SizedBox(height: 12),
            Divider(color: p.onHero.withValues(alpha: 0.12), height: 1),
            const SizedBox(height: 10),
            Text(
              debt.description!,
              style: TextStyle(
                color: p.heroMuted,
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.warningTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: p.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: p.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.payment,
    required this.isPayable,
    required this.onDelete,
  });

  final DebtPayment payment;
  final bool isPayable;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final date = DateTime.fromMillisecondsSinceEpoch(payment.paymentDate);
    final color = isPayable ? p.expense : p.income;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isPayable ? p.expenseTint : p.incomeTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPayable
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 17,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPayable ? 'Pembayaran' : 'Penerimaan',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  payment.note == null
                      ? formatDate(date)
                      : '${formatDate(date)} · ${payment.note}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: p.muted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatRupiah(payment.amountPaid),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
            color: p.muted,
            tooltip: 'Hapus cicilan',
          ),
        ],
      ),
    );
  }
}
