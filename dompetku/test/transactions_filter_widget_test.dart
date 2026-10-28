import 'package:dompetku/core/database/app_database.dart';
import 'package:dompetku/core/ledger/ledger_service.dart';
import 'package:dompetku/core/ledger/ledger_types.dart';
import 'package:dompetku/core/providers/app_providers.dart';
import 'package:dompetku/core/theme/app_theme.dart';
import 'package:dompetku/core/widgets/transaction_tile.dart';
import 'package:dompetku/features/transactions/transactions_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late AppDatabase db;
  late bool dbClosed;

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dbClosed = false;
    final ledger = LedgerService(db);
    final now = DateTime.now();

    final salaryId = await _categoryId(db, 'Gaji');
    final shoppingId = await _categoryId(db, 'Belanja');

    await ledger.addManualTransaction(
      title: 'Gaji Bulan Ini',
      amount: 500000,
      type: TxType.income,
      categoryId: salaryId,
      date: DateTime(now.year, now.month, 2),
    );
    await ledger.addManualTransaction(
      title: 'Belanja Bulan Ini',
      amount: 120000,
      type: TxType.expense,
      categoryId: shoppingId,
      date: DateTime(now.year, now.month, 5),
    );

    final goalId = await ledger.createSavingsGoal(
      name: 'Dana Darurat',
      targetAmount: 5000000,
    );
    await ledger.depositToSavings(
      goalId: goalId,
      amount: 250000,
      date: DateTime(now.year, now.month, 8),
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
      date: DateTime(now.year, now.month, 12),
      force: true,
    );
  });

  tearDown(() async {
    if (!dbClosed) await db.close();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const TransactionsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmountPage(WidgetTester tester) async {
    await tester.runAsync(db.close);
    dbClosed = true;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  Future<void> openFilterSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('filter-button')));
    await tester.pumpAndSettle();
  }

  Future<void> applyFilter(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('filter-apply')));
    await tester.pumpAndSettle();
  }

  testWidgets('menampilkan seluruh transaksi tanpa filter', (tester) async {
    await pumpPage(tester);

    expect(find.byType(TransactionTile), findsNWidgets(4));
    expect(find.text('Gaji Bulan Ini'), findsOneWidget);
    expect(find.text('Belanja Bulan Ini'), findsOneWidget);
    expect(find.text('Setor Tabungan: Dana Darurat'), findsOneWidget);
    expect(find.text('Cicil Hutang: Budi'), findsOneWidget);
    await unmountPage(tester);
  });

  testWidgets('filter sumber tabungan dan transaksi otomatis read-only',
      (tester) async {
    await pumpPage(tester);
    await openFilterSheet(tester);

    expect(find.text('Filter Transaksi'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filter-source-saving')));
    await tester.pump();
    await applyFilter(tester);

    expect(find.byType(TransactionTile), findsOneWidget);
    expect(find.text('Setor Tabungan: Dana Darurat'), findsOneWidget);
    expect(find.text('Filter (1)'), findsOneWidget);

    await tester.tap(find.byType(TransactionTile));
    await tester.pumpAndSettle();

    expect(find.text('Detail Transaksi Otomatis'), findsOneWidget);
    expect(find.text('Simpan Perubahan'), findsNothing);
    await unmountPage(tester);
  });

  testWidgets('kombinasi filter manual keluar dan reset', (tester) async {
    await pumpPage(tester);
    await openFilterSheet(tester);

    await tester.tap(find.byKey(const ValueKey('filter-type-expense')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('filter-source-manual')));
    await tester.pump();
    await applyFilter(tester);

    expect(find.byType(TransactionTile), findsOneWidget);
    expect(find.text('Belanja Bulan Ini'), findsOneWidget);
    expect(find.text('Filter (1)'), findsOneWidget);

    await openFilterSheet(tester);
    await tester.tap(find.byKey(const ValueKey('filter-reset')));
    await tester.pump();
    await applyFilter(tester);

    expect(find.byType(TransactionTile), findsNWidgets(4));
    expect(find.text('Filter'), findsOneWidget);
    await unmountPage(tester);
  });

  testWidgets('filter kosong menampilkan empty state yang sesuai',
      (tester) async {
    await pumpPage(tester);
    await openFilterSheet(tester);

    await tester.tap(find.byKey(const ValueKey('filter-type-income')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('filter-source-saving')));
    await tester.pump();
    await applyFilter(tester);

    expect(find.byType(TransactionTile), findsNothing);
    expect(
      find.text('Tidak ada transaksi yang cocok dengan filter ini.'),
      findsOneWidget,
    );
    await unmountPage(tester);
  });

  testWidgets('filter kategori memilih kategori aktif', (tester) async {
    await pumpPage(tester);
    await openFilterSheet(tester);

    await tester.tap(find.byKey(const ValueKey('filter-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gaji').last);
    await tester.pumpAndSettle();
    await applyFilter(tester);

    expect(find.byType(TransactionTile), findsOneWidget);
    expect(find.text('Gaji Bulan Ini'), findsOneWidget);
    expect(find.text('Filter (1)'), findsOneWidget);
    await unmountPage(tester);
  });
}

Future<int> _categoryId(AppDatabase db, String name) async {
  final row = await (db.select(db.categories)
        ..where((c) => c.name.equals(name)))
      .getSingle();
  return row.id;
}
