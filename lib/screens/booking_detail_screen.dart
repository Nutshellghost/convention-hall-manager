import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final state = context.read<AppState>();
    _booking = await state.getBooking(widget.bookingId);
    _payments = await state.getPaymentsForBooking(widget.bookingId);
    _totalPaid = await state.getTotalPaymentsForBooking(widget.bookingId);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: const Center(child: CircularProgressIndicator()),
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
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                              Text(booking.customerName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              Text(booking.phone, style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: booking.status == 'confirmed'
                                ? Colors.orange.withOpacity(0.15)
                                : booking.status == 'completed'
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            booking.status.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: booking.status == 'confirmed'
                                  ? Colors.orange[800]
                                  : booking.status == 'completed'
                                      ? Colors.green[800]
                                      : Colors.red[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(Icons.event, 'Event Type', booking.eventType),
                    _buildInfoRow(Icons.location_city, 'Hall', booking.hallName),
                    _buildInfoRow(Icons.calendar_today, 'Function Date', DateFormat('dd MMM yyyy').format(booking.eventDate)),
                    _buildInfoRow(Icons.access_time, 'Time', '${booking.startTime} - ${booking.endTime}'),
                    if (booking.notes != null && booking.notes!.isNotEmpty)
                      _buildInfoRow(Icons.notes, 'Notes', booking.notes!),
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
                    const Text('Payment Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Divider(),
                    _buildAmountRow('Total Amount', booking.totalAmount, Colors.black),
                    _buildAmountRow('Total Paid', _totalPaid, Colors.green),
                    _buildAmountRow('Balance', balance, balance > 0 ? Colors.red : Colors.green),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Add payment button
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: balance > 0 ? () => _addPayment(booking, 'advance') : null,
                    icon: const Icon(Icons.payments),
                    label: const Text('Add Advance Payment'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: balance > 0 ? () => _addPayment(booking, 'final') : null,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Add Final Payment'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Payment history
            Text('Payment History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_payments.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.payment, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('No payments recorded', style: TextStyle(color: Colors.grey[500])),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => _editPayment(payment),
        leading: CircleAvatar(
          backgroundColor: payment.type == 'advance'
              ? Colors.blue.withOpacity(0.2)
              : Colors.green.withOpacity(0.2),
          child: Icon(
            payment.type == 'advance' ? Icons.payments : Icons.check_circle,
            color: payment.type == 'advance' ? Colors.blue : Colors.green,
          ),
        ),
        title: Text(
          '${payment.type == 'advance' ? 'Advance' : 'Final'} Payment',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${DateFormat('dd MMM yyyy').format(payment.date)} • ${payment.paymentMethod.toUpperCase()}'),
        trailing: Text(
          '₹${NumberFormat('#,##0', 'en_IN').format(payment.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: payment.type == 'advance' ? Colors.blue : Colors.green,
          ),
        ),
      ),
    );
  }

  Future<void> _addPayment(Booking booking, String type) async {
    final amountController = TextEditingController();
    String paymentMethod = 'cash';
    DateTime paymentDate = DateTime.now();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${type == 'advance' ? 'Advance' : 'Final'} Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text('Date: ${DateFormat('dd/MM/yyyy').format(paymentDate)}'),
                subtitle: const Text('Tap to change'),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: paymentDate,
                    firstDate: DateTime(2023),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    final local = DateTime(picked.year, picked.month, picked.day);
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
                      child: Text(m[0].toUpperCase() + m.substring(1)),
                    ))
                    .toList(),
                onChanged: (v) => setDialogState(() => paymentMethod = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) return;
                Navigator.pop(context, {'amount': amount, 'method': paymentMethod, 'date': paymentDate});
              },
              child: const Text('Add Payment'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final payment = Payment(
        bookingId: booking.id!,
        amount: result['amount'],
        type: type,
        paymentMethod: result['method'],
        date: result['date'] as DateTime,
      );
      await context.read<AppState>().addPayment(payment);
      await _loadData();
    }
  }

  Future<void> _editPayment(Payment payment) async {
    final amountController = TextEditingController(text: payment.amount.toString());
    String paymentMethod = payment.paymentMethod;
    DateTime paymentDate = payment.date;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text('Date: ${DateFormat('dd/MM/yyyy').format(paymentDate)}'),
                subtitle: const Text('Tap to change'),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: paymentDate,
                    firstDate: DateTime(2023),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    final local = DateTime(picked.year, picked.month, picked.day);
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
                      child: Text(m[0].toUpperCase() + m.substring(1)),
                    ))
                    .toList(),
                onChanged: (v) => setDialogState(() => paymentMethod = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) return;
                Navigator.pop(context, {'amount': amount, 'method': paymentMethod, 'date': paymentDate});
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
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
    }
  }

  Future<void> _shareWhatsApp(Booking booking) async {
    // Show a brief preview then capture
    final dateStr = DateFormat('dd MMM yyyy').format(booking.eventDate);
    final fmt = NumberFormat('#,##0', 'en_IN');

    final graffitiCard = _GraffitiBookingCard(
      booking: booking,
      dateStr: dateStr,
      fmt: fmt,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RepaintBoundary(
        key: _cardKey,
        child: graffitiCard,
      ),
    );

    // Wait for the dialog to render
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final boundary = _cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('No boundary');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('No bytes');

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/booking_${booking.id}_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      if (context.mounted) Navigator.pop(context); // close dialog

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '🎉 Booking Confirmed - Kusetty Convention Hall',
      );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteBooking(Booking booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Booking'),
        content: Text('Delete booking for ${booking.customerName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<AppState>().deleteBooking(booking.id!);
      if (context.mounted) Navigator.pop(context);
    }
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
      case 'completed': return const Color(0xFF00E676);
      case 'cancelled': return const Color(0xFFFF5252);
      default: return const Color(0xFFFFD740);
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
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
              Color(0xFF1A1A2E),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // === Spray dots decoration ===
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(8, (i) => _sprayDot()),
            ),
            const SizedBox(height: 16),

            // === Logo ===
            ClipOval(
              child: Image.asset(
                'assets/logo.png',
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.meeting_room,
                  size: 50,
                  color: Colors.cyanAccent,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // === Title - Graffiti style ===
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFF6EC7), Color(0xFFFFD740), Color(0xFF00E5FF)],
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
                color: Colors.cyanAccent.withOpacity(0.8),
                letterSpacing: 3,
              ),
            ),

            const SizedBox(height: 20),

            // === Customer highlight strip ===
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                border: Border(
                  left: BorderSide(color: Colors.pinkAccent, width: 4),
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

            // === Details ===
            _graffitiRow(Icons.event, 'Function', dateStr),
            const SizedBox(height: 8),
            _graffitiRow(Icons.access_time, 'Time', '${booking.startTime} - ${booking.endTime}'),
            const SizedBox(height: 8),
            _graffitiRow(Icons.location_city, 'Hall', booking.hallName),
            const SizedBox(height: 8),
            _graffitiRow(Icons.theater_comedy, 'Event', booking.eventType),

            const Divider(color: Colors.white24, height: 24),

            // === Amounts ===
            Row(
              children: [
                Expanded(child: _amountBox('Total', booking.totalAmount, const Color(0xFF00E5FF))),
                const SizedBox(width: 8),
                Expanded(child: _amountBox('Advance', booking.advanceAmount, const Color(0xFFFF6EC7))),
              ],
            ),

            const SizedBox(height: 16),

            // === Status badge ===
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: _statusColor(), width: 2),
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

            // === Tagline ===
            Text(
              '#MomentsMadeMemorable',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.withOpacity(0.5),
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 12),

            // === Bottom spray dots ===
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
      Colors.pinkAccent,
      Colors.cyanAccent,
      Colors.amberAccent,
      Colors.limeAccent,
    ];
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: colors[DateTime.now().millisecondsSinceEpoch % 4].withOpacity(0.3),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _graffitiRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.cyanAccent.withOpacity(0.7)),
        const SizedBox(width: 10),
        SizedBox(
          width: 65,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.withOpacity(0.6),
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
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: accent.withOpacity(0.8),
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
