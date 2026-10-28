import 'package:dompetku/core/database/app_database.dart';
import 'package:dompetku/core/ledger/ledger_service.dart';
import 'package:dompetku/core/ledger/ledger_types.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LedgerService ledger;
  late int salaryCategoryId;
  late int shoppingCategoryId;
  late int savingCategoryId;
  late int debtPaymentCategoryId;
  final month = DateTime(2024, 3);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = LedgerService(db);
    salaryCategoryId = await _categoryId(db, name: 'Gaji');
    shoppingCategoryId = await _categoryId(db, name: 'Belanja');
    savingCategoryId = await _categoryId(db, code: CategoryCodes.savingDeposit);
    debtPaymentCategoryId =
        await _categoryId(db, code: CategoryCodes.debtPayment);

    await ledger.addManualTransaction(
      title: 'Gaji Maret',
      amount: 500000,
      type: TxType.income,
      categoryId: salaryCategoryId,
      date: DateTime(2024, 3, 2),
    );
    await ledger.addManualTransaction(
      title: 'Belanja Maret',
      amount: 120000,
      type: TxType.expense,
      categoryId: shoppingCategoryId,
      date: DateTime(2024, 3, 5),
    );
    await ledger.addManualTransaction(
      title: 'Gaji April',
      amount: 600000,
      type: TxType.income,
      categoryId: salaryCategoryId,
      date: DateTime(2024, 4, 2),
    );

    final goalId = await ledger.createSavingsGoal(
      name: 'Dana Darurat',
      targetAmount: 5000000,
    );
    await ledger.depositToSavings(
      goalId: goalId,
      amount: 250000,
      date: DateTime(2024, 3, 8),
      force: true,
    );

    final debtId = await ledger.createDebt(
      personName: 'Budi',
      type: DebtType.payable,
      totalAmount: 300000,
      receivedInWallet: false,
    );
    await ledger.payDebt(
      debtId: debtId,
      amount: 100000,
      date: DateTime(2024, 3, 12),
      force: true,
    );
  });

  tearDown(() => db.close());

  Future<List<TxEntry>> query({
    String? type,
    String? source,
    int? categoryId,
  }) {
    return db
        .watchTransactionsForMonth(
          month,
          type: type,
          source: source,
          categoryId: categoryId,
        )
        .first;
  }

  List<String> titles(List<TxEntry> entries) =>
      entries.map((entry) => entry.txn.title).toList();

  test('tanpa filter menampilkan semua transaksi bulan tersebut', () async {
    final entries = await query();

    expect(titles(entries), [
      'Cicil Hutang: Budi',
      'Setor Tabungan: Dana Darurat',
      'Belanja Maret',
      'Gaji Maret',
    ]);
  });

  test('filter tipe hanya mengembalikan pemasukan atau pengeluaran', () async {
    expect(titles(await query(type: TxType.income)), ['Gaji Maret']);
    expect(titles(await query(type: TxType.expense)), [
      'Cicil Hutang: Budi',
      'Setor Tabungan: Dana Darurat',
      'Belanja Maret',
    ]);
  });

  test('filter sumber memisahkan manual, tabungan, dan utang', () async {
    final manual = await query(source: TxSource.manual);
    expect(titles(manual), ['Belanja Maret', 'Gaji Maret']);
    expect(manual.every((entry) => !entry.isAutomatic), isTrue);
    expect(manual.every((entry) => entry.txn.referenceType == null), isTrue);

    final saving = await query(source: TxSource.saving);
    expect(titles(saving), ['Setor Tabungan: Dana Darurat']);
    expect(saving.single.txn.referenceType, RefType.saving);

    final debt = await query(source: TxSource.debt);
    expect(titles(debt), ['Cicil Hutang: Budi']);
    expect(debt.single.txn.referenceType, RefType.debt);
  });

  test('filter kategori memakai id kategori', () async {
    expect(
      titles(await query(categoryId: shoppingCategoryId)),
      ['Belanja Maret'],
    );
    expect(
      titles(await query(categoryId: savingCategoryId)),
      ['Setor Tabungan: Dana Darurat'],
    );
  });

  test('kombinasi tipe, sumber, dan kategori', () async {
    expect(
      titles(await query(type: TxType.expense, source: TxSource.manual)),
      ['Belanja Maret'],
    );
    expect(
      titles(await query(type: TxType.expense, source: TxSource.saving)),
      ['Setor Tabungan: Dana Darurat'],
    );
    expect(
      titles(await query(
        type: TxType.expense,
        source: TxSource.debt,
        categoryId: debtPaymentCategoryId,
      )),
      ['Cicil Hutang: Budi'],
    );
    expect(
      titles(await query(source: TxSource.manual, categoryId: shoppingCategoryId)),
      ['Belanja Maret'],
    );
    expect(
      await query(type: TxType.income, source: TxSource.debt),
      isEmpty,
    );
    expect(
      await query(source: TxSource.saving, categoryId: shoppingCategoryId),
      isEmpty,
    );
  });
}

Future<int> _categoryId(
  AppDatabase db, {
  String? code,
  String? name,
}) async {
  final query = db.select(db.categories);
  if (code != null) {
    query.where((c) => c.code.equals(code));
  } else {
    query.where((c) => c.name.equals(name!));
  }
  return (await query.getSingle()).id;
}
