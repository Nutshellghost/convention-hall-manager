import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../providers/app_state.dart';
import '../models/booking.dart';
import '../models/payment.dart';
import 'add_booking_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final int bookingId;

  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Booking? _booking;
  List<Payment> _payments = [];
  double _totalPaid = 0;
  bool _loading = true;
  String? _loadError;
  final _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  /// Loads all booking data in parallel with error handling.
  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        context.read<AppState>().getBooking(widget.bookingId),
        context.read<AppState>().getPaymentsForBooking(widget.bookingId),
        context.read<AppState>().getTotalPaymentsForBooking(widget.bookingId),
      ]);
      if (!mounted) return;
      _booking = results[0] as Booking?;
      _payments = results[1] as List<Payment>;
      _totalPaid = (results[2] as num).toDouble();
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Failed to load: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(_loadError!, textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: const Center(child: Text('Booking not found')),
      );
    }

    final booking = _booking!;
    final balance = booking.totalAmount - _totalPaid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Download Invoice',
            onPressed: () => _generateInvoice(booking),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share on WhatsApp',
            onPressed: () => _shareWhatsApp(booking),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddBookingScreen(booking: booking),
                ),
              ).then((_) => _loadData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteBooking(booking),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Customer info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            booking.customerName[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(booking.customerName,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              Text(booking.phone,
                                  style:
                                      TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        ),
                        _buildStatusBadge(booking.status),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                        Icons.event, 'Event Type', booking.eventType),
                    _buildInfoRow(
                        Icons.location_city, 'Hall', booking.hallName),
                    _buildInfoRow(Icons.calendar_today, 'Function Date',
                        DateFormat('dd MMM yyyy').format(booking.eventDate)),
                    _buildInfoRow(Icons.access_time, 'Time',
                        '${booking.startTime} - ${booking.endTime}'),
                    if (booking.notes != null && booking.notes!.isNotEmpty)
                      _buildInfoRow(
                          Icons.notes, 'Notes', booking.notes!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Payment summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment Summary',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const Divider(),
                    _buildAmountRow(
                        'Total Amount', booking.totalAmount, Colors.black),
                    _buildAmountRow('Total Paid', _totalPaid, Colors.green),
                    _buildAmountRow(
                      'Balance',
                      balance,
                      balance > 0 ? Colors.red : Colors.green,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Add payment buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addPayment(booking, 'advance'),
                    icon: const Icon(Icons.payments),
                    label: const Text('Add Advance Payment'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _addPayment(booking, 'final'),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Add Final Payment'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Payment history
            Text('Payment History',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_payments.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.payment,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('No payments recorded',
                            style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ),
              )
            else
              ..._payments.map((p) => _buildPaymentCard(p)),
          ],
        ),
      ),
    );
  }

  /// Extracted status badge to reduce rebuild cost in build().
  Widget _buildStatusBadge(String status) {
    final bool isConfirmed = status == 'confirmed';
    final bool isCompleted = status == 'completed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isConfirmed
            ? Colors.orange.withValues(alpha: 0.15)
            : isCompleted
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isConfirmed
              ? Colors.orange[800]
              : isCompleted
                  ? Colors.green[800]
                  : Colors.red[800],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(label,
                style:
                    TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '₹${NumberFormat('#,##0.00', 'en_IN').format(amount)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Payment payment) {
    final bool isAdvance = payment.type == 'advance';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => _editPayment(payment),
        leading: CircleAvatar(
          backgroundColor: isAdvance
              ? Colors.blue.withValues(alpha: 0.2)
              : Colors.green.withValues(alpha: 0.2),
          child: Icon(
            isAdvance ? Icons.payments : Icons.check_circle,
            color: isAdvance ? Colors.blue : Colors.green,
          ),
        ),
        title: Text(
          '${isAdvance ? 'Advance' : 'Final'} Payment',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
            '${DateFormat('dd MMM yyyy').format(payment.date)} • ${payment.paymentMethod.toUpperCase()}'),
        trailing: Text(
          '₹${NumberFormat('#,##0', 'en_IN').format(payment.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isAdvance ? Colors.blue : Colors.green,
          ),
        ),
      ),
    );
  }

  Future<void> _addPayment(Booking booking, String type) async {
    final amountController = TextEditingController();
    String paymentMethod = 'cash';
    DateTime paymentDate = DateTime.now();

    try {
      final result = await showDialog<Map<String, dynamic>>(
        // Use the widget's context for Provider access; rename dialogCtx for clarity.
        context: context,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(
                '${type == 'advance' ? 'Advance' : 'Final'} Payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                      'Date: ${DateFormat('dd/MM/yyyy').format(paymentDate)}'),
                  subtitle: const Text('Tap to change'),
                  trailing: const Icon(Icons.edit),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: paymentDate,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      final local = DateTime(
                          picked.year, picked.month, picked.day);
                      setDialogState(() => paymentDate = local);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount (₹)',
                    prefixIcon: const Icon(Icons.currency_rupee),
                    border: const OutlineInputBorder(),
                    hintText: type == 'final'
                        ? 'Balance: ₹${(booking.totalAmount - _totalPaid).toStringAsFixed(0)}'
                        : null,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payment),
                  ),
                  items: ['cash', 'upi', 'card', 'bank']
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child:
                                Text(m[0].toUpperCase() + m.substring(1)),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => paymentMethod = v!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final amount =
                      double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) return;
                  Navigator.pop(dialogCtx, {
                    'amount': amount,
                    'method': paymentMethod,
                    'date': paymentDate,
                  });
                },
                child: const Text('Add Payment'),
              ),
            ],
          ),
        ),
      );

      if (result == null) return;
      if (!mounted) return;

      final payment = Payment(
        bookingId: booking.id!,
        amount: result['amount'],
        type: type,
        paymentMethod: result['method'],
        date: result['date'] as DateTime,
      );
      await context.read<AppState>().addPayment(payment);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${type == 'advance' ? 'Advance' : 'Final'} payment added'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      // Dispose controller to prevent listener leaks.
      amountController.dispose();
    }
  }

  Future<void> _editPayment(Payment payment) async {
    final amountController =
        TextEditingController(text: payment.amount.toString());
    String paymentMethod = payment.paymentMethod;
    DateTime paymentDate = payment.date;

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Edit Payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                      'Date: ${DateFormat('dd/MM/yyyy').format(paymentDate)}'),
                  subtitle: const Text('Tap to change'),
                  trailing: const Icon(Icons.edit),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: paymentDate,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      final local = DateTime(
                          picked.year, picked.month, picked.day);
                      setDialogState(() => paymentDate = local);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    prefixIcon: Icon(Icons.currency_rupee),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payment),
                  ),
                  items: ['cash', 'upi', 'card', 'bank']
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child:
                                Text(m[0].toUpperCase() + m.substring(1)),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => paymentMethod = v!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final amount =
                      double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) return;
                  Navigator.pop(dialogCtx, {
                    'amount': amount,
                    'method': paymentMethod,
                    'date': paymentDate,
                  });
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );

      if (result == null) return;
      if (!mounted) return;

      final updated = Payment(
        id: payment.id,
        bookingId: payment.bookingId,
        amount: result['amount'],
        type: payment.type,
        paymentMethod: result['method'],
        date: result['date'] as DateTime,
      );
      await context.read<AppState>().updatePayment(updated);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Edit failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      amountController.dispose();
    }
  }

  Future<void> _shareWhatsApp(Booking booking) async {
    final dateStr = DateFormat('dd MMM yyyy').format(booking.eventDate);
    final fmt = NumberFormat('#,##0', 'en_IN');

    final graffitiCard = _GraffitiBookingCard(
      booking: booking,
      dateStr: dateStr,
      fmt: fmt,
    );

    // Pop any existing dialog first, then show the capture dialog.
    // Using an OverlayEntry avoids the stuck-dialog problem entirely.
    final overlay = OverlayEntry(
      builder: (ctx) => RepaintBoundary(
        key: _cardKey,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: graffitiCard,
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);

    // Wait for the overlay to render
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      if (!mounted) {
        overlay.remove();
        return;
      }
      final boundary = _cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('No boundary');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('No bytes');

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/booking_${booking.id}_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      overlay.remove();

      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: '🎉 Booking Confirmed - Kusetty Convention Hall',
        );
      }
    } catch (e) {
      overlay.remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Share failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteBooking(Booking booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Booking'),
        content: Text('Delete booking for ${booking.customerName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await context.read<AppState>().deleteBooking(booking.id!);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // =========================================================================
  // Invoice PDF Generation
  // =========================================================================

  Future<void> _generateInvoice(Booking booking) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Generating Invoice...'),
          ],
        ),
        duration: Duration(seconds: 15),
      ),
    );

    try {
      final pdf = pw.Document();
      final formatter = NumberFormat('#,##0.00', 'en_IN');
      final dateFormat = DateFormat('dd MMM yyyy');
      final today = DateTime.now();

      String fmt(num v) => '₹${formatter.format(v)}';

      final advanceTotal = _payments
          .where((p) => p.type == 'advance')
          .fold<double>(0, (s, p) => s + p.amount);
      final finalTotal = _payments
          .where((p) => p.type == 'final')
          .fold<double>(0, (s, p) => s + p.amount);
      final balance = booking.totalAmount - _totalPaid;

      final invoiceNo = 'INV-${booking.id}-${today.year}';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context pdfCtx) => [
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 16),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom:
                      pw.BorderSide(color: PdfColors.purple800, width: 2),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Kusetty Convention Hall',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.purple800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Main Hall & Rooftop Gardenia',
                        style: pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.purple800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        invoiceNo,
                        style: pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Bill To',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(booking.customerName,
                          style: const pw.TextStyle(fontSize: 12)),
                      pw.Text(booking.phone,
                          style: pw.TextStyle(
                              fontSize: 10, color: PdfColors.grey600)),
                      if (booking.notes != null &&
                          booking.notes!.isNotEmpty)
                        pw.Text(booking.notes!,
                            style: pw.TextStyle(
                                fontSize: 9, color: PdfColors.grey500)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _invoiceInfoRow(
                          'Invoice Date', dateFormat.format(today)),
                      _invoiceInfoRow('Booking Date',
                          dateFormat.format(booking.bookingDate)),
                      _invoiceInfoRow(
                          'Status', booking.status.toUpperCase()),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _eventRow('Event', booking.eventType),
                        _eventRow('Hall', booking.hallName),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _eventRow('Function Date',
                            dateFormat.format(booking.eventDate)),
                        _eventRow('Time',
                            '${booking.startTime} - ${booking.endTime}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Charges Summary',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.purple800,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['#', 'Description', 'Amount'],
              data: [
                [
                  '1',
                  'Hall Booking (${booking.hallName})',
                  fmt(booking.totalAmount)
                ],
                if (advanceTotal > 0)
                  ['', '  Advance Paid', fmt(advanceTotal)],
                if (finalTotal > 0)
                  ['', '  Final Payment', fmt(finalTotal)],
              ],
              border:
                  pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.purple800),
              cellStyle: const pw.TextStyle(fontSize: 9),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.4),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FlexColumnWidth(1.0),
              },
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _totalRow(
                      'Total Amount', fmt(booking.totalAmount), false),
                  _totalRow('Total Paid', fmt(_totalPaid), false),
                  pw.Divider(
                      thickness: 0.5, color: PdfColors.grey400),
                  _totalRow(
                    balance > 0 ? 'Balance Due' : 'Balance',
                    fmt(balance),
                    true,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            if (_payments.isNotEmpty) ...{
              pw.Text(
                'Payment History',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.purple800,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Type', 'Method', 'Amount'],
                data: _payments.map((p) {
                  final type =
                      p.type == 'advance' ? 'Advance' : 'Final';
                  final method = p.paymentMethod[0].toUpperCase() +
                      p.paymentMethod.substring(1);
                  return [
                    dateFormat.format(p.date),
                    type,
                    method,
                    fmt(p.amount),
                  ];
                }).toList(),
                border: pw.TableBorder.all(
                    color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                  color: PdfColors.white,
                ),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.green800),
                cellStyle: const pw.TextStyle(fontSize: 9),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.0),
                  1: const pw.FlexColumnWidth(0.8),
                  2: const pw.FlexColumnWidth(0.8),
                  3: const pw.FlexColumnWidth(1.0),
                },
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                },
              ),
              pw.SizedBox(height: 20),
            },
            if (_payments.isNotEmpty) ...{
              pw.Text(
                'Payment Method Summary',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.purple800,
                ),
              ),
              pw.SizedBox(height: 8),
              () {
                final methodTotals = <String, double>{};
                for (final p in _payments) {
                  methodTotals[p.paymentMethod] =
                      (methodTotals[p.paymentMethod] ?? 0) + p.amount;
                }
                return pw.TableHelper.fromTextArray(
                  headers: ['Method', 'Total', '%'],
                  data: methodTotals.entries.map((e) {
                    final pct = _totalPaid > 0
                        ? (e.value / _totalPaid * 100)
                        : 0;
                    return [
                      e.key[0].toUpperCase() + e.key.substring(1),
                      fmt(e.value),
                      '${pct.toStringAsFixed(1)}%',
                    ];
                  }).toList(),
                  border: pw.TableBorder.all(
                      color: PdfColors.grey300, width: 0.5),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                    color: PdfColors.white,
                  ),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.blue800),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.0),
                    1: const pw.FlexColumnWidth(1.0),
                    2: const pw.FlexColumnWidth(0.8),
                  },
                  cellAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.centerRight,
                    2: pw.Alignment.center,
                  },
                );
              }(),
              pw.SizedBox(height: 20),
            },
            pw.Divider(color: PdfColors.grey300, thickness: 0.5),
            pw.SizedBox(height: 8),
            pw.Text(
              'Thank you for choosing Kusetty Convention Hall!',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.purple700,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated on ${dateFormat.format(today)} at ${DateFormat('hh:mm a').format(today)}',
              style:
                  pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
            ),
          ],
        ),
      );

      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/Invoice_${booking.id}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        await Share.shareXFiles(
          [XFile(file.path)],
          text:
              'Invoice — ${booking.customerName} • Kusetty Convention Hall',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Helper widgets for invoice PDF — defined as class-level methods returning pw.Widgets.
  pw.Widget _invoiceInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('$label: ',
              style: pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey600)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _eventRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.Text('$label: ',
              style: pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey600)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _totalRow(String label, String amount, bool bold) {
    return pw.Container(
      width: 200,
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                fontSize: bold ? 10 : 9,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              )),
          pw.Text(amount,
              style: pw.TextStyle(
                fontSize: bold ? 11 : 9,
                fontWeight: pw.FontWeight.bold,
                color: bold ? PdfColors.purple800 : PdfColors.black,
              )),
        ],
      ),
    );
  }
}

