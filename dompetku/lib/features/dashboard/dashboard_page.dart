import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/backup/backup_reminder.dart';
import '../../core/backup/backup_service.dart';
import '../../core/database/app_database.dart';
import '../../core/ledger/ledger_types.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/month_selector.dart';
import '../../core/widgets/transaction_tile.dart';
import 'expense_breakdown_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAnyTransaction =
        ref.watch(hasAnyTransactionProvider).valueOrNull ?? true;
    final showBackupReminder = ref.watch(backupReminderProvider);
    final month = ref.watch(selectedMonthProvider);
    final balance = ref.watch(mainBalanceProvider).valueOrNull ?? 0;
    final flow = ref.watch(monthlyFlowProvider).valueOrNull ??
        const MonthlyFlow(income: 0, expense: 0);
    final allocation = ref.watch(monthlyAllocationProvider).valueOrNull ??
        const MonthlyAllocation(savings: 0, debtPayments: 0);
    final byCategory =
        ref.watch(monthlyExpenseByCategoryProvider).valueOrNull ??
            const <CategorySpend>[];
    final netWorth = ref.watch(netWorthProvider);
    final dueDebts = ref.watch(dueDebtsProvider).valueOrNull ?? const <Debt>[];
    final recent =
        ref.watch(recentTransactionsProvider).valueOrNull ?? const <TxEntry>[];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            const _Header(),
            const SizedBox(height: 16),
            MonthSelector(
              month: month,
              onChanged: (value) =>
                  ref.read(selectedMonthProvider.notifier).state = value,
            ),
            const SizedBox(height: 14),
            if (!hasAnyTransaction) ...[
              _InitialBalanceCard(
                onTap: () => _editInitialBalance(context, ref, 0),
              ),
              const SizedBox(height: 16),
            ],
            if (showBackupReminder) ...[
              const _BackupReminderCard(),
              const SizedBox(height: 16),
            ],
            _BalanceCard(balance: balance, netWorth: netWorth),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Pemasukan',
                    amount: flow.income,
                    icon: Icons.south_west_rounded,
                    foreground: AppPalette.of(context).income,
                    background: AppPalette.of(context).incomeTint,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStat(
                    label: 'Pengeluaran',
                    amount: flow.expense,
                    icon: Icons.north_east_rounded,
                    foreground: AppPalette.of(context).expense,
                    background: AppPalette.of(context).expenseTint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AllocationChip(
                    icon: Icons.savings_rounded,
                    label: 'Alokasi tabungan',
                    amount: allocation.savings,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AllocationChip(
                    icon: Icons.receipt_long_rounded,
                    label: 'Cicilan bulan ini',
                    amount: allocation.debtPayments,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ExpenseBreakdownCard(
              entries: byCategory,
              periodLabel: formatMonth(month),
            ),
            if (dueDebts.isNotEmpty) ...[
              const SizedBox(height: 24),
              const _SectionHeader(title: 'Jatuh Tempo ≤ 7 Hari'),
              const SizedBox(height: 10),
              for (final debt in dueDebts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DueCard(debt: debt),
                ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionHeader(title: 'Transaksi Terakhir'),
                TextButton(
                  onPressed: () => context.go('/transactions'),
                  child: const Text('Lihat Semua'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (recent.isEmpty)
              const EmptyTransactions(
                message:
                    'Belum ada transaksi. Mulai catat pemasukan atau\npengeluaran pertama Anda.',
              )
            else
              _RecentList(entries: recent),
          ],
        ),
      ),
    );
  }

  Future<void> _editInitialBalance(
    BuildContext context,
    WidgetRef ref,
    int balance,
  ) async {
    final ledger = ref.read(ledgerServiceProvider);
    await showDialog<bool>(
      context: context,
      builder: (_) => AmountDialog(
        title: 'Atur Saldo Awal',
        description:
            'Masukkan jumlah uang tunai/aktif yang Anda miliki saat ini. '
            'Angka ini menjadi titik awal Saldo Utama.',
        initialAmount: balance,
        confirmLabel: 'Simpan',
        onSubmit: (amount) => ledger.setInitialBalance(amount),
      ),
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.entries});

  final List<TxEntry> entries;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            TransactionTile(
              entry: entries[i],
              onTap: () => openTransactionEntry(context, entries[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final now = DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                Theme.of(context).brightness == Brightness.dark
                    ? 'assets/branding/lockup_horizontal_dark.png'
                    : 'assets/branding/lockup_horizontal_light.png',
                height: 26,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
              const SizedBox(height: 6),
              const Text(
                'Halo,Prinaldi',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                'Ringkasan ${formatDate(now)}',
                style: TextStyle(fontSize: 12.5, color: p.muted),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.settings_outlined),
          style: IconButton.styleFrom(
            backgroundColor: p.card,
            side: BorderSide(color: p.line),
          ),
        ),
      ],
    );
  }
}

