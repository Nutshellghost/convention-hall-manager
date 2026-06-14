import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/booking.dart';
import '../models/payment.dart';

class AddBookingScreen extends StatefulWidget {
  final Booking? booking;

  const AddBookingScreen({super.key, this.booking});

  @override
  State<AddBookingScreen> createState() => _AddBookingScreenState();
}

class _AddBookingScreenState extends State<AddBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _advanceAmountController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _bookingDate = DateTime.now();
  DateTime _eventDate = DateTime.now();
  final _eventTypeController = TextEditingController();
  String _hallName = 'Main Hall';
  String _startTime = '06:00';
  String _endTime = '17:00';
  bool _loading = false;

  final List<String> _hallNames = [
    'Main Hall', 'Rooftop Gardenia',
  ];

  final List<String> _timeSlots = [
    '06:00', '07:00', '08:00', '09:00', '10:00', '11:00',
    '12:00', '13:00', '14:00', '15:00', '16:00', '17:00',
    '18:00', '19:00', '20:00', '21:00', '22:00', '23:00',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.booking != null) {
      final b = widget.booking!;
      _nameController.text = b.customerName;
      _phoneController.text = b.phone;
      _totalAmountController.text = b.totalAmount.toString();
      _advanceAmountController.text = b.advanceAmount.toString();
      _notesController.text = b.notes ?? '';
      _bookingDate = b.bookingDate ?? DateTime.now();
      _eventDate = b.eventDate;
      _eventTypeController.text = b.eventType;
      _hallName = b.hallName;
      _startTime = b.startTime;
      _endTime = b.endTime;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _totalAmountController.dispose();
    _advanceAmountController.dispose();
    _notesController.dispose();
    _eventTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.booking != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Booking' : 'New Booking')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Customer Section
              Text('Customer Details', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim().length < 10) return 'Enter valid phone';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Event Section
              Text('Event Details', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _eventTypeController,
                decoration: const InputDecoration(
                  labelText: 'Event Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.event),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _hallName,
                decoration: const InputDecoration(
                  labelText: 'Hall',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
                items: _hallNames.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                onChanged: (v) => setState(() => _hallName = v!),
              ),
              const SizedBox(height: 12),

              // Booking Date picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text('Booking Date: ${_bookingDate.day}/${_bookingDate.month}/${_bookingDate.year}'),
                subtitle: Text('Tap to change'),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _bookingDate,
                    firstDate: DateTime(2023),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    final local = DateTime(picked.year, picked.month, picked.day);
                    setState(() => _bookingDate = local);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Event Date picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text('Date: ${_eventDate.day}/${_eventDate.month}/${_eventDate.year}'),
                subtitle: Text('Tap to change'),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _eventDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    final local = DateTime(picked.year, picked.month, picked.day);
                    setState(() => _eventDate = local);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Time slots
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _startTime,
                      decoration: const InputDecoration(
                        labelText: 'Start Time',
                        border: OutlineInputBorder(),
                      ),
                      items: _timeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _startTime = v!),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('to'),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _endTime,
                      decoration: const InputDecoration(
                        labelText: 'End Time',
                        border: OutlineInputBorder(),
                      ),
                      items: _timeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _endTime = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Payment Section
              Text('Payment Details', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _totalAmountController,
                decoration: const InputDecoration(
                  labelText: 'Total Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _advanceAmountController,
                decoration: const InputDecoration(
                  labelText: 'Advance Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _loading ? null : _saveBooking,
                icon: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(isEditing ? 'Update Booking' : 'Save Booking'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveBooking() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final booking = Booking(
        id: widget.booking?.id,
        customerName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        eventDate: _eventDate,
        bookingDate: _bookingDate,
        eventType: _eventTypeController.text.trim(),
        hallName: _hallName,
        startTime: _startTime,
        endTime: _endTime,
        totalAmount: double.parse(_totalAmountController.text.trim()),
        advanceAmount: double.tryParse(_advanceAmountController.text.trim()) ?? 0,
        status: widget.booking?.status ?? 'confirmed',
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: widget.booking?.createdAt,
      );

      final state = context.read<AppState>();
      if (widget.booking != null) {
        await state.updateBooking(booking);
      } else {
        final id = await state.addBooking(booking);
        // If advance amount > 0, also record it as an advance payment
        if (booking.advanceAmount > 0) {
          await state.addPayment(Payment(
            bookingId: id,
            amount: booking.advanceAmount,
            type: 'advance',
            date: _bookingDate,
          ));
        }
      }

      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.booking != null ? 'Booking updated' : 'Booking created')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
