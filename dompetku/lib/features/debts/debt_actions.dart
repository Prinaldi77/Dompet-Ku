import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/ledger/ledger_service.dart';
import '../../core/ledger/ledger_types.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/dialogs.dart';

String debtTypeLabel(String type) =>
    type == DebtType.payable ? 'Hutang saya' : 'Piutang saya';

String debtActionLabel(String type) =>
    type == DebtType.payable ? 'Bayar' : 'Tagih';

Future<void> showDebtPaymentDialog(
  BuildContext context,
  WidgetRef ref,
  Debt debt,
) async {
  final ledger = ref.read(ledgerServiceProvider);
  final remaining = debt.totalAmount - debt.paidAmount;
  final isPayable = debt.type == DebtType.payable;

  await showDialog<bool>(
    context: context,
    builder: (_) => AmountDialog(
      title: isPayable ? 'Bayar Hutang' : 'Terima Cicilan',
      description:
          'Sisa ${formatRupiah(remaining)}. Nominal akan langsung '
          '${isPayable ? 'memotong' : 'menambah'} Saldo Utama.',
      initialAmount: remaining,
      confirmLabel: isPayable ? 'Bayar' : 'Terima',
      onSubmit: (amount) async {
        try {
          await ledger.payDebt(
            debtId: debt.id,
            amount: amount,
            date: DateTime.now(),
          );
        } on InsufficientBalanceException catch (error) {
          if (!context.mounted) rethrow;
          final proceed = await showConfirmDialog(
            context,
            title: 'Saldo tidak mencukupi',
            message:
                'Saldo utama Anda ${formatRupiah(error.available)}. '
                'Melanjutkan akan membuat saldo minus. Tetap bayar '
                '${formatRupiah(amount)}?',
            confirmLabel: 'Tetap Bayar',
          );
          if (!proceed) rethrow;
          await ledger.payDebt(
            debtId: debt.id,
            amount: amount,
            date: DateTime.now(),
            force: true,
          );
        }
      },
    ),
  );
}
