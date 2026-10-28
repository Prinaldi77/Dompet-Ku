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

class SavingsDetailPage extends ConsumerWidget {
  const SavingsDetailPage({super.key, required this.goalId});

  final int goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final goal = ref.watch(savingsGoalProvider(goalId)).valueOrNull;
    final logs =
        ref.watch(savingLogsProvider(goalId)).valueOrNull ?? const <SavingLog>[];

    if (goal == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Target tidak ditemukan.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.goalName, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenu(context, ref, goal, value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'archive', child: Text('Arsipkan target')),
              PopupMenuItem(
                value: 'delete',
                child: Text('Hapus & kembalikan dana'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          _GoalSummaryCard(goal: goal),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _deposit(context, ref, goal),
                  child: const Text('Setor'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _withdraw(context, ref, goal),
                  child: const Text('Tarik'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          const Text(
            'Riwayat Setor & Tarik',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (logs.isEmpty)
            const EmptyTransactions(
              message: 'Belum ada riwayat. Mulai dengan tombol Setor.',
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
                  for (var i = 0; i < logs.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    _LogTile(
                      log: logs[i],
                      onDelete: () => _deleteLog(context, ref, logs[i]),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _deposit(
    BuildContext context,
    WidgetRef ref,
    SavingsGoal goal,
  ) async {
    final ledger = ref.read(ledgerServiceProvider);
    final balance = ref.read(mainBalanceProvider).valueOrNull ?? 0;

    await showDialog<bool>(
      context: context,
      builder: (_) => AmountDialog(
        title: 'Setor ke ${goal.goalName}',
        description:
            'Tersedia di Saldo Utama: ${formatRupiah(balance)}. '
            'Nominal ini otomatis memotong Saldo Utama Anda.',
        confirmLabel: 'Setor',
        onSubmit: (amount) async {
          try {
            await ledger.depositToSavings(
              goalId: goal.id,
              amount: amount,
              date: DateTime.now(),
            );
          } on InsufficientBalanceException catch (error) {
            if (!context.mounted) rethrow;
            final proceed = await showConfirmDialog(
              context,
              title: 'Saldo tidak mencukupi',
              message:
                  'Saldo utama Anda ${formatRupiah(error.available)}. '
                  'Melanjutkan akan membuat saldo minus. Tetap setor '
                  '${formatRupiah(amount)}?',
              confirmLabel: 'Tetap Setor',
            );
            if (!proceed) rethrow;
            await ledger.depositToSavings(
              goalId: goal.id,
              amount: amount,
              date: DateTime.now(),
              force: true,
            );
          }
        },
      ),
    );
  }

  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref,
    SavingsGoal goal,
  ) async {
    final ledger = ref.read(ledgerServiceProvider);

    await showDialog<bool>(
      context: context,
      builder: (_) => AmountDialog(
        title: 'Tarik dari ${goal.goalName}',
        description:
            'Tersedia di tabungan: ${formatRupiah(goal.currentAmount)}. '
            'Dana akan kembali ke Saldo Utama tanpa mengubah kekayaan bersih.',
        confirmLabel: 'Tarik',
        onSubmit: (amount) => ledger.withdrawFromSavings(
          goalId: goal.id,
          amount: amount,
          date: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _deleteLog(
    BuildContext context,
    WidgetRef ref,
    SavingLog log,
  ) async {
    final isDeposit = log.actionType == SavingAction.deposit;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus riwayat?',
      message: isDeposit
          ? 'Setoran ${formatRupiah(log.amount)} akan dihapus dan dana '
              'dikembalikan ke Saldo Utama.'
          : 'Penarikan ${formatRupiah(log.amount)} akan dihapus dan dana '
              'dikembalikan ke tabungan.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await ref.read(ledgerServiceProvider).deleteSavingLog(log.id);
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
    SavingsGoal goal,
    String action,
  ) async {
    final ledger = ref.read(ledgerServiceProvider);

    if (action == 'archive') {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Arsipkan target?',
        message:
            'Target tidak tampil di daftar, tetapi dana tetap tercatat di tabungan.',
        confirmLabel: 'Arsipkan',
      );
      if (!confirmed) return;
      await ledger.deleteSavingsGoal(goal.id, withHistory: false);
      if (context.mounted) Navigator.of(context).pop();
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus target?',
      message:
          'Seluruh riwayat setor/tarik akan dihapus dan dana dikembalikan '
          'ke Saldo Utama.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!confirmed) return;
    await ledger.deleteSavingsGoal(goal.id);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _GoalSummaryCard extends StatelessWidget {
  const _GoalSummaryCard({required this.goal});

  final SavingsGoal goal;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ratio = goal.targetAmount == 0
        ? 0.0
        : (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
    final percent = goal.targetAmount == 0
        ? 0
        : (goal.currentAmount / goal.targetAmount * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Terkumpul',
                style: TextStyle(fontSize: 12, color: p.muted),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: p.emerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatRupiah(goal.currentAmount),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'dari target ${formatRupiah(goal.targetAmount)}',
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: p.emeraldSoft,
              valueColor: AlwaysStoppedAnimation<Color>(p.emerald),
            ),
          ),
          if (goal.targetDate != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.event_rounded,
                  size: 14,
                  color: p.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  'Tenggat ${formatDate(DateTime.fromMillisecondsSinceEpoch(goal.targetDate!))}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: p.muted,
                  ),
                ),
                if (goal.isCompleted) ...[
                  const Spacer(),
                  Text(
                    'Tercapai',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: p.income,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log, required this.onDelete});

  final SavingLog log;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDeposit = log.actionType == SavingAction.deposit;
    final date = DateTime.fromMillisecondsSinceEpoch(log.createdAt);
    final color = isDeposit ? p.income : p.expense;
    final background = isDeposit ? p.incomeTint : p.expenseTint;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
            child: Icon(
              isDeposit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
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
                  isDeposit ? 'Setoran' : 'Penarikan',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  formatDate(date),
                  style: TextStyle(
                    fontSize: 11,
                    color: p.muted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isDeposit ? '+' : '-'}${formatRupiah(log.amount)}',
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
            tooltip: 'Hapus riwayat',
          ),
        ],
      ),
    );
  }
}