// =========================================================================
// Graffiti-style Booking Confirmation Card (shared as image)
// =========================================================================

class _GraffitiBookingCard extends StatelessWidget {
  final Booking booking;
  final String dateStr;
  final NumberFormat fmt;

  const _GraffitiBookingCard({
    required this.booking,
    required this.dateStr,
    required this.fmt,
  });

  Color _statusColor() {
    switch (booking.status) {
      case 'completed':
        return const Color(0xFF00E676);
      case 'cancelled':
        return const Color(0xFFFF5252);
      default:
        return const Color(0xFFFFD740);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B5E20),
              Color(0xFF2E7D32),
              Color(0xFF388E3C),
              Color(0xFF1B5E20),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(8, (i) => _sprayDot()),
            ),
            const SizedBox(height: 16),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/logo.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.meeting_room,
                    size: 50,
                    color: Colors.cyanAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Colors.white,
                  Color(0xFF66BB6A),
                  Color(0xFFA5D6A7)
                ],
              ).createShader(bounds),
              child: const Text(
                'BOOKING\nCONFIRMED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 4,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Kusetty Convention Hall',
              style: TextStyle(
                fontSize: 13,
                color: Colors.greenAccent.withValues(alpha: 0.9),
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                border: Border(
                  left:
                      BorderSide(color: Colors.greenAccent, width: 4),
                ),
              ),
              child: Text(
                booking.customerName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _graffitiRow(Icons.event, 'Function', dateStr),
            const SizedBox(height: 8),
            _graffitiRow(Icons.access_time, 'Time',
                '${booking.startTime} - ${booking.endTime}'),
            const SizedBox(height: 8),
            _graffitiRow(
                Icons.location_city, 'Hall', booking.hallName),
            const SizedBox(height: 8),
            _graffitiRow(
                Icons.theater_comedy, 'Event', booking.eventType),
            const Divider(color: Colors.white24, height: 24),
            Row(
              children: [
                Expanded(
                    child: _amountBox(
                        'Total', booking.totalAmount, Colors.greenAccent)),
                const SizedBox(width: 8),
                Expanded(
                    child: _amountBox(
                        'Advance', booking.advanceAmount, Colors.white)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                border:
                    Border.all(color: _statusColor(), width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                booking.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _statusColor(),
                  letterSpacing: 3,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '#MomentsMadeMemorable',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.withValues(alpha: 0.5),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(8, (i) => _sprayDot()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sprayDot() {
    final colors = [
      Colors.greenAccent,
      Colors.lightGreenAccent,
      Colors.white,
      Colors.greenAccent,
    ];
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: colors[DateTime.now().millisecondsSinceEpoch % 4]
            .withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _graffitiRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon,
            size: 16,
            color: Colors.greenAccent.withValues(alpha: 0.7)),
        const SizedBox(width: 10),
        SizedBox(
          width: 65,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.withValues(alpha: 0.6),
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _amountBox(String label, double amount, Color accent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: accent.withValues(alpha: 0.8),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${fmt.format(amount)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}
