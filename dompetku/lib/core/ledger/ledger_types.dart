/// String konstan untuk kolom bertipe enum di database.
/// Disimpan sebagai TEXT agar mudah dibaca saat inspeksi SQLite.
class TxType {
  static const income = 'INCOME';
  static const expense = 'EXPENSE';
}

class RefType {
  static const saving = 'SAVING';
  static const debt = 'DEBT';
}

/// Sumber transaksi untuk filter. [manual] bukan nilai kolom database:
/// transaksi manual ditandai dengan `reference_type IS NULL`.
class TxSource {
  static const manual = 'MANUAL';
  static const saving = RefType.saving;
  static const debt = RefType.debt;
}

class DebtType {
  static const payable = 'PAYABLE';
  static const receivable = 'RECEIVABLE';
}

class SavingAction {
  static const deposit = 'DEPOSIT';
  static const withdraw = 'WITHDRAW';
}

class CategoryCodes {
  static const initialBalance = 'INITIAL_BALANCE';
  static const adjustment = 'ADJUSTMENT';
  static const savingDeposit = 'SAVING_DEPOSIT';
  static const savingWithdraw = 'SAVING_WITHDRAW';
  static const debtDisbursement = 'DEBT_DISBURSEMENT';
  static const debtPayment = 'DEBT_PAYMENT';
  static const receivableDisbursement = 'RECEIVABLE_DISBURSEMENT';
  static const receivableRepayment = 'RECEIVABLE_REPAYMENT';
}
