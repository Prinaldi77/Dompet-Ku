import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'ledger_types.dart';

class LedgerException implements Exception {
  LedgerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ValidationException extends LedgerException {
  ValidationException(super.message);
}

class ProtectedTransactionException extends LedgerException {
  ProtectedTransactionException([String? message])
      : super(message ??
            'Transaksi otomatis hanya dapat diubah dari modul sumbernya.');
}

class InsufficientBalanceException extends LedgerException {
  InsufficientBalanceException(this.available)
      : super('Saldo utama tidak mencukupi.');

  final int available;
}

/// Satu-satunya jalur tulis ke tabel yang memengaruhi Saldo Utama.
/// Setiap operasi dijalankan dalam satu database transaction agar saldo
/// tidak pernah setengah-terupdate.
class LedgerService {
  LedgerService(this._db);

  final AppDatabase _db;

  static const int maxAmount = 1000000000000; // Rp 1 triliun

  // ---------------------------------------------------------------------------
  // Transaksi manual
  // ---------------------------------------------------------------------------

  Future<int> addManualTransaction({
    required String title,
    required int amount,
    required String type,
    required int categoryId,
    required DateTime date,
    String? note,
  }) async {
    _validateTransaction(title: title, amount: amount, type: type);
    late int id;
    await _db.transaction(() async {
      id = await _insertTransaction(
        title: title.trim(),
        amount: amount,
        type: type,
        categoryId: categoryId,
        date: date.millisecondsSinceEpoch,
        note: _cleanNote(note),
      );
    });
    return id;
  }

  Future<void> updateManualTransaction({
    required int id,
    required String title,
    required int amount,
    required String type,
    required int categoryId,
    required DateTime date,
    String? note,
  }) async {
    _validateTransaction(title: title, amount: amount, type: type);
    await _db.transaction(() async {
      final row = await _getTransaction(id);
      if (row.referenceType != null) throw ProtectedTransactionException();
      await (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(
          title: Value(title.trim()),
          amount: Value(amount),
          type: Value(type),
          categoryId: Value(categoryId),
          transactionDate: Value(date.millisecondsSinceEpoch),
          note: Value(_cleanNote(note)),
        ),
      );
    });
  }

  Future<void> deleteManualTransaction(int id) async {
    await _db.transaction(() async {
      final row = await _getTransaction(id);
      if (row.referenceType != null) throw ProtectedTransactionException();
      await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
    });
  }

  // ---------------------------------------------------------------------------
  // Saldo awal & penyesuaian
  // ---------------------------------------------------------------------------

  Future<void> setInitialBalance(int amount) async {
    if (amount < 0 || amount > maxAmount) {
      throw ValidationException('Nominal saldo awal tidak valid.');
    }
    await _db.transaction(() async {
      final category = await _categoryByCode(CategoryCodes.initialBalance);
      final existing = await (_db.select(_db.transactions)
            ..where((t) => t.categoryId.equals(category.id)))
          .get();
      final now = DateTime.now().millisecondsSinceEpoch;

      if (existing.isEmpty) {
        await _insertTransaction(
          title: 'Saldo Awal',
          amount: amount,
          type: TxType.income,
          categoryId: category.id,
          date: now,
        );
      } else {
        await (_db.update(_db.transactions)
              ..where((t) => t.id.equals(existing.first.id)))
            .write(TransactionsCompanion(
          amount: Value(amount),
          transactionDate: Value(now),
        ));
      }
    });
  }

