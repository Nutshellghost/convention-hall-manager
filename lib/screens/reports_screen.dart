import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_state.dart';
import '../data/database_helper.dart';
import '../models/payment.dart';
import '../models/expense.dart';
import '../models/decoration_charge.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _currencyFormat = NumberFormat('#,##0.00', 'en_IN');

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  List<Map<String, dynamic>> _paymentsWithBookings = [];
  List<Expense> _expenses = [];
  List<DecorationCharge> _decorationCharges = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMonthDetail());
  }

  Future<void> _loadMonthDetail() async {
    setState(() => _loading = true);
    final db = DatabaseHelper.instance;
    try {
      final results = await Future.wait([
        db.getPaymentsWithBookingDetails(_selectedMonth.year, _selectedMonth.month),
        db.getExpensesForMonth(_selectedMonth.year, _selectedMonth.month),
        db.getDecorationChargesForMonth(_selectedMonth.year, _selectedMonth.month),
      ]);
      if (!mounted) return;
      setState(() {
        _paymentsWithBookings = results[0] as List<Map<String, dynamic>>;
        _expenses = results[1] as List<Expense>;
        _decorationCharges = results[2] as List<DecorationCharge>;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading month detail: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _goToPreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
    _loadMonthDetail();
  }

  void _goToNextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
    _loadMonthDetail();
  }

  double get _totalIncome {
    double t = 0;
    for (final p in _paymentsWithBookings) {
      t += (p['amount'] as num).toDouble();
    }
    for (final d in _decorationCharges) {
      t += d.amount;
    }
    return t;
  }

  double get _totalExpenses {
    double t = 0;
    for (final e in _expenses) {
      t += e.amount;
    }
    return t;
  }

  double get _netProfit => _totalIncome - _totalExpenses;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _loading ? null : _exportPdf,
            tooltip: 'Export PDF',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.red),
            onPressed: _loading ? null : _confirmDeleteAll,
            tooltip: 'Delete All Data',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMonthDetail,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildMonthPicker(),
                  const SizedBox(height: 16),
                  _buildSummaryCard(),
                  const SizedBox(height: 16),
                  _buildIncomeSection(),
                  const SizedBox(height: 16),
                  _buildDecorationSection(),
                  const SizedBox(height: 16),
                  _buildExpensesSection(),
                  const SizedBox(height: 16),
                  _buildProfitSharingCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthPicker() {
    final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _goToPreviousMonth,
        ),
        const SizedBox(width: 16),
        Text(
          monthName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _goToNextMonth,
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                'Total Income',
                '₹${_currencyFormat.format(_totalIncome)}',
                Colors.green,
              ),
            ),
            Container(width: 1, height: 40, color: Colors.grey[300]),
            Expanded(
              child: _buildStatItem(
                'Total Expenses',
                '₹${_currencyFormat.format(_totalExpenses)}',
                Colors.red,
              ),
            ),
            Container(width: 1, height: 40, color: Colors.grey[300]),
            Expanded(
              child: _buildStatItem(
                'Net Profit',
                '₹${_currencyFormat.format(_netProfit)}',
                _netProfit >= 0 ? Colors.blue : Colors.red,
              ),
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
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildIncomeSection() {
    if (_paymentsWithBookings.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No income entries for this month',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Income',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '₹${_currencyFormat.format(_paymentsWithBookings.fold<double>(0, (s, p) => s + (p['amount'] as num).toDouble()))}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const Divider(),
            ..._paymentsWithBookings.map((p) {
              final bookings = p['bookings'] as Map<String, dynamic>?;
              final customerName = bookings?['customer_name'] as String? ?? 'Unknown';
              final eventType = bookings?['event_type'] as String? ?? '-';
              final amount = (p['amount'] as num).toDouble();
              final paymentType = p['type'] as String? ?? '-';
              final dateStr = p['date'] as String? ?? '';
              final date = dateStr.isNotEmpty
                  ? DateFormat('dd MMM').format(DateTime.parse(dateStr))
                  : '-';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            '$eventType • $paymentType',
                            style: TextStyle(color: Colors.grey[600], fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(date, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(width: 12),
                    Text(
                      '₹${_currencyFormat.format(amount)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDecorationSection() {
    if (_decorationCharges.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No decoration charges for this month',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.brush, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Decoration Charges',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '₹${_currencyFormat.format(_decorationCharges.fold<double>(0, (s, d) => s + d.amount))}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const Divider(),
            ..._decorationCharges.map((d) {
              final dateStr = DateFormat('dd MMM').format(d.date);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        d.customerName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    Text(dateStr, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(width: 12),
                    Text(
                      '₹${_currencyFormat.format(d.amount)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.purple,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesSection() {
    if (_expenses.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No expenses for this month',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_cart, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Expenses',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '₹${_currencyFormat.format(_totalExpenses)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(),
            ..._expenses.map((e) {
              final dateStr = DateFormat('dd MMM').format(e.date);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.category,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            e.description,
                            style: TextStyle(color: Colors.grey[600], fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(dateStr, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(width: 12),
                    Text(
                      '₹${_currencyFormat.format(e.amount)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitSharingCard() {
    final half = _netProfit / 2;
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.teal.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Profit Sharing (50/50)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.person, color: Colors.blue.shade700, size: 28),
                      const SizedBox(height: 4),
                      const Text(
                        'Raja Gopal',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${_currencyFormat.format(half)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: Colors.grey[300],
                ),
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.person, color: Colors.teal.shade700, size: 28),
                      const SizedBox(height: 4),
                      const Text(
                        'Guru Prasad',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${_currencyFormat.format(half)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===== PDF EXPORT =====

  Future<void> _exportPdf() async {
    // Show loading
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Generating PDF...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final pdf = pw.Document();
      final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);
      final shortMonth = DateFormat('MMM yyyy').format(_selectedMonth);
      final formatter = NumberFormat('#,##0.00', 'en_IN');

      String fmt(num v) => '₹${formatter.format(v)}';

      // Compute payment method breakdown
      final methodTotals = <String, double>{};
      for (final p in _paymentsWithBookings) {
        final method = p['payment_method'] as String? ?? 'cash';
        methodTotals[method] = (methodTotals[method] ?? 0) + (p['amount'] as num).toDouble();
      }

      // Total decoration charges
      final decorationTotal = _decorationCharges.fold<double>(0, (s, d) => s + d.amount);
      final grandIncome = _totalIncome;
      final netProfit = _netProfit;
      final half = netProfit / 2;
      final totalTransactions = _paymentsWithBookings.length + _expenses.length + _decorationCharges.length;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (pw.Context ctx) {
            if (ctx.pageNumber == 1) return pw.SizedBox();
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Kusetty Convention Hall — $shortMonth | Page ${ctx.pageNumber}',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
              ),
            );
          },
          footer: (pw.Context ctx) => pw.Container(
            padding: const pw.EdgeInsets.only(top: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Kusetty Convention Hall',
                  style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Generated ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                ),
              ],
            ),
          ),
          build: (pw.Context ctx) => [
            // ===== COVER / HEADER =====
            pw.Container(
              padding: const pw.EdgeInsets.fromLTRB(0, 16, 0, 20),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.purple300, width: 2),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Kusetty Convention Hall',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.purple800,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Monthly Report — $monthLabel',
                    style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      _metaBadge('Transactions', '$totalTransactions'),
                      pw.SizedBox(width: 16),
                      _metaBadge('Report', shortMonth),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // ===== EXECUTIVE SUMMARY (always visible) =====
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Executive Summary',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.purple800,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  _summaryRow('Total Income (Payments + Decoration)', grandIncome,
                      color: PdfColors.green700),
                  _summaryRow('Total Expenses', _totalExpenses, color: PdfColors.red700),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                  _summaryRow('Net Profit', netProfit,
                      color: netProfit >= 0 ? PdfColors.blue700 : PdfColors.red700,
                      bold: true),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // ===== INCOME SECTION =====
            if (_paymentsWithBookings.isNotEmpty) ...[
              _sectionTitle('Income — Payments Received'),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Customer', 'Event', 'Type', 'Method', 'Amount'],
                data: _paymentsWithBookings.map((p) {
                  final bookings = p['bookings'] as Map<String, dynamic>?;
                  final rawDate = p['date'] as String? ?? '';
                  final date = rawDate.length >= 10 ? rawDate.substring(5) : rawDate;
                  final customer = bookings?['customer_name'] as String? ?? 'Unknown';
                  final event = bookings?['event_type'] as String? ?? '-';
                  final payType = (p['type'] as String? ?? '').toUpperCase();
                  final method = p['payment_method'] as String? ?? 'cash';
                  return [date, customer, event, payType, method.toUpperCase(), fmt((p['amount'] as num).toDouble())];
                }).toList(),
                border: null,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
                cellStyle: pw.TextStyle(fontSize: 8),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.6),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(1.0),
                  3: const pw.FlexColumnWidth(0.6),
                  4: const pw.FlexColumnWidth(0.6),
                  5: const pw.FlexColumnWidth(0.8),
                },
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
                  5: pw.Alignment.centerRight,
                },
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Subtotal: ${fmt(_paymentsWithBookings.fold<double>(0, (s, p) => s + (p['amount'] as num).toDouble()))}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.green700),
                ),
              ),
              pw.SizedBox(height: 16),
            ],
            if (methodTotals.isNotEmpty) ...[
              _sectionTitle('Payment Method Breakdown'),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Method', 'Total', 'Percentage'],
                data: methodTotals.entries.map((e) {
                  final pct = grandIncome > 0 ? (e.value / grandIncome * 100) : 0;
                  return [
                    e.key[0].toUpperCase() + e.key.substring(1),
                    fmt(e.value),
                    '${pct.toStringAsFixed(1)}%',
                  ];
                }).toList(),
                border: null,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
                cellStyle: pw.TextStyle(fontSize: 9),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                },
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.center,
                },
              ),
              pw.SizedBox(height: 16),
            ],

            // ===== DECORATION CHARGES =====
            if (_decorationCharges.isNotEmpty) ...[
              _sectionTitle('Decoration Charges'),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Customer', 'Amount'],
                data: _decorationCharges.map((d) {
                  return [DateFormat('dd MMM').format(d.date), d.customerName, fmt(d.amount)];
                }).toList(),
                border: null,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.purple700),
                cellStyle: pw.TextStyle(fontSize: 9),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.6),
                  1: const pw.FlexColumnWidth(1.6),
                  2: const pw.FlexColumnWidth(0.8),
                },
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                },
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Subtotal: ${fmt(decorationTotal)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.purple700),
                ),
              ),
              pw.SizedBox(height: 16),
            ],

            // ===== EXPENSES SECTION =====
            if (_expenses.isNotEmpty) ...[
              _sectionTitle('Expenses'),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Category', 'Description', 'Amount'],
                data: _expenses.map((e) {
                  return [DateFormat('dd MMM').format(e.date), e.category, e.description, fmt(e.amount)];
                }).toList(),
                border: null,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.red800),
                cellStyle: pw.TextStyle(fontSize: 9),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.6),
                  1: const pw.FlexColumnWidth(0.8),
                  2: const pw.FlexColumnWidth(1.4),
                  3: const pw.FlexColumnWidth(0.8),
                },
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight,
                },
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Subtotal: ${fmt(_totalExpenses)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.red700),
                ),
              ),
              pw.SizedBox(height: 16),
            ],

            // ===== EMPTY STATE NOTE =====
            if (totalTransactions == 0) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(24),
                child: pw.Center(
                  child: pw.Text(
                    'No transactions recorded for this month.',
                    style: pw.TextStyle(color: PdfColors.grey500, fontSize: 12),
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
            ],

            // ===== PROFIT SHARING ====
            pw.SizedBox(height: 8),
            _sectionTitle('Profit Sharing (50 / 50)'),
            pw.SizedBox(height: 12),

            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.purple300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text('Raja Gopal', style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blue700,
                          )),
                          pw.SizedBox(height: 4),
                          pw.Text(fmt(half), style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.blue700,
                          )),
                        ],
                      ),
                      pw.Container(
                        width: 1, height: 40, color: PdfColors.purple200,
                      ),
                      pw.Column(
                        children: [
                          pw.Text('Guru Prasad', style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.teal700,
                          )),
                          pw.SizedBox(height: 4),
                          pw.Text(fmt(half), style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.teal700,
                          )),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Signature: ___________________', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Signature: ___________________', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      // Save to app documents (persistent storage)
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'Kusetty_Report_${_selectedMonth.year}_${_selectedMonth.month.toString().padLeft(2, '0')}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Share
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Kusetty Convention Hall — $monthLabel Report',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF Error: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
      );
    }
  }

  pw.Widget _metaBadge(String label, String value) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Text(
            '$label: $value',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
      ],
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Delete All Data?'),
          ],
        ),
        content: const Text(
          'This will permanently delete ALL bookings, payments, expenses, and decoration charges from the cloud database.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final state = context.read<AppState>();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Deleting all data...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      await state.deleteAllData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data deleted successfully'), backgroundColor: Colors.green),
      );
      _loadMonthDetail();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting data: $e'), backgroundColor: Colors.red),
      );
    }
  }

  pw.Widget _summaryRow(String label, double amount,
      {PdfColor? color, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            '₹${_currencyFormat.format(amount)}',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
