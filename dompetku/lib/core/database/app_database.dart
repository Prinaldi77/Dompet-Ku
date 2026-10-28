import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../ledger/ledger_types.dart';
import 'tables.dart';

part 'app_database.g.dart';

class MonthlyFlow {
  const MonthlyFlow({required this.income, required this.expense});

  final int income;
  final int expense;
}

class MonthlyAllocation {
  const MonthlyAllocation({required this.savings, required this.debtPayments});

  final int savings;
  final int debtPayments;
}

class TxEntry {
  const TxEntry({required this.txn, required this.category});

  final Txn txn;
  final TxCategory category;

  bool get isAutomatic => txn.referenceType != null;
}

class CategorySpend {
  const CategorySpend({required this.name, required this.amount});

  final String name;
  final int amount;
}

@DriftDatabase(
  tables: [
    Categories,
    Transactions,
    SavingsGoals,
    SavingLogs,
    Debts,
    DebtPayments,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'dompetku'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedCategories();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await _seedCategories();
        },
      );

  Future<void> _seedCategories() async {
    final existing = await select(categories).get();
    if (existing.isNotEmpty) return;

    await batch((batch) {
      batch.insertAll(categories, [
        CategoriesCompanion.insert(
          code: const Value(CategoryCodes.initialBalance),
          name: 'Saldo Awal',
          icon: const Value('account_balance_wallet'),
          tipe: TxType.income,
          isSystem: const Value(true),
          sortOrder: const Value(1),
        ),
        CategoriesCompanion.insert(
          code: const Value(CategoryCodes.adjustment),
          name: 'Penyesuaian',
          icon: const Value('tune'),
          tipe: 'BOTH',
          isSystem: const Value(true),
          sortOrder: const Value(2),
        ),
        CategoriesCompanion.insert(
          code: const Value(CategoryCodes.savingDeposit),
          name: 'Setor Tabungan',
          icon: const Value('savings'),
          tipe: TxType.expense,
          isSystem: const Value(true),
          sortOrder: const Value(3),
        ),
        CategoriesCompanion.insert(
          code: const Value(CategoryCodes.savingWithdraw),
          name: 'Tarik Tabungan',
          icon: const Value('savings'),
          tipe: TxType.income,
          isSystem: const Value(true),
          sortOrder: const Value(4),
        ),
        CategoriesCompanion.insert(
          code: const Value(CategoryCodes.debtDisbursement),
          name: 'Penerimaan Pinjaman',
          icon: const Value('account_balance'),
          tipe: TxType.income,
          isSystem: const Value(true),
          sortOrder: const Value(5),
        ),
        CategoriesCompanion.insert(
          code: const Value(CategoryCodes.debtPayment),
          name: 'Pembayaran Hutang',
          icon: const Value('credit_card'),
          tipe: TxType.expense,
          isSystem: const Value(true),
          sortOrder: const Value(6),
        ),
        CategoriesCompanion.insert(
          code: const Value(CategoryCodes.receivableDisbursement),
          name: 'Pemberian Pinjaman',
          icon: const Value('handshake'),
          tipe: TxType.expense,
          isSystem: const Value(true),
          sortOrder: const Value(7),
        ),
        CategoriesCompanion.insert(
          code: const Value(CategoryCodes.receivableRepayment),
          name: 'Pelunasan Piutang',
          icon: const Value('handshake'),
          tipe: TxType.income,
          isSystem: const Value(true),
          sortOrder: const Value(8),
        ),
        CategoriesCompanion.insert(
          name: 'Gaji',
          icon: const Value('payments'),
          tipe: TxType.income,
          sortOrder: const Value(10),
        ),
        CategoriesCompanion.insert(
          name: 'Pemasukan Lain',
          icon: const Value('trending_up'),
          tipe: TxType.income,
          sortOrder: const Value(20),
        ),
        CategoriesCompanion.insert(
          name: 'Makanan',
          icon: const Value('restaurant'),
          tipe: TxType.expense,
          sortOrder: const Value(10),
        ),
        CategoriesCompanion.insert(
          name: 'Transportasi',
          icon: const Value('directions_car'),
          tipe: TxType.expense,
          sortOrder: const Value(20),
        ),
        CategoriesCompanion.insert(
          name: 'Belanja',
          icon: const Value('shopping_bag'),
          tipe: TxType.expense,
          sortOrder: const Value(30),
        ),
        CategoriesCompanion.insert(
          name: 'Tagihan',
          icon: const Value('receipt_long'),
          tipe: TxType.expense,
          sortOrder: const Value(40),
        ),
        CategoriesCompanion.insert(
          name: 'Hiburan',
          icon: const Value('movie'),
          tipe: TxType.expense,
          sortOrder: const Value(50),
        ),
        CategoriesCompanion.insert(
          name: 'Pengeluaran Lain',
          icon: const Value('trending_down'),
          tipe: TxType.expense,
          sortOrder: const Value(60),
        ),
      ]);
    });
  }

  // ---------------------------------------------------------------------------
  // Ringkasan & agregasi (dilakukan di SQL, bukan iterasi di Dart)
  // ---------------------------------------------------------------------------

  Stream<int> watchMainBalance() {
    return customSelect(
      "SELECT COALESCE(SUM(CASE WHEN type = '${TxType.income}' THEN amount "
      "ELSE -amount END), 0) AS v FROM transactions",
      readsFrom: {transactions},
    ).watchSingle().map((row) => row.read<int>('v'));
  }

  Stream<MonthlyFlow> watchMonthlyFlow(DateTime month) {
    return customSelect(
      'SELECT '
      "COALESCE(SUM(CASE WHEN type = '${TxType.income}' THEN amount ELSE 0 END), 0) AS income, "
      "COALESCE(SUM(CASE WHEN type = '${TxType.expense}' THEN amount ELSE 0 END), 0) AS expense "
      'FROM transactions '
      'WHERE reference_type IS NULL AND transaction_date >= ? AND transaction_date < ?',
      variables: [
        Variable.withInt(_monthStart(month).millisecondsSinceEpoch),
        Variable.withInt(_nextMonth(month).millisecondsSinceEpoch),
      ],
      readsFrom: {transactions},
    ).watchSingle().map(
          (row) => MonthlyFlow(
            income: row.read<int>('income'),
            expense: row.read<int>('expense'),
          ),
        );
  }

  Stream<MonthlyAllocation> watchMonthlyAllocation(DateTime month) {
    return customSelect(
      'SELECT '
      "COALESCE(SUM(CASE WHEN c.code = '${CategoryCodes.savingDeposit}' THEN t.amount ELSE 0 END), 0) AS savings, "
      "COALESCE(SUM(CASE WHEN c.code IN ('${CategoryCodes.debtPayment}', '${CategoryCodes.receivableRepayment}') THEN t.amount ELSE 0 END), 0) AS debtPayments "
      'FROM transactions t JOIN categories c ON c.id = t.category_id '
      'WHERE t.transaction_date >= ? AND t.transaction_date < ?',
      variables: [
        Variable.withInt(_monthStart(month).millisecondsSinceEpoch),
        Variable.withInt(_nextMonth(month).millisecondsSinceEpoch),
      ],
      readsFrom: {transactions, categories},
    ).watchSingle().map(
          (row) => MonthlyAllocation(
            savings: row.read<int>('savings'),
            debtPayments: row.read<int>('debtPayments'),
          ),
        );
  }

  Stream<List<CategorySpend>> watchManualExpenseByCategory(DateTime month) {
    return customSelect(
      'SELECT c.name AS name, SUM(t.amount) AS total '
      'FROM transactions t JOIN categories c ON c.id = t.category_id '
      "WHERE t.type = '${TxType.expense}' AND t.reference_type IS NULL "
      'AND t.transaction_date >= ? AND t.transaction_date < ? '
      'GROUP BY c.id, c.name ORDER BY total DESC',
      variables: [
        Variable.withInt(_monthStart(month).millisecondsSinceEpoch),
        Variable.withInt(_nextMonth(month).millisecondsSinceEpoch),
      ],
      readsFrom: {transactions, categories},
    ).watch().map(
          (rows) => rows
              .map((row) => CategorySpend(
                    name: row.read<String>('name'),
                    amount: row.read<int>('total'),
                  ))
              .toList(),
        );
  }

  Stream<int> watchTotalSavings() {
    return customSelect(
      'SELECT COALESCE(SUM(current_amount), 0) AS v FROM savings_goals WHERE is_archived = 0',
      readsFrom: {savingsGoals},
    ).watchSingle().map((row) => row.read<int>('v'));
  }

  Stream<int> watchTotalReceivables() {
    return customSelect(
      "SELECT COALESCE(SUM(total_amount - paid_amount), 0) AS v FROM debts "
      "WHERE type = '${DebtType.receivable}' AND is_archived = 0",
      readsFrom: {debts},
    ).watchSingle().map((row) => row.read<int>('v'));
  }

  Stream<int> watchTotalPayables() {
    return customSelect(
      "SELECT COALESCE(SUM(total_amount - paid_amount), 0) AS v FROM debts "
      "WHERE type = '${DebtType.payable}' AND is_archived = 0",
      readsFrom: {debts},
    ).watchSingle().map((row) => row.read<int>('v'));
  }

  // ---------------------------------------------------------------------------
  // Transaksi
  // ---------------------------------------------------------------------------

  Stream<List<TxEntry>> watchRecentTransactions({int limit = 5}) {
    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
    ])
      ..orderBy([
        OrderingTerm.desc(transactions.transactionDate),
        OrderingTerm.desc(transactions.id),
      ])
      ..limit(limit);

    return query.watch().map(_mapTxRows);
  }

  Stream<List<TxEntry>> watchTransactionsForMonth(
    DateTime month, {
    String? type,
    String? source,
    int? categoryId,
  }) {
    var where = transactions.transactionDate
            .isBiggerOrEqualValue(_monthStart(month).millisecondsSinceEpoch) &
        transactions.transactionDate
            .isSmallerThanValue(_nextMonth(month).millisecondsSinceEpoch);

    if (type != null) {
      where = where & transactions.type.equals(type);
    }
    if (source == TxSource.manual) {
      where = where & transactions.referenceType.isNull();
    } else if (source != null) {
      where = where & transactions.referenceType.equals(source);
    }
    if (categoryId != null) {
      where = where & transactions.categoryId.equals(categoryId);
    }

    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
    ])
      ..where(where)
      ..orderBy([
        OrderingTerm.desc(transactions.transactionDate),
        OrderingTerm.desc(transactions.id),
      ]);

    return query.watch().map(_mapTxRows);
  }

  Future<TxEntry?> getTransactionById(int id) async {
    final row = await (select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
    ])..where(transactions.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return TxEntry(
      txn: row.readTable(transactions),
      category: row.readTable(categories),
    );
  }

  Future<bool> hasAnyTransaction() async {
    final rows = await (select(transactions)..limit(1)).get();
    return rows.isNotEmpty;
  }

  Stream<bool> watchHasAnyTransaction() {
    return (select(transactions)..limit(1))
        .watch()
        .map((rows) => rows.isNotEmpty);
  }

  Stream<int> watchTransactionCount() {
    final count = transactions.id.count();
    return (selectOnly(transactions)..addColumns([count]))
        .watchSingle()
        .map((row) => row.read(count) ?? 0);
  }

  List<TxEntry> _mapTxRows(List<TypedResult> rows) {
    return rows
        .map((row) => TxEntry(
              txn: row.readTable(transactions),
              category: row.readTable(categories),
            ))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Tabungan
  // ---------------------------------------------------------------------------

  Stream<List<TxCategory>> watchCategories() {
    final query = select(categories)
      ..where((c) => c.isActive.equals(true))
      ..orderBy([
        (c) => OrderingTerm(expression: c.isSystem),
        (c) => OrderingTerm(expression: c.sortOrder),
        (c) => OrderingTerm(expression: c.name),
      ]);
    return query.watch();
  }

  Stream<List<SavingsGoal>> watchSavingsGoals() {
    final query = select(savingsGoals)
      ..where((g) => g.isArchived.equals(false))
      ..orderBy([
        (g) => OrderingTerm(expression: g.isCompleted),
        (g) => OrderingTerm(expression: g.id, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  Stream<SavingsGoal?> watchSavingsGoal(int id) {
    return (select(savingsGoals)..where((g) => g.id.equals(id)))
        .watchSingleOrNull();
  }

  Stream<List<SavingLog>> watchSavingLogs(int goalId) {
    return (select(savingLogs)
          ..where((l) => l.savingId.equals(goalId))
          ..orderBy([(l) => OrderingTerm(expression: l.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // Hutang & piutang
  // ---------------------------------------------------------------------------

  Stream<List<Debt>> watchDebts(String type) {
    final query = select(debts)
      ..where((d) => d.type.equals(type) & d.isArchived.equals(false))
      ..orderBy([
        (d) => OrderingTerm(expression: d.isSettled),
        (d) => OrderingTerm(expression: d.dueDate, mode: OrderingMode.asc),
        (d) => OrderingTerm(expression: d.id, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  Stream<Debt?> watchDebt(int id) {
    return (select(debts)..where((d) => d.id.equals(id))).watchSingleOrNull();
  }

  Stream<List<DebtPayment>> watchDebtPayments(int debtId) {
    return (select(debtPayments)
          ..where((p) => p.debtId.equals(debtId))
          ..orderBy([(p) => OrderingTerm(expression: p.paymentDate, mode: OrderingMode.desc)]))
        .watch();
  }

  Stream<List<Debt>> watchUpcomingDebts({int days = 7}) {
    final limit = DateTime.now()
        .add(Duration(days: days))
        .millisecondsSinceEpoch;
    final query = select(debts)
      ..where((d) =>
          d.isSettled.equals(false) &
          d.isArchived.equals(false) &
          d.dueDate.isNotNull() &
          d.dueDate.isSmallerOrEqualValue(limit))
      ..orderBy([(d) => OrderingTerm(expression: d.dueDate, mode: OrderingMode.asc)]);
    return query.watch();
  }

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  static DateTime _monthStart(DateTime date) => DateTime(date.year, date.month);

  static DateTime _nextMonth(DateTime date) =>
      DateTime(date.year, date.month + 1);
}
