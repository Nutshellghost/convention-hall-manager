import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_state.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, dynamic>> _monthlyReport = [];
  Map<String, double> _categorySummary = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _loading = true);
    final state = context.read<AppState>();
    _monthlyReport = await state.getMonthlyProfitReport();
    _categorySummary = await state.getExpenseSummaryByCategory();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reports')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReports,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Net Profit Summary Card
            _buildSummaryCard(context),
            const SizedBox(height: 16),

            // Profit Trend Chart
            if (_monthlyReport.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Monthly Profit Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: _buildProfitChart(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLegend(Colors.green, 'Revenue'),
                          const SizedBox(width: 24),
                          _buildLegend(Colors.red, 'Expenses'),
                          const SizedBox(width: 24),
                          _buildLegend(Colors.blue, 'Net Profit'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Expense breakdown by category
            if (_categorySummary.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Expenses by Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: _buildPieChart(),
                      ),
                      const SizedBox(height: 12),
                      ..._categorySummary.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 12, height: 12,
                              decoration: BoxDecoration(
                                color: _getCategoryColor(e.key),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
                            Text(
                              '₹${NumberFormat('#,##0', 'en_IN').format(e.value)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Monthly report table
            if (_monthlyReport.isNotEmpty) ...[
              Text('Monthly Breakdown', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._monthlyReport.map((r) => _buildMonthlyRow(r)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    double totalRevenue = 0, totalExpenses = 0;
    for (var r in _monthlyReport) {
      totalRevenue += (r['total_payments'] as num).toDouble();
      totalExpenses += (r['total_expenses'] as num).toDouble();
    }
    final netProfit = totalRevenue - totalExpenses;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatItem('Total Revenue', '₹${NumberFormat('#,##0', 'en_IN').format(totalRevenue)}', Colors.green),
                ),
                Container(width: 1, height: 40, color: Colors.grey[200]),
                Expanded(
                  child: _buildStatItem('Total Expenses', '₹${NumberFormat('#,##0', 'en_IN').format(totalExpenses)}', Colors.red),
                ),
                Container(width: 1, height: 40, color: Colors.grey[200]),
                Expanded(
                  child: _buildStatItem('Net Profit', '₹${NumberFormat('#,##0', 'en_IN').format(netProfit)}', netProfit >= 0 ? Colors.blue : Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      ],
    );
  }

  Widget _buildProfitChart() {
    if (_monthlyReport.isEmpty) return const SizedBox();

    final reversed = _monthlyReport.reversed.toList();
    final maxVal = reversed.fold<double>(0, (max, r) {
      final pm = (r['total_payments'] as num).toDouble();
      final ex = (r['total_expenses'] as num).toDouble();
      return [max, pm, ex].reduce((a, b) => a > b ? a : b);
    });

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.2,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= reversed.length) return const SizedBox();
                final month = reversed[idx]['month'] as String;
                final parts = month.split('-');
                final months = ['', 'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
                return Text(months[int.parse(parts[1])], style: const TextStyle(fontSize: 10));
              },
              reservedSize: 20,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text('₹${(value / 1000).toInt()}k', style: const TextStyle(fontSize: 9));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: maxVal / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.15),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(reversed.length, (i) {
          final r = reversed[i];
          final payments = (r['total_payments'] as num).toDouble();
          final expenses = (r['total_expenses'] as num).toDouble();
          final profit = payments - expenses;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: payments,
                color: Colors.green.withOpacity(0.7),
                width: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: expenses,
                color: Colors.red.withOpacity(0.7),
                width: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: profit < 0 ? 0 : profit,
                color: Colors.blue.withOpacity(0.7),
                width: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPieChart() {
    final total = _categorySummary.values.fold<double>(0, (a, b) => a + b);
    final colors = [
      Colors.amber, Colors.blue, Colors.brown, Colors.teal,
      Colors.cyan, Colors.pink, Colors.orange, Colors.indigo,
      Colors.deepOrange, Colors.lime, Colors.purple, Colors.grey,
    ];

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 30,
        sections: _categorySummary.entries.toList().asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final percentage = (e.value / total * 100);
          return PieChartSectionData(
            color: colors[i % colors.length],
            value: e.value,
            title: '${percentage.toStringAsFixed(0)}%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthlyRow(Map<String, dynamic> report) {
    final month = report['month'] as String;
    final parts = month.split('-');
    final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthName = months[int.parse(parts[1])];
    final year = parts[0];
    final payments = (report['total_payments'] as num).toDouble();
    final expenses = (report['total_expenses'] as num).toDouble();
    final profit = (report['net_profit'] as num).toDouble();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(monthName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(year, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('+₹${NumberFormat('#,##0', 'en_IN').format(payments)}', style: const TextStyle(color: Colors.green, fontSize: 12)),
                  Text('-₹${NumberFormat('#,##0', 'en_IN').format(expenses)}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: profit >= 0
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '₹${NumberFormat('#,##0', 'en_IN').format(profit)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: profit >= 0 ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Electricity': return Colors.amber;
      case 'Water': return Colors.blue;
      case 'Maintenance': return Colors.brown;
      case 'Staff Salary': return Colors.teal;
      case 'Cleaning': return Colors.cyan;
      case 'Decoration': return Colors.pink;
      case 'Catering': return Colors.orange;
      case 'Security': return Colors.indigo;
      case 'Renovation': return Colors.deepOrange;
      case 'Transport': return Colors.lime;
      case 'Insurance': return Colors.purple;
      default: return Colors.grey;
    }
  }
}
