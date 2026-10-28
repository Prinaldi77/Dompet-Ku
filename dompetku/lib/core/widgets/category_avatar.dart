import 'package:flutter/material.dart';

import '../../core/ledger/ledger_types.dart';
import '../../core/theme/app_theme.dart';

const Map<String, IconData> _categoryIcons = {
  'account_balance_wallet': Icons.account_balance_wallet_rounded,
  'account_balance': Icons.account_balance_rounded,
  'tune': Icons.tune_rounded,
  'savings': Icons.savings_rounded,
  'credit_card': Icons.credit_card_rounded,
  'handshake': Icons.handshake_rounded,
  'payments': Icons.payments_rounded,
  'trending_up': Icons.trending_up_rounded,
  'trending_down': Icons.trending_down_rounded,
  'restaurant': Icons.restaurant_rounded,
  'directions_car': Icons.directions_car_rounded,
  'shopping_bag': Icons.shopping_bag_rounded,
  'receipt_long': Icons.receipt_long_rounded,
  'movie': Icons.movie_rounded,
  'category': Icons.category_rounded,
};

IconData iconForCategory(String icon) =>
    _categoryIcons[icon] ?? Icons.category_rounded;

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    super.key,
    required this.icon,
    required this.tipe,
    this.size = 42,
  });

  final String icon;
  final String tipe;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (background, foreground) = switch (tipe) {
      TxType.income => (p.incomeTint, p.income),
      TxType.expense => (p.expenseTint, p.expense),
      _ => (p.emeraldSoft, p.emerald),
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(
        iconForCategory(icon),
        size: size * 0.5,
        color: foreground,
      ),
    );
  }
}
