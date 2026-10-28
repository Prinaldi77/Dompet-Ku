import 'package:drift/drift.dart';

/// Kategori transaksi. Sistem memakai `code` untuk lookup yang stabil,
/// sedangkan pengguna hanya berinteraksi dengan `name`.
@DataClassName('TxCategory')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().nullable().unique()();
  TextColumn get name => text().withLength(min: 1, max: 60).unique()();
  TextColumn get icon => text().withDefault(const Constant('category'))();
  TextColumn get tipe => text()(); // INCOME | EXPENSE | BOTH
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

@TableIndex(name: 'idx_transactions_date', columns: {#transactionDate})
@TableIndex(name: 'idx_transactions_ref', columns: {#referenceType, #referenceId})
@TableIndex(name: 'idx_transactions_type_date', columns: {#type, #transactionDate})
@DataClassName('Txn')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  IntColumn get amount => integer()(); // Rupiah penuh
  TextColumn get type => text()(); // INCOME | EXPENSE
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get transactionDate => integer()(); // epoch millis (UTC)
  TextColumn get note => text().nullable()();

  /// NULL berarti transaksi manual. Nilai lain menandai transaksi otomatis.
  TextColumn get referenceType => text().nullable()(); // SAVING | DEBT
  IntColumn get referenceId => integer().nullable()();
}

@DataClassName('SavingsGoal')
class SavingsGoals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get goalName => text().withLength(min: 1, max: 80)();
  IntColumn get targetAmount => integer()();
  IntColumn get currentAmount => integer().withDefault(const Constant(0))();
  IntColumn get targetDate => integer().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

@DataClassName('SavingLog')
class SavingLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get savingId =>
      integer().references(SavingsGoals, #id, onDelete: KeyAction.cascade)();
  IntColumn get transactionId => integer()
      .references(Transactions, #id, onDelete: KeyAction.cascade)
      .unique()();
  IntColumn get amount => integer()();
  TextColumn get actionType => text()(); // DEPOSIT | WITHDRAW
  IntColumn get createdAt => integer()();
}

@DataClassName('Debt')
class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get personName => text().withLength(min: 1, max: 80)();
  TextColumn get type => text()(); // PAYABLE | RECEIVABLE
  IntColumn get totalAmount => integer()();
  IntColumn get paidAmount => integer().withDefault(const Constant(0))();
  IntColumn get dueDate => integer().nullable()();
  BoolColumn get isSettled => boolean().withDefault(const Constant(false))();
  IntColumn get initialTransactionId =>
      integer().nullable().references(Transactions, #id, onDelete: KeyAction.setNull)();
  TextColumn get description => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

@DataClassName('DebtPayment')
class DebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get debtId => integer().references(Debts, #id, onDelete: KeyAction.cascade)();
  IntColumn get transactionId => integer()
      .references(Transactions, #id, onDelete: KeyAction.cascade)
      .unique()();
  IntColumn get amountPaid => integer()();
  IntColumn get paymentDate => integer()();
  TextColumn get note => text().nullable()();
}