class _InitialBalanceCard extends StatelessWidget {
  const _InitialBalanceCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.warningTint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.warning.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: p.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Atur Saldo Awal',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: p.warning,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tentukan saldo Anda agar perhitungan akurat.',
                    style: TextStyle(fontSize: 12, color: p.warning),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.warning),
          ],
        ),
      ),
    );
  }
}

class _BackupReminderCard extends ConsumerStatefulWidget {
  const _BackupReminderCard();

  @override
  ConsumerState<_BackupReminderCard> createState() =>
      _BackupReminderCardState();
}

class _BackupReminderCardState extends ConsumerState<_BackupReminderCard> {
  bool _busy = false;

  Future<void> _backup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = await ref.read(backupServiceProvider).exportBackup();
      if (!mounted) return;
      _showMessage(
        saved ? 'Backup database berhasil disimpan.' : 'Backup dibatalkan.',
      );
    } on BackupException catch (error) {
      if (!mounted) return;
      _showMessage('Gagal membuat backup: ${error.message}');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Gagal membuat backup: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: p.warningTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.warning.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_upload_outlined, color: p.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Waktunya backup data',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: p.warning,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Data Anda hanya tersimpan di perangkat ini. '
                      'Simpan salinan .sqlite agar tidak hilang.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: p.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const ValueKey('backup-reminder-action'),
              style: FilledButton.styleFrom(
                backgroundColor: p.warning,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 40),
              ),
              onPressed: _busy ? null : _backup,
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Backup Sekarang'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.netWorth});

  final int balance;
  final int netWorth;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: p.heroSurface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.onHero.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 18,
                  color: p.onHero,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Saldo Utama',
                style: TextStyle(
                  color: p.heroMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatRupiah(balance),
              style: TextStyle(
                color: p.onHero,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: p.onHero.withValues(alpha: 0.12), height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kekayaan bersih',
                style: TextStyle(color: p.heroMuted, fontSize: 12),
              ),
              Text(
                formatRupiah(netWorth),
                style: TextStyle(
                  color: p.onHero,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.amount,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String label;
  final int amount;
  final IconData icon;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: foreground),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: p.muted),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatRupiah(amount),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: foreground,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationChip extends StatelessWidget {
  const _AllocationChip({
    required this.icon,
    required this.label,
    required this.amount,
  });

  final IconData icon;
  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.emeraldSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: p.emerald),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10.5, color: p.emerald),
                ),
                Text(
                  formatRupiah(amount),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: p.emerald,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
    );
  }
}

class _DueCard extends StatelessWidget {
  const _DueCard({required this.debt});

  final Debt debt;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final remaining = debt.totalAmount - debt.paidAmount;
    final isPayable = debt.type == DebtType.payable;
    final due = debt.dueDate == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(debt.dueDate!);

    final today = DateTime.now();
    final daysLeft = due == null
        ? null
        : DateTime(due.year, due.month, due.day)
            .difference(DateTime(today.year, today.month, today.day))
            .inDays;

    final urgent = daysLeft != null && daysLeft <= 3;
    final color = urgent ? p.expense : p.warning;
    final background = urgent ? p.expenseTint : p.warningTint;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
            child: Icon(
              isPayable ? Icons.call_made_rounded : Icons.call_received_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPayable
                      ? 'Hutang ke ${debt.personName}'
                      : 'Piutang dari ${debt.personName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _dueLabel(due, daysLeft),
                  style: TextStyle(fontSize: 11.5, color: color),
                ),
              ],
            ),
          ),
          Text(
            formatRupiah(remaining),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _dueLabel(DateTime? due, int? daysLeft) {
    if (due == null || daysLeft == null) return 'Tanpa tenggat waktu';
    if (daysLeft < 0) return 'Terlambat ${daysLeft.abs()} hari · ${formatDate(due)}';
    if (daysLeft == 0) return 'Jatuh tempo hari ini';
    return 'Jatuh tempo dalam $daysLeft hari · ${formatDate(due)}';
  }
}
