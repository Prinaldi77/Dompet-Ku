import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

const _darkSlices = [
  Color(0xFF0F766E),
  Color(0xFF0EA5E9),
  Color(0xFFF59E0B),
  Color(0xFF6366F1),
  Color(0xFFEC4899),
  Color(0xFF8B5CF6),
  Color(0xFF22C55E),
  Color(0xFF94A3B8),
];

const _lightSlices = [
  Color(0xFF2DD4BF),
  Color(0xFF38BDF8),
  Color(0xFFFBBF24),
  Color(0xFF818CF8),
  Color(0xFFF472B6),
  Color(0xFFA78BFA),
  Color(0xFF4ADE80),
  Color(0xFFCBD5E1),
];

class ExpenseBreakdownCard extends StatelessWidget {
  const ExpenseBreakdownCard({
    super.key,
    required this.entries,
    required this.periodLabel,
  });

  final List<CategorySpend> entries;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.amount);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pengeluaran per Kategori',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      periodLabel,
                      style: TextStyle(fontSize: 11.5, color: p.muted),
                    ),
                  ],
                ),
              ),
              Text(
                formatRupiah(total),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: [
                  Icon(Icons.pie_chart_outline_rounded, color: p.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Belum ada pengeluaran pada bulan ini.',
                      style: TextStyle(fontSize: 12.5, color: p.muted),
                    ),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final chart = SizedBox(
                  width: 132,
                  height: 132,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 38,
                      startDegreeOffset: -90,
                      sections: _sections(context, total),
                    ),
                    duration: const Duration(milliseconds: 350),
                  ),
                );
                final legend = _Legend(
                  entries: entries,
                  total: total,
                  colors: _sliceColors(context),
                );

                if (constraints.maxWidth < 330) {
                  return Column(
                    children: [
                      Center(child: chart),
                      const SizedBox(height: 16),
                      legend,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    chart,
                    const SizedBox(width: 16),
                    Expanded(child: legend),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  List<Color> _sliceColors(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? _lightSlices
          : _darkSlices;

  List<PieChartSectionData> _sections(BuildContext context, int total) {
    final colors = _sliceColors(context);
    return [
      for (var i = 0; i < entries.length; i++)
        PieChartSectionData(
          value: entries[i].amount.toDouble(),
          color: colors[i % colors.length],
          radius: 18,
          showTitle: false,
        ),
    ];
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.entries,
    required this.total,
    required this.colors,
  });

  final List<CategorySpend> entries;
  final int total;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final visible = entries.take(5).toList();
    final restTotal = entries
        .skip(5)
        .fold<int>(0, (sum, entry) => sum + entry.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < visible.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors[i % colors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    visible[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${(visible[i].amount / total * 100).round()}%',
                  style: TextStyle(fontSize: 11.5, color: p.muted),
                ),
              ],
            ),
          ),
        if (restTotal > 0)
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colors[visible.length % colors.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Lainnya',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${(restTotal / total * 100).round()}%',
                style: TextStyle(fontSize: 11.5, color: p.muted),
              ),
            ],
          ),
      ],
    );
  }
}
