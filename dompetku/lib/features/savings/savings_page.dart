import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/category_avatar.dart';

class SavingsPage extends ConsumerWidget {
  const SavingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals =
        ref.watch(savingsGoalsProvider).valueOrNull ?? const <SavingsGoal>[];
    final total = ref.watch(totalSavingsProvider).valueOrNull ?? 0;
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tabungan'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/savings/new'),
        backgroundColor: p.emerald,
        foregroundColor: p.onAccent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Target'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        children: [
          _TotalSavingsCard(total: total, goalCount: goals.length),
          const SizedBox(height: 16),
          if (goals.isEmpty)
            _EmptyGoals(
              onAdd: () => context.push('/savings/new'),
            )
          else
            for (final goal in goals)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GoalCard(
                  goal: goal,
                  onTap: () => context.push('/savings/${goal.id}'),
                ),
              ),
        ],
      ),
    );
  }
}

class _TotalSavingsCard extends StatelessWidget {
  const _TotalSavingsCard({required this.total, required this.goalCount});

  final int total;
  final int goalCount;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.emerald,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.onAccent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.savings_rounded,
                  size: 18,
                  color: p.onAccent,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Total Aset di Tabungan',
                style: TextStyle(
                  color: p.onAccent.withValues(alpha: 0.8),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatRupiah(total),
              style: TextStyle(
                color: p.onAccent,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$goalCount target aktif · dana tersimpan terpisah dari Saldo Utama',
            style: TextStyle(
              color: p.onAccent.withValues(alpha: 0.8),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap});

  final SavingsGoal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ratio = goal.targetAmount == 0
        ? 0.0
        : (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
    final percent = goal.targetAmount == 0
        ? 0
        : (goal.currentAmount / goal.targetAmount * 100).round();

    return InkWell(
      onTap: onTap,
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
                    Icons.flag_rounded,
                    size: 19,
                    color: p.emerald,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    goal.goalName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: p.emerald,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: p.emeraldSoft,
                valueColor: AlwaysStoppedAnimation<Color>(p.emerald),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatRupiah(goal.currentAmount)} dari ${formatRupiah(goal.targetAmount)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: p.muted,
                    ),
                  ),
                ),
                if (goal.isCompleted)
                  _Badge(
                    label: 'Tercapai',
                    color: p.income,
                    background: p.incomeTint,
                  )
                else if (goal.targetDate != null)
                  Text(
                    'Tenggat ${formatDate(DateTime.fromMillisecondsSinceEpoch(goal.targetDate!))}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: p.muted,
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

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line),
      ),
      child: Column(
        children: [
          const CategoryAvatar(icon: 'savings', tipe: 'BOTH', size: 56),
          const SizedBox(height: 12),
          const Text(
            'Belum ada target tabungan',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Buat target seperti dana darurat atau liburan, '
            'lalu setor dana secara bertahap.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: onAdd,
            child: const Text('Buat Target'),
          ),
        ],
      ),
    );
  }
}
