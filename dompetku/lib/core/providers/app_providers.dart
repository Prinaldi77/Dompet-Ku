import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../categories/category_service.dart';
import '../database/app_database.dart';
import '../ledger/ledger_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Bulan yang sedang dilihat di Beranda dan Arus Kas.
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final ledgerServiceProvider = Provider<LedgerService>((ref) {
  return LedgerService(ref.watch(databaseProvider));
});

final categoryServiceProvider = Provider<CategoryService>((ref) {
  return CategoryService(ref.watch(databaseProvider));
});

final mainBalanceProvider = StreamProvider<int>((ref) {
  return ref.watch(databaseProvider).watchMainBalance();
});

final monthlyFlowProvider = StreamProvider<MonthlyFlow>((ref) {
  return ref
      .watch(databaseProvider)
      .watchMonthlyFlow(ref.watch(selectedMonthProvider));
});

final monthlyAllocationProvider = StreamProvider<MonthlyAllocation>((ref) {
  return ref
      .watch(databaseProvider)
      .watchMonthlyAllocation(ref.watch(selectedMonthProvider));
});

final monthlyExpenseByCategoryProvider =
    StreamProvider<List<CategorySpend>>((ref) {
  return ref
      .watch(databaseProvider)
      .watchManualExpenseByCategory(ref.watch(selectedMonthProvider));
});

final totalSavingsProvider = StreamProvider<int>((ref) {
  return ref.watch(databaseProvider).watchTotalSavings();
});

final totalReceivablesProvider = StreamProvider<int>((ref) {
  return ref.watch(databaseProvider).watchTotalReceivables();
});

final totalPayablesProvider = StreamProvider<int>((ref) {
  return ref.watch(databaseProvider).watchTotalPayables();
});

final netWorthProvider = Provider<int>((ref) {
  final balance = ref.watch(mainBalanceProvider).valueOrNull ?? 0;
  final savings = ref.watch(totalSavingsProvider).valueOrNull ?? 0;
  final receivables = ref.watch(totalReceivablesProvider).valueOrNull ?? 0;
  final payables = ref.watch(totalPayablesProvider).valueOrNull ?? 0;
  return balance + savings + receivables - payables;
});

final hasAnyTransactionProvider = StreamProvider<bool>((ref) {
  return ref.watch(databaseProvider).watchHasAnyTransaction();
});

final transactionCountProvider = StreamProvider<int>((ref) {
  return ref.watch(databaseProvider).watchTransactionCount();
});

final recentTransactionsProvider = StreamProvider<List<TxEntry>>((ref) {
  return ref.watch(databaseProvider).watchRecentTransactions(limit: 5);
});

typedef TransactionFilters = ({
  DateTime month,
  String? type,
  String? source,
  int? categoryId,
});

final transactionsProvider =
    StreamProvider.family<List<TxEntry>, TransactionFilters>((ref, filter) {
  return ref.watch(databaseProvider).watchTransactionsForMonth(
        filter.month,
        type: filter.type,
        source: filter.source,
        categoryId: filter.categoryId,
      );
});

final categoriesProvider = StreamProvider<List<TxCategory>>((ref) {
  return ref.watch(databaseProvider).watchCategories();
});

final savingsGoalsProvider = StreamProvider<List<SavingsGoal>>((ref) {
  return ref.watch(databaseProvider).watchSavingsGoals();
});

final savingsGoalProvider =
    StreamProvider.family<SavingsGoal?, int>((ref, id) {
  return ref.watch(databaseProvider).watchSavingsGoal(id);
});

final savingLogsProvider = StreamProvider.family<List<SavingLog>, int>((ref, goalId) {
  return ref.watch(databaseProvider).watchSavingLogs(goalId);
});

final debtsProvider = StreamProvider.family<List<Debt>, String>((ref, type) {
  return ref.watch(databaseProvider).watchDebts(type);
});

final debtProvider = StreamProvider.family<Debt?, int>((ref, id) {
  return ref.watch(databaseProvider).watchDebt(id);
});

final debtPaymentsProvider =
    StreamProvider.family<List<DebtPayment>, int>((ref, debtId) {
  return ref.watch(databaseProvider).watchDebtPayments(debtId);
});

final dueDebtsProvider = StreamProvider<List<Debt>>((ref) {
  return ref.watch(databaseProvider).watchUpcomingDebts();
});
