import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/ledger/ledger_types.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import 'debt_actions.dart';

class DebtsPage extends StatelessWidget {
  const DebtsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Utang & Piutang'),
          actions: [
            IconButton(
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
          bottom: TabBar(
            labelColor: p.emerald,
            unselectedLabelColor: p.muted,
            indicatorColor: p.emerald,
            indicatorWeight: 3,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(text: 'Utang Saya'),
              Tab(text: 'Piutang Saya'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            final index = DefaultTabController.of(context).index;
            final type =
                index == 0 ? DebtType.payable : DebtType.receivable;
            context.push('/debts/new?type=$type');
          },
          backgroundColor: p.emerald,
          foregroundColor: p.onAccent,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Catat'),
        ),
        body: const TabBarView(
          children: [
            _DebtList(type: DebtType.payable),
            _DebtList(type: DebtType.receivable),
          ],
        ),
      ),
    );
  }
}

class _DebtList extends ConsumerWidget {
  const _DebtList({required this.type});

  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(debtsProvider(type)).valueOrNull ?? const <Debt>[];
    final remaining = debts
        .where((debt) => !debt.isSettled)
        .fold<int>(0, (sum, debt) => sum + debt.totalAmount - debt.paidAmount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        _DebtSummary(type: type, remaining: remaining, count: debts.length),
        const SizedBox(height: 14),
        if (debts.isEmpty)
          _EmptyDebts(type: type)
        else
          for (final debt in debts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DebtCard(debt: debt),
            ),
      ],
    );
  }
}

class _DebtSummary extends StatelessWidget {
  const _DebtSummary({
    required this.type,
    required this.remaining,
    required this.count,
  });

  final String type;
  final int remaining;
  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isPayable = type == DebtType.payable;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.emeraldSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPayable
                  ? Icons.call_made_rounded
                  : Icons.call_received_rounded,
              color: p.emerald,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPayable ? 'Total sisa hutang' : 'Total sisa piutang',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: p.muted,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatRupiah(remaining),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$count catatan',
            style: TextStyle(fontSize: 11, color: p.muted),
          ),
        ],
      ),
    );
  }
}

class _DebtCard extends ConsumerWidget {
  const _DebtCard({required this.debt});

  final Debt debt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final remaining = debt.totalAmount - debt.paidAmount;
    final ratio = debt.totalAmount == 0
        ? 0.0
        : (debt.paidAmount / debt.totalAmount).clamp(0.0, 1.0);
    final isPayable = debt.type == DebtType.payable;
    final due = debt.dueDate == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(debt.dueDate!);
    final overdue = due != null &&
        !debt.isSettled &&
        due.isBefore(DateTime.now());

    return InkWell(
      onTap: () => context.push('/debts/${debt.id}'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: p.emeraldSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    size: 20,
                    color: p.emerald,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.personName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        debtTypeLabel(debt.type),
                        style: TextStyle(
                          fontSize: 11,
                          color: p.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatRupiah(remaining),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'dari ${formatRupiah(debt.totalAmount)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: p.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 7,
                backgroundColor: p.emeraldSoft,
                valueColor: AlwaysStoppedAnimation<Color>(p.emerald),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (due != null) ...[
                  Icon(
                    Icons.event_rounded,
                    size: 13,
                    color: overdue ? p.expense : p.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    overdue ? 'Jatuh tempo lewat' : formatDate(due),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: overdue ? p.expense : p.muted,
                    ),
                  ),
                ],
                const Spacer(),
                if (debt.isSettled)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: p.incomeTint,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      isPayable ? 'Lunas' : 'Tertagih',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: p.income,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 34,
                    child: isPayable
                        ? FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 34),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () =>
                                showDebtPaymentDialog(context, ref, debt),
                            child: Text(debtActionLabel(debt.type)),
                          )
                        : OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 34),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () =>
                                showDebtPaymentDialog(context, ref, debt),
                            child: Text(debtActionLabel(debt.type)),
                          ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDebts extends StatelessWidget {
  const _EmptyDebts({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isPayable = type == DebtType.payable;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: p.emeraldSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPayable
                  ? Icons.call_made_rounded
                  : Icons.call_received_rounded,
              color: p.emerald,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isPayable ? 'Belum ada hutang' : 'Belum ada piutang',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isPayable
                ? 'Catat hutang Anda agar sisa kewajiban dan cicilannya terpantau.'
                : 'Catat uang yang Anda pinjamkan agar pengembaliannya terpantau.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
        ],
      ),
    );
  }
}