  /// Menyesuaikan saldo ke nominal target dengan membuat transaksi selisih.
  /// Menghasilkan 0 transaksi jika saldo sudah sama.
  Future<void> adjustBalanceTo(int target) async {
    if (target < 0 || target > maxAmount) {
      throw ValidationException('Saldo target tidak valid.');
    }
    await _db.transaction(() async {
      final current = await _mainBalance();
      final diff = target - current;
      if (diff == 0) return;

      final category = await _categoryByCode(CategoryCodes.adjustment);
      await _insertTransaction(
        title: diff > 0 ? 'Penyesuaian Saldo (masuk)' : 'Penyesuaian Saldo (keluar)',
        amount: diff.abs(),
        type: diff > 0 ? TxType.income : TxType.expense,
        categoryId: category.id,
        date: DateTime.now().millisecondsSinceEpoch,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Tabungan
  // ---------------------------------------------------------------------------

  Future<int> createSavingsGoal({
    required String name,
    required int targetAmount,
    DateTime? targetDate,
  }) async {
    if (name.trim().isEmpty) throw ValidationException('Nama target wajib diisi.');
    if (targetAmount <= 0 || targetAmount > maxAmount) {
      throw ValidationException('Nominal target tidak valid.');
    }
    return _db.into(_db.savingsGoals).insert(
          SavingsGoalsCompanion.insert(
            goalName: name.trim(),
            targetAmount: targetAmount,
            targetDate: Value(targetDate?.millisecondsSinceEpoch),
          ),
        );
  }

  Future<void> depositToSavings({
    required int goalId,
    required int amount,
    required DateTime date,
    String? note,
    bool force = false,
  }) async {
    _validateAmount(amount);
    await _db.transaction(() async {
      final goal = await _getGoal(goalId);
      final balance = await _mainBalance();
      if (!force && amount > balance) {
        throw InsufficientBalanceException(balance);
      }

      final category = await _categoryByCode(CategoryCodes.savingDeposit);
      final txId = await _insertTransaction(
        title: 'Setor Tabungan: ${goal.goalName}',
        amount: amount,
        type: TxType.expense,
        categoryId: category.id,
        date: date.millisecondsSinceEpoch,
        note: _cleanNote(note),
        referenceType: RefType.saving,
      );
      final logId = await _db.into(_db.savingLogs).insert(
            SavingLogsCompanion.insert(
              savingId: goalId,
              transactionId: txId,
              amount: amount,
              actionType: SavingAction.deposit,
              createdAt: date.millisecondsSinceEpoch,
            ),
          );
      await (_db.update(_db.transactions)..where((t) => t.id.equals(txId)))
          .write(TransactionsCompanion(referenceId: Value(logId)));
      await _refreshGoal(goalId);
    });
  }

  Future<void> withdrawFromSavings({
    required int goalId,
    required int amount,
    required DateTime date,
    String? note,
  }) async {
    _validateAmount(amount);
    await _db.transaction(() async {
      final goal = await _getGoal(goalId);
      final available = await _goalAmount(goalId);
      if (amount > available) {
        throw ValidationException('Nominal melebihi saldo tabungan saat ini.');
      }

      final category = await _categoryByCode(CategoryCodes.savingWithdraw);
      final txId = await _insertTransaction(
        title: 'Tarik Tabungan: ${goal.goalName}',
        amount: amount,
        type: TxType.income,
        categoryId: category.id,
        date: date.millisecondsSinceEpoch,
        note: _cleanNote(note),
        referenceType: RefType.saving,
      );
      final logId = await _db.into(_db.savingLogs).insert(
            SavingLogsCompanion.insert(
              savingId: goalId,
              transactionId: txId,
              amount: amount,
              actionType: SavingAction.withdraw,
              createdAt: date.millisecondsSinceEpoch,
            ),
          );
      await (_db.update(_db.transactions)..where((t) => t.id.equals(txId)))
          .write(TransactionsCompanion(referenceId: Value(logId)));
      await _refreshGoal(goalId);
    });
  }

  Future<void> deleteSavingLog(int logId) async {
    await _db.transaction(() async {
      final log = await (_db.select(_db.savingLogs)
            ..where((l) => l.id.equals(logId)))
          .getSingleOrNull();
      if (log == null) throw ValidationException('Riwayat tidak ditemukan.');

      await (_db.delete(_db.transactions)
            ..where((t) => t.id.equals(log.transactionId)))
          .go();
      await (_db.delete(_db.savingLogs)..where((l) => l.id.equals(logId))).go();
      await _refreshGoal(log.savingId);
    });
  }

  /// [withHistory] true menghapus seluruh riwayat dan memulihkan Saldo Utama;
  /// false hanya mengarsipkan goal sehingga dana tetap tercatat.
  Future<void> deleteSavingsGoal(int goalId, {bool withHistory = true}) async {
    await _db.transaction(() async {
      await _getGoal(goalId);
      if (!withHistory) {
        await (_db.update(_db.savingsGoals)..where((g) => g.id.equals(goalId)))
            .write(const SavingsGoalsCompanion(isArchived: Value(true)));
        return;
      }

      final logs = await (_db.select(_db.savingLogs)
            ..where((l) => l.savingId.equals(goalId)))
          .get();
      for (final log in logs) {
        await (_db.delete(_db.transactions)
              ..where((t) => t.id.equals(log.transactionId)))
            .go();
      }
      await (_db.delete(_db.savingsGoals)..where((g) => g.id.equals(goalId)))
          .go();
    });
  }

  // ---------------------------------------------------------------------------
  // Hutang & piutang
  // ---------------------------------------------------------------------------

  Future<int> createDebt({
    required String personName,
    required String type,
    required int totalAmount,
    DateTime? dueDate,
    String? description,
    bool receivedInWallet = true,
    bool force = false,
  }) async {
    if (personName.trim().isEmpty) {
      throw ValidationException('Nama orang wajib diisi.');
    }
    if (type != DebtType.payable && type != DebtType.receivable) {
      throw ValidationException('Tipe hutang tidak dikenal.');
    }
    _validateAmount(totalAmount);

    return _db.transaction(() async {
      final cleanDescription = _cleanNote(description);
      final debtId = await _db.into(_db.debts).insert(
            DebtsCompanion.insert(
              personName: personName.trim(),
              type: type,
              totalAmount: totalAmount,
              dueDate: Value(dueDate?.millisecondsSinceEpoch),
              description: Value(cleanDescription),
            ),
          );

      int? txId;
      if (type == DebtType.payable) {
        if (receivedInWallet) {
          final category = await _categoryByCode(CategoryCodes.debtDisbursement);
          txId = await _insertTransaction(
            title: 'Pinjaman dari ${personName.trim()}',
            amount: totalAmount,
            type: TxType.income,
            categoryId: category.id,
            date: DateTime.now().millisecondsSinceEpoch,
            referenceType: RefType.debt,
            referenceId: debtId,
          );
        }
      } else {
        final balance = await _mainBalance();
        if (!force && totalAmount > balance) {
          throw InsufficientBalanceException(balance);
        }
        final category =
            await _categoryByCode(CategoryCodes.receivableDisbursement);
        txId = await _insertTransaction(
          title: 'Pinjaman untuk ${personName.trim()}',
          amount: totalAmount,
          type: TxType.expense,
          categoryId: category.id,
          date: DateTime.now().millisecondsSinceEpoch,
          referenceType: RefType.debt,
          referenceId: debtId,
        );
      }

      if (txId != null) {
        await (_db.update(_db.debts)..where((d) => d.id.equals(debtId)))
            .write(DebtsCompanion(initialTransactionId: Value(txId)));
      }
      return debtId;
    });
  }

  /// Mengembalikan nominal yang benar-benar diterapkan (di-clamp ke sisa).
  Future<int> payDebt({
    required int debtId,
    required int amount,
    required DateTime date,
    String? note,
    bool force = false,
  }) async {
    _validateAmount(amount);
    late int applied;

    await _db.transaction(() async {
      final debt = await _getDebt(debtId);
      final remaining = debt.totalAmount - debt.paidAmount;
      if (remaining <= 0) {
        throw ValidationException('Hutang/piutang ini sudah lunas.');
      }
      applied = amount > remaining ? remaining : amount;

      final isPayable = debt.type == DebtType.payable;
      if (isPayable) {
        final balance = await _mainBalance();
        if (!force && applied > balance) {
          throw InsufficientBalanceException(balance);
        }
      }

      final category = await _categoryByCode(
        isPayable ? CategoryCodes.debtPayment : CategoryCodes.receivableRepayment,
      );
      final txId = await _insertTransaction(
        title: isPayable
            ? 'Cicil Hutang: ${debt.personName}'
            : 'Terima Cicilan: ${debt.personName}',
        amount: applied,
        type: isPayable ? TxType.expense : TxType.income,
        categoryId: category.id,
        date: date.millisecondsSinceEpoch,
        note: _cleanNote(note),
        referenceType: RefType.debt,
      );
      final paymentId = await _db.into(_db.debtPayments).insert(
            DebtPaymentsCompanion.insert(
              debtId: debtId,
              transactionId: txId,
              amountPaid: applied,
              paymentDate: date.millisecondsSinceEpoch,
              note: Value(_cleanNote(note)),
            ),
          );
      await (_db.update(_db.transactions)..where((t) => t.id.equals(txId)))
          .write(TransactionsCompanion(referenceId: Value(paymentId)));
      await _refreshDebt(debtId);
    });

    return applied;
  }

  Future<void> deleteDebtPayment(int paymentId) async {
    await _db.transaction(() async {
      final payment = await (_db.select(_db.debtPayments)
            ..where((p) => p.id.equals(paymentId)))
          .getSingleOrNull();
      if (payment == null) throw ValidationException('Cicilan tidak ditemukan.');

      await (_db.delete(_db.transactions)
            ..where((t) => t.id.equals(payment.transactionId)))
          .go();
      await (_db.delete(_db.debtPayments)
            ..where((p) => p.id.equals(paymentId)))
          .go();
      await _refreshDebt(payment.debtId);
    });
  }

  Future<void> deleteDebt(int debtId, {bool withHistory = true}) async {
    await _db.transaction(() async {
      final debt = await _getDebt(debtId);
      if (!withHistory) {
        await (_db.update(_db.debts)..where((d) => d.id.equals(debtId)))
            .write(const DebtsCompanion(isArchived: Value(true)));
        return;
      }

      final payments = await (_db.select(_db.debtPayments)
            ..where((p) => p.debtId.equals(debtId)))
          .get();
      for (final payment in payments) {
        await (_db.delete(_db.transactions)
              ..where((t) => t.id.equals(payment.transactionId)))
            .go();
      }
      final initialTxId = debt.initialTransactionId;
      if (initialTxId != null) {
        await (_db.delete(_db.transactions)
              ..where((t) => t.id.equals(initialTxId)))
            .go();
      }
      await (_db.delete(_db.debts)..where((d) => d.id.equals(debtId))).go();
    });
  }

  // ---------------------------------------------------------------------------
  // Recompute cache derived (selalu di dalam transaction pemanggil)
  // ---------------------------------------------------------------------------

  Future<void> _refreshGoal(int goalId) async {
    final goal = await (_db.select(_db.savingsGoals)
          ..where((g) => g.id.equals(goalId)))
        .getSingleOrNull();
    if (goal == null) return;

    final current = await _goalAmount(goalId);
    await (_db.update(_db.savingsGoals)..where((g) => g.id.equals(goalId)))
        .write(SavingsGoalsCompanion(
      currentAmount: Value(current),
      isCompleted: Value(current >= goal.targetAmount),
    ));
  }

  Future<void> _refreshDebt(int debtId) async {
    final debt =
        await (_db.select(_db.debts)..where((d) => d.id.equals(debtId)))
            .getSingleOrNull();
    if (debt == null) return;

    final payments = await (_db.select(_db.debtPayments)
          ..where((p) => p.debtId.equals(debtId)))
        .get();
    final paid = payments.fold<int>(0, (sum, p) => sum + p.amountPaid);
    await (_db.update(_db.debts)..where((d) => d.id.equals(debtId))).write(
      DebtsCompanion(
        paidAmount: Value(paid),
        isSettled: Value(paid >= debt.totalAmount),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  Future<int> _mainBalance() async {
    final row = await _db.customSelect(
      "SELECT COALESCE(SUM(CASE WHEN type = '${TxType.income}' THEN amount "
      'ELSE -amount END), 0) AS v FROM transactions',
    ).getSingle();
    return row.read<int>('v');
  }

  Future<int> _goalAmount(int goalId) async {
    final logs = await (_db.select(_db.savingLogs)
          ..where((l) => l.savingId.equals(goalId)))
        .get();
    return logs.fold<int>(
      0,
      (sum, log) =>
          sum + (log.actionType == SavingAction.deposit ? log.amount : -log.amount),
    );
  }

  Future<TxCategory> _categoryByCode(String code) async {
    final row = await (_db.select(_db.categories)..where((c) => c.code.equals(code)))
        .getSingleOrNull();
    if (row == null) {
      throw ValidationException('Kategori sistem "$code" tidak ditemukan.');
    }
    return row;
  }

  Future<Txn> _getTransaction(int id) async {
    final row = await (_db.select(_db.transactions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) throw ValidationException('Transaksi tidak ditemukan.');
    return row;
  }

  Future<SavingsGoal> _getGoal(int id) async {
    final row = await (_db.select(_db.savingsGoals)..where((g) => g.id.equals(id)))
        .getSingleOrNull();
    if (row == null) throw ValidationException('Target tabungan tidak ditemukan.');
    return row;
  }

  Future<Debt> _getDebt(int id) async {
    final row = await (_db.select(_db.debts)..where((d) => d.id.equals(id)))
        .getSingleOrNull();
    if (row == null) throw ValidationException('Data hutang tidak ditemukan.');
    return row;
  }

  Future<int> _insertTransaction({
    required String title,
    required int amount,
    required String type,
    required int categoryId,
    required int date,
    String? note,
    String? referenceType,
    int? referenceId,
  }) {
    return _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            title: title,
            amount: amount,
            type: type,
            categoryId: categoryId,
            transactionDate: date,
            note: Value(note),
            referenceType: Value(referenceType),
            referenceId: Value(referenceId),
          ),
        );
  }

  void _validateTransaction({
    required String title,
    required int amount,
    required String type,
  }) {
    if (title.trim().isEmpty) {
      throw ValidationException('Judul transaksi wajib diisi.');
    }
    if (type != TxType.income && type != TxType.expense) {
      throw ValidationException('Tipe transaksi tidak dikenal.');
    }
    _validateAmount(amount);
  }

  void _validateAmount(int amount) {
    if (amount <= 0) {
      throw ValidationException('Nominal harus lebih dari nol.');
    }
    if (amount > maxAmount) {
      throw ValidationException('Nominal melebihi batas yang didukung.');
    }
  }

  String? _cleanNote(String? note) {
    final trimmed = note?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
