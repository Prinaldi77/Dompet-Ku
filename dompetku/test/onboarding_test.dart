import 'package:dompetku/core/database/app_database.dart';
import 'package:dompetku/core/ledger/ledger_service.dart';
import 'package:dompetku/core/ledger/ledger_types.dart';
import 'package:dompetku/core/onboarding/onboarding_prefs.dart';
import 'package:dompetku/core/providers/app_providers.dart';
import 'package:dompetku/core/theme/app_theme.dart';
import 'package:dompetku/features/dashboard/dashboard_page.dart';
import 'package:dompetku/features/onboarding/onboarding_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late bool dbClosed;

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dbClosed = false;
  });

  tearDown(() async {
    if (!dbClosed) await db.close();
  });

  Future<void> pumpOnboarding(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingPage(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const Scaffold(body: Text('Dashboard')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          theme: buildAppTheme(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> advanceToBalanceStep(WidgetTester tester) async {
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mulai'));
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.runAsync(db.close);
    dbClosed = true;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  test('hasAnyTransaction mengikuti isi database', () async {
    expect(await db.hasAnyTransaction(), isFalse);
    expect(await db.watchHasAnyTransaction().first, isFalse);

    final category = await (db.select(db.categories)
          ..where((c) => c.name.equals('Belanja')))
        .getSingle();
    await LedgerService(db).addManualTransaction(
      title: 'Makan siang',
      amount: 25000,
      type: TxType.expense,
      categoryId: category.id,
      date: DateTime(2026, 10, 20),
    );

    expect(await db.hasAnyTransaction(), isTrue);
    expect(await db.watchHasAnyTransaction().first, isTrue);
  });

  testWidgets('DB kosong menampilkan langkah saldo awal dan menyimpannya',
      (tester) async {
    await pumpOnboarding(tester);
    await advanceToBalanceStep(tester);

    expect(find.text('Berapa saldo awal Anda?'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('initial-balance-field')),
      '1.500.000',
    );
    await tester.tap(find.text('Simpan & Mulai'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(await loadOnboardingDone(), isTrue);

    final rows = await db.select(db.transactions).get();
    expect(rows, hasLength(1));
    final tx = rows.single;
    expect(tx.title, 'Saldo Awal');
    expect(tx.type, TxType.income);
    expect(tx.referenceType, isNull);
    expect(tx.amount, 1500000);

    final category = await (db.select(db.categories)
          ..where((c) => c.id.equals(tx.categoryId)))
        .getSingle();
    expect(category.code, CategoryCodes.initialBalance);

    await unmount(tester);
  });

  testWidgets('langkah saldo awal bisa dilewati', (tester) async {
    await pumpOnboarding(tester);
    await advanceToBalanceStep(tester);

    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(await loadOnboardingDone(), isTrue);
    expect(await db.select(db.transactions).get(), isEmpty);

    await unmount(tester);
  });

  testWidgets('Lewati di intro tetap menampilkan langkah saldo awal',
      (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();

    expect(find.text('Berapa saldo awal Anda?'), findsOneWidget);
    expect(await loadOnboardingDone(), isFalse);
    expect(await db.select(db.transactions).get(), isEmpty);

    await unmount(tester);
  });

  testWidgets('nominal kosong ditolak dan tetap di langkah saldo awal',
      (tester) async {
    await pumpOnboarding(tester);
    await advanceToBalanceStep(tester);

    await tester.tap(find.text('Simpan & Mulai'));
    await tester.pumpAndSettle();

    expect(find.text('Nominal harus lebih dari nol.'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
    expect(await db.select(db.transactions).get(), isEmpty);

    await unmount(tester);
  });

  testWidgets('DB yang sudah berisi transaksi melewati langkah saldo awal',
      (tester) async {
    final salary = await (db.select(db.categories)
          ..where((c) => c.name.equals('Gaji')))
        .getSingle();
    await LedgerService(db).addManualTransaction(
      title: 'Gaji lama',
      amount: 300000,
      type: TxType.income,
      categoryId: salary.id,
      date: DateTime(2026, 10, 1),
    );

    await pumpOnboarding(tester);
    await advanceToBalanceStep(tester);

    expect(find.text('Berapa saldo awal Anda?'), findsNothing);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(await db.select(db.transactions).get(), hasLength(1));

    await unmount(tester);
  });

  testWidgets('kartu Atur Saldo Awal hanya muncul saat DB kosong',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const DashboardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Atur Saldo Awal'), findsOneWidget);

    await tester.runAsync(() => LedgerService(db).setInitialBalance(100000));
    await tester.pumpAndSettle();

    expect(find.text('Atur Saldo Awal'), findsNothing);

    await unmount(tester);
  });
}
