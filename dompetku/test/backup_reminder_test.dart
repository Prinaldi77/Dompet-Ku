import 'package:dompetku/core/backup/backup_reminder.dart';
import 'package:dompetku/core/database/app_database.dart';
import 'package:dompetku/core/ledger/ledger_service.dart';
import 'package:dompetku/core/ledger/ledger_types.dart';
import 'package:dompetku/core/providers/app_providers.dart';
import 'package:dompetku/core/theme/app_theme.dart';
import 'package:dompetku/features/dashboard/dashboard_page.dart';
import 'package:dompetku/features/settings/settings_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime(2026, 10, 27, 12);
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

  Future<void> unmount(WidgetTester tester) async {
    await tester.runAsync(db.close);
    dbClosed = true;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          ...overrides,
        ],
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('shouldRemindBackup', () {
    test('tidak tampil saat transaksi kurang dari 20', () {
      expect(
        shouldRemindBackup(
          transactionCount: 19,
          lastBackupAt: now.subtract(const Duration(days: 60)),
          firstOpenAt: now.subtract(const Duration(days: 60)),
          now: now,
        ),
        isFalse,
      );
    });

    test('tampil saat belum pernah backup lebih dari 30 hari', () {
      expect(
        shouldRemindBackup(
          transactionCount: 20,
          lastBackupAt: null,
          firstOpenAt: now.subtract(const Duration(days: 31)),
          now: now,
        ),
        isTrue,
      );
    });

    test('tidak tampil tepat 30 hari', () {
      expect(
        shouldRemindBackup(
          transactionCount: 20,
          lastBackupAt: now.subtract(const Duration(days: 30)),
          firstOpenAt: now.subtract(const Duration(days: 90)),
          now: now,
        ),
        isFalse,
      );
    });

    test('tampil saat backup terakhir lebih dari 30 hari', () {
      expect(
        shouldRemindBackup(
          transactionCount: 50,
          lastBackupAt: now.subtract(const Duration(days: 31)),
          firstOpenAt: now.subtract(const Duration(days: 90)),
          now: now,
        ),
        isTrue,
      );
    });

    test('tidak tampil saat baru saja backup', () {
      expect(
        shouldRemindBackup(
          transactionCount: 50,
          lastBackupAt: now.subtract(const Duration(days: 3)),
          firstOpenAt: now.subtract(const Duration(days: 90)),
          now: now,
        ),
        isFalse,
      );
    });
  });

  test('menyimpan dan membaca waktu backup terakhir', () async {
    expect(await loadLastBackupAt(), isNull);

    final saved = await saveBackupTimestamp();
    final loaded = await loadLastBackupAt();

    expect(loaded, isNotNull);
    expect(loaded!.difference(saved).inSeconds, 0);
  });

  test('acuan first open hanya dibuat sekali', () async {
    final first = await loadOrCreateFirstOpenAt();
    final second = await loadOrCreateFirstOpenAt();

    expect(second, first);
  });

  test('watchTransactionCount mengikuti jumlah transaksi', () async {
    expect(await db.watchTransactionCount().first, 0);

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

    expect(await db.watchTransactionCount().first, 1);
  });

  testWidgets('dashboard menampilkan kartu pengingat backup', (tester) async {
    await pumpPage(
      tester,
      const DashboardPage(),
      overrides: [backupReminderProvider.overrideWithValue(true)],
    );

    expect(find.text('Waktunya backup data'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('backup-reminder-action')),
      findsOneWidget,
    );

    await unmount(tester);
  });

  testWidgets('dashboard menyembunyikan pengingat saat tidak diperlukan',
      (tester) async {
    await pumpPage(
      tester,
      const DashboardPage(),
      overrides: [backupReminderProvider.overrideWithValue(false)],
    );

    expect(find.text('Waktunya backup data'), findsNothing);

    await unmount(tester);
  });

  testWidgets('pengaturan menampilkan tanggal backup terakhir', (tester) async {
    await pumpPage(
      tester,
      const SettingsPage(),
      overrides: [
        lastBackupAtProvider.overrideWith((ref) => DateTime(2026, 10, 20)),
      ],
    );

    expect(find.text('Terakhir 20 Okt 2026'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('pengaturan menampilkan status belum pernah backup',
      (tester) async {
    await pumpPage(tester, const SettingsPage());

    expect(
      find.text('Belum pernah backup · simpan salinan .sqlite'),
      findsOneWidget,
    );

    await unmount(tester);
  });
}
