import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'glassmorphism.dart';

/// Gastuen dashboard txiki bat erakusten duen widget-a: pie chart, legenda eta transakzioak.
///
/// Helburua: hileroko gastuen banaketa eta azken transakzioak bistaratzea,
/// demo moduan 'saldatu' aukerarekin interakzioa ahalbidetuz.
class ExpenseDashboard extends StatelessWidget {
  const ExpenseDashboard({super.key});

  static const List<_ExpenseSlice> _slices = [
    _ExpenseSlice('Alquiler', 780, Color(0xFF10B981)),
    _ExpenseSlice('Suministros', 126, Color(0xFF22D3EE)),
    _ExpenseSlice('Internet', 42, Color(0xFF94A3B8)),
    _ExpenseSlice('Comida', 238, Color(0xFFA7F3D0)),
  ];

  static const List<_TransactionItem> _transactions = [
    _TransactionItem('rent_may', 'Alquiler mayo', 'Pendiente con Lucia', 260),
    _TransactionItem('fiber', 'Internet fibra', 'Pagado por Daniel', 14),
    _TransactionItem('groceries', 'Compra semanal', 'Compartido entre 3', 79),
  ];

  @override
  Widget build(BuildContext context) {
    final total = _slices.fold<double>(0, (sum, item) => sum + item.amount);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final secondaryText =
        isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    final allSettled = true;
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      borderRadius: 26,
      opacity: isDark ? 0.08 : 0.16,
      glowColor: AppTheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: isDark ? 0.28 : 0.16),
                      blurRadius: 22,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.donut_large_rounded,
                  color: AppTheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gastos del mes',
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Distribucion de Mi Casa',
                      style: TextStyle(color: secondaryText, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Text(
                '${total.toStringAsFixed(0)} EUR',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 188,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          centerSpaceRadius: 52,
                          sectionsSpace: 3,
                          startDegreeOffset: -90,
                          borderData: FlBorderData(show: false),
                          sections: _slices.map((slice) {
                            return PieChartSectionData(
                              value: slice.amount,
                              color: slice.color,
                              radius: 22,
                              showTitle: false,
                            );
                          }).toList(growable: false),
                        ),
                      ),
                      // Pie chart eta erdiko total balioa elkarren gainean jartzen dira.
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${total.toStringAsFixed(0)} EUR',
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Total',
                            style: TextStyle(color: secondaryText, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _slices
                        .map((slice) => _LegendRow(slice: slice, total: total))
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Transacciones recientes',
            style: TextStyle(
              color: primaryText,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ..._transactions.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TransactionRow(
                item: item,
                settled: settledExpenses.contains(item.id),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: allSettled ? null : () {},
              icon: Icon(
                allSettled
                    ? Icons.check_circle_rounded
                    : Icons.payments_rounded,
                size: 18,
              ),
              label: Text(allSettled ? 'Deuda saldada' : 'Saldar deuda'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pie chart-eko kolore bakoitzerako legenda errenkada bat.
///
/// Parametroak:
/// - `slice`: Kolore eta label informazioa duen _ExpenseSlice.
/// - `total`: Guztira kalkulatutako soma, ehunekoa kalkulatzeko erabiltzen da.
class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice, required this.total});

  final _ExpenseSlice slice;
  final double total;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final percent = (slice.amount / total * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              slice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$percent%',
            style: TextStyle(
              color: AppTheme.primary.withValues(alpha: isDark ? 0.95 : 0.86),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Transakzio bakunaren errenkada: informazioa eta egoera (saldatuta ala ez).
///
/// Parametroak:
/// - `item`: _TransactionItem objetua (id, title, subtitle, amount).
/// - `settled`: Boolean adierazten du transakzioa saldatu den edo ez.
class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.item, required this.settled});

  final _TransactionItem item;
  final bool settled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final secondaryText =
        isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.52),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.64),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: isDark ? 0.12 : 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppTheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // Testu desberdina erakutsi saldatu egoeraren arabera.
                  settled ? 'Saldado en demo offline' : item.subtitle,
                  style: TextStyle(color: secondaryText, fontSize: 12),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: AppTheme.motionFast,
            child: settled
                ? const Icon(
                    Icons.check_circle_rounded,
                    key: ValueKey<String>('settled'),
                    color: AppTheme.primary,
                  )
                : Text(
                    '${item.amount.toStringAsFixed(0)} EUR',
                    key: const ValueKey<String>('amount'),
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseSlice {
  const _ExpenseSlice(this.label, this.amount, this.color);

  final String label;
  final double amount;
  final Color color;
}

class _TransactionItem {
  const _TransactionItem(this.id, this.title, this.subtitle, this.amount);

  final String id;
  final String title;
  final String subtitle;
  final double amount;
}
