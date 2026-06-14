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
                    SizedBox(
                      width: 100,
                      child: Text(
                        '₹${_currencyFormat.format(amount)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                          fontSize: 13,
                        ),
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
                    SizedBox(
                      width: 100,
                      child: Text(
                        '₹${_currencyFormat.format(d.amount)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.purple,
                          fontSize: 13,
                        ),
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
                    SizedBox(
                      width: 100,
                      child: Text(
                        '₹${_currencyFormat.format(e.amount)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                          fontSize: 13,
                        ),
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
    final pdf = pw.Document();
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);
    final formatter = NumberFormat('#,##0.00', 'en_IN');

    // Helper to build amount text
    String fmt(num v) => '₹${formatter.format(v)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Text(
              'Kusetty Convention Hall',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Monthly Report — $monthLabel',
            style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 24),

          // === Income Section ===
          if (_paymentsWithBookings.isNotEmpty) ...[
            pw.Header(level: 1, text: 'Income (Payments)'),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Customer', 'Event Type', 'Payment Type', 'Amount'],
              data: _paymentsWithBookings.map((p) {
                final bookings = p['bookings'] as Map<String, dynamic>?;
                final date = p['date'] as String? ?? '-';
                final customer = bookings?['customer_name'] as String? ?? 'Unknown';
                final event = bookings?['event_type'] as String? ?? '-';
                final payType = p['type'] as String? ?? '-';
                final amount = (p['amount'] as num).toDouble();
                return [date, customer, event, payType, fmt(amount)];
              }).toList(),
              border: pw.TableBorder.all(
                color: PdfColors.grey300, width: 0.5,
              ),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total Income (Payments): ${fmt(_paymentsWithBookings.fold<double>(0, (s, p) => s + (p['amount'] as num).toDouble()))}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                  color: PdfColors.green700,
                ),
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // === Decoration Charges ===
          if (_decorationCharges.isNotEmpty) ...[
            pw.Header(level: 1, text: 'Decoration Charges'),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Customer', 'Amount'],
              data: _decorationCharges.map((d) {
                final ds = DateFormat('yyyy-MM-dd').format(d.date);
                return [ds, d.customerName, fmt(d.amount)];
              }).toList(),
              border: pw.TableBorder.all(
                color: PdfColors.grey300, width: 0.5,
              ),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: PdfColors.purple800),
              cellStyle: pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total Decoration Charges: ${fmt(_decorationCharges.fold<double>(0, (s, d) => s + d.amount))}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                  color: PdfColors.purple700,
                ),
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // === Expenses Section ===
          if (_expenses.isNotEmpty) ...[
            pw.Header(level: 1, text: 'Expenses'),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Category', 'Description', 'Amount'],
              data: _expenses.map((e) {
                final ds = DateFormat('yyyy-MM-dd').format(e.date);
                return [ds, e.category, e.description, fmt(e.amount)];
              }).toList(),
              border: pw.TableBorder.all(
                color: PdfColors.grey300, width: 0.5,
              ),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: PdfColors.red800),
              cellStyle: pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Total Expenses: ${fmt(_totalExpenses)}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                  color: PdfColors.red700,
                ),
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // === Summary ===
          pw.Header(level: 1, text: 'Summary'),
          pw.SizedBox(height: 8),
          _summaryRow('Total Income (Payments + Decorations)', _totalIncome),
          _summaryRow('Total Expenses', _totalExpenses, color: PdfColors.red),
          pw.Divider(),
          _summaryRow('Net Profit', _netProfit,
              color: _netProfit >= 0 ? PdfColors.green : PdfColors.red,
              bold: true),
          pw.SizedBox(height: 20),

          // === Profit Sharing ===
          pw.Header(level: 1, text: 'Profit Sharing (50 / 50)'),
          pw.SizedBox(height: 8),
          _summaryRow('Raja Gopal (50%)', _netProfit / 2,
              color: PdfColors.blue700, bold: true),
          _summaryRow('Guru Prasad (50%)', _netProfit / 2,
              color: PdfColors.teal700, bold: true),
        ],
      ),
    );

    // Save and share
    final dir = await getTemporaryDirectory();
    final fileName =
        'Kusetty_Report_${_selectedMonth.year}_${_selectedMonth.month.toString().padLeft(2, '0')}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Kusetty Convention Hall — $monthLabel Report',
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
