import 'dart:math';

import 'package:dompetku/core/database/app_database.dart';
import 'package:dompetku/core/ledger/ledger_service.dart';
import 'package:dompetku/core/ledger/ledger_types.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LedgerService ledger;
  late int expenseCategoryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = LedgerService(db);
    final expenseCategory = await (db.select(db.categories)
          ..where((c) => c.name.equals('Belanja')))
        .getSingle();
    expenseCategoryId = expenseCategory.id;
  });

  tearDown(() => db.close());

  Future<int> balance() => db.watchMainBalance().first;
  Future<int> savingsAmount(int goalId) async =>
      (await (db.select(db.savingsGoals)..where((g) => g.id.equals(goalId)))
              .getSingle())
          .currentAmount;
  Future<Debt> debt(int id) =>
      (db.select(db.debts)..where((d) => d.id.equals(id))).getSingle();

  group('Saldo awal & penyesuaian', () {
    test('saldo awal hanya satu baris dan bisa diperbarui', () async {
      await ledger.setInitialBalance(500000);
      await ledger.setInitialBalance(750000);

      final rows = await db.select(db.transactions).get();
      expect(rows, hasLength(1));
      expect(await balance(), 750000);
    });

    test('adjustBalanceTo membuat transaksi selisih dan tidak dobel', () async {
      await ledger.setInitialBalance(100000);
      await ledger.adjustBalanceTo(400000);
      await ledger.adjustBalanceTo(400000);

      expect(await balance(), 400000);
      expect(await db.select(db.transactions).get(), hasLength(2));
    });

    test('menolak nominal saldo awal negatif', () async {
      expect(
        () => ledger.setInitialBalance(-1),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('Transaksi manual', () {
    test('menambah dan menghapus transaksi mengubah saldo', () async {
      await ledger.setInitialBalance(100000);
      final id = await ledger.addManualTransaction(
        title: 'Makan siang',
        amount: 25000,
        type: TxType.expense,
        categoryId: expenseCategoryId,
        date: DateTime(2024, 3, 10),
        note: '  nasi padang  ',
      );

      expect(await balance(), 75000);
      final entry = await db.getTransactionById(id);
      expect(entry!.txn.note, 'nasi padang');

      await ledger.deleteManualTransaction(id);
      expect(await balance(), 100000);
    });

    test('ringkasan bulanan hanya menghitung transaksi manual', () async {
      final month = DateTime(2024, 3);
      await ledger.addManualTransaction(
        title: 'Gaji',
        amount: 500000,
        type: TxType.income,
        categoryId: expenseCategoryId,
        date: DateTime(2024, 3, 1),
      );
      await ledger.addManualTransaction(
        title: 'Belanja',
        amount: 120000,
        type: TxType.expense,
        categoryId: expenseCategoryId,
        date: DateTime(2024, 3, 5),
      );
      // Otomatis dari modul tabungan: harus diabaikan ringkasan manual.
      final goalId = await ledger.createSavingsGoal(
        name: 'Dana Darurat',
        targetAmount: 1000000,
      );
      await ledger.depositToSavings(
        goalId: goalId,
        amount: 50000,
        date: DateTime(2024, 3, 7),
        force: true,
      );

      final flow = await db.watchMonthlyFlow(month).first;
      expect(flow.income, 500000);
      expect(flow.expense, 120000);

      final breakdown = await db.watchManualExpenseByCategory(month).first;
      expect(breakdown, hasLength(1));
      expect(breakdown.single.name, 'Belanja');
      expect(breakdown.single.amount, 120000);

      final allocation = await db.watchMonthlyAllocation(month).first;
      expect(allocation.savings, 50000);
    });

    test('transaksi pada bulan lain tidak ikut terhitung', () async {
      await ledger.addManualTransaction(
        title: 'April',
        amount: 90000,
        type: TxType.expense,
        categoryId: expenseCategoryId,
        date: DateTime(2024, 4, 2),
      );
      final flow = await db.watchMonthlyFlow(DateTime(2024, 3)).first;
      expect(flow.expense, 0);
    });

    test('menolak transaksi tanpa judul dan nominal nol', () async {
      expect(
        () => ledger.addManualTransaction(
          title: '   ',
          amount: 1000,
          type: TxType.expense,
          categoryId: expenseCategoryId,
          date: DateTime(2024, 3, 1),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => ledger.addManualTransaction(
          title: 'Nol',
          amount: 0,
          type: TxType.expense,
          categoryId: expenseCategoryId,
          date: DateTime(2024, 3, 1),
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('Tabungan', () {
    test('setor memotong saldo, tarik mengembalikan, hapus log memulihkan',
        () async {
      await ledger.setInitialBalance(300000);
      final goalId = await ledger.createSavingsGoal(
        name: 'Liburan',
        targetAmount: 200000,
      );

      await ledger.depositToSavings(
        goalId: goalId,
        amount: 200000,
        date: DateTime(2024, 3, 3),
      );
      expect(await balance(), 100000);
      expect(await savingsAmount(goalId), 200000);

      final goal = await (db.select(db.savingsGoals)
            ..where((g) => g.id.equals(goalId)))
          .getSingle();
      expect(goal.isCompleted, isTrue);

      await ledger.withdrawFromSavings(
        goalId: goalId,
        amount: 50000,
        date: DateTime(2024, 3, 4),
      );
      expect(await balance(), 150000);
      expect(await savingsAmount(goalId), 150000);

      final log = await (db.select(db.savingLogs)
            ..where((l) => l.savingId.equals(goalId))
            ..orderBy([(l) => OrderingTerm.desc(l.id)])
            ..limit(1))
          .getSingle();
      await ledger.deleteSavingLog(log.id);
      expect(await balance(), 100000);
      expect(await savingsAmount(goalId), 200000);
    });

    test('setor melebihi saldo ditolak kecuali force', () async {
      await ledger.setInitialBalance(100000);
      final goalId = await ledger.createSavingsGoal(
        name: 'Motor',
        targetAmount: 500000,
      );

      await expectLater(
        ledger.depositToSavings(
          goalId: goalId,
          amount: 150000,
          date: DateTime(2024, 3, 3),
        ),
        throwsA(isA<InsufficientBalanceException>()),
      );
      expect(await balance(), 100000);

      await ledger.depositToSavings(
        goalId: goalId,
        amount: 150000,
        date: DateTime(2024, 3, 3),
        force: true,
      );
      expect(await balance(), -50000);
      expect(await savingsAmount(goalId), 150000);
    });

    test('tarik melebihi saldo tabungan ditolak', () async {
      final goalId = await ledger.createSavingsGoal(
        name: 'Kosong',
        targetAmount: 100000,
      );
      await expectLater(
        ledger.withdrawFromSavings(
          goalId: goalId,
          amount: 1000,
          date: DateTime(2024, 3, 3),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('hapus target dengan riwayat mengembalikan seluruh dana', () async {
      await ledger.setInitialBalance(200000);
      final goalId = await ledger.createSavingsGoal(
        name: 'Laptop',
        targetAmount: 150000,
      );
      await ledger.depositToSavings(
        goalId: goalId,
        amount: 150000,
        date: DateTime(2024, 3, 3),
      );

      await ledger.deleteSavingsGoal(goalId);
      expect(await balance(), 200000);
      expect(await db.select(db.savingsGoals).get(), isEmpty);
    });

    test('arsip target tidak mengubah saldo', () async {
      await ledger.setInitialBalance(200000);
      final goalId = await ledger.createSavingsGoal(
        name: 'Sepeda',
        targetAmount: 100000,
      );
      await ledger.depositToSavings(
        goalId: goalId,
        amount: 100000,
        date: DateTime(2024, 3, 3),
      );

      await ledger.deleteSavingsGoal(goalId, withHistory: false);
      expect(await balance(), 100000);
      expect((await db.select(db.savingsGoals).getSingle()).isArchived, isTrue);
    });
  });

  group('Hutang & piutang', () {
    test('hutang yang diterima di dompet menambah saldo', () async {
      final debtId = await ledger.createDebt(
        personName: 'Budi',
        type: DebtType.payable,
        totalAmount: 250000,
      );
      expect(await balance(), 250000);

      final record = await debt(debtId);
      expect(record.initialTransactionId, isNotNull);
    });

    test('hutang tanpa penerimaan tidak mengubah saldo', () async {
      final debtId = await ledger.createDebt(
        personName: 'Lama',
        type: DebtType.payable,
        totalAmount: 250000,
        receivedInWallet: false,
      );
      expect(await balance(), 0);
      expect((await debt(debtId)).initialTransactionId, isNull);

      final entry = await db.getTransactionById(
        (await debt(debtId)).initialTransactionId ?? 0,
      );
      expect(entry, isNull);
    });

    test('bayar hutang di-clamp ke sisa dan menandai lunas', () async {
      final debtId = await ledger.createDebt(
        personName: 'Budi',
        type: DebtType.payable,
        totalAmount: 200000,
      );

      final applied = await ledger.payDebt(
        debtId: debtId,
        amount: 250000,
        date: DateTime(2024, 3, 5),
      );
      expect(applied, 200000);
      expect(await balance(), 0);

      final record = await debt(debtId);
      expect(record.paidAmount, 200000);
      expect(record.isSettled, isTrue);

      await expectLater(
        ledger.payDebt(
          debtId: debtId,
          amount: 1000,
          date: DateTime(2024, 3, 6),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('bayar hutang melebihi saldo ditolak kecuali force', () async {
      final debtId = await ledger.createDebt(
        personName: 'Siti',
        type: DebtType.payable,
        totalAmount: 100000,
        receivedInWallet: false,
      );

      await expectLater(
        ledger.payDebt(
          debtId: debtId,
          amount: 50000,
          date: DateTime(2024, 3, 5),
        ),
        throwsA(isA<InsufficientBalanceException>()),
      );
      expect(await balance(), 0);

      await ledger.payDebt(
        debtId: debtId,
        amount: 50000,
        date: DateTime(2024, 3, 5),
        force: true,
      );
      expect(await balance(), -50000);
      expect((await debt(debtId)).paidAmount, 50000);
    });

    test('piutang memotong saldo dan cicilan menambah saldo', () async {
      await ledger.setInitialBalance(500000);
      final debtId = await ledger.createDebt(
        personName: 'Andi',
        type: DebtType.receivable,
        totalAmount: 150000,
      );
      expect(await balance(), 350000);

      await ledger.payDebt(
        debtId: debtId,
        amount: 100000,
        date: DateTime(2024, 3, 5),
      );
      expect(await balance(), 450000);
      expect((await debt(debtId)).paidAmount, 100000);
      expect((await debt(debtId)).isSettled, isFalse);
    });

    test('piutang melebihi saldo ditolak kecuali force', () async {
      await ledger.setInitialBalance(50000);
      await expectLater(
        ledger.createDebt(
          personName: 'Andi',
          type: DebtType.receivable,
          totalAmount: 100000,
        ),
        throwsA(isA<InsufficientBalanceException>()),
      );
      expect(await balance(), 50000);

      final debtId = await ledger.createDebt(
        personName: 'Andi',
        type: DebtType.receivable,
        totalAmount: 100000,
        force: true,
      );
      expect(await balance(), -50000);
      expect((await debt(debtId)).totalAmount, 100000);
    });

    test('hapus cicilan mengembalikan saldo dan status', () async {
      await ledger.setInitialBalance(500000);
      final debtId = await ledger.createDebt(
        personName: 'Budi',
        type: DebtType.payable,
        totalAmount: 100000,
      );
      await ledger.payDebt(
        debtId: debtId,
        amount: 40000,
        date: DateTime(2024, 3, 5),
      );
      expect(await balance(), 560000);

      final payment = await (db.select(db.debtPayments)
            ..where((p) => p.debtId.equals(debtId)))
          .getSingle();
      await ledger.deleteDebtPayment(payment.id);

      expect(await balance(), 600000);
      final record = await debt(debtId);
      expect(record.paidAmount, 0);
      expect(record.isSettled, isFalse);
    });

    test('hapus hutang mengembalikan saldo awal', () async {
      await ledger.setInitialBalance(100000);
      final debtId = await ledger.createDebt(
        personName: 'Budi',
        type: DebtType.payable,
        totalAmount: 100000,
      );
      await ledger.payDebt(
        debtId: debtId,
        amount: 40000,
        date: DateTime(2024, 3, 5),
      );

      await ledger.deleteDebt(debtId);
      expect(await balance(), 100000);
      expect(await db.select(db.debts).get(), isEmpty);
    });

    test('arsip hutang tidak mengubah saldo', () async {
      final debtId = await ledger.createDebt(
        personName: 'Budi',
        type: DebtType.payable,
        totalAmount: 100000,
      );
      await ledger.deleteDebt(debtId, withHistory: false);
      expect(await balance(), 100000);
      expect((await debt(debtId)).isArchived, isTrue);
    });

    test('nama kosong dan tipe tidak dikenal ditolak', () async {
      await expectLater(
        ledger.createDebt(
          personName: '  ',
          type: DebtType.payable,
          totalAmount: 10000,
        ),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        ledger.createDebt(
          personName: 'Budi',
          type: 'UNKNOWN',
          totalAmount: 10000,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('Proteksi transaksi otomatis', () {
    test('transaksi otomatis tidak bisa diubah atau dihapus manual', () async {
      await ledger.setInitialBalance(200000);
      final goalId = await ledger.createSavingsGoal(
        name: 'Dana',
        targetAmount: 100000,
      );
      await ledger.depositToSavings(
        goalId: goalId,
        amount: 100000,
        date: DateTime(2024, 3, 3),
      );

      final autoTx = await (db.select(db.transactions)
            ..where((t) => t.referenceType.equals(RefType.saving)))
          .getSingle();

      await expectLater(
        ledger.updateManualTransaction(
          id: autoTx.id,
          title: 'Diubah',
          amount: 1000,
          type: TxType.expense,
          categoryId: autoTx.categoryId,
          date: DateTime(2024, 3, 3),
        ),
        throwsA(isA<ProtectedTransactionException>()),
      );
      await expectLater(
        ledger.deleteManualTransaction(autoTx.id),
        throwsA(isA<ProtectedTransactionException>()),
      );
    });
  });

  group('Invarian saldo (property test)', () {
    test('Σ transaksi == Saldo Utama setelah 200 operasi acak', () async {
      final random = Random(20261027);
      final incomeCategory = await (db.select(db.categories)
            ..where((c) => c.name.equals('Gaji')))
          .getSingle();
      final manualIds = <int>[];
      final goalIds = <int>[];
      final debtIds = <int>[];

      Future<int> transactionSum() async {
        final rows = await db.select(db.transactions).get();
        return rows.fold<int>(
          0,
          (sum, row) =>
              sum + (row.type == TxType.income ? row.amount : -row.amount),
        );
      }

      Future<void> expectConsistent() async {
        expect(await balance(), await transactionSum());
      }

      await ledger.setInitialBalance(1000000);
      await expectConsistent();

      for (var i = 0; i < 200; i++) {
        final categoryId = random.nextBool()
            ? incomeCategory.id
            : expenseCategoryId;
        final type = categoryId == incomeCategory.id
            ? TxType.income
            : TxType.expense;
        try {
          switch (random.nextInt(9)) {
            case 0:
            case 1:
              manualIds.add(
                await ledger.addManualTransaction(
                  title: 'Acak $i',
                  amount: 1 + random.nextInt(50000),
                  type: type,
                  categoryId: categoryId,
                  date: DateTime(2024, 3, 1)
                      .add(Duration(days: random.nextInt(60))),
                ),
              );
            case 2:
              if (manualIds.isNotEmpty) {
                await ledger.updateManualTransaction(
                  id: manualIds[random.nextInt(manualIds.length)],
                  title: 'Ubah $i',
                  amount: 1 + random.nextInt(50000),
                  type: type,
                  categoryId: categoryId,
                  date: DateTime(2024, 4, 1),
                );
              }
            case 3:
              if (manualIds.isNotEmpty) {
                await ledger.deleteManualTransaction(
                  manualIds.removeAt(random.nextInt(manualIds.length)),
                );
              }
            case 4:
              goalIds.add(
                await ledger.createSavingsGoal(
                  name: 'Target $i',
                  targetAmount: 1 + random.nextInt(200000),
                ),
              );
            case 5:
              if (goalIds.isNotEmpty) {
                final goalId = goalIds[random.nextInt(goalIds.length)];
                if (random.nextBool()) {
                  await ledger.depositToSavings(
                    goalId: goalId,
                    amount: 1 + random.nextInt(30000),
                    date: DateTime(2024, 5, 1),
                  );
                } else {
                  await ledger.withdrawFromSavings(
                    goalId: goalId,
                    amount: 1 + random.nextInt(30000),
                    date: DateTime(2024, 5, 1),
                  );
                }
              }
            case 6:
              if (goalIds.isNotEmpty) {
                await ledger.deleteSavingsGoal(
                  goalIds.removeAt(random.nextInt(goalIds.length)),
                );
              }
            case 7:
              debtIds.add(
                await ledger.createDebt(
                  personName: 'Orang $i',
                  type: random.nextBool()
                      ? DebtType.payable
                      : DebtType.receivable,
                  totalAmount: 1 + random.nextInt(100000),
                  receivedInWallet: true,
                ),
              );
            case 8:
              if (debtIds.isNotEmpty) {
                final debtId = debtIds[random.nextInt(debtIds.length)];
                if (random.nextBool()) {
                  await ledger.payDebt(
                    debtId: debtId,
                    amount: 1 + random.nextInt(30000),
                    date: DateTime(2024, 6, 1),
                  );
                } else {
                  await ledger.adjustBalanceTo(random.nextInt(500000));
                }
              }
          }
        } on ValidationException {
          // Operasi acak boleh ditolak; invarian tetap harus terjaga.
        } on InsufficientBalanceException {
          // Idem.
        }
        await expectConsistent();
      }
    });
  });

  group('Kekayaan bersih', () {
    test('saldo, tabungan, piutang, dan hutang saling konsisten', () async {
      await ledger.setInitialBalance(1000000);
      final goalId = await ledger.createSavingsGoal(
        name: 'Dana Darurat',
        targetAmount: 500000,
      );
      await ledger.depositToSavings(
        goalId: goalId,
        amount: 300000,
        date: DateTime(2024, 3, 1),
      );
      await ledger.createDebt(
        personName: 'Andi',
        type: DebtType.receivable,
        totalAmount: 100000,
      );
      await ledger.createDebt(
        personName: 'Budi',
        type: DebtType.payable,
        totalAmount: 200000,
        receivedInWallet: false,
      );

      expect(await balance(), 600000);
      expect(await db.watchTotalSavings().first, 300000);
      expect(await db.watchTotalReceivables().first, 100000);
      expect(await db.watchTotalPayables().first, 200000);
    });
  });
}
